---
title: "[Data Engineering Lab] #3. KRaft 모드로 Kafka Cluster 로컬에 구축하기"
date: 2025-12-26
tags:
  - Kafka
  - KRaft
  - Docker
  - DataEngineering
  - Lab
featured: false
draft: false
---

안녕하세요 지난 포스팅([이전 글](./de-lab-2-docker-container-static-ip.md))에 이어 Kafka Cluster를 로컬 제 맥북에 구축해보도록 하겠습니다.

[[Data Engineering Lab] #2. Docker Container에 고정 IP 할당하기](./de-lab-2-docker-container-static-ip.md)

## 1. 클러스터 아키텍처

![](/images/posts/de-lab-3-kafka-kraft-cluster-local/img-1.png)

Kafka Cluster

분산 서버 코디네이터인 `Zookeeper` 를 사용하지 않고 카프카 스스로 메티데이터를 관리하는 `KRaft` 모드를 사용하였으며,  
특히 이 모드에서는 Controller와 Broker 역할을 한번에 수행할 수 있어 설정 편의를 위해 통합모드를 사용하는 카프카 노드 3대로 클러스터를 구성하였습니다.

`KRaft` 모드의 자세한 내용은 아래 링크를 통해 확인해보시길 바랍니다.

[https://developer.confluent.io/learn/kraft/](https://developer.confluent.io/learn/kraft/)

[KRaft - Apache Kafka Without ZooKeeper

Apache Kafka Raft (KRaft) simplifies Kafka architecture by consolidating metadata into Kafka, removing the ZooKeeper dependency. Learn how it works, benefits, and what this means for Kafka's scalability.

developer.confluent.io]([https://developer.confluent.io/learn/kraft/](https://developer.confluent.io/learn/kraft/))

## 2. Docker Compose

```ruby
version: '3.8'

services:
  # ==========================================
  # Kafka Node 1 (IP: 10.100.0.41)
  # ==========================================
  kafka-1:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-1
    restart: always
    ports:
      - "9092:9092"
    environment:
      - KAFKA_NODE_ID=1
      - KAFKA_PROCESS_ROLES=broker,controller
      - KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      - KAFKA_LISTENERS=PLAINTEXT://:29092,CONTROLLER://:9093,EXTERNAL://:9092
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-1:29092,EXTERNAL://localhost:9092
      - KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT
      - CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk
      - KAFKA_LOG_DIRS=/var/lib/kafka/data
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2
    volumes:
      - ./data/kafka-1:/var/lib/kafka/data
    networks:
      default:
        ipv4_address: 10.100.0.41

  # ==========================================
  # Kafka Node 2 (IP: 10.100.0.42)
  # ==========================================
  kafka-2:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-2
    restart: always
    ports:
      - "9093:9092"
    environment:
      - KAFKA_NODE_ID=2
      - KAFKA_PROCESS_ROLES=broker,controller
      - KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      - KAFKA_LISTENERS=PLAINTEXT://:29092,CONTROLLER://:9093,EXTERNAL://:9092
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-2:29092,EXTERNAL://localhost:9093
      - KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT
      - CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk
      - KAFKA_LOG_DIRS=/var/lib/kafka/data
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2
    volumes:
      - ./data/kafka-2:/var/lib/kafka/data
    networks:
      default:
        ipv4_address: 10.100.0.42

  # ==========================================
  # Kafka Node 3 (IP: 10.100.0.43)
  # ==========================================
  kafka-3:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka-3
    restart: always
    ports:
      - "9094:9092"
    environment:
      - KAFKA_NODE_ID=3
      - KAFKA_PROCESS_ROLES=broker,controller
      - KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      - KAFKA_LISTENERS=PLAINTEXT://:29092,CONTROLLER://:9093,EXTERNAL://:9092
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-3:29092,EXTERNAL://localhost:9094
      - KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT
      - CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk
      - KAFKA_LOG_DIRS=/var/lib/kafka/data
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2
    volumes:
      - ./data/kafka-3:/var/lib/kafka/data
    networks:
      default:
        ipv4_address: 10.100.0.43

  # ==========================================
  # Kafka UI (IP: 10.100.0.44)
  # ==========================================
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    restart: always
    ports:
      - "8080:8080"
    environment:
      - KAFKA_CLUSTERS_0_NAME=local-cluster
      # 변경된 IP(41, 42, 43) 반영
      - KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=10.100.0.41:29092,10.100.0.42:29092,10.100.0.43:29092
      - DYNAMIC_CONFIG_ENABLED=true
    networks:
      default:
        ipv4_address: 10.100.0.44

# ==========================================
# Network Configuration
# ==========================================
networks:
  default:
    name: dataplatform-net
    external: true
```

### 1. 노드 식별 및 역할 설정

| 환경변수 | 설정값 (예시) | 설명 |
| --- | --- | --- |
| **KAFKA_NODE_ID** | `1`, `2`, `3` | 클러스터 내에서 노드를 구분하는 고유 번호 |
| **KAFKA_PROCESS_ROLES** | `broker, controller` | **KRaft 모드** 활성. 데이터 저장 및 클러스터 관리 역할 병행 |
| **CLUSTER_ID** | `MkU3O...` | 클러스터 고유 ID. 모든 노드가 동일해야 하나의 클러스터로 구성됨 |
| **KAFKA_LOG_DIRS** | `/var/lib/kafka/data` | 카프카 메시지 로그가 저장되는 내부 데이터 경로 |

### 2. 통신 및 리스너 설정

카프카 리스너는 접속 주체(내부 노드, 외부 클라이언트, 컨트롤러)에 따라 통신 경로를 분리하는 역할을 합니다.

| 환경변수 | 설정값 내용 | 설명 |
| --- | --- | --- |
| **KAFKA_LISTENERS** | `29092(INT)`, `9093(CTL)`, `9092(EXT)` | 서버가 실제로 수신 대기할 포트와 프로토콜 정의 |
| **KAFKA_ADVERTISED_LISTENERS** | `localhost:909x`, `kafka-x:29092` | 클라이언트가 접속 시 응답받을 실제 접속 주소 (내/외부 구분) |
| **KAFKA_CONTROLLER_QUORUM_VOTERS** | `1@kafka-1:9093, ...` | 리더 선출을 위한 컨트롤러 노드들의 목록 (투표권자 리스트) |
| **KAFKA_LISTENER_SECURITY_...** | `CONTROLLER:PLAINTEXT, ...` | 각 리스너 이름에 사용할 보안 프로토콜 매핑 |
| **KAFKA_INTER_BROKER_...** | `PLAINTEXT` | 브로커들끼리 데이터를 복제할 때 사용할 리스너 이름 |

### 3. 고가용성 및 복제 설정

| 환경변수 | 설정값 | 설명 |
| --- | --- | --- |
| **KAFKA_OFFSETS_TOPIC_...** | `3` | 컨슈머 읽기 위치(Offset) 저장 토픽의 복제본 수 |
| **KAFKA_TRANSACTION_STATE_...** | `3` | 트랜잭션 상태 로그의 복제본 수 |
| **KAFKA_TRANSACTION_STATE_..._MIN_ISR** | `2` | 트랜잭션 성공을 위해 동기화되어야 할 최소 복제본(ISR) 수 |

### 4. Kafka UI

| 항목 | 상세 설정 | 설명 |
| --- | --- | --- |
| **고정 IP 할당** | `10.100.0.41 ~ 44` | 도커 네트워크 내 고정 IP 할당으로 통신 안정성 확보 |
| **포트 포워딩** | `9092, 9093, 9094` | 호스트(localhost)에서 각 브로커로 개별 접속하기 위한 포트 구분 |
| **볼륨 마운트** | `./data/kafka-x` | 컨테이너 재시작/삭제 시에도 데이터를 유지하기 위한 호스트 연결 |
| **Kafka UI 연결** | `10.100.0.4x:29092` | 관리 도구가 내부 망 IP를 통해 전체 클러스터를 모니터링 |

### 5. Cluster IP 직접 접근

![](/images/posts/de-lab-3-kafka-kraft-cluster-local/img-2.png)

docker-mac-net-connect을 통한 IP 직접접근

Docker Desktop for Mac에서는 컨테이너 IP에 직접 접근이 불가능하기 때문에 컨테이너마다 외부 포트를 다르게 지정해야하는 불편함이 있습니다.

그래서 지난포스팅( [/blog/dataengineering/de-lab-2-docker-container-static-ip )](./de-lab-2-docker-container-static-ip.md) 에서 세팅을 했다면 도커 포트설정없이 IP로 접근이 가능합니다.

## 3. Kafka Cluster 배포

docker-compose.yml 파일을 작성한 위치에서 아래 커맨드로 배포를 시작합니다.

```
docker compose up -d
```
![](/images/posts/de-lab-3-kafka-kraft-cluster-local/img-3.png)

Kafka-ui

localhost:8080 또는 10.100.0.44:8080 로 접속하여 클러스터 배포가 잘 되었는지 확인합니다.
