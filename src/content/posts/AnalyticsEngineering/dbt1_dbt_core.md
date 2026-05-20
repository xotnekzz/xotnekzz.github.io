---
title: dbt 살펴보기 (dbt_core)
date: 2026-05-20
tags:
  - AnalyticsEngineering
featured: false
draft: false
---
## dbt란?
**dbt (Data Build Tool)** 는 데이터 웨어하우스 안에서 SQL을 사용하여 데이터 변환(Transform)할 수 있게 해주는 오픈소스 도구입니다. ETL 워크플로우에서 "T"단계를 담당하며, 분석 엔지니어와 데이터 엔지니어가 소프트웨어 엔지니어링의 모범 사례(버전관리, 모듈화, 테스트, 문서화 등)를 데이터 변환 작업에 적용할 수 있도록 돕습니다.

## dbt Core

**dbt Core**는 dbt Labs가 개발해 Apache Liscense 2.0으로 공개한 오픈소스 데이터 변환 도구입니다. **Python으로 작성된 CLI**도구 이며, 분석가와 데이터 엔지니어가 SQL과 Jinja만으로 데이터 웨어하우스 내부의 변환 로직을 코드로 관리할 수 있게 해줍니다. 산업 표준이 된 **ELT** 패러다임의 "T(Transform)"단 계를 담당하는 도구로, 현재 나와 있는 dbt Cloud, dbt Fusion 엔진도 모두 이 dbt Core의 프레임워크 위에서 출발했습니다.

dbt Core 핵심 철학은 "데이터 변환에도 소프트 엔지니어링의 모범 사례를 적용하자"는 것 입니다. 즉 모든 변환 로직은 Git으로 버전 관리 되는 SQL 파일이 되고, 모듈화-재사용-테스트-문서화-CI/CD가 자연스럽게 간으해 집니다.

동작 방식은 간단합니다. 사용자가 `SELECT`문으로 모델을 작성하면, dbt Core가 이를 `CREATE TABLE AS` 또는 `CREATE VIE AS`문으로 컴파일해 데이터 웨어하우스에 직접 전송하고 실행시킵니다. dbt Core자체는 데이터를  저장하지도, 직접 처리하지도 않습니다. 실제 연산은 Snowflake, BigQuery, Redshift, Postgres, Databricks 같은 웨어하우스에서 일어납니다.

웨어하우스와 통신할 때는 어댑터(adapter)라는 플러그인 구조를 사용합니다. 예를 들어 Postgres는 `dbt-postgres`, Snowflake는 `dbt-snowflake` 어댑터를 설치하면 됩니다. 어댑터를 설치하면 의존성으로 `dbt-core` 가 함께 설치됩니다.


## dbt Core 주요 기능
dbt Core의 주요 기능을 정리하면 다음과 같습니다.

**모델(Models)**: 변환 로직을 담은 SQL 파일이며, `ref()` 함수로 모델 간 의존성을 선언하면 dbt가 자동으로 DAG(Directed Acyclic Graph)를 만들고 실행 순서를 결정합니다. 

**시드(Seed)**: CSV 형태의 작은 정적 데이터를 웨어하우스에 테이블로 로드합니다.

**스냅샷(Snapshots)**: Type 2 SCD(Slowly Changing Dimension) 처리를 자동으로 수행해 변경 이력을 보존합니다.

**테스트(Tests)**: `not null`, `unique`, `accepted_values`, `relationships` 같은 기본 테스트와 사용자 정의 SQL 테스트로 데이터 품질을 검증합니다.

**문서화(Docs)**: 모델,컬럼,설명과 Lineage 그래프를 자동으로 정적 사이트로 생성합니다.

**Jinja와 매크로(Macros)**: SQL안에서 변수, 반복문, 조건문을 사용하고 함수처럼 재사용 가능한 코드를 정의 할 수 있습니다.

**소스(Source)**: 원천 테이블을 명명-문서화하고 freshness 체크를 수행합니다.

## dbt 프로젝트 구조
```bash
my_dbt_project/
├── dbt_project.yml          # 프로젝트 설정 파일 (필수)
├── profiles.yml             # ~/.dbt/ 디렉토리에 위치, 웨어하우스 연결 정보
├── models/                  # SQL 모델 파일들
│   ├── staging/             # 원천 데이터 정제 (1:1 매핑)
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── schema.yml       # 모델/컬럼 문서 + 테스트
│   ├── intermediate/        # 중간 변환 단계
│   │   └── int_orders_joined.sql
│   └── marts/               # 비즈니스 최종 테이블
│       ├── dim_customers.sql
│       └── fct_orders.sql
├── seeds/                   # CSV 파일 (소형 룩업 데이터)
│   └── country_codes.csv
├── snapshots/               # SCD Type 2 스냅샷
│   └── orders_snapshot.sql
├── tests/                   # 사용자 정의 singular 테스트
│   └── assert_positive_total_payment.sql
├── macros/                  # 재사용 가능한 Jinja 매크로
│   └── cents_to_dollars.sql
├── analyses/                # 일회성 분석 쿼리 (실행되지 않음)
├── docs/                    # 추가 문서 블록
└── target/                  # 컴파일/실행 결과물 (gitignore 권장)
```

각 디렉토리의 역할을 좀 더 자세히 보면 다음과 같습니다.

`dbt_project.yml`은 모든 프로젝트의 진입점입니다. 프로젝트 이름,버전, 사용할 profile, 각 디렉토리 경로(model-paths, sed-paths 등), 모델멸 materialization 설정 등이 들어갑니다.

