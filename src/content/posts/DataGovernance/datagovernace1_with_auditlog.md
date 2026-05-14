---
title: Audit Log 로 만든 테이블 생애주기 거버넌스 대시보드 도입기
description: Audit Log 로 만든 테이블 생애주기 거버넌스 대시보드 도입기
date: 2026-05-14
tags:
  - DataGovernance
  - Grafana
featured: false
---
## 들어가며 — "이 테이블, 누가 쓰는 거예요?"

데이터 플랫폼 운영에서 답하기 가장 까다로운 질문 중 하나입니다. 누군가 분명 쓰고 있을 것 같은데, 누구인지는 모릅니다. 안 쓰는 것 같지만 함부로 지울 수도 없습니다. 그렇게 데이터 웨어하우스에는 **안 쓰이지만 안 지워지는 테이블**이 시간이 갈수록 쌓여갑니다.

이걸 자동화하려면 두 가지 정보가 필요했습니다.

- **연결 정보** — 이 테이블을 누가, 어떻게 참조하는가? → **Lineage**
- **사용 정보** — 이 테이블이 실제로 쓰이고 있는가? → **Usage**

첫 번째는 **OpenMetadata 의 Lineage 기능**으로 해결했습니다 *(별도 글 작성 예정)*. 이번 글은 두 번째 — 사용 정보를 audit_log 에서 뽑아내 거버넌스 대시보드로 만든 이야기입니다.

---

## 1장. 출발 — 사용량을 데이터로

데이터 정리는 늘 "한 번 다 같이 보고 정리합시다" 로 시작해서 흐지부지됩니다. 이유는 매번 똑같습니다:

- 1000개가 넘는 테이블을 사람이 하나하나 확인할 수 없음
- "누가 쓰는지" 물어볼 때마다 답이 다름
- 정리한 다음 누군가가 "그거 우리가 쓰는데요?" 라고 등장
- 결국 무서워서 아무것도 못 지움

거버넌스를 사람의 기억력 대신 **데이터로** 옮기려면 audit_log 가 자연스러운 후보였습니다. 모든 쿼리는 audit_log 에 기록되고, 어느 사용자가 어떤 SQL 을 실행했는지 정확히 알 수 있으니까요.

다만 우리 환경에는 3개의 OLAP/OLTP 클러스터가 있고, 각자 audit_log 의 형태가 다릅니다.

| 클러스터 | Audit 위치 | 수집 방식 |
|---|---|---|
| **Doris** | `__internal_schema.audit_log` | 기본 설정만으로 자동 수집 |
| **StarRocks** | `starrocks_audit_db__.starrocks_audit_tbl__` | 별도 audit-loader 플러그인 |
| **MariaDB** | `mysql-audit.log.*` (파일) | server_audit 플러그인 → 파일 → ETL → Doris |

세 클러스터의 audit 를 한 화면에 모아 거버넌스 할 수 있게 만드는 것이 목표입니다.

### 각 클러스터의 audit log 수집 방식

같은 "audit log" 라고 부르지만, 세 클러스터의 수집 경로는 꽤 다릅니다.

**Apache Doris** — 가장 간단한 케이스. FE 설정 (`enable_audit_log = true`) 만 켜두면 `__internal_schema.audit_log` 테이블에 자동으로 적재됩니다. 별도 인프라 없이 SQL 로 바로 조회 가능 — 거의 "공짜" 입니다.

**StarRocks** — 기본 제공이 아니라 **별도 audit-loader 플러그인** 을 설치해야 합니다. FE 가 자체적으로 audit log 를 파일로 떨어뜨리면, audit-loader 가 그 파일을 Routine Load 로 `starrocks_audit_db__.starrocks_audit_tbl__` 에 적재. 플러그인 설치 + audit 테이블 DDL 한 번만 해두면 그 다음은 자동입니다.

**MariaDB** — 가장 손이 많이 가는 케이스. `server_audit` 플러그인이 audit 를 **파일** (`mysql-audit.log.*`) 로만 떨어뜨립니다. 이 파일을 어떻게 적재할 것인가가 문제였습니다.

