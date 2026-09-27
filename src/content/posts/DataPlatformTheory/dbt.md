---
title: dbt Core 이론 — SQL 모델 DAG와 웨어하우스 실행
description: dbt Core의 파싱, ref 의존성, 어댑터, materialization과 테스트 흐름을 설명합니다.
date: 2026-09-23
tags: [dbt, AnalyticsEngineering, Architecture]
draft: false
---

dbt Core는 SQL 변환을 **버전 관리 가능한 프로젝트**로 만드는 도구입니다. 모델은 보통 `SELECT` 문으로 작성하고, dbt가 의존성을 해석하여 실행 SQL을 만듭니다. 실제 데이터를 계산하고 저장하는 곳은 dbt 프로세스가 아니라 연결한 데이터 플랫폼입니다.

![dbt Core 프로젝트에서 웨어하우스까지의 처리 경로](/images/posts/data-platform-theory/dbt-architecture.svg)

## 파일과 실행기의 역할

| 요소 | 역할 |
|---|---|
| Model | 변환 SQL입니다. 모델 하나가 보통 하나의 데이터 관계(테이블·뷰 등)로 구체화됩니다. |
| `source()` | 프로젝트 밖의 원천 테이블을 명시적으로 참조합니다. 문서화와 신선도 점검의 기준이 됩니다. |
| `ref()` | 다른 모델을 참조하면서 DAG의 의존 간선을 만듭니다. 이름을 SQL 문자열로 직접 쓰는 것과 다릅니다. |
| Parser·Compiler | 프로젝트 SQL·YAML·Jinja를 읽고 의존 그래프 및 실제 실행 SQL을 만듭니다. |
| Adapter | 대상 데이터베이스의 연결, SQL 방언, 생성 방식을 제공합니다. |
| Materialization | 결과를 view, table, incremental 등의 형태로 만드는 전략입니다. |
| Data Test | 쿼리 결과가 예상 조건을 위반하는 행을 찾습니다. 변환 성공과 품질 성공을 분리해 볼 수 있습니다. |

## 모델 두 개가 실행되는 흐름

`stg_orders`가 `source('app', 'orders')`를 읽고, `fct_orders`가 `ref('stg_orders')`를 읽는다고 가정하겠습니다. dbt는 먼저 의존성을 해석해 `stg_orders → fct_orders` 순서를 정합니다. 매크로와 Jinja를 대상 DB의 SQL로 컴파일하고, 어댑터가 쿼리를 보냅니다. 데이터는 **원천 테이블 → 웨어하우스 안의 staging → mart**로 이동합니다. dbt CLI와 웨어하우스 사이에는 명령과 결과 상태가 오갑니다.

`dbt run`은 모델 구축, `dbt test`는 테스트 실행, `dbt build`는 선택한 리소스의 구축과 테스트를 DAG 순서로 수행합니다. Incremental 모델은 이미 만든 대상에 새 데이터를 반영하지만, 변경 데이터 식별 조건과 중복 처리 설계가 필요합니다. `unique` 테스트를 추가했다고 원천의 중복이 자동 수정되지는 않습니다.

## 변환 DAG는 어떻게 만들어집니까?

dbt는 모델 파일을 읽고 `ref()`와 `source()` 호출을 해석해 노드와 의존 간선을 구성합니다. Jinja 매크로는 프로젝트 설정과 실행 컨텍스트를 이용해 SQL 일부를 생성합니다. 그래서 dbt 프로젝트는 단순한 SQL 파일 모음보다 **컴파일 가능한 의존성 그래프**에 가깝습니다. 순환 참조는 실행 순서를 만들 수 없으므로 그래프 구성 단계에서 오류가 됩니다.

기본 모델 실행은 보통 두 단계를 거칩니다. 먼저 프로젝트 정의로 실행 SQL을 컴파일하고, 다음으로 Adapter가 대상 플랫폼에 맞는 SQL을 전송합니다. dbt는 웨어하우스에 SQL을 제출하고 상태를 기록하지만, 자체적으로 전체 테이블을 메모리에 읽어 변환하는 엔진은 아닙니다. 데이터 처리 비용은 대상 플랫폼의 쿼리와 저장 작업에서 발생합니다.

## Materialization은 모델의 물리적 수명입니다

`view`는 쿼리 정의를 저장하고 조회 시 계산을 위임합니다. `table`은 실행 시 결과를 물리화하며, `incremental`은 설정된 필터·키 전략으로 기존 결과를 유지하면서 일부 데이터를 갱신합니다. 선택 기준은 모델 데이터량, 조회 지연, 갱신 주기, 목적지 플랫폼의 지원 기능입니다. 이름이 같더라도 Adapter와 데이터 플랫폼마다 세부 구현이 다를 수 있습니다.

