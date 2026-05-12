---
title: "[Data Engineering Lab] #9. Routine Load를 사용하여 Kafka 데이터를 StarRocks에 실시간 적재하기"
date: 2026-01-16
tags:
  - StarRocks
  - Kafka
  - RoutineLoad
  - DataEngineering
  - Lab
featured: false
draft: false
---

안녕하세요. 지난 포스팅([이전 글](./de-lab-8-debezium-mariadb-kafka-cdc.md))에서 Debeziun 커넥터를 띄우고 이를 사용하여 "MariaDB (source) -> Debezium -> Kafka" 형태의 CDC 파이프라인 구축해 보았습니다.

이번에는 이 파이프라인의 핵심인 **분석(Analytics)** 단계입니다. Kafka에 쌓이고 있는 이커머스 주문 이벤트 데이터를 StarRock가 실시간으로 읽어들여(Consume), 분석용 테이블에 적재(Upsert)하는 과정을 다뤄보겠습니다.

## 1. 구현 목표

![](/images/posts/de-lab-9-kafka-to-starrocks-routine-load/img-1.png)

- 상황: 이커머스 쇼핑몰에서 주문이 발생하면 MariaDB에 데이터가 생성됩니다.
- 흐름: Debezium이 이 변경사항(CDC)을 감지하여 Kafka Topic(orders_topic)에 JSON 포맷으로 발행합니다.
- 목표: StarRocks의 `Routine Load` 기능을 사용하여 Kafka Topic을 구독하고, 변경된 주문 정보를 실시간 StarRocks 테이블에 반영(Insert/Update)합니다.

## 2. 왜 Kafka Sink Connector 대신 Routine Load인가?

보통 Kafka에 데이터를 DB로 가져올 땐 Kafka Sink Connect를 사용하지만, StarRocks에서 제공하는 `Routine Load` 가 매력적인 선택지가 될 수 있습니다.

| 비교 항목 | **Routine Load (StarRocks Native)** | **Kafka Sink Connector** |  |
| --- | --- | --- | --- |
| 아키텍처 복잡도 | 단순함 (StarRocks가 직접 Kafka 접속) | 복잡함 (별도의 Connect 클러스터 운영 필요) |  |
| 관리 포인트 | SQL 문 하나로 Job 관리 (생성/중지/재개) | Connector 설정 파일 및 Worker 프로세스 관리 |  |
| 데이터 변환 | 간단한 컬럼 매핑, 필터링(WHERE) 지원 | SMT를 이용한 복잡한 변환 가능 |  |
| 리소스 효율 | StarRocks BE 노드 리소스 활용 | 별도의 JVM(Connect) 리소스 필요 |  |

우리는 복잡한 데이터 변환이 필요 없고, 별도의 컴포넌트를 추가할 리소스가 제한적이기 때문에 SQL 하나로 제어 가능한 Routine Load를 사용하는 것이 훨씬 효율적입니다.

## 3. Kafka 메시지 구조 분석

Routine Load를 작성하기 전에, Kafka 토픽(mysql.demo_db.oreders)에 실제로 어떤 데이터가 들어오는지 확인해보곘습니다. Debezium은 데이터의 변경 전(before)과 변경 후(after)상태를 모두 포함하는 구조를 가집니다.  

**- 실제로 Kafka 메시지 예시:** 주문상태가 PENDING에서 SHIPPED로 변경(Update)되었을 때의 로그입니다.

```clojure
{
  "before": {
    "id": 1,
    "user_id": 1,
    "product_id": 1,
    "quantity": 2,
    "total_price": "Lt4=",
    "status": "PENDING",
    "order_date": "2026-01-12T15:19:14Z",
    "updated_at": "2026-01-12T15:19:14Z"
  },
  "after": {
    "id": 1,
    "user_id": 1,
    "product_id": 1,
    "quantity": 2,
    "total_price": "Lt4=",
    "status": "SHIPPED",  // <-- 변경된 값
    "order_date": "2026-01-12T15:19:14Z",
    "updated_at": "2026-01-12T15:19:18Z"
  },
  "source": { ... },
  "op": "u",  // <-- Update 오퍼레이션
  "ts_ms": 1768231158013
}
```
- **after**: 우리가 적재해야 할 최신 데이터가 들어있습니다.
- **op**: 변경 유형을 나타냅니다. (c: create, u: update, d:delete, r: read)

우리는 이 JSON 구조에서 `after` 내부의 데이터와 `op` 값만 추출하여 StarRocks에 넣겠습니다.

## 4. StarrRocks 분석용 테이블 생성하기

가장 먼저 Kafka 데이터를 받아 분석용으로 저장할 StarRocks 테이블을 생성합니다. Source DB(MariaDB)의 변경 사항을 반영해야 하므로,  
StarRocks의 `Primary Key` 모델을 사용하여 중복 데이터를 방지하고 최신 데이터를 유지하도록 구성합니다.

```sql
CREATE TABLE \`orders_analytics\` (
  \`order_id\` bigint(20) NOT NULL COMMENT "주문 ID (Source: id)",
  \`customer_id\` bigint(20) NULL COMMENT "고객 ID (Source: user_id)",
  \`order_amount\` decimal(10, 2) NULL COMMENT "주문 금액 (Source: total_price)",
  \`order_status\` varchar(20) NULL COMMENT "주문 상태 (Source: status)",
  \`order_date\` date NULL COMMENT "주문 일자 (Source: order_date)",
  \`op_check\` varchar(2) NULL COMMENT "CDC Operation Type (c, u, d, r)"
) ENGINE=OLAP 
PRIMARY KEY(\`order_id\`) -- 주문ID 기준 Upsert (덮어쓰기)
DISTRIBUTED BY HASH(\`order_id\`) BUCKETS 3 
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true", -- PK 조회 성능 최적화
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "1" -- 데모 환경이므로 복제본 1 설정
);
```