처음엔 cron 으로 파일을 `grep` → CSV 변환 → `mariadb-import` 로 **같은 MariaDB 안의 `log_report.idb_audit_log` 테이블에 적재**했습니다. 단순하고 데이터 위치가 한 군데라 좋아 보였죠.

문제는 곧 드러났습니다. 7일치 audit 가 9천5백만 행에 달했고, 거버넌스 쿼리 — 특히 `GROUP BY tables` 같은 집계 — 가 Grafana panel timeout 을 매번 넘었습니다. MariaDB 는 OLTP 라 이런 풀스캔 집계에 약합니다.

해법은 **적재 위치를 Doris 로 옮기기**. 같은 데이터지만 OLAP 인 Doris 는 동일한 집계를 1~2초에 끝냅니다. ETL 스크립트도 `mariadb-import` → **Doris Stream Load (HTTP PUT)** 로 갈아탔습니다 (자세한 스크립트는 3장 참고).

| 단계 | 도구 | 비고 |
|---|---|---|
| audit 생성 | MariaDB `server_audit` 플러그인 | 파일로만 출력 |
| 일일 추출 | cron + `grep` + Python 정제 스크립트 | `SELECT` 만 필터링 |
| 적재 | `curl --location-trusted` → Doris Stream Load | `label` 로 멱등성 보장 |
| 분석 | Doris `idb_log.idb_audit_log` | OLAP 컬럼나리 — 집계 빠름 |

이렇게 세 클러스터의 audit 가 모두 SQL 로 접근 가능한 형태가 되었습니다.

---

## 2장. 전체 그림 — 데이터가 흐르고 패널이 되는 길

본격적인 디테일에 들어가기 전, 데이터가 어디서 시작해서 어떻게 대시보드 패널이 되는지 한 장에 정리해 두면 좋습니다.

![data flow](../../images/audit-governance-architecture.svg)

흐름을 4계층으로 정리하면:

**① 원본 Audit Log** — Doris/StarRocks 는 SQL 로 직접 조회 가능. MariaDB 만 audit 가 **파일**이라 별도 ETL 을 거쳐 Doris 의 `idb_log.idb_audit_log` 에 적재합니다 (그림에서 빨간 점선).

**② 클러스터별 Audit Store** — Grafana 입장에서는 3개의 MySQL-protocol datasource. 물리적으론 분산되어 있지만, 위 ETL 덕분에 MariaDB 의 사용 기록도 Doris 에서 조회 가능합니다.

**③ 논리 변환 (Grafana SQL)** — raw audit 한 줄 한 줄을 의미 있는 정보로 만드는 4단계:
1. **정규식 / explode_split 으로 테이블명 추출** — `stmt` 본문에서 FROM/JOIN 뒤 테이블명을 추출하거나, 별도 컬럼이 있으면 분해
2. **last_hit per fqdn 집계** — `MAX(time)` 으로 각 테이블의 마지막 사용 시각 산출
3. **information_schema OUTER JOIN** — 실재 테이블과 사용된 테이블을 매칭
4. **severity 분류** — 마지막 사용 시각 기준 Active / Warning / Delete

**④ 패널 합성** — 같은 변환 결과에서 여러 화면을 만든다. 12개 KPI 카드, Cleanup Candidates 테이블, Schema-Level Rollup, Upcoming Warning.

이 한 장이 본문 나머지의 지도 역할입니다. ETL 은 ①→②, Cross-DB Join 은 ③의 3, 거버넌스 룰은 ③의 4, 대시보드 구조는 ④.

---

## 3장. 데이터를 한 줄로 모으기

가장 어려웠던 건 단순해 보이는 문제였습니다. **"이 SQL 이 어떤 테이블을 건드리는가?"**

audit_log 에는 SQL 본문 (`stmt`) 만 기록됩니다. 어떤 테이블을 참조했는지 알려면 직접 파싱해야 합니다.