Incremental 모델은 수학적으로 “이전 결과 + 새 입력”으로 전체 결과와 같은 상태를 만드는 규칙을 작성하는 일입니다. 늦게 도착한 수정 데이터의 조회 범위를 너무 좁게 잡으면 과거 결과가 오래된 채 남을 수 있습니다. 재실행 시 중복을 막을 고유 키, 갱신 범위, 삭제 반영, 초기 전체 적재의 기준을 모델별로 정의해야 합니다.

## 테스트와 스냅샷은 서로 다른 질문에 답합니다

Data Test는 현재 데이터가 `not_null`, `unique`, 관계 조건 등 기대한 불변 조건을 만족하는지 확인합니다. Snapshot은 현재 행과 이전에 관찰한 행을 비교해 변경 이력을 남기는 메커니즘입니다. 테스트는 이상 상태를 감지하고, Snapshot은 시간에 따른 상태 변화를 보존합니다. 둘 다 원천 시스템의 CDC 로그나 비즈니스 이벤트 원장을 대체하지 않습니다.

모델 변경을 배포할 때는 코드 diff뿐 아니라 DAG 하류 영향, materialization 전환, 권한, 테스트 커버리지를 봅니다. view에서 table로 바꾸거나 키·스키마를 바꾸면 데이터베이스 객체의 재생성·이관 비용이 생길 수 있습니다.

장애가 나면 파싱·컴파일 오류인지, DB 권한·SQL 실행 오류인지, 테스트의 데이터 품질 실패인지 먼저 나눠 확인해 보세요. 이 구분이 수정 책임을 명확하게 합니다.

## 실무 적용: Doris 위의 dbt와 Airflow 실행 계약

사내에서는 하나의 저장소에 도메인별 dbt 프로젝트 7개(광고 수익 통합, 게임 로그 리포트, LiveOps KPI, 마케팅, UA 매체, CX, 정산)를 두고, **모두 `dbt-doris` 어댑터로 Apache Doris를 대상 엔진**으로 씁니다. 이론에서 말한 대로 dbt는 SQL을 컴파일해 Doris에 제출할 뿐이고, 원천 테이블 → Silver → Gold 마트로의 데이터 이동은 전부 Doris 안에서 일어납니다.

### 계층과 스키마 규칙

- **Medallion 계층**: 원천은 `source()`로 선언된 Doris raw·bronze 테이블, 정제·표준화는 Silver, 지표·리포트는 Gold 마트입니다. 중간 가공 모델은 `ephemeral`로 두어 DB 객체를 만들지 않고 서브쿼리로 합칩니다.
- **dev/운영 스키마 분리**: `generate_schema_name` 매크로가 운영 target이 아니면 스키마 앞에 `zdev_` 접두사를 붙입니다. `profiles.yml`의 dev 스키마는 운영과 같은 이름으로 두고, 접두사는 **매크로 한 곳에서만** 붙입니다. 두 곳에서 붙이면 `zdev_zdev_`가 됩니다.
- **자격증명**: `profiles.yml`에는 `env_var()`만 두고 실제 값은 저장소 밖 `.env`에서 읽습니다.
- 필수 매크로(`generate_schema_name`, `make_temp_relation`, DDL 매크로)는 새로 작성하지 않고 기존 프로젝트에서 **파일째 복사**합니다. 프로젝트 간 차이를 `diff` 한 번으로 잡기 위해서입니다.

### Materialization은 대부분 직접 만들었습니다

이론에서 Incremental 모델은 "이전 결과 + 새 입력 = 전체 결과"를 만드는 규칙이라고 했습니다. Doris에서는 기본 `incremental`만으로 이 규칙을 안전하게 지키기 어려워, 모델 대부분이 **커스텀 materialization**을 사용합니다. 저장소 전체에서 기본 `incremental`은 3개 모델뿐이고, `doris_txn_swap`이 35개 모델로 가장 많이 쓰입니다.

| Materialization | 동작 |
|---|---|
| `doris_txn_swap` | 결과를 tmp 테이블에 먼저 CTAS(트랜잭션 밖, 느린 작업) → 영향받은 날짜마다 `BEGIN → DELETE → INSERT → COMMIT` |
| `doris_temp_partition_swap` | 임시 파티션에 데이터를 채운 뒤 `REPLACE PARTITION`으로 조회 공백 없이 교체 |
| `doris_multi_date_txn_swap`, `doris_date_range_swap` | 여러 날짜·날짜 구간 단위 교체 |
| `doris_full_swap` | 전체 테이블 교체 |