## 5. Rotuine Load 생성

이제 StarRocks가 Kafka Topic을 구독하도록 Routine Laod Job을 생성합니다. 별도의 프로세스 설치 없이 SQL만으로 ETL로직(데이터 매핑, 필터링 로직)을 대체할 수 있습니다.

## 주요 설정 포인트

**1. Column Mapping:** Source JSON 필드와 Target 테이블 컬럼을 1:1로 매핑하지 않고, 필요한 컬럼만 선택적으로 가져옵니다.  
**2. Delete 필터링:** `op_check` 컬럼으로 삭제된 데이터는 적재하지 않도록 필터링합니다.  
**3. JSON Paths:** Debezium JSON 구조($.after.xx)에서 필요한 데이터만 쏙쏙 뽑아냅니다.

```swift
CREATE ROUTINE LOAD demo_db.orders_analytics_rl ON orders_analytics
COLUMNS(
    order_id,
    customer_id,
    order_amount,
    order_status,
    order_date,
    op_check
),
WHERE op_check != 'd'
PROPERTIES
(
    "format" = "json",
    "strip_outer_array" = "false",
    "jsonpaths" = "[\"$.after.id\", \"$.after.user_id\", \"$.after.total_price\", \"$.after.status\", \"$.after.order_date\", \"$.op\"]",
    "desired_concurrent_number" = "1",
    "max_error_number" = "0",
    "task_consume_second" = "30",
    "max_batch_interval" = "20"
)
FROM KAFKA
(
    "kafka_broker_list" = "10.100.0.41:29092,10.100.0.42:29092,10.100.0.43:29092",
    "kafka_topic" = "mysql.demo_db.orders",
    "kafka_partitions" = "0",
    "property.kafka_default_offsets" = "OFFSET_BEGINNING"
);
```

## 6. 적재 상태 확인 및 검증하기

## 6.1 상태 조회

```sql
SHOW ROUTINE LOAD FOR demo_db.orders_analytics_rl;
```

## 6.2 데이터 검증

### - 주문번호 54878 현재 상태 확인 (StarRocks)

```
SELECT * FROM \`demo_db\`.\`orders_analytics\` WHERE \`order_id\` = 54878
```

| **order_id** | **customer_id** | **order_amount** | **order_status** | **order_date** | **op_check** |
| --- | --- | --- | --- | --- | --- |
| 54878 | 955 |  | PENDING | 2026-01-16 | c |

현재 주문 번호 `54878` 는 PENDING 상태입니다.

### - 주문번호 54878 상태를 업데이트 (MariaDB - Source)

배송이 완료되어 주문번호 `54878` 의 상태를 `SHIPPED` 로 변경합니다.

```sql
UPDATE orders SET status = 'SHIPPED' WHERE id = 54878;
```

### - 카프카 토픽 이벤트 메시지 확인

```json
{
    "before": {
        "id": 54878,
        "user_id": 955,
        "product_id": 2,
        "quantity": 3,
        "total_price": "AJfC",
        "status": "PENDING",
        "order_date": "2026-01-16T07:00:47Z",
        "updated_at": "2026-01-16T07:00:47Z"
    },
    "after": {
        "id": 54878,
        "user_id": 955,
        "product_id": 2,
        "quantity": 3,
        "total_price": "AJfC",
        "status": "SHIPPED",
        "order_date": "2026-01-16T07:00:47Z",
        "updated_at": "2026-01-16T07:03:20Z"
    },
    "source": {
        "version": "2.4.2.Final",
        "connector": "mysql",
        "name": "mysql",
        "ts_ms": 1768547000000,
        "snapshot": "false",
        "db": "demo_db",
        "sequence": null,
        "table": "orders",
        "server_id": 223344,
        "gtid": null,
        "file": "mysql-bin.000002",
        "pos": 30023773,
        "row": 0,
        "thread": null,
        "query": null
    },
    "op": "u",
    "ts_ms": 1768547000756,
    "transaction": null
}
```

before와 after의 status 차이를 비교해여 SHIPPED로 변경되었는지 확인합니다.

### - 주문번호 54878 최종 상태 확인 (StarRocks)

```
SELECT * FROM \`demo_db\`.\`orders_analytics\` WHERE \`order_id\` = 54878
```

| **order_id** | **customer_id** | **order_amount** | **order_status** | **order_date** | **op_check** |
| --- | --- | --- | --- | --- | --- |
| 54878 | 955 |  | SHIPPED | 2026-01-16 | u |

다음과 같이 StarRocks 테이블에도 SHIPPED로 자동으로 업데이트 되었다면 성공입니다.

## 마치며

이제 이커머스 트래픽 생성기(python)에서 발생한 데이터가 MariaDB에 저장되고 Kakfa를 거쳐 StarRocks 분석 테이블 까지 실시간으로 적재되는 파이프라인이 완료되었습니다.

다음 포스팅에서는 이렇게 적재된 분석 데이터를 Redash를 사용한 실시간 대시보드를 구축해보도록 하겠습니다.

