---
title: "별도 분석 인프라 없이 AI와 DuckDB로 Nginx 로그 분석하기"
description: "SeaweedFS에 보관된 gzip nginx 로그를 AI 에이전트 스킬과 DuckDB만으로 내려받고, 서비스 종료 판단에 필요한 실제 호출 근거를 만든 과정"
date: 2026-09-09
tags:
  - DuckDB
  - SeaweedFS
  - Nginx
  - AI
  - DataEngineering
  - LogAnalysis
featured: false
draft: false
---

### 1. 들어가며

오래 운영한 서비스는 언젠가 정리해야 합니다. 문제는 컨테이너가 살아 있는지보다 **정말 누가 아직 호출하고 있는지** 입니다. 코드 저장소를 검색하면 오래된 설정과 이미 멈춘 배포 파일까지 함께 나오고, 모니터링 로그만 보면 실제 사용자 트래픽처럼 보일 수 있습니다.

이번에는 `open-api.datawave.co.kr`를 종료해도 되는지 판단하기 위해 SeaweedFS에 보관된 nginx access log를 한 달 단위로 확인했습니다. 별도의 Elasticsearch, ClickHouse, 로그 파이프라인을 새로 만들지 않았습니다. AI 에이전트가 만든 `duckdb-seaweedfs` 스킬과 로컬 DuckDB만 사용했습니다.

목표는 단순히 "요청 수가 몇 건이다"가 아니었습니다.

- 모니터링을 제외해도 실제 호출이 남아 있는가?
- 어떤 endpoint가 살아 있고, 어떤 호출자는 이미 실패를 반복하는가?
- 서비스 종료 전에 반드시 옮겨야 할 의존성은 무엇인가?

### 2. 왜 별도 분석 인프라를 만들지 않았나

한 달치 nginx 로그를 한 번 조사하기 위해 수집기, 인덱스, 대시보드를 새로 만드는 것은 과합니다. 오히려 분석 환경의 수명주기가 대상 서비스보다 길어질 수 있습니다.

이번 상황에는 다음 조건이 잘 맞았습니다.

| 조건 | 선택 |
| --- | --- |
| 원본 로그 | SeaweedFS File Browser의 `.gz` access log |
| 조회 범위 | 특정 virtual host의 한 달치 로그 |
| 분석 엔진 | 로컬 DuckDB 파일 하나 |
| 실행 도구 | Python 표준 라이브러리 + DuckDB + AI 에이전트 스킬 |
| 산출물 | 원본 gzip, manifest, DuckDB, Markdown 판단 보고서 |

DuckDB는 파일을 로컬에서 바로 SQL로 분석할 수 있어 이런 일회성·조사성 작업에 특히 잘 맞습니다. 서버를 띄우거나 계정을 만들 필요도 없고, 결과를 `.duckdb` 파일 하나로 보존할 수 있습니다.

### 3. `duckdb-seaweedfs` 스킬로 만든 분석 흐름

스킬의 역할은 "로그를 다운받아 보세요" 수준의 안내가 아닙니다. 날짜 경계, gzip 무결성, nginx 포맷 파싱, 모니터링 분류, 결과 보고서까지 반복 가능한 작업으로 고정하는 것입니다.

![SeaweedFS에서 로컬 DuckDB 보고서까지 이어지는 nginx 로그 분석 시퀀스|640](/images/posts/duckdb-seaweedfs-nginx-log-analysis/analysis-sequence.svg)

1. 사용자가 분석할 월과 host를 지정합니다.
2. 스킬은 SeaweedFS Admin API의 read-only download endpoint로 시간별 gzip 로그를 가져옵니다.
3. 내려받은 모든 파일을 gzip으로 다시 검증하고, 파일별 상태·크기·checksum을 manifest에 남깁니다.
4. nginx combined log 뒤에 `rt`, `urt`가 붙은 포맷을 파싱해 DuckDB 테이블로 적재합니다.
5. 파일명 대신 로그 본문의 타임스탬프로 정확한 달만 필터링합니다.
6. 모니터링과 실제 호출을 분리한 view를 만들고, endpoint·상태 코드·User-Agent·일별 활동을 집계합니다.
7. 마지막으로 서비스 종료 판단과 사전 확인 목록을 Markdown 보고서로 만듭니다.

