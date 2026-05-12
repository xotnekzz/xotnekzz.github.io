---
title: StarRocks의 압도적 퍼포먼스 경험기
description: 1. 들어가며현재 회사에서 MariaDB ColumnStore를 메인 OLAP 데이터베이스로 잘 사용해왔습니다.
date: 2025-12-05
tags:
  - StarRocks
  - OLAP
  - Performance
  - DataEngineering
featured: false
draft: false
---

### 1. 들어가며

현재 회사에서 MariaDB ColumnStore를 메인 OLAP 데이터베이스로 잘 사용해왔습니다. 하지만 어느 순간부터 원인 불명의 '데이터 뻥튀기기' 현상과 커뮤니티 버전이 더 이상 업데이트 되지 않아 안정적인 운영이 어렵다고 판단하여 데이터베이스 교체를 검토하였습니다.

이에 대안으로 Starrocks를 도입했고, 결과는 기대 이상이었습니다. 약 1년 지난 지금 Starrocks는 압도적인 성능과 편의성을 통해 데이터 분석환경에 큰 도움이 되고 있습니다.  
  
제가 직접 경험한 Starrocks 핵심 강점을 소개하고자 합니다.

### 2. Starrocks?

Starrocks는 대규모 데이터 분석을 위해 설계된 MPP(Massively Parallel Processing) 데이터 베이스 입니다. Apache Doris에서 파생되었지만, 독자적인 C++ 벡터화 실행 엔진 CBO(Cost-based-optimization)를 탑재하여 1초 미만의 빠른 쿼리 처리 속도로 대규모 분성을 수행할 수 있도록 설계되었습니다.  

### 3. Architecture

![](/images/posts/starrocks-performance-experience/img-1.png)

[출처] https://docs.starrocks.io/assets/images/architecture_choices-ddd6ad78779f16a6691ec53a1f86ef06.png

Starrocks는 'Shared-nothing' 과 'Shared-data' 2가지 아키텍처 방식을 가지고 있습니다. 간단히 설명하면 'Shared-nothing'은 직접 be 노드를 구성하여 데이터를 저장하는 방식(Local storage)이고, 'Shared-data'는 S3/HDFS와 같은 이미 구성되어있는 데이터 레이크 환경에 쿼리하고 자주 사용되는 데이터는 CN노드가 캐싱하여 빠르게 데이터를 쿼리하는 방식입니다.  
  
본 포스팅에서는 'Shared-nothing' 에 대한 설명을 주로 다루겠습니다.

- FE (Frontend): 클러스터 메타데이터 관리, 클라이언트 연결, 쿼리 플래닝을 담당합니다. (Java)
- BE (Backend): 실제 데이터 저장 및 SQL 실행을 담당합니다. (C++)

BE 모드에서 로컬데이터에 직접 액세스하여 연산을 수행하므로, 네트워크를 통한 불필요한 데이터 전송 및 복사를 방지합니다. 네트워크 오버헤드를 줄여 초고속 쿼리 및 분석 성능을 제공하는 원동력이됩니다.  
  
또한 replica를 지원하여 높은 동시성(High Concurrency)과 데이터 안정성을 보장합니다.  

### 4. 사용해보면서 느낀 강력함

