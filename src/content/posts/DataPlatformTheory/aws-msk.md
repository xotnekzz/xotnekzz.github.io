---
title: Amazon MSK 이론 — Kafka 로그를 관리형 서비스로 운영하기
description: MSK의 관리 경계와 Kafka Broker, Topic, Partition, Replication, Consumer Group 데이터 흐름을 설명합니다.
date: 2026-09-26
tags: [AWS, MSK, Kafka, Streaming, Architecture]
draft: false
---

Amazon Managed Streaming for Apache Kafka(MSK)는 Apache Kafka를 사용하는 애플리케이션을 위한 관리형 스트리밍 서비스입니다. AWS가 클러스터 생성·변경 같은 Control Plane 작업을 제공하고, Producer와 Consumer는 표준 Kafka 데이터 작업을 사용합니다. MSK는 Kafka 호환 브로커 클러스터의 운영 부담을 줄이지만, 이벤트의 의미·스키마·소비자 처리 보장까지 자동으로 결정하지는 않습니다.

![Amazon MSK의 제어 영역과 Kafka 이벤트 경로](/images/posts/data-platform-theory/aws-msk-architecture.svg)

## 관리형 서비스의 경계를 이해합니다

MSK Control Plane은 클러스터 생성, 설정 변경, Broker 확장 같은 AWS API 작업을 제공합니다. Kafka Data Plane은 기존 Kafka Producer, Consumer, Admin Client가 Topic과 Partition을 사용해 데이터를 쓰고 읽는 영역입니다. 애플리케이션은 VPC 안의 Broker Bootstrap 주소를 통해 연결하며, 클러스터 관리 API와 Kafka 프로토콜 트래픽은 다른 경로입니다.

| 구성요소 | 기능 | 이론적 의미 |
|---|---|---|
| Broker | Topic 파티션의 로그 데이터를 저장하고 Produce/Fetch 요청을 처리합니다. | 클러스터의 실제 데이터 용량과 처리량을 담당하는 서버입니다. |
| Topic | 이벤트 종류를 구분하는 논리 이름입니다. | 보존 정책과 스키마·권한 운영의 단위가 됩니다. |
| Partition | Topic 로그를 분할해 여러 Broker와 Consumer에 병렬성을 제공합니다. | 파티션 안에서는 순서가 있지만 Topic 전체 순서는 보장되지 않습니다. |
| Leader / Replica | 각 파티션의 Leader가 읽기·쓰기를 주로 처리하고, 동기화 상태인 Replica(ISR)가 설정된 복제 정책에 따라 로그를 복제합니다. | 복제는 Broker 장애에 대한 내구성과 가용성 기반입니다. |
| Producer | 레코드를 Topic의 파티션으로 발행합니다. | 키는 같은 엔터티의 레코드를 같은 파티션으로 보내는 기준이 될 수 있습니다. |
| Consumer Group | 그룹의 Consumer들이 파티션을 분담해 읽습니다. | 그룹별 Offset이 독립적이므로 서로 다른 서비스가 같은 이벤트를 각자 소비할 수 있습니다. |
| KRaft 또는 ZooKeeper | Kafka 클러스터 메타데이터와 조정을 관리합니다. | 적용되는 메타데이터 방식은 Kafka 버전과 클러스터 구성에 따라 확인합니다. |

Amazon MSK Provisioned에서는 Broker 수와 유형 등 클러스터 용량을 선택합니다. MSK Serverless는 Broker 인프라 운영을 더 많이 서비스에 맡기고 클러스터 수준의 Kafka 자원을 사용합니다. 어느 모드에서도 Topic 파티션 설계와 Producer·Consumer의 동작은 애플리케이션 성능에 큰 영향을 줍니다.

## 레코드 한 건이 이동하는 순서

