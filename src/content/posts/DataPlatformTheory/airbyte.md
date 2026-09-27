---
title: Airbyte 이론 — Source에서 Destination으로 복제하기
description: Airbyte의 Connection, Connector, 동기화 상태와 복제 작업 흐름을 설명합니다.
date: 2026-09-23
tags: [Airbyte, ELT, Architecture]
draft: false
---

Airbyte는 데이터 원천과 목적지 사이의 **복제 작업**을 정의하고 실행합니다. `Source`와 `Destination`은 연결할 외부 시스템이고, `Connector`는 그 시스템과 대화하는 구현체입니다. 이 장은 Airbyte의 데이터 이동 플랫폼 개념을 다루며, 별도의 AI 에이전트 기능은 범위에 넣지 않았습니다.

![Airbyte의 설정 계층과 Source·Destination 데이터 경로](/images/posts/data-platform-theory/airbyte-architecture.svg)

## 무엇을 설정하고 무엇이 실행됩니까?

| 요소 | 역할 |
|---|---|
| Source Connector | 원천 API·DB·파일을 읽고 레코드와 상태 메시지를 만듭니다. |
| Destination Connector | 전달받은 레코드를 목적지 형식으로 적재합니다. |
| Connection | Source와 Destination, 선택한 스트림, 동기화 일정·방식을 묶습니다. |
| Catalog·Stream | 복제 가능한 테이블·객체와 그 스키마를 표현합니다. |
| Job·Workload | 실제 동기화 시도의 실행 단위입니다. 플랫폼이 예약하고 작업 환경에서 커넥터를 실행합니다. |
| State | 증분 읽기의 마지막 진행 위치입니다. Source의 의미 있는 체크포인트로 이해하시면 됩니다. |

## 증분 동기화 한 번을 따라가 보겠습니다

1. Connection에서 복제할 Stream과 증분 방식이 정해집니다.
2. 플랫폼이 Job을 예약하고 Source·Destination Connector 작업을 실행합니다. 배포 방식에 따라 작업 실행 인프라가 달라집니다.
3. Source는 원천에서 레코드와 진행 상태를 읽습니다. Destination은 레코드를 목적지에 적재합니다.
4. 성공한 상태가 다음 실행의 시작점을 결정합니다. 실패 후 재시도와 목적지 중복 처리는 동기화 방식, 커넥터 구현, 키 설계에 따라 달라집니다.

**Full refresh**는 선택한 범위를 다시 읽고, **incremental**은 커서·CDC 등의 위치 이후 변경분을 읽습니다. 목적지의 append와 deduped는 결과 테이블의 중복 처리 방식까지 다릅니다. “증분”이라는 이름만으로 정확히 한 번 적재를 보장한다고 가정하지 마세요.

## 커넥터 프로토콜과 State의 의미

Airbyte Protocol은 플랫폼과 커넥터 사이의 표준 메시지 경계를 정의합니다. Source는 레코드뿐 아니라 Stream·Schema·로그·진행 State 같은 제어 메시지도 낼 수 있습니다. Destination은 레코드를 기록하고 동기화 결과를 플랫폼에 알립니다. 커넥터가 서로 다른 언어로 작성되더라도 프로토콜 경계가 맞으면 동일한 실행 플랫폼에 연결할 수 있습니다.

State는 “데이터가 Destination에 안전하게 반영된 위치”를 나타내야 합니다. Source가 읽은 위치를 너무 일찍 확정하면 목적지에 쓰이지 않은 레코드를 건너뛸 수 있고, 반영 후에도 State가 뒤처지면 같은 구간이 다시 전달되어 중복될 수 있습니다. 그래서 State 저장 시점, 목적지 쓰기 결과, 재시도 시 동작의 순서가 중요합니다. 구체적인 보장은 커넥터의 구현과 동기화 모드에 따라 달라집니다.

## 증분 읽기와 목적지 쓰기의 두 축

증분 읽기는 “원천에서 어디부터 가져올 것인가”를 정하고, Append/Deduped 같은 Destination 처리 모드는 “받은 레코드를 대상에 어떻게 쌓을 것인가”를 정합니다. 둘은 서로 다른 결정입니다. Append는 같은 입력이 재전송되면 중복 행이 남을 수 있습니다. Deduped는 Primary Key 등으로 중복을 정리할 수 있지만, 키가 없거나 Source의 변경 의미가 빠지면 기대한 최신 상태를 만들지 못할 수 있습니다.

