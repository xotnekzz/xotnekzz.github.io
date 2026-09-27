---
title: DuckDB 이론 — 프로세스 안에서 동작하는 분석 엔진
description: DuckDB의 SQL 계획, 벡터 실행, 파일 읽기와 내장형 배포 모델을 설명합니다.
date: 2026-09-23
tags: [DuckDB, OLAP, Architecture]
draft: false
---

DuckDB는 애플리케이션 프로세스 안에 들어가는 분석용 데이터베이스입니다. Python, CLI 또는 다른 호스트 프로그램이 SQL을 호출하면 같은 프로세스의 DuckDB 엔진이 이를 처리합니다. 기본 구조에 별도의 서버·브로커·분산 Worker가 등장하지 않는다는 점이 Spark·Doris와 가장 큰 차이입니다.

![DuckDB의 SQL 계획과 DataChunk 실행 경로](/images/posts/data-platform-theory/duckdb-architecture.svg)

## 쿼리는 어떤 단계를 지나갑니까?

| 단계 | 역할 |
|---|---|
| Parser·Binder | SQL 구문을 읽고 테이블·열 이름과 타입을 실제 객체에 연결합니다. |
| Logical Plan·Optimizer | 필터·조인·집계의 논리적 순서를 표현하고 불필요한 읽기와 연산을 줄입니다. |
| Physical Plan | 실행 가능한 연산자 트리를 만듭니다. |
| Scan | DuckDB DB 파일 또는 Parquet·CSV 같은 외부 파일에서 필요한 데이터를 읽습니다. |
| Vectorized Engine | 한 행씩 처리하는 대신 여러 행을 묶은 `DataChunk`를 연산자 사이로 보냅니다. |
| Storage | 영속 DB 파일은 row group과 압축 등을 사용합니다. 외부 파일을 직접 질의할 때는 꼭 DuckDB DB 파일로 복사할 필요가 없습니다. |

## `SELECT` 한 번의 데이터 흐름

애플리케이션이 SQL을 제출하면 Binder가 참조를 확인하고 Optimizer가 실행 계획을 바꿉니다. Scan은 필요한 열과 조건을 고려해 데이터 청크를 읽습니다. 필터·조인·집계 연산자가 청크를 처리해 최종 결과를 호출자에게 반환하거나 파일·테이블에 씁니다. 이 과정의 병렬성은 로컬 CPU와 스레드에서 나옵니다. 여러 머신에 자동으로 작업을 배치한다는 뜻은 아닙니다.

DuckDB의 기본 실행 단위인 `Vector`는 한 열의 값 묶음이고 `DataChunk`는 여러 Vector를 합친 행 묶음입니다. 그래서 “벡터화”는 임베딩 벡터 검색을 뜻하는 말이 아니라 **분석 연산을 묶음 단위로 실행**한다는 뜻입니다.

## 열 지향 저장과 벡터 실행의 관계

분석 쿼리는 대개 테이블의 모든 열이 아니라 일부 열만 읽습니다. 열 지향 저장은 열별 값을 가까이 배치해 필요한 열만 읽고 압축을 활용하기 쉽습니다. 실행기는 읽은 열을 Vector로 만들어 같은 연산을 많은 값에 적용합니다. 저장 배치인 row group과 메모리 실행 단위인 DataChunk는 서로 연결되지만 같은 개념은 아닙니다. 전자는 파일·테이블의 영속 구조, 후자는 연산자 사이에서 전달되는 메모리 구조입니다.

DuckDB의 실행 경로는 입력을 연산자 트리에 공급하는 push 기반 벡터 실행을 사용합니다. 물리 연산자는 청크를 받으면 선택·투영·집계 등을 수행해 다음 연산자로 전달합니다. 한 번에 한 레코드마다 가상 호출을 반복하는 방식보다 벡터 연산과 SIMD 활용에 유리할 수 있습니다. 성능은 여전히 데이터 분포, 조인 알고리즘, 메모리, I/O에 좌우됩니다.

## SQL 계획 단계가 분리된 이유

Parser는 문자열을 구문 트리로 만들고 Binder는 열 이름과 타입을 확인합니다. Optimizer는 필터 푸시다운, 불필요한 열 제거, 조인 순서 같은 규칙으로 논리 계획을 다듬습니다. Physical Planner는 실제 실행 가능한 Scan·Join·Aggregate 연산자를 선택합니다. SQL 구문 오류, 존재하지 않는 열, 실행 계획상 비싼 조인은 이처럼 다른 단계의 문제입니다.

Parquet를 직접 읽는 SQL이 DuckDB 데이터베이스 파일을 반드시 만든다는 뜻은 아닙니다. 파일 시스템·HTTP 등 확장 기능을 통해 외부 데이터를 읽고, 결과를 기존 파일이나 DuckDB의 영속 테이블로 쓸 수 있습니다. 따라서 임시 분석에는 배포가 단순하지만, 동시에 여러 프로세스가 같은 로컬 DB 파일에 접근할 때의 동시성·파일 공유를 분산 데이터베이스처럼 가정해서는 안 됩니다.

## 트랜잭션과 영속 파일

