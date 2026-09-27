---
title: SeaweedFS 이론 — Master·Volume·Filer의 분리
description: SeaweedFS의 경로 메타데이터와 파일 바이트 저장 구조, 읽기·쓰기 흐름을 설명합니다.
date: 2026-09-23
tags: [SeaweedFS, Storage, Architecture]
draft: false
---

SeaweedFS는 파일의 **이름과 경로**를 관리하는 계층과 **실제 바이트**를 저장하는 계층을 분리한 분산 저장 시스템입니다. 작은 파일을 볼륨 내부에 연속으로 저장하는 설계가 핵심입니다. S3 호환 API를 사용할 때는 S3 Gateway와 Filer를 거치므로, 단순 blob(binary large object) API의 직접 접근 경로와 구분하셔야 합니다.

![SeaweedFS의 S3, Filer, Master, Volume Server 구조](/images/posts/data-platform-theory/seaweedfs-architecture.svg)

SeaweedFS 공식 저장소의 그림은 Master, Volume Server, Filer의 배치를 보여 줍니다. 공식 개념도를 함께 두어, 이론 설명의 청크·Filer metadata 경로를 제품 그림과 대조할 수 있게 했습니다.

![SeaweedFS 공식 아키텍처 그림](/images/posts/data-platform-theory/official/seaweedfs-official.png)

