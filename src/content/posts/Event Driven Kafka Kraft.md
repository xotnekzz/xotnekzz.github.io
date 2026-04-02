---
title: Event Driven Kafka Kraft
description: KRaft 모드 Kafka를 활용한 이벤트 드리븐 아키텍처 설계 — 수천 개 마케팅 캠페인의 실시간 오케스트레이션
date: 2024-09-01
tags:
  - Kafka
  - KRaft
  - Django
  - Python
  - Event-Driven Architecture
featured: false
---

> **기간:** 2024.09 ~ 2024.12
**참여인원: 2명**
**역할:** Lead Infrastructure & Backend Engineer (Kafka 클러스터 구축 및 비동기 아키텍처 설계 및 개발)
**기술 스택:** Apache Kafka (KRaft), Django, MariaDB (Procedure), Python, Event-Driven Architecture, Docker

## 1. Background & Challenges

경영진의 '원클릭 데이터 기반 의사결정 자동화' 비전 달성을 위해 수천 개의 마케팅 캠페인, 광고그룹, 키워드 등의 변경 사항을 실시간으로 감지하고 처리해야 했습니다. 기존의 방식은 시스템 간의 결합도가 높고 데이터 처리 지연이 발생하여, 대규모 캠페인을 실시간으로 오케스트레이션하기에는 한계가 있었습니다.

## 2. Architecture: Event-Driven Infrastructure

KRaft 기반의 Kafka 클러스터를 구축하여 시스템 간의 결합도를 낮추고 비동기적으로 이벤트를 처리하는 고성능 인프라를 설계했습니다. 특히, 이벤트 발행 시점으로부터 30분 뒤에 작업을 실행하는 지연 처리 로직과 다수의 컨수머를 통한 안정성 확보 구조를 핵심으로 합니다.

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/d6c914d3-8b88-4820-bc5d-e60113e56636/kafka_event.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466TQJNTHLQ%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153147Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJGMEQCIArf3JxokL%2B%2BICh5iLkIWvwIqVCxDOqNy0WWDzbwlqTyAiBe5%2Bq87UwQk0ooR15IhhT%2Bokzr0U5Vk8oYY3wAXg0VryqIBAiL%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDYzNzQyMzE4MzgwNSIMWyihPFQUGn4X1xqqKtwDctnbkkDNfvyf0eJZHZuGZzqG5Mazx2NmpnXkN%2FvhjR8pQFa5AeUDxBFhwKWPyzAl4JLrX9k1UuXkZ3%2FSztD5o8p4JV7%2Fh7SbeuYaGYUilDICqbjQvVB9RMbGO2QK1ye5ysiPw4f11WTZO1xEKmlpketqXugnhdoeopwShLbdZstNFmETsV9kvpFxf%2FVHsddD2vjp7V4g9FXcLPKo8xSw8AtN9cN6tU%2BGRqzfWuzRgkPewisq4R9Y2lHfwMnRlkOJU6qwK4u3V5fCMlv1%2FTWRbsuSZrLm4p3F6P6PwAWr37gel%2FSVzHLXIuPoF8MJ7VmQNOYw2RtdE46YJh4cLK0jsygHMYTm0jU0MTBz510pHT6%2B5Lo%2Bx%2BPeFIGvXJJxYmNCnaSW74E40zbYJ%2BoNH8GnsSocSc%2BNW8upwHFmFGqJS3StDUC4RmOw7EFQ5SIIOYmG5uj4E6EFTJXgV1UB1TxyjjRRM6%2BTBFV2Zig0vDiCtw4JXDfVNQMxti5jhudoMsjR8u1DzX0DMJCUFoD%2FHui41dPi2LIqfNNFMDTJPMZjIOllbj6v3a1%2FS94APihSRqIHKOPWZxp01%2FNLBOA1xpLYl%2B8T3IitpkR%2Bm0jkaRNwEkaGA89Er%2BBUM8JBsx0wubzPzQY6pgFKNwemHZrxfg20z4Rx2ltKFn%2FXvy0PyDpf%2FRf2F5fIcWCNozCxEgjyM9fS9XFlTnDuIfOcErfJNwGPT8UdEa2eyRq8bDZd2jcTICGx7E9yVqm8U01m356WUx6YxozAYTzmMG4BJmKyi1SU21z6ZEl4FAG%2FFETymUpVkf8HosFfwk0cm%2B%2B4qffq%2BdkQcIDgeIvQDgNa%2BwHCJs8l3HWmkjhTHuU4JRj2&X-Amz-Signature=57200d0d303f4960947cfa1ad64facaf7cb363d02e49abc48dc305bea90b584d&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

## 3. Solution & Technical Insights

1. **Zookeeper-less KRaft 기반 Kafka 클러스터 구축**
- **[Issue]** 기존 Kafka의 Zookeeper 의존성은 관리 복잡성을 증가시키고 장애 포인트를 늘리는 원인이었습니다.
- **[Solution]** 최신 **KRaft(Kafka Raft Metadata Mode)** 기반의 Kafka 클러스터를 구축하여 아키텍처를 단순화했습니다. 이를 통해 별도의 Zookeeper 관리 없이도 고성능, 고가용성의 메시징 인프라를 안정적으로 운영할 수 있게 되었습니다.
1. **이벤트 스트리밍 기반 비동기 연동 구조 설계**
- **[Issue]** 시스템 간의 동기 호출 방식은 성능 병목을 유발하고 확장성을 저해했습니다.
- **[Solution]** 캠페인 생성, 수정, 삭제 등의 주요 이벤트를 Kafka 토픽으로 발행(Publish)하고, 다수의 워커(Worker)들이 이를 구독(Subscribe)하여 비동기적으로 처리하는 **이벤트 드리븐(Event-Driven)** 구조를 설계했습니다. 이를 통해 시스템 간의 결합도를 획기적으로 낮추고 개별 서비스의 독립적 확장을 가능하게 했습니다.
1. **대규모 캠페인 오케스트레이션 최적화**
- 수천 개의 캠페인 변경 사항이 발생하더라도 Kafka의 높은 처리량을 바탕으로 지연 없이 오케스트레이션 워크플로우를 실행할 수 있는 기반을 마련했습니다.
## 4. Impact & Result

- 🚀 **의사결정 지연 최소화:** 실시간 이벤트 스트리밍을 통해 마케팅 운영 데이터의 반영 속도를 비약적으로 향상시켰습니다.
- 🦾 **시스템 확장성 및 안정성 확보:** 비동기 아키텍처 도입으로 대규모 트래픽 발생 시에도 안정적인 서비스 운영이 가능해졌습니다.
- 💰 **인프라 관리 효율 증대:** KRaft 도입을 통해 인프라 구성 요소를 단순화하고 운영 리소스를 최적화했습니다.
- 🎯 **데이터 기반 자동화 구현:** 경영진의 '원클릭 자동화' 비전을 뒷받침하는 기술적 근간을 완성했습니다.