CDC 스트림에서는 초기 스냅샷과 변경 로그가 시간상 일관된 경계에서 이어져야 합니다. 데이터베이스 커넥터는 로그 오프셋·LSN·Binlog 위치 같은 원천 특성에 의존할 수 있습니다. 원천 보존 기간이 State보다 짧아지면 증분 재개가 불가능해져 전체 재동기화가 필요할 수 있습니다.

## 플랫폼 제어 경로와 레코드 전송 경로

Airbyte의 내부 구성은 “Job을 관리하는 경로”와 “Connector가 레코드를 주고받는 경로”로 나뉩니다. Config API는 Source·Destination·Connection 설정을 받고 Config & Jobs DB에 설정과 작업 이력을 저장합니다. Temporal은 Job workflow와 task queue의 순서를 관리합니다. Worker가 Connection 실행을 조정해 Workload API에 실행 요청을 보내면 Workload Launcher가 실행 환경에 Connector workload를 시작합니다. Kubernetes 배포에서는 이 workload가 connector operation pod로 실행될 수 있습니다.

Connector 컨테이너 사이의 레코드 전달에는 연결 가능한 기능에 따라 두 모드가 있습니다. Socket mode에서는 Source와 Destination이 Unix domain socket으로 레코드를 직접 주고받고, Bookkeeper가 State·로그 같은 제어 메시지를 처리합니다. Legacy mode에서는 Container Orchestrator 미들웨어가 표준 입출력 스트림 사이에 위치해 데이터와 제어 메시지를 함께 중계합니다. 따라서 레코드 데이터가 플랫폼 API나 config DB를 통과한다고 이해하면 실제 데이터 경로를 잘못 그리게 됩니다.

두 경로의 장애 양상도 다릅니다. Temporal/Worker/Launcher 문제는 작업을 시작하거나 상태를 갱신하지 못하는 제어 평면 문제입니다. Connector의 API 권한, 원천 rate limit, Destination 쓰기는 데이터 평면 문제입니다. 어느 쪽이 먼저 실패했는지 Job log와 connector log를 구분해 보면 원인을 더 빨리 찾을 수 있습니다.

## 동기화 실패를 나누는 방법

원천 접근 실패, 레코드 변환·스키마 호환 실패, 목적지 쓰기 실패, 상태 기록 실패는 서로 다른 복구 전략이 필요합니다. 장애 분석 시 Job 성공 여부 하나만 보지 말고 마지막으로 전진한 Stream과 State, 목적지에 반영된 Primary Key 범위를 확인합니다. 커넥터 업그레이드는 API 변경, rate limit, 타입 변환에 영향을 줄 수 있으므로 버전과 로그를 함께 기록하는 것이 좋습니다.

운영할 때는 원천 API 제한·커서 단절, Source 읽기 오류, Destination 쓰기 오류, 상태 저장 문제를 구분해 보세요. 플랫폼 메타데이터의 Source 설정과 실제 원천 시스템의 데이터는 서로 다릅니다.

## 실무 적용: 플랫폼 없이 커넥터만 씁니다

사내에서는 광고 매체·앱 스토어·환율 등 외부 API 데이터를 Airbyte 커넥터로 수집합니다. 다만 위에서 설명한 **Airbyte 플랫폼(Config API, Temporal, Workload Launcher)은 설치하지 않았습니다.** 대신 커넥터를 Python 라이브러리로 실행하는 **PyAirbyte**를 Airflow Task 안에서 호출합니다. 이미 Airflow가 스케줄·재시도·백필을 담당하고 있어서, 제어 평면을 두 개 운영할 이유가 없었기 때문입니다.

### 이론의 개념이 어디로 옮겨 갔는가

| Airbyte 플랫폼 개념 | 사내 대응 |
|---|---|
| Connection | Airflow Variable `airbyte_metadata_config`의 매체(pid)·스트림 설정 1건 → DAG 1개 |
| Job·Workload | DagRun과 `extract` → `load_to_db` Task |
| Schedule | `CronPartitionTimetable` (처리 날짜 = partition_key) |
| State (증분 커서) | **사용하지 않음.** Airflow가 날짜 구간을 정해 커넥터 config의 `start_date`/`end_date`에 주입 |
| Destination Connector | 사용하지 않음. Airflow Task가 Doris Stream Load(또는 MariaDB INSERT)로 직접 적재 |

