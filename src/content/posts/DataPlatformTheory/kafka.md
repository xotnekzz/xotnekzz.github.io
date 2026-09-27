---
title: Apache Kafka 이론 — 파티션 로그와 KRaft 제어 계층
description: Kafka의 Producer, Broker, Partition, Consumer Group, KRaft Controller를 설명합니다.
date: 2026-09-23
tags: [Kafka, EventStreaming, Architecture]
draft: false
---

Apache Kafka는 이벤트를 **파티션별 순서가 있는 로그**에 기록하고, 소비자가 자신의 위치에서 읽도록 하는 플랫폼입니다. 이 장은 KRaft 기반 구성을 기준으로 합니다. Controller의 메타데이터 제어 경로와 Broker의 이벤트 데이터 경로를 구분해 보시면 운영 구조가 이해됩니다.

![Kafka KRaft 제어 계층과 Producer에서 Consumer까지의 로그 경로](/images/posts/data-platform-theory/kafka-architecture.svg)

## 이름이 비슷한 요소를 분리하겠습니다

| 요소 | 역할 |
|---|---|
| Topic | 이벤트의 논리적 이름입니다. 실제 기록은 그 아래 Partition에 나뉩니다. |
| Partition | append-only 로그와 offset의 범위입니다. **순서 보장은 파티션 내부**에 적용됩니다. |
| Broker | 파티션 로그를 저장하고 Producer·Consumer 요청을 처리합니다. |
| Partition Leader·Follower | 리더가 해당 파티션의 쓰기·읽기를 담당하고 Follower가 복제합니다. |
| KRaft Controller | 토픽·파티션·리더 등 메타데이터를 quorum으로 관리합니다. 일반적인 이벤트 바이트 처리와 역할이 다릅니다. |
| Producer | 키와 파티션 지정 규칙에 따라 이벤트를 보냅니다. |
| Consumer Group | 같은 그룹의 소비자들이 파티션을 분담하고 offset을 관리합니다. 서로 다른 그룹은 독립적으로 읽습니다. |

## 주문 이벤트가 소비되기까지

1. Producer가 주문 ID 같은 키로 파티션을 선택하고 해당 파티션의 리더 Broker에 이벤트를 보냅니다.
2. Broker가 로그에 추가하고 설정에 따라 Follower로 복제합니다. ACK 설정과 복제 상태가 쓰기 내구성에 영향을 줍니다.
3. Consumer가 Broker에서 레코드를 **pull**하고, 자신이 처리한 위치를 offset으로 관리합니다.
4. 같은 그룹의 소비자들은 파티션을 나눠 맡습니다. 다른 그룹은 같은 로그를 별도의 속도로 다시 읽을 수 있습니다.

Topic의 전체 이벤트에 단일 순서가 있는 것은 아닙니다. 같은 키의 순서가 중요하면 키가 같은 파티션으로 가도록 설계해야 합니다. 소비자 인스턴스 수를 파티션 수보다 늘려도 전통적인 Consumer Group에서는 한 파티션을 동시에 여러 인스턴스가 처리하지 않습니다. Kafka 4.1의 Share Group은 별도 모델이므로 이 설명과 구분해 주세요.

## 로그, 오프셋, 보존 정책

각 파티션은 레코드를 뒤에 추가하는 로그이며, 레코드는 파티션 안에서 증가하는 Offset으로 식별됩니다. Offset은 Consumer의 진행 위치이지 레코드의 고유한 업무 ID가 아닙니다. Consumer가 재시작해 같은 Offset에서 다시 읽으면 레코드가 애플리케이션에 다시 전달될 수 있습니다.

Kafka는 소비 여부와 독립적으로 시간·크기 기준 보존 정책에 따라 로그를 보관하거나, Compact 정책에서 키별 최신 상태를 남깁니다. 따라서 Kafka를 큐로만 보면 안 됩니다. Consumer Group마다 별도 Offset이 있어 새 그룹이 오래된 데이터부터 읽을 수 있습니다. 단, 보존 기간이 지나 제거된 로그는 새 소비자가 재생할 수 없습니다. 데이터 보존 기간은 재처리·감사 요구와 디스크 예산 사이의 설계값입니다.

## 복제와 쓰기 확인

Leader Replica는 쓰기를 받고 Followers는 로그를 복제합니다. ISR(In-Sync Replicas)은 리더와 충분히 동기화된 복제본 집합입니다. Producer의 `acks`, `min.insync.replicas`, 복제 수 설정은 처리량과 기록 승인의 내구성 사이 균형을 바꿉니다. Kafka 공식 문서의 데이터 손실 보장은 최소 한 개의 동기화 복제본이 남는다는 조건에 의존합니다. 복제본 개수만 늘린다고 모든 장애 조합에서 안전한 것은 아닙니다.

## Producer와 Consumer의 처리 보장

At-most-once는 손실 가능성을 감수하고 재처리를 하지 않는 방식, At-least-once는 재시도로 손실을 줄이는 대신 중복 가능성이 있는 방식입니다. Idempotent Producer와 Transaction은 Kafka 내부의 재전송·다중 토픽 기록과 Offset 반영을 더 강하게 묶을 수 있습니다. 하지만 외부 DB·HTTP API까지 하나의 Kafka 트랜잭션에 자동 포함되는 것은 아닙니다. Consumer의 외부 쓰기에는 목적지의 트랜잭션 또는 멱등 키가 별도로 필요합니다.

## KRaft는 메타데이터 합의 경로입니다

KRaft 모드에서 Controller quorum은 클러스터 메타데이터 변경을 Raft 방식으로 복제하고 리더 Controller를 선출합니다. Broker는 Produce/Fetch 요청과 파티션 로그를 담당합니다. 작은 클러스터에서는 노드가 두 역할을 함께 수행할 수도 있지만 논리적 역할은 다릅니다. 장애 분석 시 Controller quorum의 메타데이터 가용성과 각 파티션 Leader·ISR 상태를 따로 보셔야 합니다.

문제가 생기면 생산 지연, 리더·복제 상태, 파티션별 입력 불균형, Consumer Lag, 재할당(rebalance)을 각각 확인해 보세요. Lag는 쌓인 데이터의 양이지 반드시 처리 오류를 뜻하지는 않습니다.

**공식 문서:** [Introduction](https://kafka.apache.org/intro/), [Design — Log Compaction](https://kafka.apache.org/41/design/design/), [KRaft vs ZooKeeper](https://kafka.apache.org/41/getting-started/zk2kraft/)