### 정규식으로 시작했다 — 그리고 한계

처음엔 단순한 정규식이면 되겠다 싶었습니다:

```sql
REGEXP_EXTRACT(stmt,
  '(?i)(?:from|join|into|update|table)[[:space:]]+([a-zA-Z0-9_.]+)', 1)
```

`SELECT * FROM users WHERE ...` 같은 단순 쿼리는 잘 잡힙니다. 그런데 실제 audit_log 에 들어오는 쿼리는:

- 백틱이 둘러쳐진 테이블명: `` SELECT * FROM `schema`.`table` ``
- 줄바꿈/탭이 잔뜩 있는 멀티라인 SQL
- JOIN 이 5~6개 걸린 복잡한 쿼리

이걸 다 잡으려면 사전 정제가 필요했습니다:

```sql
REGEXP_EXTRACT(
  REPLACE(REPLACE(REPLACE(stmt, '`', ''), '\n', ' '), '\r', ' '),
  '(?i)(?:from|join|into|update|table)[[:space:]]+([a-zA-Z0-9_.]+)', 1)
```

JOIN 이 여러 개라도 첫 테이블만 잡힙니다. 보수적이지만 거버넌스 목적엔 충분 — "한 번이라도 등장하면 active" 라는 정의에서 false positive (실사용 중인데 dormant 로 잘못 분류) 위험이 낮으면 되니까요.

### MariaDB 는 더 운이 좋았다 — pre-extracted 컬럼

MariaDB audit log 를 Doris 로 옮기는 ETL 단계에서 이미 `tables` 컬럼에 `db.table` 형식으로 정리해 두었습니다. 한 SQL 이 여러 테이블을 건드리면 CSV 로 저장됩니다:

```
tables = 'librenms.devices,librenms.ports'
```

이건 정규식 없이 explode 한 줄로 끝납니다:

```sql
SELECT LOWER(TRIM(t.col)) AS fqdn
FROM idb_log.idb_audit_log a
LATERAL VIEW explode_split(a.`tables`, ',') t AS col
```

### 95M rows 가 너무 무거워서 Doris 로 옮긴 이야기

처음엔 MariaDB audit 테이블을 그대로 Grafana 가 조회했습니다. 7일 윈도우에 약 9천5백만 행. KPI 한 개에 ~30초씩 걸렸고 detail 패널은 timeout. 사람이 보기 전에 Grafana 가 먼저 토라졌습니다.

해법은 **적재 위치를 옮기기**. Doris 는 같은 7일치를 1~2초에 GROUP BY 합니다. 기존 `mariadb-import` 셸 스크립트를 **Doris Stream Load** 로 바꿨습니다:

```bash
curl --location-trusted \
  -u "${DORIS_USER}:${DORIS_PASS}" \
  -H "label:idb_audit_${TARGET_DATE}" \
  -H "format:csv" -H "column_separator:," \
  -H "enclose:\"" -H "skip_lines:1" \
  -H "columns:\`timestamp\`,username,ip_address,session_id,query_id,\`database\`,\`tables\`,query" \
  -T ${TEMP_CSV} -XPUT \
  "http://${FE_HOST}:8030/api/idb_log/idb_audit_log/_stream_load"