실행은 다음처럼 단순합니다.

```bash
python3 /Users/tskim/.agents/skills/seaweedfs-nginx-duckdb/scripts/analyze.py \
  --month 2026-08 \
  --host open-api.datawave.co.kr \
  --output-dir /absolute/path/open-api-retirement-2026-08
```

### 4. 날짜 경계에서 놓치기 쉬운 점

처음 파일 목록을 살펴보면 `20260801` 디렉터리의 `...2026080100.gz` 파일이 7월 31일 23시 로그를 담고 있었습니다. 로그 rotation의 파일명과 실제 timestamp가 한 시간 차이 난 것입니다.

따라서 단순히 `20260801`부터 `20260831` 디렉터리만 받으면 8월 마지막 한 시간을 놓칠 수 있습니다. 스킬은 다음 방식으로 처리합니다.

- 대상 월의 시간별 파일과 다음 날 경계 파일까지 내려받는다.
- 각 줄의 nginx timestamp를 `+0900` timezone으로 파싱한다.
- `2026-08-01 00:00:00+09` 이상, `2026-09-01 00:00:00+09` 미만만 DuckDB에 적재한다.

이 원칙은 로그 분석에서 꽤 중요합니다. **파일명은 보조 메타데이터일 뿐이고, 분석 기준은 이벤트가 실제 발생한 시간이어야 합니다.**

### 5. 원본을 보존하면서 분석용 view 만들기

원본 request target에는 SQL, sheet ID, token처럼 민감한 query parameter가 들어갈 수 있습니다. 그래서 원본 `request_target`은 로컬 DB에 보존하되, 보고서와 집계에서는 query string을 제거한 `request_path`만 사용했습니다.

```sql
SELECT
  method,
  request_path,
  count(*) AS requests,
  count(DISTINCT CAST(ts AS DATE)) AS active_days,
  round(100.0 * count_if(status BETWEEN 200 AND 399) / count(*), 1) AS success_pct
FROM service_usage
GROUP BY ALL
ORDER BY requests DESC;
```

여기서 `service_usage`는 파싱에 성공했고 모니터링으로 분류되지 않은 행만 담은 view입니다. `Uptime-Kuma`, `check_http`, 일반적인 health endpoint는 제거하지만 Google Sheets, Apps Script, curl, 사내 배치 호출은 제외하지 않습니다. 자동화 호출도 서비스 종료 시 깨질 수 있는 실제 의존성이기 때문입니다.

### 6. 실제 분석 결과: 서비스는 아직 살아 있었다

2026년 8월 분석에서는 시간별 gzip 768개를 확인했습니다. 모두 gzip 검증을 통과했고, 58,352건 중 파싱 실패는 비정상 request line 1건뿐이었습니다.

| 구분 | 결과 |
| --- | ---: |
| 전체 access log | 58,352건 |
| 모니터링 요청 | 53,572건 |
| 모니터링 제외 요청 | 4,779건 |
| 정상 응답(2xx–3xx) | 1,935건 |
| 모니터링 제외 활동 일수 | 31일 |
| `/api/v1/modules/gdoc` 요청 | 2,313건 |
| `gdoc` 정상 응답 | 1,924건 (83.2%) |

결론은 명확했습니다. **즉시 종료하면 안 됩니다.**

특히 `gdoc` endpoint는 axios, curl, Python 요청으로 실제 성공 응답을 계속 내고 있었습니다. 반면 Google Docs와 Google Apps Script에서 오는 여러 다른 endpoint는 500을 지속적으로 반환했습니다. 이것은 "안 쓰는 API"라는 뜻이 아니라, 이미 실패하고 있어도 호출자가 계속 재시도하는 **깨진 의존성**일 수 있습니다.