1. **압도적인 Join 성능과 CBO  
	**OLAP DB들이 Join 성능이 좋지 못해 데이터를 넓게 펼쳐야(Flatten) 했다면, Starrocks는 그럴 필요 없습니다.  
	**  
	- CBO (Cost-based optimizer):** 복잡한 다중 테이블 Join시 최적의 실행 계획을 찾습니다.  
	**- 벡터화 엔진 (Vectorized Execution:** cpu의 simd 명령어를 활용해 한 번의 사이클로 여러 데이터를 처리합니다.
2. **표준 SQL을 지원하는 익숙한 사용경험 (MySql 호환)**  
	MySql에 익숙한 자라면 새로운 쿼리 문법을 학습할 필요가 없습니다.  
	  
	**- 표준 SQL 지원** **:** ANSI SQL을 지원  
	**- MySQL 프로토콜 호환** **:** mysql 클라이언트로 접속이 가능하며, Tableau, Superset 등 기존 BI 툴과 드라이버 호환성 이슈 없이 연동 가능
3. **Async Materialized View  
	**  
	**- 쿼리 재작성 (Query rewirte)**: 사용자가 굳이 MV테이블을 지정하지 않고 원본 테이블을 조회해도, Starrocks가 미리 생성된 MV가 있다면 MV를 타도록 쿼리를 변경합니다.  
	- **비동기 업데이트**: 원본 테이블에 데이터 추가 또는 변경이 일어나면 주기적으로 비동기 방식으로 MV가 업데이트 됩니다.  
	**- External Catalog 연동:** HDFS, S3 등 외부 DB 엔진의 테이블 Join이 필요한 경우에도 MV를 활용하여 쿼리 성능 최적화가 가능합니다.

### 5. 데이터 로딩

Starrocks를 사용하면서 가장 큰 매력을 느꼈던 부분은 데이터 로딩에 대한 방법이 다양하고 사용방법이 SQL 단 몇줄로 해결되는 것 이었습니다.

**Stream Load**

```bash
# 로컬의 data.csv를 curl 명령어 한 줄로 적재
curl --location-trusted -u root: \
    -H "label:123" \
    -H "column_separator:," \
    -T data.csv \
    http://<fe_host>:8030/api/mydb/mytable/_stream_load
```

HTTP 프로토콜을 통해 로컬 파일이나 애플리케이션 메모리 상의 스트림 데이터를 실시간으로 적재합니다. Flink나 Spark 커넥터도 내부적으로 이 방식을 사용합니다.  

**Broker Load**

```sql
LOAD LABEL migration_job_2025
(
    DATA INFILE("s3://bucket/data/*")
    INTO TABLE my_table
    FORMAT AS "parquet"
)
WITH BROKER;
-- 백그라운드에서 비동기로 실행되며, SHOW LOAD 명령어로 진행률 확인 가능
```

S3, HDFS 등에 있는 대용량 파일(Parquet, ORC, CSV)을 고속으로 적재하는 비동기 방식입니다. 저희 팀은 기존 데이터를 StarRocks로 이관(Migration)할 때 이 방식을 사용하여 수 테라바이트의 데이터를 빠르고 안정적으로 적재했습니다.

**Routine Load**

```sql
CREATE ROUTINE LOAD my_kafka_job ON my_table
PROPERTIES
(
    "format" = "json"
)
FROM KAFKA
(
    "kafka_broker_list" = "broker1:9092,broker2:9092",
    "kafka_topic" = "user_behavior_log",
    "property.group.id" = "starrocks_group"
);
```

Kafka 토픽을 지정하면 StarRocks가 알아서 Consumer Group이 되어 데이터를 실시간으로 가져옵니다. 별도의 **Consumer 애플리케이션을 개발할 필요가 없어** 파이프라인이 획기적으로 단순해집니다.  
  
**Pipe**

```sql
CREATE PIPE my_s3_pipe
PROPERTIES
(
    "auto_ingest" = "true" -- 파일 감지 시 자동 로드
)
AS INSERT INTO my_table
SELECT * FROM FILES
(
    "path" = "s3://bucket/events/",
    "format" = "parquet"
);
```

HDFS나 S3 경로를 주기적으로 폴링(Polling)하여, 새로 추가되거나 업데이트된 파일을 자동으로 감지해 로딩합니다. Broker Load보다 파일의 유효성 검사나 관리가 더 엄격(Strict)하고 체계적입니다.

### 6. 다른 OLAP DB와의 비교

**1. Apache Doris**

StarRocks는 Apache Doris에서 포크(Fork)된 프로젝트입니다. 뿌리는 같지만 **StarRocks는 "성능의 극한"을 추구** 하며 독자적인 진화를 택했습니다.

- **차이점:** StarRocks는 초기부터 **C++ 기반의 벡터화 엔진** 을 전면 도입하고 고도화하는 데 집중했습니다.
- **결과:** 특히 복잡한 다차원 Join 쿼리나 고성능이 필요한 시나리오에서 StarRocks가 더 민첩한 성능을 보여줍니다.

**2. ClickHouse**

ClickHouse는 단일 테이블 조회 속도만큼은 강력합니다.

- **Join의 한계:** ClickHouse는 Join 성능이 상대적으로 약해 비정규화(Flattening)가 강제됩니다. 반면 StarRocks는 **강력한 Join** 을 지원해 데이터 모델링이 훨씬 자유롭습니다.
- **운영:** ClickHouse는 클러스터 운영 시 Clickhouse Keeper 의존성이 높고 복잡하지만, StarRocks는 클러스터 코디네이터 없이 심플하게 구성됩니다.

| 구분 | Starroocks | Apache Doris | Clickhouse |
| --- | --- | --- | --- |
| 핵심 강점 | 고성능 Join & CBO | 안정성 & 생태계 | 단일 테이블 속도 |
| 운영 난이도 | 쉽다 (FE/BE) | 쉬움 | 복잡 (Cickhouse Keeper 운영) |
| Join 성능 | 최상 | 상 | 중/하 |
| 데이터 갱신 | 실시간 Upsert (PK 테이블 한정) | 지원 | 제한적 |

### 7. Docker 배포 & Grafana 모니터링 지원

**1. Docker Compose로 쉽게 배포 가능합니다. (예제 코드 참고)**

```sql
version: "3"
services:
  starrocks-fe: # Frontend
    image: starrocks/fe-ubuntu:latest
    container_name: starrocks-fe
    ports:
      - "8030:8030" # HTTP (Web UI & Metrics)
      - "9030:9030" # MySQL Protocol
    command: /opt/starrocks/fe/bin/start_fe.sh
    networks: [starrocks-net]

  starrocks-be: # Backend
    image: starrocks/be-ubuntu:latest
    container_name: starrocks-be
    ports:
      - "8040:8040" # BE HTTP (Metrics)
      - "9050:9050" # Heartbeat
    command: /opt/starrocks/be/bin/start_be.sh
    depends_on: [starrocks-fe]
    networks: [starrocks-net]
    volumes: [./be_storage:/opt/starrocks/be/storage]

networks:
  starrocks-net:
    driver: bridge
```

**2. Grafana 모니터링 공식 지원**

![](/images/posts/starrocks-performance-experience/img-2.png)

출처: https://docs.starrocks.io/assets/images/monitor15-210b53b9e827c45dffd4e1c1c37e415c.png

- **Built-in Exporter:** 별도 설치 없이 http://<host>:8040/metrics에서 Prometheus 포맷의 메트릭을 제공합니다.
- **공식 대시보드:** StarRocks 커뮤니티에서 제공하는 공식 Grafana 템플릿을 Import 하면, **QPS, Latency, 리소스 사용량** 등을 즉시 시각화할 수 있습니다.

### 8. 마치며

StarRocks를 운영하며 가장 만족스러웠던 순간은 뛰어난 쿼리성능도 있지만 복잡한 인프라 관리의 수고를 덜고, **데이터 엔지니어가 본질적인 데이터 분석과 가치 창출에 집중할 수 있는 환경** 을 만들어주었다는 점입니다.

단순히 빠른 DB를 넘어, 운영의 효율성까지 고민하는 팀이라면 StarRocks는 정말 좋은 선택지라고 생각합니다. 지금 새로운 OLAP 도입을 고민하고 계신다면, 주저 없이 StarRocks를 검토해 보시기를 적극 추천합니다.

#### 참고.

- [StarRocks 소개 (What is StarRocks)](https://docs.starrocks.io/docs/introduction/what_is_starrocks/)
- [아키텍처 (Architecture)](https://docs.starrocks.io/docs/introduction/Architecture/)
- [주요 기능 (Features)](https://docs.starrocks.io/docs/introduction/Features/)
- [데이터 로딩 (Data Loading)](https://docs.starrocks.io/docs/loading/loading_introduction/loading_concepts/)
- [모니터링 & 알림 (Monitor & Alert)](https://docs.starrocks.io/docs/administration/management/monitoring/Monitor_and_Alert/)
- [OLAP DB 비교 (Estuary.dev)](https://estuary.dev/blog/real-time-olap-databases/)