가장 큰 차이는 **State를 Airbyte가 아니라 Airflow가 가진다**는 점입니다. 이론에서 "State를 너무 일찍 확정하면 레코드를 건너뛰고, 늦으면 중복된다"고 설명했는데, 사내 구조에서는 이 문제를 구간 교체로 피합니다.

1. `initialize_date`가 partition_key(또는 수동 실행 파라미터)로 조회 구간을 정합니다. `lookback_days`로 며칠 앞까지 다시 읽을지 매체별로 조절합니다.
2. `extract`가 PyAirbyte로 그 구간의 레코드를 DataFrame으로 받습니다.
3. `load_to_db`가 목적지에서 **같은 날짜 구간(과 계정)을 DELETE한 뒤** 5,000행 단위 청크로 Doris에 Stream Load 합니다. 청크마다 고유 label을 붙이고, 응답 상태가 성공이 아니면 ErrorURL과 함께 실패시킵니다.
4. 모든 계정의 적재가 끝나면 `emit_outlets`가 Doris 테이블 Asset 이벤트를 발행해 하류 dbt DAG를 깨웁니다.

같은 구간을 몇 번 다시 돌려도 결과가 같으므로, 재처리와 백필은 "날짜를 지정해 다시 실행"이 전부입니다. 대가는 원천 API를 매번 구간 전체만큼 다시 호출한다는 점입니다. 광고 리포트 API처럼 하루치 데이터가 크지 않고 과거 수치가 며칠 동안 보정되는 원천에는, 커서 위치를 관리하는 것보다 lookback 구간을 통째로 다시 읽는 편이 단순하고 안전합니다. CDC가 필요한 DB 복제에는 맞지 않는 구조입니다.

한 매체에 광고 계정이 여러 개면 config 목록을 계정별 Task Group으로 펼쳐 병렬 실행하고, DELETE 범위도 해당 계정으로 좁힙니다. 한 계정이 실패해도 다른 계정의 적재는 보존됩니다.

### Declarative manifest와 커스텀 컴포넌트

커넥터는 대부분 직접 작성한 **Low-code(Declarative) manifest**입니다. AdMob, AppLovin, Unity, ironSource, Facebook, Apple Search Ads, Google Play, App Store 등 21개 매체·스토어의 YAML이 별도 저장소에 있고, YAML만으로 표현하기 어려운 부분은 CDK 클래스를 상속한 Python 컴포넌트로 채웁니다.

| 디렉터리 | 예시 |
|---|---|
| `authenticators/` | App Store Connect JWT 서명 인증 |
| `extractors/` | CSV·ZIP으로 내려오는 리포트를 레코드로 변환 |
| `partition_routers/` | 캠페인 목록을 먼저 조회한 뒤 캠페인별로 요청을 나누기 |
| `error_handlers/` | 429 응답의 `Retry-After`가 1,000초 가까이 오는 API를 위해 CDK 기본 재시도 한도(600초)를 7,200초로 확장 |
| `transformations/` | 매체별 필드명·타입 보정 |

Google Ads, GCS처럼 공식 커넥터가 충분한 경우에는 manifest 대신 공식 Docker 이미지를 지정합니다. DAG 팩토리는 `connector_type`이 `custom`이면 manifest를, `official`이면 이미지를 로드합니다. 참고로 custom manifest가 동작하지 않는 PyAirbyte 버그가 있어, 수정 PR이 정식 릴리스될 때까지 해당 PR 브랜치를 고정해 설치하고 있습니다.

커넥터 저장소는 master에 머지되면 CI가 파일을 SeaweedFS로 동기화하고, Airflow Worker는 그 경로를 마운트해 읽습니다. 새 매체 추가는 API 문서를 읽고 manifest와 컴포넌트를 만들어 주는 사내 AI 에이전트 스킬로 초안을 만든 뒤 검토하는 방식으로 진행합니다.


**공식 문서:** [Sources, destinations, and connectors](https://github.com/airbytehq/airbyte/blob/master/docs/platform/move-data/sources-destinations-connectors.md), [High-level view](https://github.com/airbytehq/airbyte/blob/master/docs/platform/understanding-airbyte/high-level-view.md), [Airbyte Protocol](https://github.com/airbytehq/airbyte/blob/master/docs/platform/understanding-airbyte/airbyte-protocol.md)