```

`label` 이 멱등 키 — 같은 날짜를 재시도해도 중복 적재가 없습니다.

### Cross-DB Join — Mixed Datasource

MariaDB 의 audit 는 Doris 로 옮겼는데, `information_schema` 는 여전히 MariaDB 에 있습니다. 둘을 JOIN 해야 "정말로 안 쓰는 테이블" 이 보이는데 single SQL 로 묶을 수 없죠.

처음엔 **Doris JDBC Catalog** 로 MariaDB 의 info_schema 를 Doris 안에서 보이게 할까 했는데, JDBC driver 배포 + 인프라 변경 비용이 들어 보류. 대신 Grafana 의 **Mixed Datasource** 를 썼습니다:

- **Target A** (`doris_mysql`): audit 측 fqdn + last_seen
- **Target B** (`idb_mariadb`): info_schema 측 fqdn + 메타데이터
- **`joinByField outer`** 트랜스폼으로 `fqdn` 기준 합치기

추가 트랜스폼으로 NULL 필터링까지 (`audit_hit IS NULL` 인 행이 진짜 dormant). SQL JOIN 만큼 깔끔하진 않아도 인프라 비용 없이 작동합니다.

### 노이즈 필터링

순수 사용량만 보려면 이런 것들은 제외:

- `information_schema`, `mysql`, `sys`, `performance_schema` 같은 시스템 스키마
- `SELECT 1`, `SELECT @@version` 같은 헬스체크 (정규식이 자연스레 거름 — FROM 이 없으니)
- UPDATE/INSERT/DELETE 같은 DML — "ETL 이 쓰는 것 ≠ 사람이 보는 것" 이라 **SELECT 만 카운트**

Doris/StarRocks 에선 `stmt_type = 'SELECT'` / `isQuery = 1`. MariaDB 는 ETL 단계에서 이미 SELECT 만 추출.

---

## 4장. 거버넌스 룰을 대시보드로

데이터가 갖춰지면 그 다음은 "어떤 규칙으로 정리할 것인가" 입니다.

### Active / Warning / Delete — 30일과 90일

가장 단순한 룰 3단계:

| 분류 | 기준 | 의미 |
|---|---|---|
| **Active** | 최근 30일 내 SELECT | 정상 사용 — 건드리지 마라 |
| **Warning** | 30~90일간 SELECT 없음 | owner 확인 필요 |
| **Delete** | 90일+ SELECT 없음 또는 audit 에 한 번도 등장 안 함 | 정리 후보 |

30일·90일은 임의지만 실용적으로는:

- **30일**: 월 단위 보고나 분석 주기를 한 번 거치는 시간
- **90일**: 분기 보고를 한 번 거치는 시간. 분기에 한 번도 안 본 테이블이라면 사실상 안 쓰는 것

### "Reclaimable rows" 에서 "Reclaimable GB" 로

처음엔 KPI 에 "Delete 후보들의 row 수 합" 을 넣었습니다. 같이 보던 분이 한마디 했죠:

> "이 테이블은 row 수가 적은데 한 row 가 큰 텍스트 컬럼이라 GB 단위로 큰데, 이건 row 수만으로는 안 보이네요?"

거버넌스의 핵심은 **비용 절감 효과** 입니다. row 수보다 실제 스토리지 용량이 더 직관적인 신호:

```sql
-- 변경 전
SUM(CASE WHEN delete_condition THEN t.TABLE_ROWS ELSE 0 END) AS reclaimable_rows

-- 변경 후
SUM(CASE WHEN delete_condition AND t.TABLE_TYPE = 'BASE TABLE'
         THEN COALESCE(t.DATA_LENGTH, 0) ELSE 0 END) AS reclaimable_bytes
