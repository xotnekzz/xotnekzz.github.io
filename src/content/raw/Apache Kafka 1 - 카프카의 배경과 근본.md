---
title: "Apache Kafka [1] - 카프카의 배경과 근본"
source: "https://tedi.tistory.com/52"
author:
  - "[[Tedi__]]"
published: 2025-12-17
created: 2026-05-12
description: "1. 카프카의 배경과 근본: 데이터 배관공(Plumbers)에서 벗어나기Apache Kafka를 단순히 \"데이터를 주고받는 큐(Queue)\" 정도로 이해한다면, 카프카의 진정한 가치를 놓치게 됩니다. 카프카는 링크드인(LinkedIn) 엔지니어들이 겪었던 두 가지의 치명적인 문제를 해결하기 위해 탄생한 '이벤트 스트리밍 플랫폼'입니다.1-1. 탄생 배경: 링크드인(LinkedIn)의 스파게티 아키텍처 2010년경, 링크드인 개발팀은 심각한 아키텍처적 한계에 부딪혔습니다. 당시 그들이 직면한 문제는 크게 두 가지 였습니다. 문제 1: 실시간 비동기 애플리케이션의 갈 곳 없는 데이터당시 시스템은 대부분 REST 기반의 요청/응답(Request/Reponse)방식이었습니다. 하지만 뉴스피드(Newsfeed).."
tags:
  - "clippings"
---
## 1\. 카프카의 배경과 근본: 데이터 배관공(Plumbers)에서 벗어나기

Apache Kafka를 단순히 "데이터를 주고받는 큐(Queue)" 정도로 이해한다면, 카프카의 진정한 가치를 놓치게 됩니다. 카프카는 링크드인(LinkedIn) 엔지니어들이 겪었던 두 가지의 치명적인 문제를 해결하기 위해 탄생한 '이벤트 스트리밍 플랫폼'입니다.

## 1-1. 탄생 배경: 링크드인(LinkedIn)의 스파게티 아키텍처

