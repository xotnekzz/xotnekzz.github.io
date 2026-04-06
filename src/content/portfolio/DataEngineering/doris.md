---
title: Doris 전환
description: HDFS/Impala 게임로그 데이터 저장소를 Apache Doris로 전환
date: 2026-02-01
tags:
  - Apache Doris
  - OLAP
featured: false
---

## 1. Background & Challenges

**40대 규모의 HDFS/Impala 기반 클러스터**는 지터난 10년간 수백억 건의 게임 로그와 마케팅 데이터를 안정적으로 처리해온 사내 핵심 인프라였습니다. 하지만 기술적 환경 변화와 인프라 노후화에 따라 시스템 현대화의 필요성이 대두되었습니다.

- **유지보수 및 기술 지원 한계:** Cloudera Impala의 지원 정책이 CDP(Cloudera Data Platform) 중심으로 개편됨에 따라, 레거시 환경에서의 보안 패치 및 버전 최신화에 대한 업무 리소스 부담이 발생하였습니다.
- **고비용 & 저효율 구조 개선:** 10년 전 설계된 아키텍처 특성상 수백억 건의 데이터에 대한 단순 조회가 수십 초 이상 소요되어, 데이터 분석시 답답함이 있었습니다.

## 2. Architecture: As-Is vs To-Be

### As-Is Architecture

![기존 HDFS/Impala 기반의 아키텍처는 총 40대 규모(NameNode 3대, DataNode 37대)로 구성되었으며, Hive Metastore와 Impala를 연동하여 SQL로 게임로그를 분석합니다.](/images/Legacy%20Pipeline.svg)

1. **로그 발송:** 게임 유저가 이벤트 로그를 로그 서버로 발송
2. **로그 수집:** 로그 서버(HTTP GET)가 수신 후 `access.log`에 기록
3. **파싱 및 필터링:** Fluentd가 1시간 단위로 수집 및 TSV 형태로 파싱
4. **저장:** Fluentd에서 HDFS로 TSV 파일 저장
5. **ETL:** Airflow를 통해 Impala 엔진으로 HDFS의 TSV를 쿼리하여 Parquet 포맷의 운영 테이블로 변환/저장
6. **활용:** Impala OLAP 테이블 직접 쿼리 또는 Airflow 가공 후 MariaDB 적재 후 BI 도구(Superset, Metabase) 연결

### To-Be Architecture

![Shared Nothing 방식의 자체 스토리지 엔진과 고성능 OLAP 데이터베이스 Doris를 도입하여 쾌적한 로그 분석 환경을 구축하는 것을 목표로 합니다.](/images/Fluentd%20to%20HDFS%20Data-2026-03-12-113747.svg)

1. **로그 발송 & 수집:** (As-Is와 동일)
2. **파싱 및 필터링:** (As-Is와 동일)
3. **저장 및 압축:** Fluentd에서 SeaweedFS(버퍼)에 1시간 단위(1h batch)로 **TSV 포맷**의 데이터를 저장함과 동시에, 장기 보관용 로그는 **별도 스토리지 서버에 압축 저장**
4. **로드:** **Apache Airflow** 스케줄링을 통해 SeaweedFS에 저장된 **1시간 단위 TSV 데이터**를 **Apache Doris Broker Load**로 운영 테이블에 배치 적재
5. **활용:** Doris 기반 고성능 쿼리 및 BI 도구(Superset, Metabase 등) 연결

## 3. Solution & Technical Insights

1. **인프라 재배치만으로 저비용 데이터 플랫폼 현대화 달성**
    - **[Issue]** 신규 서버 도입이 어려운 온프레미스 환경에서 10년 된 노후 장비 40대만으로 최신 OLAP 성능을 구현해야 함.
    - **[Solution]** 과거 MariaDB ColumnStore → StarRocks 전환 성공 사례(쿼리 12.4배 향상)를s 근거로 경영진을 설득. 기존 40대 장비를 기능별(SeaweedFS 9, Doris FE 3, BE 28)로 전략적 재배치하여 인프라 구축 비용 100% 절감과 성능 현대화를 동시에 달성.
2. **Shared Nothing 구조 전환을 통한 Network I/O 병목 해소**
    - **[Issue]** 기존 Impala/HDFS(Shared Storage) 구조는 대규모 쿼리 시 연산 노드가 네트워크를 통해 데이터를 끌어와야 하는 'Network I/O' 정체가 성능의 핵심 병목이었음.
    - **[Solution]** 데이터와 컴퓨팅 리소스를 동일 노드에 배치하는 **Apache Doris(Shared Nothing)** 도입. 불필요한 데이터 이동을 제거하고 로컬 디스크 I/O 속도만으로 수백억 건의 데이터를 탐색할 수 있는 아키텍처적 기반 마련.
3. **운영 자동화 (Static to Dynamic Partitioning)**
    - **[Issue]** 레거시 환경에서는 데이터를 적재할 때마다 Airflow 스케줄러가 사전에 파티션을 생성해야 하는 정적 구조였음. 파티션 생성 누락 시 적재 장애로 이어지며, 주기적인 통계 수집(Compute Stats) 등 수동 Ops 부담이 과다함.
    - **[Solution]** Doris의 **Dynamic Partitioning** 기능을 튜닝하여 파티션 생애 주기를 완전 자동화. 엔진 레벨의 자동 통계 수집 및 백그라운드 컴팩션(Compaction) 최적화를 통해 엔지니어의 상시 운영 업무를 제거하고 Zero-Ops 지향.
4. **하드웨어 제약(No-AVX2)의 아키텍처적 돌파**
    - **[Issue]** 도입 검토 중인 최신 OLAP 엔진(StarRocks 등)들이 노후 서버의 벡터화 연산 세트(AVX2) 미지원으로 인해 실행조차 불가능한 물리적 한계 직면.
    - **[Solution]** **No-AVX2 빌드를 공식 지원하는 Apache Doris**로 전략적 선회. 하드웨어 제약을 소프트웨어 선택으로 우회함과 동시에, SeaweedFS를 **Ingestion Buffer**로 정의하여 파이프라인의 안정성을 높이는 아키텍처적 유연성 발휘.
    - **[과제] No-AVX2는 SIMD를 지원하지 않아서**

## 4. Impact & Result

- 🚀 **쿼리 성능 단축 (최대 1,715배):** 특정 조건의 수백억 건 단순 집계 쿼리 응답 시간을 기존 85초에서 **50ms 이내**로 비약적으로 단축. BI 대시보드 로딩 속도를 실시간 수준으로 개선했습니다. [StarRocks vs Impala 벤치마크 자료](https://www.notion.so/StarRocks-vs-Impala-31bcfd4e6dcf80eb9423d07be49010db?pvs=21)
- 💰 **서버 가용성 및 효율성 극대화:** 신규 서버 도입 없이 기존 40대 장비의 역할을 재정의(SeaweedFS 9, FE 3, BE 28)하는 것만으로 폭발적인 성능 향상을 달성하여 추가 인프라 구축 비용을 100% 절감했습니다.
- 🦾 **ETL 효율화 및 지표 자동화:** Impala의 MV 부재로 인한 복잡한 Airflow DAG(2차 가공) 구조를 Doris MV 기반의 **SQL 레벨 사전 집계**로 전환하여, 파이프라인 운영 리소스를 최소화하고 데이터 정합성을 강화했습니다.