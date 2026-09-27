---
title: AWS DMS 이론 — Full load와 CDC가 이어지는 복제 작업
description: AWS DMS의 Endpoint, Replication Instance, Task와 Full load·CDC 데이터 흐름을 설명합니다.
date: 2026-09-26
tags: [AWS, DMS, CDC, DataEngineering, Architecture]
draft: false
---
AWS Database Migration Service(DMS)는 원본 데이터 저장소에서 데이터를 읽고 대상 저장소에 적재하는 데이터 이동 서비스입니다. 데이터베이스 이전 시 전체 데이터를 복사하거나, 초기 적재와 함께 원본의 변경 로그를 읽어 대상에 변경분을 반영할 수 있습니다. DMS가 원본과 대상의 모든 스키마 차이와 애플리케이션 로직을 자동으로 해결하는 범용 변환 엔진은 아닙니다.

![AWS DMS의 Full load, 변경 캐시, CDC 흐름](/images/posts/data-platform-theory/aws-dms-architecture.svg)

![AWS 공식 문서의 Replication Instance와 Task 구성 예시](https://docs.aws.amazon.com/images/dms/latest/userguide/images/datarep-intro-rep-task1.png)

[공식 그림 출처: Components of AWS DMS](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Components.html)

## 구성요소는 연결·실행·규칙으로 나눕니다

| 구성요소                 | 역할                                                    | 설계 시 볼 부분                                                                 |
| -------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------- |
| Source Endpoint      | 원본 DB의 주소, 엔진, 자격 증명과 CDC에 필요한 로그 설정을 정의합니다.          | DMS Replication Instance에서 네트워크로 연결 가능해야 하며, 엔진별 CDC 권한과 로그 보존 설정이 필요합니다. |
| Target Endpoint      | 대상 DB나 지원 대상 저장소에 연결하는 정보를 정의합니다.                     | 접속 권한, 테이블 준비 모드, 대상 쓰기 처리량과 네트워크 경로가 필요합니다.                              |
| Replication Instance | 하나 이상의 DMS Task를 실행하는 관리형 복제 컴퓨팅입니다.                  | CPU·메모리·네트워크·스토리지 용량이 동시 Task와 데이터 지연에 영향을 줍니다.                           |
| Replication Task     | 원본·대상 Endpoint, 선택 테이블, 처리 방식, 로깅·오류 규칙을 묶은 실행 단위입니다. | Full load, Full load + CDC, CDC only 중 데이터의 시작 상태에 맞는 방식을 선택합니다.          |
| Table Mapping        | 어떤 스키마·테이블을 포함할지와 이름 변환 등 선택 규칙을 지정합니다.               | 포함 규칙을 넓히면 의도하지 않은 테이블을 옮길 수 있으므로 범위를 검증합니다.                              |

DMS Replication Instance는 Task를 실행하는 역할이고 Endpoint는 연결 정보를 나타냅니다. 데이터가 Replication Instance를 거쳐 이동하더라도, 원본 DB가 CDC 로그를 유지하고 대상 DB가 변경 속도를 따라갈 수 있어야 복제 지연이 지속적으로 낮아집니다.

## Full load + CDC의 데이터 흐름

1. 원본과 대상 Endpoint를 만들고 연결 테스트를 합니다. 보안 그룹·서브넷·라우팅·포트·TLS 설정과 DB 계정 권한을 확인합니다.
2. Replication Task에 원본 Endpoint, 대상 Endpoint, Table Mapping과 마이그레이션 방식을 지정합니다.
3. Full load가 기존 테이블 데이터를 읽어 대상으로 병렬 적재합니다. 이 단계에서 원본의 변경이 발생하면 DMS는 변경분을 캡처해 Replication Instance에 보관합니다.
4. 개별 테이블의 Full load가 끝나면 그 테이블의 캐시된 변경분을 적용하고, 이후 변경 로그를 따라가는 CDC를 지속합니다.
5. 대상 지연이 충분히 줄어든 뒤 전환 시점에 쓰기를 중단하거나 제한하고, 남은 변경을 반영한 다음 애플리케이션을 새 DB로 전환합니다.

Full load와 변경 캡처는 Task 전체에서 하나의 원자적 스냅샷이 아니라 테이블별 처리 흐름으로 진행될 수 있습니다. 공식 문서는 각 테이블의 Full load가 시작될 때부터 변경 캡처를 시작하며, Full load 완료 후 해당 테이블의 캐시 변경을 적용한다고 설명합니다. 따라서 여러 테이블에 걸친 비즈니스 트랜잭션의 시점 일관성이 중요하면 전환 계획에서 애플리케이션 쓰기 정지, 검증, 재조정 절차를 별도로 설계해야 합니다.

## 세 가지 마이그레이션 방식

| 방식 | 시작 조건과 동작 | 자주 쓰는 상황 |
|---|---|---|
| Full load | 원본의 기존 데이터를 대상으로 복사합니다. 계속 변경을 추적하지는 않습니다. | 이전 후 원본을 더 이상 사용하지 않거나 변경분을 다른 방식으로 맞출 수 있는 경우입니다. |
| Full load + CDC | 기존 데이터를 복사하면서 변경을 캡처하고, 이후 변경분을 적용합니다. | 원본 사용을 유지한 채 대상 DB를 준비하고, 지연을 따라잡은 뒤 전환하려는 경우입니다. |
| CDC only | 기존 데이터가 이미 대상에 있고, 지정한 로그 위치 이후의 변경만 복제합니다. | 별도 벌크 로드 후 변경분을 맞추거나 이미 초기화한 데이터셋을 동기화할 때 사용합니다. |

CDC는 DB 엔진의 고유 변경 로그를 읽는 방식입니다. 예를 들어 MySQL 계열은 row 기반 binlog, PostgreSQL은 logical replication slot과 디코딩 구성을 사용할 수 있습니다. 따라서 Endpoint 종류마다 사전 설정이 다릅니다. DMS CDC를 “실시간”이라고 단정할 수는 없습니다. AWS 문서는 원본 부하, 네트워크, Replication Instance, 대상 수용량 등에 따라 지연이 달라지고 CDC 지연 SLA가 없다고 안내합니다.

## 버퍼와 지연은 병목 위치를 알려줍니다

Full load 중 캡처한 변경은 우선 메모리에서 버퍼링될 수 있고, 메모리가 부족하면 Replication Instance 디스크에 저장될 수 있습니다. 원본 변경 생성 속도보다 대상 적용 속도가 느리면 변경 캐시가 쌓이고 지연이 늘어납니다. Task 모니터링의 `CDCLatencySource`와 `CDCLatencyTarget`을 함께 보면 변경을 원본에서 읽는 구간과 대상에 적용하는 구간을 나누어 살필 수 있습니다.

- `CDCLatencySource`가 증가하면 원본 로그 읽기, 원본 연결, Task 처리 능력을 확인합니다.
- Source 지연은 낮지만 Target 지연이 높으면 대상 쓰기 병목, 인덱스·제약, 네트워크, Replication Instance의 apply 용량을 살펴봅니다.
- 메모리 부족과 디스크 캐시 증가는 Full load 테이블 병렬도, 동시 Task 수, 인스턴스 크기와 함께 분석합니다.

Task 수를 무조건 늘리는 것이 처리량을 높이는 것은 아닙니다. 여러 Task가 하나의 Replication Instance CPU·메모리·네트워크를 공유하고, 대상 DB에는 동시에 더 많은 쓰기 부하가 걸릴 수 있습니다. 충분한 로그 보존 기간은 Task 중단 후 재개할 수 있는 시간 범위와도 연결됩니다.

## 데이터 이동과 스키마 변환은 분리합니다

DMS는 데이터 복제에 필요한 테이블 등을 생성할 수 있지만, 모든 데이터베이스 객체와 프로시저를 완전히 변환하는 기능과는 구분해야 합니다. AWS DMS Schema Conversion은 별도의 기능으로 스키마와 일부 코드 객체를 대상 DB에 맞게 변환하는 데 사용됩니다. 변환이 되지 않는 객체는 수동 수정과 테스트가 필요할 수 있습니다.

마이그레이션 전후에는 테이블 행 수와 대표 집계, PK·NULL 조건, 문자셋·시간대, LOB 컬럼, 데이터 타입 변환을 검증합니다. Task가 `Running`이라는 것은 복제 엔진의 상태이지 업무 데이터의 의미적 동등성이 모두 검증되었다는 뜻은 아닙니다.

## 운영 전 체크 항목

- 원본 DB의 CDC 사전 요건, 로그 활성화와 보존 기간을 확인합니다.
- Replication Instance가 원본과 대상에 모두 접근하도록 VPC 경로와 보안 규칙을 구성합니다.
- Full load 시 테이블 병렬도와 원본·대상 DB 부하를 측정합니다.
- Task 재시작·테이블 재적재 때 대상 데이터가 어떻게 준비되는지 `TargetTablePrepMode`를 결정합니다.
- 컷오버 기준을 지연 수치 하나에만 두지 않고, 쓰기 중단·최종 검증·되돌리기 계획까지 정합니다.

서버리스 복제 옵션도 제공되지만, 이 장의 설명은 Replication Instance 기반의 기본 구성요소와 Full load + CDC의 일반 흐름에 초점을 둡니다. 서버리스의 초기화 시간, 용량 단위와 운영 특성은 별도 문서에서 확인해야 합니다.

## 핵심 정리

DMS Task는 Endpoint 사이에서 초기 데이터를 옮기고 변경 로그를 적용하는 실행 단위입니다. Full load + CDC의 핵심은 기존 데이터를 옮기는 동안 생긴 변경분을 안전하게 버퍼링하고, 적용 지연을 따라잡아 컷오버 시점을 만드는 데 있습니다. 성공 상태만으로 일관성과 완전성을 단정하지 말고, 로그 보존·대상 처리량·검증·전환 절차까지 함께 설계해야 합니다.

**공식 문서:** [Components of AWS DMS](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Components.html), [High-level view of AWS DMS](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.HighLevelView.html), [Working with AWS DMS tasks](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.html), [Ongoing replication and CDC](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Task.CDC.html), [Replication Instance sizing](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_BestPractices.SizingReplicationInstance.html)