공통 원칙은 **"처리 구간을 통째로 갈아 끼운다"**입니다. 같은 날짜를 다시 실행하면 그 날짜만 교체되므로 재시도와 백필이 멱등합니다. `target_repoid`(게임 ID) 변수가 있으면 DELETE 범위를 그 게임으로 좁혀, 여러 게임을 병렬로 빌드해도 서로의 데이터를 지우지 않습니다. 또 tmp CTAS 전에 세션의 `query_timeout`·`insert_timeout`을 낮춥니다. 클라이언트가 끊겨도 Doris FE가 쿼리를 취소하지 않아 수 시간짜리 좀비 쿼리가 I/O를 점유한 경험 때문입니다.

테이블 생성도 dbt에 맡기지 않습니다. Doris의 파티션·버킷·키 모델을 정확히 지정하기 위해 모델마다 `create_<model>_if_not_exists` DDL 매크로를 두고, 테이블이 없는데 매크로도 없으면 컴파일 에러로 멈추게 했습니다.

### Airflow에서의 실행 계약

운영 반영은 dbt 저장소에 파일을 추가하는 일이 아니라, Airflow Variable `dbt_metadata_config`에 **config 1건을 등록하는 것**입니다. config 1건이 DAG 1개가 됩니다.

```json
{
  "dag_id": "doris_roimon_gdata_facebook",
  "dbt_project": "roimon",
  "dbt_model": "gdata",
  "dbt_target": "prod",
  "dbt_vars": { "target_pid": "facebook" },
  "group_key": "target_account",
  "group_values": ["account_a", "account_b"],
  "assets": ["doris://fastlog/hourly"],
  "outlets": ["roimon.gdata"],
  "dq_steps": ["pre_validate", "post_validate"]
}
```

생성되는 DAG는 다음 모양입니다.

```text
skip_if_already_processed → initialize_date → create_table_if_not_exists
  → [pre_validate → run_dbt → post_validate] × group_values (병렬)
  → emit_outlets (fan-in: 모든 그룹 성공 시 1회)
```

- `initialize_date`는 **처리 날짜 하나**를 정해 `start_date`와 `end_date`에 같은 값으로 주입합니다. 우선순위는 수동 conf → Asset에서 상속한 partition_key → `data_interval_start - n_days_ago` 순입니다. 모델은 이 vars로 자기 날짜 구간만 읽고 교체합니다.
- `group_values`마다 독립 Task 시퀀스를 만들고 그 값을 dbt var로 넘깁니다. 한 그룹이라도 실패하면 `emit_outlets`가 실행되지 않아 하류가 불완전한 데이터로 깨어나지 않습니다.
- `dbt_target`을 빼면 dev로 돕니다. 운영 등록은 `prod`를 명시해야 합니다.
- dbt는 Worker 이미지 안의 전용 venv에서 실행되고, 기본 30분 타임아웃을 넘기면 dbt 프로세스 그룹째 종료됩니다.

### 테스트는 opt-in으로, 결과는 OpenMetadata로

운영 기본값은 `dbt run`만 실행합니다. 이론에서 `dbt build`가 구축과 테스트를 함께 수행한다고 했지만, 기존 DAG의 동작과 실행 시간을 바꾸지 않기 위해 **테스트는 `dq_steps`로 선택한 DAG에서만** 돕니다.

- `pre_validate`: config의 `inlets`(원천 테이블)에 대응하는 dbt Source를 `dbt ls`로 찾아 Source Test를 실행합니다. 원천이 비었거나 깨졌으면 변환 전에 멈춥니다.
- `post_validate`: 대상 모델의 Model Test를 실행합니다.
- 결과는 `run_results.json`·`manifest.json`에서 읽어 OpenMetadata의 Test Case/Result로 기록합니다. 테스트 YAML의 `meta.data_quality_dimension`(Completeness 등)이 OM의 품질 차원이 되고, 결과가 한 건이라도 저장된 테이블에는 DQ 커버리지 태그가 붙습니다.

```yaml
data_tests:
  - data_missing:
      name: data_missing
      description: "현재 실행의 날짜·게임 범위에 데이터가 한 건도 없는 상태를 검사합니다."
      config:
        meta:
          data_quality_dimension: Completeness
      arguments:
        partition_column: logdate
```

테스트도 모델과 같은 날짜·그룹 vars를 받아 **이번 실행이 교체한 범위만** 검사합니다. 테이블 전체를 매번 스캔하는 테스트는 Doris 부하와 실행 시간 모두에 부담이 되기 때문입니다. dbt의 기본 개념은 [dbt 살펴보기](/blog/dae/dbt1_dbt_core/)에도 정리해 두었습니다.


**공식 문서:** [dbt 프로젝트 개요](https://docs.getdbt.com/docs/build/projects), [Models](https://docs.getdbt.com/docs/build/sql-models), [Materializations](https://docs.getdbt.com/docs/build/materializations)
