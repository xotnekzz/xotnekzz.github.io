---
title: "[Data Engineering Lab] #6. 실시간 이커머스 CDC 파이프라인 설계"
description: 그동안 Kafka, StarRocks, MariaDB 등 데이터 엔지니어링을 위한 인프라 구축을 완료하였습니다.이번 포스팅 부터는 실제 상황과 비슷한 시나리오를 만들어 데이터 파이프라인 프로토타입을 구축해볼 예정입니다.1.
date: 2025-12-28
tags:
  - CDC
  - Kafka
  - Debezium
  - StarRocks
  - DataEngineering
  - Lab
featured: false
draft: false
---

그동안 Kafka, StarRocks, MariaDB 등 데이터 엔지니어링을 위한 인프라 구축을 완료하였습니다.  

이번 포스팅 부터는 실제 상황과 비슷한 시나리오를 만들어 데이터 파이프라인 프로토타입을 구축해볼 예정입니다.

## 1. 시나리오 목표: "주문 즉시 업데이트되는 대시보드"

첫 번째 시나리오로 실시간 이커머스 CDC 파이프라인을 구축해보고자 하는데요.  

전통적인 Batch 방식이라면 매일 밤 12시 그날의 매출을 집계하지만,  
우리의 목표는 **"고객이 주문 버튼을 누른 지 1초 안에 운영자 대시보드이 매출 지표가 바뀌는 것"** 입니다.

단순히 데이터를 옮기는 것을 넘어, 다음과 같은 **엔지니어링 난제** 도 살펴보고자 합니다.

- **Data Integrity:** 소스 DB에소 주문이 취소(Delete)되거나 상태가 변경(Update)되었을 때, 대시보드가 이를 얼마나 정확하게 반영하는가?
- **High Availability:** 시스템의 일부(Kafka 브로커 등)가 죽어도 대시보드가 멈추지 않고 유지되는가?
- **End-to-End Latency:** 데이터 생성부터 시각화까지 총 몇 초의 지연이 발생하는가?

## 2. 전체 아키텍처

![](/images/posts/de-lab-6-realtime-ecommerce-cdc-pipeline/img-1.png)

CDC Pipeline Architecture

**Source Layer ( MariaDB + Python ):** 실제 서비스 환경과 유사하게 주문, 취소, 가입 이벤트를 쉴 새 없이 발생시킵니다.

**Ingestion Layer (Devezium):** DB의 BinLog를 읽어 데이터 변화를 실시간 이벤트 스트림 플랫폼에 전달합니다.  
**Streaming Layer (Kafka):** 3대의 브로커가 데이터를 복제하여 저장하며, 시스템의 고가용성을 보장하는 완충지대 역할을 합니다.  
**Analytics Layer (StarRocks):** Routine Load를 통해 Kafka 토픽 메세지를 가져와 실시간으로 쿼리가 가능하도록 즉시 저장합니다.  
**Visualization Layer (Redash):** Redash에 StarRock를 Mysql 커넥터로 연결 후 데이터를 쿼리하여 유저에게 실시간 차트와 지표를 시각화하여 보여줍니다.  

이렇게 CDC 파이프라인을 설계한 이유는 Kafka, StarRocks, Devezium을 학습해보고자하는 의도도 있지만,  
리소스를 많이 들이지 않고 파이프라인을 구축할 수 있도록하는 내장 기능들이 있기 떄문입니다.  
  
**Devezium** 은 이터베이스의 변경 이벤트를 쉽게 카프카에 메세지를 생성할 수 있으며,  
**StarRocks** 는 Routine Load를 사용하여 Kafka 메세지를 별도의 컨수머를 만들지 않아도 하나의 SQL만으로 데이터베이스에 저장할 수 있습니다.

## 3. 연구 포인트

단순히 CDC 파이프라인을 구축하고 땡이 아니라, 엔지니어링 연구포인트를 잡아 진행하겠습니다.  
  
**- 실시간 정합성 테스트:** 주문이 취소되었을 때 대시보드의 매출 합계가 즉각적으로 차감되는지 확인합니다.  
**- 장애 유발 테스트:** 의도적으로 Kafka, Starrocks 등 노드 하나를 중지시켜 대시보드가 끊임 없이 서비스 되는지 지켜봅니다.  
**- E2E 모니터링:** 맥북 한 대라는 한정된 자원에서 전체 파이프라인의 병목 지점을 찾고 최적화합니다.

## 마치며

다음 포스팅에서는 **이커머스 서비스 환경과 유사한 데이터 트래픽 생성기 (Python)** 개발을 다루도록 하겠습니다.  