`profiles.yml` 은 보안상 프로젝트 디렉토리가 아닌 `~/.dbt/` 아래에 둡니다. 웨어하우스 호스트, 사용자, 비밀번호, 스키마 같은 연결정보를 담습니다.

`models/` 는 보통 `staging -> intemediate -> mart` 3계층으로 구성합니다. **staging**은 원천 테이블을 1:1로 정제하는 단계, **intermediate**는 여러 **staging**을 결합하는 중간 단계, **marts**는 BI도구가 직접 조회하는 비즈니스 최종 테이블입니다.

`schema.yml`은 모델 옆에 두는 메타데이터 파일로, 모델,컬럼,설명과 테스트를 함께 선업합니다.

## 간단한 실습으로 dbt 찍먹하기 (Postgres + dbt Core)

실습은 **Postgres**를 예시로 들지만, 어댑터만 바꾸고 SQL 문법 호환만 갖추면 어떤 웨어하우스에서도 동일하게 동작합니다.

### 설치

```bash
# 1. 프로젝트 폴더 생성 및 가상환경 만들기
mkdir dbt_practice && cd dbt_practice
python3 -m venv env
source env/bin/activate

# 2. dbt-postgres 설치 (dbt-core가 함께 설치)
python -m pip install --upgrade pip
python -m pip install dbt-postgres

# 3. 설치확인
dbt --version
```

### 프로젝트 초기화

```bash
dbt init jaffle_shop
cd jaffle_shop
```

`dbt init`을 실행하면 **Posrgres** 접속 정보를 물어보고, 입력한 값을 `~/.dbt/profiles.yml` 에 저장합니다. 잘 연결되는지 확인하려면 다음 명령을 실행합니다.

```bash
dbt debug
```

`All checks passed!` 메시지가 나오면 준비 끝입니다.

### 시드(seed) 데이터 추가

`seeds/` 폴더에 작은 CSV를 두 개 만들어 봅니다.

`seed/raw_customers.csv`

```csv
id,first_name,last_name 1,Michael,P. 2,Shawn,M. 3,Kathleen,P.

```

`seeds/raw_orders.csv`

```csv
id,user_id,order_date,status
1,1,2024-01-01,completed
2,1,2024-01-03,completed
3,2,2024-01-05,returned
4,3,2024-01-06,completed
```

CSV를 웨어하우스에 테이블로 로드합니다.

```
dbt seed
```

### Staging 모델 작성

`models/staging/` 폴더를 만들고 다음 두 파일을 작성합니다.

`models/staging/stg_customers.sql`

```sql
SELECT
	id as customer_id,
	first_name,
	last_name
FROM {{ ref('raw_customers') }}
```

`models/stagig/stg_orders.sql`

```sql
SELECT
	id as order_id,
	user_id as customer_id,
	order_date,
	status
FROM {{ ref('raw_orders') }}
```

`{{ ref('...') }}` 함수가 다른 모델을 참조하는 dbt의 핵심 문법입니다. 이를 통해 dbt는 모델 간 의존성 그래프를 자동으로 구성합니다.

### Marts 모델 작성

`models/marts/customer_orders.sql`

```sql
{{ config(materialized='table') }}

WITH customers AS (
	SELECT * FROM {{ ref('stg_customers') }}
),
orders AS (
	SELECT * FROM {{ ref('stg_orders') }}
),
customer_orders AS (
	SELECT
		c.customer_id,
		c.first_name,
		c.last_name,
		COUNT(o.order_id) AS total_orders,
		min(o.order_date) AS first_order_date,
		max(o.order_date) AS most_recent_order_date
	FROM customer c
	LEFT JOIN orders o
		ON c.customer_id = o.customer_id
	GROUP BY 1,2,3,
)
SELECT * FOM customer_orders
```

{{ config(materialized='table') }} 블록은 이 모델을 뷰가 아닌 실제 테이블로 만들도록 지시합니다. 기본값은 `view`입니다.

### 테스트와 문서 추가

```yml
version: 2

models:
  - name: stg_customers
    description: "고객 마스터 정제 테이블"
    columns:
      - name: customer_id
        description: "고객 고유 ID"
        tests:
          - not_null
          - unique

  - name: stg_orders
    description: "주문 정제 테이블"
    columns:
      - name: order_id
        tests:
          - not_null
          - unique
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: status
        tests:
          - accepted_values:
              values: ['completed', 'returned', 'pending']
```

### 실행

```bash
# 모델만 빌드.
dbt run

# 테스트만 빌드.
dbt test

# seed + snapshot + run + test를 의존성 순서대로 한 번에 실행
dbt build
```

특정 모델만 실행하고 싶다면  `--select` 옵션을 씁니다.

```bash
dbt run --select stg_customers
dbt run --select staging # 디렉토리 단위
dbt run --select +customer_orders # customer_orders와 모든 상위 의존 모델
```

### 문서 생성과 lineage 확인

```bash
dbt docs generate
dbt docs serve
```

브라우저가 자동으로 열리며, 모든 모델,컬럼,설명과 함께 시각적인 Graph를 확인 할 수 있습니다.

### 결과 확인

웨어하우스에 접속해서 보면 다음 객체들이 생성되어 있습니다.

- `raw_customers`, `raw_orders` — seed로 로드된 테이블
- `stg_customers`, `stg_orders` — staging 뷰(기본 머티리얼라이제이션)
- `customer_orders` — 최종 마트 테이블

```sql
select * from customer_orders;
```