---
title: "[Data Engineering Lab] #8. Debezium 커넥터 등록하기 — MariaDB와 Kafka CDC 구현하기"
date: 2026-01-13
tags:
  - Debezium
  - Kafka
  - MariaDB
  - CDC
  - DataEngineering
  - Lab
featured: false
draft: false
---

지난 포스팅에서 Binlog가 활성화된 MariaDB에 실시간 이커머스 트래픽 데이터를 생성 및 저장하는 과정을 구현하였습니다.  
이번 시간에는 Debezium MariaDB Connecto 통해 MariaDB에 저장된 데이터를 실시간으로 Kafka에 전송하는 과정을 구현해보겠습니다.

## 1. 구현 목표

![](/images/posts/de-lab-8-debezium-mariadb-kafka-cdc/img-1.png)

소스데이터인 MariaDB(Mysql)에서 발생하는 Create, Update, Delete 로그를 debezium connector가 읽어 Kafka Topic을 생성하여 메세지를 전달하는 것까지가 목표입니다.

## 2. Debezium 이란?

Debezium은 데이터베이스의 변경 사항(INSERT, UPDATE, DELETE)을 실시간으로 감지(Capture)하여, 이를 이벤트 스트리 형태로 Kafka에 전송해 주는 오픈소스 분산 CDC(Capture Data Capture)플랫폼 입니다.

Kafka Connect 프레임워크 위에서 Source Connector 형태로 동작하며, 별도의 코딩없이 설정만으로 데이터 파이프라인을 구축 할 수 있습니다.

### 왜 Debezium을 사용할까?

Debezium을 사용하는 몇 가지 장점을 소개하겠습니다.

### 1. 모든 변경 감지

폴링(Poling)방식은 `SELECT* FROM table WHERE updated_at > last_check` 와 같이 쿼리를 날려 데이터를 가져오는 방식이기 때문에 삭제된 데이터에 대해서는 감지할 수 가 없습니다..

그러나 Debezium은 DB의 트랜잭션 로그(Binlog)를 직접 읽기 때문에, 데이터가 삭제된 사실까지 정확하게 캡쳐하여 전송이 가능합니다.

### 2. 실시간성 (Low Latency)

트랜잭션 로그에 기록되는 즉시 이벤트를 발생시키므로, 거의 실시간으로 데이터가 동기화 됩니다.

### 3. 데이터베이스 부하 최소화

폴링방식은 주기적으로 SELECT 쿼리를 날려야하므로 데이터가 많을 수록 부하가 발생하지만,.

Debezium은 DB엔진을 사용하지 않고 로그파일만 읽어가는 방식으로 상대적으로 부하가 훨씬 적습니다.

### 4. Outbox Pattern

마이크로서비스 환경에서 DB에 데이터를 저장하고, 동시에 Kafka를 메세지를 보낼때 두 작업이 Atomic(원자적)하게 묶이지 않으면, DB에는 저장되었으나 Kafka 전송은 실패하는 데이터 불일치가 발생할 수 있습니다.

마이크로 사비스에서 DB에만 데이터가 잘 저장하면, Debezium이 알아서 Kafka에 데이터 쏴주는 구조가 되어 코드를 단순화시킬수 있고, 데이터 정합성이 보장됩니다. (Outbox Pattern)

## 3. Debezium Connector를 Docker Compose로 띄우기

```yaml
version: '3.8'

services:
  debezium:
    image: quay.io/debezium/connect:2.4
    container_name: debezium-connector
    restart: always
    ports:
      - "8083:8083"
    environment:
      # VM Kafka Cluster IPs (server-3, 4, 5)
      - BOOTSTRAP_SERVERS=10.100.0.41:29092,10.100.0.42:29092,10.100.0.43:29092
      - GROUP_ID=1
      - CONFIG_STORAGE_TOPIC=my_connect_configs
      - OFFSET_STORAGE_TOPIC=my_connect_offsets
      - STATUS_STORAGE_TOPIC=my_connect_statuses
      - KEY_CONVERTER=org.apache.kafka.connect.json.JsonConverter
      - VALUE_CONVERTER=org.apache.kafka.connect.json.JsonConverter
      # JSON 데이터만 남기기 위해 Schema 정보 비활성화 (선택 사항)
      - CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE=false
      - CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE=false

      # [중요] 컨테이너 메모리 제한에 맞춰 Java Heap 사이즈 조절 (컨테이너 제한보다 약간 작게 설정)
      - KAFKA_HEAP_OPTS=-Xms1G -Xmx1536M
    networks:
      - default
    # --- Debezium 메모리 제한 설정 ---
    deploy:
      resources:
        limits:
          memory: 2G

# ==========================================
# Network Configuration
# ==========================================
networks:
  default:
    name: dataplatform-net
    external: true
```

## 4. Debezium Mariadb Connector 등록하기