로그만으로 끝내지 않고 저장소도 교차 검색했습니다. `services/`, `scripts/`, `provisioning/` 아래에서 host 참조 파일이 53개 확인됐고, 오래된 `zz-old` 경로를 제외해도 `/api/v1/modules/gdoc` 직접 참조가 26개 남아 있었습니다. `game-ops`, `server-error-alarm`, `mongodb-exporter`, Kong 계열 서비스, 운영 스크립트가 대표적이었습니다.

### 7. 서비스 종료 판단은 성공 요청만 보면 안 된다

이번 조사에서 가장 유용했던 분리는 아래 네 가지였습니다.

| 분류 | 해석 | 종료 전 조치 |
| --- | --- | --- |
| 모니터링 200 | 생존 확인 트래픽 | 모니터링 설정 이전 또는 제거 |
| 실제 호출 2xx–3xx | 현재 기능 의존성 | 호출자 식별 후 대체 API로 전환 |
| 실제 호출 4xx/5xx | 실패 중인 숨은 의존성 가능성 | owner 확인 후 재시도·자동화 정리 |
| 단발성 브라우저 요청 | 운영자 수동 사용 가능성 | 사용 목적과 대체 절차 확인 |

5xx가 많다고 서비스가 없어져도 된다는 결론을 내리면 위험합니다. 실패한 요청은 대개 문서에 남지 않은 Apps Script, 스케줄러, 개인 도구를 가리킵니다. 서비스를 끄기 전에는 실패 호출까지 owner를 확인해야 합니다.

### 8. 스킬에 넣은 안전장치

AI가 파일을 많이 다루는 작업은 편리함만큼 재현성과 안전성이 중요합니다. `duckdb-seaweedfs`에는 다음 조건을 넣었습니다.

- SeaweedFS에는 읽기 전용 download 요청만 보낸다.
- 기존에 검증된 gzip은 재다운로드하지 않아 중단 후에도 이어서 실행할 수 있다.
- 모든 파일의 상태, 크기, SHA-256을 manifest로 남긴다.
- gzip 검증 실패 파일은 DuckDB에 넣지 않는다.
- raw query string과 client IP는 보고서에 쓰지 않는다.
- 분석 월 밖의 timestamp가 들어가지 않았는지 마지막에 SQL로 검증한다.

결과 디렉터리에는 `logs/`, `download_manifest.csv`, `nginx_logs.duckdb`, `retirement_assessment.md`가 함께 남습니다. 그래서 몇 주 뒤 다시 봐도 "어떤 원본을 어떤 규칙으로 분석했는지"를 추적할 수 있습니다.

### 9. 마치며

서비스 종료 판단은 단순한 인프라 정리 작업이 아닙니다. 로그에는 살아 있는 의존성과 이미 고장 난 의존성이 함께 섞여 있습니다.

이번에는 AI 에이전트를 이용해 다운로드, 포맷 파싱, 날짜 경계 처리, SQL 집계, 보고서 작성을 하나의 스킬로 묶었습니다. 새 분석 플랫폼을 운영하지 않고도 한 달치 로그에서 서비스의 실제 사용 근거를 빠르게 만들 수 있었습니다.

다만 한 달의 로그만으로 안전한 종료를 증명할 수는 없습니다. 최종 종료 전에는 최소한 다음을 확인해야 합니다.

1. 상위 endpoint별 호출 주체와 owner를 확인한다.
2. 배치·Apps Script·대시보드·설정 파일의 host 참조를 전환한다.
3. 공지 후 짧은 차단 또는 read-only canary로 숨은 의존성을 확인한다.
4. 업무 주기를 포함하는 추가 기간의 로그와 애플리케이션 로그를 함께 검토한다.

AI와 DuckDB가 결정을 대신하지는 않습니다. 하지만 필요한 증거를 빠르고 재현 가능하게 모아, "꺼도 될 것 같다"를 **검증 가능한 종료 계획**으로 바꾸는 데는 아주 좋은 조합이었습니다.