```

`AND t.TABLE_TYPE = 'BASE TABLE'` 한 줄이 추가된 건 **View 는 logical 이라 storage 가 0** 이라는 사실을 늦게 깨달았기 때문입니다. View 도 정리 대상에는 들어가지만 회수량은 0.

### 2계층 구조 — 거버넌스와 클러스터

대시보드 자체는 두 레벨로 나눴습니다.

![Audit Governance Dashboard](../../images/audit_dashboard.png)

**거버넌스 (위)** — 한눈에 보고 싶은 요약:

- **12개 KPI 카드 (3 cluster × 4 metric)**
  ![12 KPI Cards](../../images/audit_dashboard_kpi.png)
- **Upcoming Warning (25~30일 임박)**
  ![Upcoming Warning](../../images/audit_dashboard_warning.png)
- **Cleanup Candidates table (정리 우선순위)**
  ![Cleanup Candidates](../../images/audit_dashboard_cleanup.png)
- **Schema-Level Rollup (스키마별 dormant 비율)**
  ![Schema-Level Rollup](../../images/audit_dashboard_schema.png)

**클러스터 (아래)** — 깊이 들여다볼 때만:

![Cluster Panels](../../images/audit_dashboard_cluster_specific.png)

- 각 클러스터별 Active barchart, Activity detail, 사용 없음 테이블 목록

첫 화면은 거버넌스만 보이고, 클러스터 row 는 `collapsed: true` 로 두어 사용자가 필요할 때만 펼치게 했습니다. 첫 로드 부하도 줄어듭니다.

### Time semantics — 거버넌스 vs 클러스터

미묘한 결정 하나: **거버넌스 KPI 는 180일 고정 윈도우**, 아래 클러스터 패널은 **dashboard time picker 따라감**.

- 거버넌스 룰 (30/90일) 은 절대 기준이라 time picker 와 무관해야 한다
- 클러스터 드릴다운은 "지난 1주일 활동" 같은 다른 질문이라 time picker 가 자연스럽다

대시보드 description 과 row 제목에 "fixed 180d window" 를 명시했지만, 처음 보는 사람이 헷갈리기 쉬운 부분입니다.

---

## 5장. 실제 운영과 남은 과제

대시보드는 만들어졌지만, 진짜 가치는 운영 흐름이 정착할 때 나옵니다. 우리 워크플로우는 이렇습니다.

### 매주 — Upcoming Warning 명단

마지막 SELECT 가 25~30일 전인 테이블이 곧 Warning 으로 진입합니다. 매주 월요일에 그 명단을 보고:

- "이 테이블 이번 분기 안 쓰실 거 맞아요?" 를 owner 에 ping
- 답이 없으면 → Warning 진입 후 추적

### 매월 — Delete 후보 정리

Reclaimable size 큰 순으로 Delete 후보를 봅니다. owner 와 협의 → DROP. 정리한 양은 다음 달 보고에서 누적 회수량으로 추적.

### 매분기 — Schema-Level Rollup

스키마(DB) 단위로 dormant 비율을 봅니다. 특정 스키마의 dormant 가 50% 를 넘는다면 그 스키마 owner 와 단위 정리 캠페인 — 테이블 단위보다 효율적입니다.

### 다음 단계 — Lineage + Usage 통합

Usage 만으로는 부족한 경우가 있습니다. 한 테이블이 audit_log 에 한 번도 안 나타나도, **다른 테이블의 view 가 그 테이블을 참조**하고 있다면? Usage 만 보면 Delete 후보지만, 실제로 지우면 view 가 깨집니다.

Lineage (OpenMetadata) 와 Usage (이 대시보드) 가 결합되면:

- "Direct usage 없음 + view 5개 의존" → Warning, owner 협의
- "Direct usage 없음 + 의존 객체 없음" → Delete 안전

이게 다음 글의 주제입니다.

### 남은 과제

- **시스템 계정 분리**: 현재 `admin` 만 제외. 데이터 수집기, 모니터링 봇 등 추가 분리하면 정확도 ↑
- **TABLE_COMMENT → 정식 ownership**: 지금은 TABLE_COMMENT 에 owner 적어둔 곳만 표시. OpenMetadata Owner 메타데이터와 연동 필요
- **Slack 자동 routing**: Warning 진입 시 owner 에 자동 ping
- **Pre-aggregated daily summary**: 거버넌스 KPI 가 1초 미만으로 응답

---

## 마치며 — Lineage 와 Usage, 거버넌스의 두 다리

거버넌스를 자동화하려면 두 정보가 필요합니다.

**Lineage** 만으로는 "어디에 영향이 가는지" 는 알지만 "실제로 쓰는 사람이 있는지" 는 모릅니다. **Usage** 만으로는 그 반대 — 누가 쓰는지는 알지만 지우면 어디가 깨질지 모릅니다.

두 시그널이 모두 갖춰질 때 비로소 **"지워도 된다"** 가 데이터로 증명됩니다.

이 글이 audit_log 를 거버넌스 시그널로 활용하려는 누군가에게 출발점이 되었으면 좋겠습니다.