```php
#!/bin/bash

# Debezium 서비스 URL
CONNECT_HOST="127.0.0.1"
CONNECT_PORT="8083"
HEADER="Content-Type: application/json"

echo "Waiting for Debezium to start..."

# Health Check Loop
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' http://${CONNECT_HOST}:${CONNECT_PORT}/)" != "200" ]]; do
    sleep 5
    echo -n "."
done

echo -e "\nDebezium is up! Registering Connector..."

# 커넥터 등록 요청 (Kafka Broker IP 수정 포함)
curl -i -X POST -H "${HEADER}" http://${CONNECT_HOST}:${CONNECT_PORT}/connectors/ -d '{
  "name": "mariadb-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "mariadb",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "dbz",
    "database.server.id": "184054",
    "topic.prefix": "mysql",
    "database.include.list": "demo_db",
    "schema.history.internal.kafka.bootstrap.servers": "10.100.0.41:29092,10.100.0.42:29092,10.100.0.43:29092",
    "schema.history.internal.kafka.topic": "schema-changes.inventory"
  }
}'

echo -e "\n\nConnector Registration Completed."
```

## 스크립트 상세 분석 및 설정 가이드

위 스크립트는 단순히 커넥터를 등록하는 것을 넘어, 운영 환경에서 고려해야 할 중요한 설정들이 포함되어 있습니다.

### 1. 서비스 준비 대기 (Health Check)

```lua
while [[ ... != "200" ]]; do ... done
```

Kafka Connect(포트 8083)가 정상적으로 `200 OK` 응답을 줄 때까지 5초 간격으로 대기합니다. 이 로직이 없으면 컨테이너가 채 뜨기도 전에 요청을 보내 "Connection Refused" 에러가 발생할 수 있습니다.

### 2. 기본 설정 (Config)

- **`connector.class`**: MariaDB는 MySQL 프로토콜과 호환되므로 `io.debezium.connector.mysql.MySqlConnector` 를 사용합니다.
- **`database.server.id`**: MariaDB 클러스터 내에서 이 커넥터를 식별하는 **고유 ID(숫자)** 입니다. 다른 Slave 서버나 커넥터와 겹치지 않게 설정해야 합니다.
- **`database.include.list`**: DB 내의 모든 테이블을 가져오지 않고, `demo_db` 라는 특정 데이터베이스만 모니터링하겠다는 필터링 설정입니다.

### 3. 네트워크 설정 주의사항 (가장 중요!)

```
"schema.history.internal.kafka.bootstrap.servers": "10.100.0.41:29092,..."
```

Debezium은 테이블 구조 변경(`ALTER TABLE` 등) 내역을 별도의 Kafka 토픽에 저장합니다.

- **IP 설정 이유**: 이 주소는 **Debezium 컨테이너 내부에서** Kafka 브로커로 접속하기 위한 주소입니다.
- **환경에 따른 수정**: 위 예시는 특정 사설 IP 대역(`10.100.x.x`)을 사용하고 있습니다. 만약 로컬 Docker Compose 환경이라면 `kafka:9092` 로, 외부 서버라면 해당 서버의 공인 IP로 변경해주어야 합니다.

### 4. 스크립트 실행

스크립트 실행후 Kafka-UI를 확인하면 아래와 같이 2개의 connector 토픽이 생성되면 성공적으로 커넥터가 등록된 것 입니다.

![](/images/posts/de-lab-8-debezium-mariadb-kafka-cdc/img-2.png)

## 5. CDC 테스트 - 이커머스 데이터 생성기 실행

[이전 글](./de-lab-7-ecommerce-traffic-generator.md) 에서 생성한 이커머스 데이터 생성기를 실행하여, 데이터 베이스에 데이터를 입력, 수정, 삭제를 진행해보겠습니다.

```sql
(venv) tskim@MacBook-Pro mariadb % python3 gen_data.py
🚀 Starting Traffic Generator... (Press Ctrl+C to stop)
[USER] Created: Russell Smith
[ORDER] New Order! User 1 bought Item 1 ($ 119.98)
[ORDER] New Order! User 1 bought Item 4 ($ 45.0)
[UPDATE] Order 1 status changed to SHIPPED
[UPDATE] Order 2 status changed to SHIPPED
[USER] Created: Tina Burke
[ORDER] New Order! User 2 bought Item 2 ($ 647.5)
[ORDER] New Order! User 2 bought Item 2 ($ 647.5)
^[[DELETE] Order 4 was cancelled (Deleted)
[ORDER] New Order! User 1 bought Item 4 ($ 45.0)
[ORDER] New Order! User 2 bought Item 1 ($ 59.99)
[ORDER] New Order! User 1 bought Item 3 ($ 60.0)
[USER] Created: Christopher Santos
[ORDER] New Order! User 1 bought Item 2 ($ 259.0)
```

아래 이미지 처럼 데이터가 생성된 테이블 이름피 포함된 토픽이 생성되고 메세지가 발행되면 성공입니다.

**토픽 생성 확인**

![](/images/posts/de-lab-8-debezium-mariadb-kafka-cdc/img-3.png)

#### 토픽 내 메세지 생성 확인

![](/images/posts/de-lab-8-debezium-mariadb-kafka-cdc/img-4.png)