[그림 출처: SeaweedFS README — Architecture](https://github.com/seaweedfs/seaweedfs/blob/master/README.md#architecture)

## 구성요소와 메타데이터의 위치

| 구성요소 | 담당 정보 |
|---|---|
| Master | 어떤 Volume Server에 어떤 볼륨이 있는지 추적하고 쓰기에 사용할 파일 ID를 배정합니다. 개별 파일 경로 전체를 보관하는 서비스는 아닙니다. |
| Volume Server | 파일 바이트를 볼륨의 needle로 저장합니다. 볼륨 내부 인덱스가 파일 키를 데이터 위치에 연결합니다. |
| Filer | 디렉터리와 파일 경로를 제공하고, 경로가 참조하는 청크·파일 ID를 관리합니다. 큰 파일은 청크로 나눌 수 있습니다. |
| Filer Metadata Store | 경로·속성·청크 참조를 지속 저장하는 DB입니다. 실제 파일 바이트와 별도입니다. |
| S3 Gateway | S3 요청을 Filer 기반 객체 접근으로 바꿉니다. 배포 시 선택하는 접근 계층입니다. |

## 객체 하나를 써 보겠습니다

1. 클라이언트가 S3 Gateway에 객체를 보내면 Filer가 경로와 청크를 처리합니다.
2. Filer는 Master에 쓸 위치와 파일 ID를 요청합니다. Master는 볼륨 위치를 알려 줍니다.
3. 바이트는 Volume Server에 기록되고, Filer는 경로와 파일 ID의 연결을 Metadata Store에 기록합니다.
4. 읽을 때는 경로 메타데이터에서 파일 ID를 찾고, 해당 볼륨 위치를 알아낸 뒤 Volume Server의 바이트를 읽습니다. 순수 blob 접근에서는 위치를 캐시해 Master를 읽기 경로에서 제외할 수 있습니다.

**복제**는 여러 사본을 두는 방식이고, **Erasure Coding(EC)**은 데이터를 조각과 패리티로 나누는 방식입니다. 둘은 저장 공간과 복구 비용이 다르며, EC는 운영 정책과 시점에 따라 백그라운드에서 적용됩니다. Filer DB의 백업과 Volume 데이터의 백업은 서로 다른 대상을 보호하므로 둘 다 필요합니다.

## 파일 ID와 인덱스가 데이터 경로를 짧게 만듭니다

SeaweedFS의 파일 ID(FID)는 볼륨을 식별하는 부분과 해당 볼륨 안의 파일 키·쿠키로 구성됩니다. Master는 볼륨 배치와 ID 발급을 담당하고, Volume Server의 인덱스는 파일 키를 볼륨 파일 내부의 오프셋·크기에 연결합니다. 파일마다 운영체제 파일 하나를 만들지 않고 여러 작은 파일을 볼륨 파일에 이어 쓰기 때문에 작은 객체가 매우 많은 경우 파일 시스템의 inode 부담을 줄일 수 있습니다.

여기서 “Master가 파일을 찾는다”는 표현은 절반만 맞습니다. 먼저 볼륨 ID를 Volume Server 주소로 바꾸는 위치 확인에는 Master 정보가 필요하지만, 파일 바이트의 위치는 Volume Server 내부 인덱스가 찾습니다. 위치를 얻은 클라이언트는 이후 데이터 요청을 Volume Server로 직접 보낼 수 있습니다.

## 경로 계층과 blob 계층의 정합성

Filer를 사용하는 파일 경로는 외부 Metadata Store와 실제 볼륨 데이터의 두 상태를 연결합니다. 경로 레코드가 있는데 바이트가 없거나, 데이터는 있지만 참조 메타데이터가 없으면 사용자 관점에서 파일이 사라지거나 고아 데이터가 됩니다. 따라서 장애 복구와 백업에서는 Filer DB를 복구하는 시간점과 Volume 데이터를 보존하는 정책을 함께 설계해야 합니다. 이 둘은 각각 독립적으로 복구되더라도 서로 일치하는 스냅샷인지 확인해야 합니다.

## 복제와 EC의 목적

복제는 같은 데이터를 여러 곳에 보관해 읽기 가용성과 단순한 복구를 제공합니다. EC는 데이터와 패리티 조각을 여러 서버에 분산해 전체 복제보다 저장 공간 효율을 높이는 대신, 손실 조각을 재구성할 계산과 네트워크 비용이 필요합니다. 어느 방식을 쓸지는 객체의 읽기 온도, 장애 도메인, 복구 시간 목표, 여유 용량을 기준으로 정합니다. “복제 수가 곧 백업 수”는 아닙니다. 운영자 실수나 논리적 삭제는 사본에도 전파될 수 있으므로 별도 백업 정책이 필요합니다.

운영 시 파일이 안 보이면 Filer 메타데이터 조회 → Master 볼륨 위치 → Volume Server의 볼륨·needle 상태 순서로 추적해 보세요. 이름을 찾는 실패와 바이트를 읽는 실패를 분리할 수 있습니다.

## 실무 적용: 데이터 레이크와 공용 파일 저장소

사내에서는 SeaweedFS를 **데이터 레이크 겸 사내 공용 파일 저장소**로 씁니다. 같은 클러스터를 Filer HTTP 경로와 S3 API 두 방식으로 접근합니다.

| 용도 | 접근 방식 | 사용하는 쪽 |
|---|---|---|
| Nginx 원본 로그 보관 (`weblogs/<서버>/<날짜>/…gz`) | Filer HTTP | Airflow 센서가 HEAD 요청으로 파일 도착 확인, fastlog-etl이 다운로드 |
| 정규화된 로그 Parquet (`<appid>/logdate=/inputdatetime=`) | S3 API | fastlog-etl이 업로드, Doris Broker Load가 직접 읽음 |
| GeoIP DB (`.mmdb`) | S3 API | 주간 Airflow DAG가 최신본과 날짜별 아카이브를 업로드, ETL이 매 실행 다운로드 |
| Airbyte 커넥터 manifest | Filer | GitLab CI가 master 머지 시 저장소 파일을 동기화 |

이론에서 "이름(Filer 메타데이터)과 바이트(Volume)는 다른 곳에 있다"고 설명했는데, 파이프라인은 주로 **이름 계층**을 계약으로 삼습니다. 센서는 경로가 존재하는지만 보고, 적재는 `inputdatetime` prefix 단위로 지우고 다시 씁니다. 경로 규칙이 곧 파티션이자 멱등성의 단위입니다.

### 운영에서 만난 문제

- **S3 서명 호환성**: Doris Broker Load 하나에 여러 S3 경로를 묶으면 두 번째 경로에서 서명 불일치로 거부되는 경우가 있어, 경로마다 별도 Load로 나눠 실행합니다. S3 호환 API라도 AWS S3와 세부 동작이 같다고 가정하면 안 됩니다.
- **EC와 TTL**: 가장 큰 용량을 차지하는 웹 로그에는 TTL 60일을 걸어 자동 삭제합니다. 자주 삭제되는 로그성 데이터에 EC가 오히려 용량 문제를 일으킨 경험은 [SeaweedFS 디스크 용량 트러블슈팅](../DE/seaweedfs-disk-troubleshooting-erasure-coding)에 정리했습니다. 이론에서 본 "EC는 읽기 온도와 워크로드에 맞춰 고른다"는 기준을 실제로 체감한 사례입니다.
- **디스크 장애**: HDD 하나가 사라졌을 때 오래된(stale) 복제본을 안전하게 복구한 과정은 [SeaweedFS stale replica 복구 경험](../de/seaweedfs3-hdd-failure-replica-recovery)에 있습니다.
**공식 문서:** [SeaweedFS README Architecture](https://github.com/seaweedfs/seaweedfs/blob/master/README.md#architecture), [SeaweedFS Architecture PDF](https://github.com/seaweedfs/seaweedfs/wiki/SeaweedFS_Architecture.pdf)