![](https://blog.kakaocdn.net/dna/lVlxo/dJMcaiIB2hi/AAAAAAAAAAAAAAAAAAAAAEjOVOKEUioI7y-WII4ci93-_VapnvFG1lZTUJVzp5Xa/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=RaAIqyuGPwe8pBXdF1vTKEOCDsY%3D)

스파게티 아키텍처 \[출처:https://www.confluent.io/blog/event-streaming-platform-1/\]

2010년경, 링크드인 개발팀은 심각한 아키텍처적 한계에 부딪혔습니다. 당시 그들이 직면한 문제는 크게 두 가지 였습니다.

**문제 1: 실시간 비동기 애플리케이션의 갈 곳 없는 데이터**

당시 시스템은 대부분 REST 기반의 요청/응답(Request/Reponse)방식이었습니다. 하지만 뉴스피드(Newsfeed)갱신이나 광고 시스템처럼, 사용자의 행동과 비동기적으로 분리되어 동작해야 하는 기능들이 점점 많아졌습니다.

- **REST의 한계:** 일시적인 호출만으로는 데이터를 안정적으로 비동기 처리하기 어려웠다.
- **기존 MQ의 실패:** ActiveMQ 같은 기존 메시징 시스템을 도입해 보았지만, 링크드인의 거대한 트래픽을 감당하기엔 관리와 확장이 너무 어려웠다.

**문제 2: 데이터 통합의 지옥**

링크드인에는 수많은 데이터 시스템이 있었습니다. OLTP 데이터베이스(Oracle), 하둡(Hadoop), 검색 엔진, 모니터링 시스템, 데이터 웨어하우스(Teradata)등이 뒤섞여 있었고, 이 시스템들은 서로 데이터를 주고 받아야 했습니다.

처음에는 필요할 때마다 시스템끼리 1:1로 연결하는 임시방편(Ad-hoc) 파이프라인을 만들었으나, 시스템이 늘어날수록 상황 통제 불능이 되었습니다.

- **파이프라인의 파편화:**
	- **로그 파이프라인:** 확장은 잘 되는데 데이터 유실이 발생하고 느림.
		- **Oracle 간 파이프라인:** 빠르고 정확하나 확장이 불가능.
		- **검색용 파이프라인:** 빠르지만 DB에 강하게 결합됨.
- **신뢰성 붕괴:** A 시스템과 B 시스템의 데이터가 다르고, C 시스템을 보니 또 다릅니다. 데이터 품질 문제를 해결하느라 시간을 허비함.
- **지리적 복제(Geo-replication)의 난관:** 전 세계로 데이터센터를 확장해야 하는데, 이 복잡한 스파게티 연결망을 그대로 복제하는 것은 불가능에 가까웠다.

## 1-2. 모든 데이터의 중앙 허브

이 문제를 해결하기 위해 링크드인 팀은 발상을 전환했습니다. "복잡하게 얽인 파이프라인을 다 끊어내고, **모든 데이터 스트림이 모이고 퍼져나가는 단 하나의 중앙 허브** 를 만들자."

그렇게 탄생한 것이 바로 Apache Kafka입니다.

![](https://blog.kakaocdn.net/dna/BEuv7/dJMcaiu4J4h/AAAAAAAAAAAAAAAAAAAAAJk6lG_vnMzaMFpNxh7AoXIXRMPzl4gwudy7x2EV3ciq/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=yhebhEHFnLXbeYaB8Izkz701WTw%3D)

스트림 중심 아키텍처 \[출처:https://www.confluent.io/blog/event-streaming-platform-1/\]

카프카를 도입 한 후, 아키텍처는 스파게티 구조에서 **깔끔한 스트림 중심(Stream-Centric)구조** 로 변모했습니다.

- **Universal Pipeline:** 모든 시스템(Producer)은 카프카라는 하나의 파이프라인으로 데이터를 보냅니다.
- **Decoupling:** 데이터를 쓰는 시스템(Consumer)은 누가 데이터를 보냈는지 신경 쓸 필요 없이, 카프카에서 필요한 데이터를 가져가기만 하면 됩니다.
- **Ligua Franca (만국 공통어):** 카프카에 저장된 데이터는 시스템, 애플리케이션, 데이터센터를 가로지르는 표준 언어 역할을 하게 되었습니다.

**실제 작동 예시**

> 1\. 업데이트 정보가 카프카로 들어옵니다.  
> 2\. 스트림 프로세서가 즉시 데이터를 표준화합니다.  
> 3\. 이 정제된 데이터는 검색 인덱스로 흘러가 검색 결과를 갱신하고,  
> 4\. 추천 시스템으로 흘러가 더 나은 구직 정보를 매칭하며,  
> 5\. 동시에 \*\*하둡(Hadoop)\*\*으로 저장되어 장기 분석용 데이터가 됩니다.

이 모든 과정이 단 밀리초(ms)안에, 서로 간섭 없이 일어납니다. 현재 링크드인은 하루 1조개 이상의 이벤트를 카프카로 처리하고 있습니다.

## 1-3. 분산 커밋 로그 (Distributed Commit Log)

카프카를 이해하는 가장 중요한 키워드는 **로그(LOG)** 입니다. 여기서 말하는 로그는 개발자가 디버깅을 위해 파일에 남기는 텍스트 로그(Application Log)와는 완전히 다른 개념입니다.

컴퓨터 과학에서 말하는 로그는 **"시간 순서대로 정렬된, 불편(Immutable)의 레코드 연속"** 을 의미합니다.

**왜 '로그' 인가?**

데이터베이스(RDBMS)의 내부를 들여다보면, 그 핵심에는 WAL(Write-Ahead Log) 또는 트랙잭션 로그가 있습니다. DB는 데이터를 테이블에 쓰기 전에, "무슨 일이 일어났는지"를 로그 파일에 먼저 기록합니다. 그래야 DB가 셧다운되어도 로그를 다시 읽어(Replay) 상태를 복구 할 수 있기 때문입니다.

카프카의 창시자들은 생각했습니다.

> 데이터베이스의 구현 세부 사항(Implementation Detail)에 불과했던 이 '로그' 자체를 시스템 밖으로 꺼내서, 데이터 저장의 핵심 메커니즘으로 쓰면 어떨까?"  

이 발상의 전환이 카프카의 핵심입니다. 카프카는 **거대한 분산 커밋 로그** 입니다.

- **Append Only:** 데이터는 오직 맨 뒤에 추가될 뿐입니다. 중간에 삽입하거나 수정하지 않습니다. 덕분에 디스크의 순차 쓰기(Sequential Write) 성능을 100% 활용하여 압도적인 처리량을 냅니다.
- **Immutable:** 한 번 기록된 역사는 변하지 않습니다. 이는 분산 시스템에서 데이터가 정합성을 맞추는 복잡한 문제를 단순하게 만듭니다.

## 1-4. 기존 메시징 시스템(RabbitMQ 등)과의 결정적 차이

많은 분들이 "RabbitMQ랑 카프카랑 뭐가 달라요?"라고 묻습니다. 가장 큰 차이는 **데이터를 대하는 철학** 에 있습니다.

**1) Smart Broker vs Smart Client**

- **기존 MQ (RabbitMQ):** 브로커가 똑똑합니다.(Smart Broker), 메세지를 누구에게 보넀는지, 누가 읽었는지 추적하고, 소비(Consume)된 메시지는 즉시 삭제합니다. 메시지 전달 보장에 집중합니다.
- **Kafka:** 브로커는 단순하고 멍청합니다.(Dumb Broker). 그냥 들어온 데이터를 디스크에 순서대로 박아두기만 합니다. 대신 클라이언트(Consumer)가 똑똑합니다. 자신이 어디까지 읽었는지(Offset)를 직접 관리합니다. 이 설계 덕분에 카프카는 브로커의 부하를 줄이고 압도적인 성능을 낼 수 있습니다.
![](https://tedi.tistory.com/consumer_position_image.png)

Kafka Offset \[출처 - https://docs.confluent.io/kafka/design/consumer-design.html\]

**2) 휘발성 vs 영속성 (Persistence)**

- **기존 MQ:** 메시지는 소비되면 사라집니다. 즉 데이터 큐에 머무는 시간은 매우 짧습니다.
- **Kafka:** 카프카는 메시지를 **디스크에 저장** 합니다. 하루든, 일주일이든, 영원히든 설정한 기간 동안 데이터는 남아 있습니다.

이 **영속성** 이 가져온 변화는 혁명적이었습니다. 컨슈머가 장애가 나서 죽었다가 1시간 뒤에 살아나도, 카프카에 데이터가 그대로 남아있기 때문에 **죽었던 시점부터 다시 데이터를 읽어 처리** 할 수 있게 된 것입니다. 이는 단순한 메시지 전달을 넘어 **데이터 저장소** 로서의 역할을 가능하게 했습니다.

## 1-5. 이벤트 소싱(Event Sourcing)의 실현

카프카의 로그 기반 구조는 **이벤트 소싱** 아키텍터를 완벽하게 구현할 수 있게 해줍니다.

일반적인 DB는 **현재 상태(Current State)** 만을 저장합니다.

> 예: "철수의 잔고는 100만원이다"

하지만 카프카는 **"상태를 변경시킨 사건(Event)의 흐름"** 을 저장합니다.

> 예: "철수가 계좌를 개설했다" -> "50만 원 입금" -> "30만 원 입금" -> "100만 원 입금" -> "80만 원 출금"

이 이벤트들을 처음부터 끝까지 순서대로 실행하면 현재의 잔고(100만 원)가 나옵니다. 만약 로직이 잘못되어 잔고 계산을 다시 해야 한다면? 카프카에 저장된 이벤트를 처음부터 다시 읽으면 됩니다.

**결론적으로 카프카는 단순한 파이프라인이 아닙니다.** 과거의 모든 데이터를 기억하고 있으며, 필요할 때 언제든지 다시 꺼내 쓸 수 있는 **기억을 가진 신경망** 입니다. 이것이 바로 빅테크 기업들이 카프카 메인 데이터 허브로 사용하는 이유입니다.

## 1-6. 그래서 누가, 어떻게 쓰는가? (Use Cases)

앞서 설명한 '분산 커밋 로그'와 '영속성'이라는 강력한 특징 덕분에, 카프카는 단순한 메시지 전달을 넘어 빅테크 기업들의 핵심 비즈니스 로직을 담당하고 있습니다. 대표적인 4가지 패턴을 소개합니다.

**1) 사용자 활동 추적 (Activity Tracking) - 카프카의 탄생 목적**

링크드인(LinkedIn)이 카프카를 만든 본래 목적입니다. 웹사이트나 앱에서 발생하는 모든 사용자 행동(클릭, 페이지 뷰, 검색, 스크롤 등)을 실시간으로 수집합니다.

- **특징:** 데이터 양이 어마어마합니다.(High Volume). 기존 MQ로는 감당이 불가능하지만, 카프카는 높은 처리량(Throughput)으로 이를 거뜬히 받아냅니다.
- **활용:** 이렇게 모인 데이터는 하둡(Hadoop) 같은 데이터웨어하우스로 보내져 오프라인 분석에 쓰이거나, 실시간 모니터링 시스템으로 전송됩니다.

**2) 마이크로서비스(MSA)의 비동기 통신 (Messaging / Decoupling)**

배달의민족이나 우버 같은 서비스에서 주문이 발생했을 때, 결제/배달/알림 등 수십 개의 마이크로서비스가 동시에 동작해야 합니다.

- **문제:** 서비스끼리 직접 API를 호출(Synchronous)하면, 결제 서버가 죽었을 떄 주문 전체가 실패하는 연쇄 장애가 발생합니다.
- **해결:** '주문 서비스'는 카프카에 "주문 발생함"이라는 메시지만 던지고 잊어버립니다.(Fire and Forget). 결제, 배달, 알림 서비스는 각자의 속도에 맞춰 카프카에서 메시지를 가져가 처리합니다. 이를 통해 시스템 간 결합도를 낮추고(Decoupling) 장애 격리가 가능해집니다.

**3) 로그 집계 및 모니터링 (Log Aggregation)**

수천 대의 서버에서 쏟아지는 애플리케이션 로그, 에러 로그, 서버 메트릭(CPU, RAM 사용량)을 중앙으로 수집하는 파이프라인의 중심입니다.

- **활용:**: 각 서버에 로그 파일을 남기는 대신 카프카로 쏘고, 카프카는 이를 ELK(Elasticsearch, Logstash, Kibana)스택이나 Datadog 같은 모니터링 도구로 전달합니다. 엔지니어는 흩어진 로그를 찾아다닐 필요 없이 한 곳에서 통합 검색을 할 수 있습니다.

**4) 실시간 스트림 프로세싱 (Stream Processing)**

