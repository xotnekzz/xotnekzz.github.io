---
title: Doris 전환
description: HDFS/Impala 게임로그 데이터 저장소를 Apache Doris로 전환
date: 2026-02-01
tags:
  - OLAP
featured: true
draft: false
---
> **기간:** 2026.2
> **참여인원:** 1명
> **역할:** 데이터 인프라 구축 및 데이터 마이그레이션
> **기술 스택:** Apache Doris, SeaweedFS, Airflow, Ansible

## 1. Background & Challenges

**40대 규모의 HDFS/Impala 기반 클러스터**는 지난 10년간 수백억 건의 게임 로그와 마케팅 데이터를 안정적으로 처리해온 사내 핵심 인프라였습니다. 하지만 기술적 환경 변화와 인프라 노후화에 따라 시스템 현대화의 필요성이 대두되었습니다.

- **유지보수 및 기술 지원 한계:** Cloudera Impala의 지원 정책이 CDP(Cloudera Data Platform) 중심으로 개편됨에 따라, 레거시 환경에서의 보안 패치 및 버전 최신화에 대한 업무 리소스 부담이 발생하였습니다.
- **고비용 & 저효율 구조 개선:** 10년 전 설계된 아키텍처 특성상 수백억 건의 데이터에 대한 단순 조회가 수십 초 이상 소요되어, 데이터 분석시 답답함이 있었습니다.

## 2. Architecture: As-Is vs To-Be

### As-Is Architecture

![Fluentd가 실시간으로 로그를 변환하지만 TSV를 1시간마다 집중 전송하여 게임 서비스와 공유하는 네트워크에 장애 위험을 유발하는 기존 배치 파이프라인|697](/images/legacy-pipeline-bottleneck.svg)

1. **로그 발송:** 게임 유저가 이벤트 로그를 로그 서버로 발송
2. **로그 수집:** 로그 서버(HTTP GET)가 수신 후 `access.log`에 기록
3. **파싱 및 필터링:** Fluentd가 1시간 단위로 수집 및 TSV 형태로 파싱
4. **저장:** Fluentd에서 HDFS로 TSV 파일 저장
5. **ETL:** Airflow를 통해 Impala 엔진으로 HDFS의 TSV를 쿼리하여 Parquet 포맷의 운영 테이블로 변환/저장
6. **활용:** Impala OLAP 테이블 직접 쿼리 또는 Airflow 가공 후 MariaDB 적재 후 BI 도구(Superset, Metabase) 연결

### To-Be Architecture

![Nginx 로그를 시간 단위로 압축하고 DuckDB로 Parquet 변환한 뒤 Apache Doris에서 분석하는 배치 데이터 파이프라인|697](/images/log-pipeline-duckdb-seaweedfs.svg)

1. **로그 발송 및 수집:** 게임 유저가 전송한 이벤트 로그를 로그 서버가 수신하여 Nginx `access.log`에 기록
2. **로그 회전 및 압축:** `access.log`를 1시간 단위로 rotate하고 gzip으로 압축
3. **원본 로그 동기화:** 압축한 로그 파일을 SeaweedFS에 동기화하여 원본 데이터로 보관
4. **ETL 실행:** Airflow DAG Sensor가 시간 단위 로그 파일의 수신을 감지하면, Docker로 격리한 DuckDB ETL 작업을 실행
5. **분석 포맷 변환:** DuckDB SQL로 로그를 파싱·정제한 뒤 분석에 적합한 Parquet 포맷으로 변환하여 SeaweedFS에 저장
6. **로드 및 활용:** Parquet 데이터를 Apache Doris 운영 테이블에 배치 적재하고 BI 도구(Superset, Metabase 등)와 연동

## 3. Solution & Technical Insights

1. **인프라 재배치만으로 저비용 데이터 플랫폼 현대화 달성**
    - **[Issue]** 신규 서버 도입이 어려운 온프레미스 환경에서 10년 된 노후 장비 40대만으로 최신 OLAP 성능을 구현해야 함.
    - **[Solution]** 과거 MariaDB ColumnStore → StarRocks 전환 성공 사례(쿼리 12.4배 향상)를 근거로 경영진을 설득. 기존 40대 장비를 기능별(SeaweedFS 9, Doris FE 3, BE 28)로 전략적 재배치하여 인프라 구축 비용 100% 절감과 성능 현대화를 동시에 달성.