1. Producer가 Bootstrap 주소를 사용해 Broker를 찾고 Topic 메타데이터를 조회합니다.
2. 레코드에 키가 있으면 파티셔너가 키를 기준으로 Partition을 선택할 수 있습니다. 키가 없으면 Producer 설정과 파티셔너 정책에 따라 분배됩니다.
3. 선택한 파티션의 Leader Broker가 레코드를 로그 끝에 추가합니다. Broker는 설정된 복제 정책과 ISR(동기화 중인 Replica 집합)에 따라 Replica에 로그를 전파합니다.
4. Consumer Group의 멤버가 할당받은 파티션에서 순서대로 레코드를 가져옵니다. Consumer가 Offset을 커밋하면 같은 그룹은 재시작 후 그 위치를 기준으로 이어 읽을 수 있습니다.
5. 보존 시간·크기 정책에 따라 로그가 유지되며, Consumer가 읽었다고 바로 삭제되지 않습니다. 새로운 Consumer Group은 보존 기간 안의 이벤트를 처음부터 다시 읽을 수 있습니다.

Kafka의 순서 보장은 파티션 단위입니다. 동일한 고객·주문 키를 같은 Partition에 보내면 해당 키의 이벤트 순서를 유지하기 쉬워집니다. 반대로 파티션 수와 키 전략을 바꾸면 엔터티가 다른 Partition으로 이동할 수 있으므로, 파티션 확장과 키 변경은 순서 의미를 검토하고 수행해야 합니다.

## Partition과 Consumer 병렬성

파티션은 저장 분할 단위이자 Consumer Group 내 병렬 처리 단위입니다. 한 Group 안에서 파티션은 동시에 최대 한 Consumer에게 할당되므로, 활성 Consumer 수가 파티션 수보다 많으면 일부 Consumer는 작업을 받지 못합니다. Consumer 수만 늘려도 단일 파티션의 처리량을 여러 Consumer가 나눠 갖지는 않습니다.

파티션 수가 많아지면 병렬성이 올라갈 수 있지만, 메타데이터와 파일 핸들 관리, 리밸런스 비용, Broker 부하도 증가합니다. 메시지 크기, 초당 생산량, 보존 기간, 복제 계수, 소비 속도를 함께 고려해 Topic을 설계해야 합니다. 파티션 수는 운영 중 바꾸기 쉽지 않고 메시지 순서에도 영향을 줄 수 있으므로 시작 시점에 용도별 요구량을 산정하는 편이 좋습니다.

## Offset, 재처리, 처리 보장의 범위

Kafka Broker는 Consumer가 어디까지 읽었는지 Offset을 관리할 수 있지만, 업무 DB에 대한 처리 완료를 자동으로 함께 커밋하지는 않습니다. 예를 들어 Consumer가 DB에 쓴 뒤 Offset을 커밋하기 전에 죽으면 동일 레코드를 다시 받을 수 있습니다. Offset을 먼저 커밋하고 DB 쓰기 전에 죽으면 처리가 빠질 수 있습니다.

따라서 전달 의미를 “Kafka가 exactly-once를 제공한다”처럼 뭉뚱그려 말하기보다 다음 경계를 나눠야 합니다.

- Producer의 재시도와 멱등성 설정이 Broker에 중복 기록될 가능성을 줄이는지 확인합니다.
- Consumer가 Offset을 언제 커밋하는지, 레코드 처리가 실패했을 때 재시도·Dead Letter 흐름이 있는지 확인합니다.
- 외부 DB나 API 쓰기는 중복 이벤트가 와도 안전하도록 고유 이벤트 ID, Upsert, 트랜잭션 또는 멱등 키를 둡니다.
- Kafka 트랜잭션은 Kafka 입력 Offset과 Kafka 출력 레코드 사이에서 원자적 처리를 구성할 수 있지만, 외부 시스템까지 자동으로 하나의 원자적 트랜잭션에 포함하지는 않습니다.

데이터 보존은 재처리 가능 시간을 제공하지만 무기한 이력을 보장하지 않습니다. 보존 설정이 지났거나 압축 정책이 적용되면 과거 이벤트의 존재 방식이 달라집니다. 장기 원본 데이터 보관은 별도 객체 저장소나 데이터 레이크와 함께 설계할 수 있습니다.

## MSK 운영 모드와 주변 서비스