데이터가 저장된 후에 분석하는 것이 아니라, 데이터가 흐르는 그 순간에 분석합니다.

- **넷플릭스(Netflix):** 유저가 영상을 보는 동안 실시간으로 시청 로그를 분석하여, 영상이 끝나자마자 "당신이 좋아할 만한 다른 콘텐츠"를 추천합니다.
- **금융권:** 신용카드 결제 트랜젝션이 들어오는 0.1초 사이에 AI 모델이 패턴을 분석하여 이상 거래(Fraud)를 탐지하고 즉시 차단합니다. 카프카의 낮은 지연 시간(Low Latency) 덕분에 가능한 일입니다.

## 결론

결국 카프카는 **'데이터 호수(Data Lake)'로 가는 거대한 파이프라인'** 이자, 마이크로서비스들의 대화를 중계하는 **'중앙 신경망'** 입니다.

이제 이 거대한 시스템이 물리적으로 어떻게 구성되어 있길래 이런 성능을 낼 수 있는지, 다음 포스팅에서 다루어 보도록 하겠습니다.  

## 참고 문헌

[https://www.confluent.io/blog/event-streaming-platform-1/](https://www.confluent.io/blog/event-streaming-platform-1/)

[

Putting Apache Kafka To Use: A Practical Guide To Building an Event Streaming Platform (Part 1) | Confluent

Putting Apache Kafka To Use: A Practical Guide to Building an Event Streaming Platform.

www.confluent.io

](https://www.confluent.io/blog/event-streaming-platform-1/)

도서: Confluent\_Kafka\_Definitive\_Guide\_Complete

#### 'Data Engineering' 카테고리의 다른 글

| [\[Data Engineering Lab\] #2. Docker Container에 고정 IP 할당하기](https://tedi.tistory.com/55) (0) | 2025.12.20 |
| --- | --- |
| [\[Data Engineering Lab\] #1. Ansible, Vagrant 환경을 Docker로 변경한 이유](https://tedi.tistory.com/54) (0) | 2025.12.20 |
| [StarRocks의 압도적 퍼포먼스 경험기](https://tedi.tistory.com/37) (0) | 2025.12.05 |
| [Cron 기반의 레거시 ETL 파이프라인을, Airflow Dynamic Dag로 우아하게 전환하기](https://tedi.tistory.com/46) (0) | 2025.12.02 |
| [Airflow 살펴보기](https://tedi.tistory.com/31) (0) | 2025.12.01 |