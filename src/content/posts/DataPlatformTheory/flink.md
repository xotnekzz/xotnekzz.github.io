---
title: Apache Flink 이론 — JobManager·TaskManager·상태와 체크포인트
description: Flink의 분산 데이터 흐름, 상태 저장, 체크포인트와 장애 복구를 설명합니다.
date: 2026-09-23
tags: [Flink, StreamProcessing, Architecture]
draft: false
---

Apache Flink는 유한한 배치와 끝없이 들어오는 스트림을 데이터 흐름으로 실행하는 분산 처리 엔진입니다. 특히 이벤트를 처리하며 유지하는 **상태(State)**와 장애 후 복구 지점인 **Checkpoint**를 함께 이해하면 구조가 선명해집니다.

![Flink의 JobManager, TaskManager, 상태와 Sink 경로](/images/posts/data-platform-theory/flink-architecture.svg)

Flink 공식 문서의 런타임 그림은 Client가 JobGraph를 제출하고 JobManager가 TaskManager 실행을 조정하는 관계를 보여 줍니다. 공식 그림에는 연산자 내부 상태와 체크포인트 흐름이 생략되어 있어, 아래 개념도와 이어서 보시면 좋습니다.

![Apache Flink 공식 문서의 분산 런타임 아키텍처](/images/posts/data-platform-theory/official/flink-official.svg)

[그림 출처: Flink Architecture](https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/flink-architecture/)

## 누가 작업을 배치하고 실행합니까?

| 구성요소 | 역할 |
|---|---|
| Client | 프로그램을 JobGraph로 준비해 제출합니다. 실행 중 계속 붙어 있어야 하는 것은 아닙니다. |
| JobManager | 클러스터의 조정 프로세스입니다. Dispatcher, ResourceManager, 작업별 JobMaster가 주요 내부 구성입니다. |
| Dispatcher | 제출 요청을 받고 작업별 JobMaster를 시작합니다. |
| ResourceManager | TaskManager의 Task Slot을 관리하고 배포 환경의 자원을 확보합니다. |
| JobMaster | 한 Job의 실행·복구와 체크포인트를 조정합니다. |
| TaskManager | 실제 Source, 변환, Sink 연산자와 네트워크 버퍼를 실행합니다. Slot은 실행 자원의 배치 단위입니다. |
| State Backend·Checkpoint Storage | 실행 중 상태 관리와 지속적인 스냅샷 저장의 역할을 구분합니다. |

## 상태 있는 집계 흐름

Kafka에서 주문 이벤트를 읽어 고객별 1분 집계를 만든다고 가정하겠습니다. Source가 이벤트와 입력 위치를 추적하고, `keyBy` 이후 같은 키의 이벤트가 담당 연산자로 전달됩니다. 연산자는 누적값·윈도 상태를 갱신하고 Sink에 결과를 씁니다. JobMaster가 체크포인트를 시작하면 입력 위치와 연산자 상태를 일관된 시점으로 스냅샷합니다. 장애가 나면 마지막 성공한 체크포인트부터 입력과 상태를 복구합니다.

이때 **Task Slot**은 CPU 코어 하나와 항상 1:1이 아닙니다. 한 Slot에 연산자 체인이 함께 놓일 수 있습니다. 또한 체크포인트가 있다고 외부 Sink까지 언제나 정확히 한 번 반영되는 것은 아닙니다. Source 재생 가능성과 Sink의 트랜잭션·멱등 지원을 함께 확인해야 합니다.

지연이 커지면 입력량 증가, 키 쏠림, Sink 지연에 따른 backpressure, 체크포인트 정렬·저장 시간을 분리해 살펴보세요. 처리 지연과 복구 가능성은 서로 다른 지표입니다.

## 이벤트 시간과 상태가 스트림 의미를 만듭니다

처리 시간(Processing Time)은 Flink가 레코드를 처리한 시각이고, 이벤트 시간(Event Time)은 레코드 자체가 나타내는 사건 발생 시각입니다. 네트워크 지연이나 원천 재전송이 있으면 도착 순서와 사건 순서는 달라집니다. 이벤트 시간 윈도우는 이벤트 타임스탬프를 기준으로 그룹을 계산하고, Watermark는 “이 시각 이전의 이벤트가 대체로 도착했다”고 연산자에 알리는 진행 신호입니다. Watermark가 늦게 도착한 레코드를 물리적으로 막지는 않습니다. 늦은 데이터 처리 정책은 허용 지연과 side output 같은 애플리케이션 설정으로 결정합니다.

`keyBy` 이후의 Keyed State는 키별 누적값·윈도 상태를 저장합니다. Operator State는 연산자 병렬 인스턴스에 붙는 상태입니다. 두 상태 유형은 병렬도 변경 시 재분배 방법이 다릅니다. 상태가 커질수록 저장 매체와 체크포인트 빈도, 재시작 시간의 균형이 운영상 중요해집니다.

## 체크포인트 장벽은 일관된 스냅샷을 만듭니다

체크포인트 Coordinator가 Source에 번호가 붙은 Barrier를 주입하면 Barrier가 데이터 스트림을 따라갑니다. 연산자는 Barrier 전까지 처리한 상태를 스냅샷하고, 여러 입력을 받는 연산자는 각 입력의 Barrier가 모일 때까지 정렬해 어느 입력에서 온 레코드가 빠지거나 중복 스냅샷에 포함되지 않게 합니다. 상태 스냅샷과 Source 오프셋이 같은 논리적 시점에 저장되어야 복구 후 일관된 계산을 이어갈 수 있습니다.

Checkpoint와 Savepoint는 둘 다 상태 스냅샷이지만 수명과 목적이 다릅니다. Checkpoint는 런타임 장애 복구를 위해 자동 관리되고, Savepoint는 업그레이드·재배포·운영자 제어를 위한 명시적 스냅샷입니다. Savepoint 경로는 상태가 큰 Job의 이관, 연산자 UID 유지, 호환성 확인이 필요합니다.

## Exactly-once의 범위를 이해해야 합니다

Flink의 Exactly-once 상태 의미는 이벤트가 장애로 재생되더라도 관리 상태에 한 번만 반영된다는 뜻입니다. 모든 사용자 코드가 물리적으로 한 번만 호출된다는 뜻은 아닙니다. 외부 Sink까지 end-to-end exactly-once를 얻으려면 Source가 체크포인트 시점으로 재생 가능해야 하고, Sink가 트랜잭션을 지원하거나 중복 적용을 막는 멱등성을 제공해야 합니다. 이 조건이 맞지 않으면 적어도 한 번 처리로 중복이 생길 수 있습니다.

**공식 문서:** [Flink Architecture](https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/flink-architecture/), [Checkpoints](https://nightlies.apache.org/flink/flink-docs-stable/docs/ops/state/checkpoints/), [Fault Tolerance](https://nightlies.apache.org/flink/flink-docs-stable/docs/learn-flink/fault_tolerance/)