DuckDB DB 파일에 대한 변경은 트랜잭션의 커밋·롤백 모델을 따릅니다. Write-Ahead Log(WAL)는 커밋된 변경을 데이터 파일에 체크포인트하기 전까지 보관해 내구성 회복에 사용됩니다. 메모리 DB와 읽기 전용 파일 질의, 영속 파일 쓰기는 저장 수명과 동시성 특성이 다릅니다. 파일 포맷의 하위 호환성 목표가 있더라도 버전 업그레이드 전에는 공식 Storage Versions 안내와 백업 절차를 확인해야 합니다.

## 언제 구조가 유리합니까?

로컬·단일 노드에서 파일을 직접 읽는 탐색 분석, ETL 중간 처리, 앱 안의 분석 기능에 잘 맞습니다. 큰 데이터를 다룰 수 있더라도 메모리, 임시 디스크, 파일 읽기 대역폭이라는 호스트의 한계는 남습니다. 운영 장애를 볼 때는 SQL 계획과 파일 스캔량, 메모리 사용량, 임시 디스크 공간을 차례로 확인해 보세요. 영속 DB 파일의 버전 호환성도 업그레이드 때 확인해야 합니다.

## 실무 적용: 시간별 로그 ETL 엔진으로 쓰기

사내에서는 DuckDB를 **분산 클러스터 없이 돌아가는 배치 ETL 엔진**으로 씁니다. `fastlog-etl`은 게임 Nginx access 로그를 한 시간 단위로 정규화해 Parquet으로 적재하는 파이프라인이고, 변환 로직 전부가 DuckDB SQL입니다. 이론에서 말한 "ETL 중간 처리"에 해당하는 사용법입니다.

```text
Airflow (fastlog_hourly_etl, 매시 25분)
  └─ 로그 서버별 DockerOperator (일회성 컨테이너, 병렬)
       └─ python -m etl.main -d <날짜> -H <시간> -s <서버>
            ├─ SeaweedFS Filer에서 시간별 gzip 다운로드
            ├─ DuckDB: read_csv → 정규화·쿼리스트링 파싱 → GeoIP 보강
            ├─ COPY ... TO PARQUET (PARTITION_BY, ZSTD, 48개 컬럼)
            └─ SeaweedFS S3 업로드 → Doris Broker Load
```

### 단일 프로세스 엔진이라 생기는 설계

- **메모리 한도는 컨테이너보다 작게**: `memory_limit`을 컨테이너 `mem_limit`보다 낮게(기본 2GB) 잡아, DuckDB가 한도를 넘으면 OOM Kill 대신 임시 디스크로 넘기게 합니다. 이론의 "호스트의 한계는 남는다"를 설정으로 관리하는 셈입니다.
- **gzip은 먼저 풀기**: DuckDB는 `.gz` 하나를 스레드 하나로 풀기 때문에, 파싱 전체가 압축 해제 속도에 묶입니다. 측정해 보니 스레드를 8개로 늘려도 gzip을 직접 읽을 때는 약 1.5배밖에 빨라지지 않았지만, 먼저 풀어 둔 평문 파일은 약 6배 빨라졌습니다. 그래서 작업 디렉터리에 한 번 풀어 둔 뒤 `read_csv`가 모든 스레드로 병렬 파싱하게 했습니다.
- **VIEW와 TABLE 선택**: 정규화 결과는 기본적으로 VIEW(스트리밍)로 두어 메모리를 아낍니다. 메모리가 넉넉한 환경에서는 환경변수 하나로 TABLE로 materialize해 gzip 파싱을 한 번만 하게 바꿀 수 있습니다. RAM과 속도를 맞바꾸는 스위치입니다.
- **파싱 실패는 버리지 않기**: 타입 변환·파싱에 실패한 행은 날짜·시간·서버별 JSONL Dead Letter Queue에 남기고, 실행 요약(성공 여부, 처리 행 수, 소요 시간, DLQ 행 수)을 audit 라인으로 출력합니다.

### 멱등한 출력

출력 경로는 `appid/logdate=<이벤트 날짜>/inputdatetime=<배치 시간>/`입니다. 한 시간치 로그에도 여러 날짜의 이벤트가 섞여 있어 `logdate`로 흩어지지만, 재실행의 단위는 **배치 시간(`inputdatetime`)**입니다.

- 새 Parquet을 모두 올린 뒤에 같은 prefix의 이전 객체를 지웁니다(write-then-clear). 중간에 실패해도 빈 슬롯이 남지 않습니다.
- 결과가 0행이면 업로드를 건너뜁니다. 빈 결과가 기존 데이터를 덮어쓰지 못하므로 오래된 날짜를 백필해도 안전합니다.
- 실제로 쓴 파티션 목록을 stdout 마커로 내보내고, Airflow가 이를 Asset 이벤트에 실어 Doris 적재 DAG에 넘깁니다.

같은 DuckDB로 SeaweedFS의 로그를 즉석에서 분석한 사례는 [AI와 DuckDB로 Nginx 로그 분석하기](/blog/de/duckdb-seaweedfs-nginx-log-analysis/)에 있습니다.


**공식 문서:** [Internals Overview](https://duckdb.org/docs/current/internals/overview), [Execution Format](https://duckdb.org/docs/lts/internals/vector), [Storage Format](https://duckdb.org/docs/current/internals/storage)