2. **Shared Nothing 구조 전환을 통한 Network I/O 병목 해소**
    - **[Issue]** 기존 Impala/HDFS(Shared Storage) 구조는 대규모 쿼리 시 연산 노드가 네트워크를 통해 데이터를 끌어와야 하는 'Network I/O' 정체가 성능의 핵심 병목이었음.
    - **[Solution]** 데이터와 컴퓨팅 리소스를 동일 노드에 배치하는 **Apache Doris(Shared Nothing)** 도입. 불필요한 데이터 이동을 제거하고 로컬 디스크 I/O 속도만으로 수백억 건의 데이터를 탐색할 수 있는 아키텍처적 기반 마련.
3. **운영 자동화 (Static to Dynamic Partitioning)**
    - **[Issue]** 레거시 환경에서는 데이터를 적재할 때마다 Airflow 스케줄러가 사전에 파티션을 생성해야 하는 정적 구조였음. 파티션 생성 누락 시 적재 장애로 이어지며, 주기적인 통계 수집(Compute Stats) 등 수동 Ops 부담이 과다함.
    - **[Solution]** Doris의 **Dynamic Partitioning** 기능을 튜닝하여 파티션 생애 주기를 완전 자동화. 엔진 레벨의 자동 통계 수집 및 백그라운드 컴팩션(Compaction) 최적화를 통해 엔지니어의 상시 운영 업무를 제거하고 Zero-Ops 지향.
4. **배치 특성에 맞춘 로그 수집 경량화 및 네트워크 보호**
    - **[Issue]** 로그 서버가 게임 서비스와 동일한 네트워크 대역을 사용하고 있어, Fluentd가 로그를 변환한 뒤 TSV 파일을 전송하는 과정에서 트래픽이 집중되면 게임 서비스 장애로 이어질 위험이 있었음. Fluentd는 실시간으로 로그를 처리했지만 결과 파일은 1시간마다 flush되어 실질적으로는 시간 단위 배치 파이프라인이었으며, 원본 TSV와 변환된 Parquet를 모두 보관해 저장 구조도 중복됨.
    - **[Solution]** Fluentd를 제거하고 Nginx `access.log`를 1시간 단위로 rotate·gzip한 뒤 SeaweedFS에 동기화하도록 수집 구조를 단순화. Airflow DAG Sensor가 파일 수신을 감지하면 Docker로 격리된 DuckDB ETL을 실행하여 Parquet로 변환하도록 구성함. 압축된 원본을 전송해 네트워크 사용량과 순간 부하를 줄였으며, 보관 포맷을 **gzip 원본 + Parquet 분석 데이터**로 정리해 TSV/Parquet 이중 보관 구조를 제거.

## 4. Impact & Result

- 🚀 **쿼리 성능 단축 (최대 1,715배):** 특정 조건의 수백억 건 단순 집계 쿼리 응답 시간을 기존 85초에서 **50ms 이내**로 비약적으로 단축. BI 대시보드 로딩 속도를 실시간 수준으로 개선했습니다.
- 💰 **서버 가용성 및 효율성 극대화:** 신규 서버 도입 없이 기존 40대 장비의 역할을 재정의(SeaweedFS 9, FE 3, BE 28)하는 것만으로 폭발적인 성능 향상을 달성하여 추가 인프라 구축 비용을 100% 절감했습니다.
- 🦾 **ETL 효율화 및 지표 자동화:** Impala의 MV 부재로 인한 복잡한 Airflow DAG(2차 가공) 구조를 Doris MV 기반의 **SQL 레벨 사전 집계**로 전환하여, 파이프라인 운영 리소스를 최소화하고 데이터 정합성을 강화했습니다.
- 📦 **수집 파이프라인 경량화:** Fluentd와 중간 TSV를 제거하고 압축 원본과 Parquet만 유지하여 네트워크 부하와 저장 중복을 줄였습니다. DuckDB ETL을 Docker로 격리해 실행 환경의 재현성과 배치 운영 안정성도 높였습니다.