| 선택지 | 운영 책임의 차이 | 적합성 검토 |
|---|---|---|
| MSK Provisioned | Broker 유형·수·클러스터 용량을 정하고, 파티션 배치·처리량·스토리지 요구를 관리합니다. AWS는 관리형 Broker 인프라를 운영합니다. | 장기적인 처리량과 보존 요구가 비교적 예측 가능하고 Broker 수준 용량 조정이 필요한 경우 검토합니다. |
| MSK Serverless | Broker 서버 생성·확장을 서비스에 맡기고 Kafka 클러스터 자원 사용을 관리합니다. | 용량 계획 부담을 줄일 수 있지만, 연결·처리량·비용 한도와 기능 지원 범위를 확인해야 합니다. |
| MSK Connect | Kafka Connect Worker와 Connector를 관리형 방식으로 실행하는 별도 MSK 기능입니다. | Kafka Connect 플러그인으로 외부 시스템과 데이터를 옮길 때 사용하며, MSK Broker와 같은 구성요소는 아닙니다. |
| MSK Replicator | MSK 클러스터 간 Topic 데이터를 복제하는 별도 기능입니다. | 리전 간 복제나 클러스터 전환을 검토할 때 복제 지연, Topic 설정과 Offset 동작을 확인합니다. |

MSK Connect를 선택하면 Connector JVM Worker가 Connector Task들을 실행합니다. Source Connector는 외부 데이터를 Kafka Topic으로 넣고, Sink Connector는 Topic에서 읽어 외부 저장소에 씁니다. 이 구성은 Kafka Broker 자체의 아키텍처가 아니라 관리형 Kafka Connect 작업 실행 구조입니다.

![AWS 공식 문서의 MSK Connect Worker와 Connector Task 구성](https://docs.aws.amazon.com/images/msk/latest/developerguide/images/mkc-worker-architecture.png)

[공식 그림 출처: Understand connectors](https://docs.aws.amazon.com/msk/latest/developerguide/msk-connect-connectors.html)

애플리케이션이 EKS나 EC2에서 실행되면 MSK Broker가 있는 VPC와 네트워크 연결이 되어야 합니다. 보안 그룹·서브넷·DNS와 Kafka 인증 방식(IAM 또는 SASL/SCRAM 등), 전송 암호화(TLS)는 실제 클러스터 정책에 맞춰야 합니다. 클러스터 API 권한과 Topic Produce/Consume 권한도 별도 경계로 관리합니다.

## 장애와 지연을 어디서 확인합니까?

Producer가 데이터를 쓰지 못하면 Broker 연결, 인증, ACL, 파티션 Leader 상태, 네트워크를 확인합니다. Consumer Lag이 증가하면 입력 증가율과 처리율을 비교하고, 파티션 수와 Consumer 수, 느린 외부 Sink, 리밸런스 반복을 조사합니다. Leader와 Replica 복제 지연은 가용성과 쓰기 승인 조건에 영향을 줄 수 있습니다.

MSK는 Broker 장애 같은 일반적인 클러스터 실패를 감지해 복구를 수행하지만, 이벤트 스키마 오류나 Consumer 코드 버그는 애플리케이션 책임입니다. 데이터가 Broker에 기록되었다는 사실과 그 이벤트가 목적지 DB·검색 인덱스·분석 결과에 정확히 반영되었다는 사실은 서로 다른 상태입니다.

## 핵심 정리

MSK는 Kafka 데이터 평면을 유지하면서 클러스터 인프라 운영을 AWS에 맡기는 서비스입니다. 데이터 흐름의 기본 단위는 Topic 안의 Partition 로그이며, Producer의 키 전략·Broker 복제·Consumer Group의 Offset 관리가 순서·내구성·재처리 특성을 결정합니다. 관리형 Broker는 운영 부담을 줄이지만 이벤트 처리 의미와 외부 목적지의 일관성은 애플리케이션 설계에 남습니다.

**공식 문서:** [What is Amazon MSK?](https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html), [MSK Provisioned](https://docs.aws.amazon.com/msk/latest/developerguide/msk-provisioned.html), [MSK Serverless](https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html), [MSK Connect](https://docs.aws.amazon.com/msk/latest/developerguide/msk-connect.html), [MSK Replicator](https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator.html)
