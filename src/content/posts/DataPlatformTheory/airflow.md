---
title: Apache Airflow 이론 — DAG에서 Worker까지
description: Airflow 3의 구성요소, 스케줄링, Task 실행 및 데이터 경로를 설명합니다.
date: 2026-09-23
tags: [Airflow, OpenLineage, DataEngineering, Architecture]
draft: false
---

Apache Airflow는 작업의 **순서와 실행 시점**을 관리하는 워크플로 플랫폼입니다. DAG는 작업(Task)과 의존 관계를 코드로 정의합니다. Airflow가 대용량 데이터 자체를 운반하는 것은 아닙니다. Task가 DB·파일 저장소·외부 서비스에 연결해 데이터를 처리합니다. 아래 그림은 공식 문서의 **Airflow 3 구성**을 단순화한 것입니다.

![Airflow 3의 제어 경로와 Task 실행 경로](/images/posts/data-platform-theory/airflow-architecture.svg)

Airflow 공식 문서는 배포 모양과 작업 실행 모양을 각각 보여 줍니다. 아래 분산 배포도에서는 선 색이 코드 동기화, 작업 제어, UI, 메타데이터 DB 접근을 구분합니다. Airflow 3의 DAG Processor 분리 구조도 함께 보시면 Scheduler가 사용자 DAG 코드를 직접 파싱하지 않는 이유를 확인할 수 있습니다.

![Airflow 공식 문서의 분산 배포 아키텍처](/images/posts/data-platform-theory/official/airflow-official.png)

[그림 출처: Airflow 3 Architecture Overview](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)

![Airflow 공식 문서의 DAG Processor 분리 아키텍처](/images/posts/data-platform-theory/official/airflow-dag-processor.png)

[그림 출처: Airflow 3 Architecture Overview — Separate DAG processing](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)

## 구성요소를 나누어 보겠습니다

| 구성요소 | 하는 일 | 혼동하기 쉬운 점 |
|---|---|---|
| DAG Bundle | Worker와 DAG Processor가 사용할 DAG 코드 묶음입니다. | 기본 로컬 폴더 외에 버전 있는 백엔드도 사용할 수 있습니다. |
| DAG Processor | Python DAG 파일을 파싱하고 직렬화한 정의를 메타데이터 DB에 저장합니다. | Airflow 3에서는 Scheduler와 별도 프로세스입니다. |
| Metadata DB | DAG·DagRun·Task Instance 상태와 직렬화된 DAG 정보를 보관합니다. | 업무 데이터의 저장소가 아닙니다. |
| Scheduler | 일정과 의존 관계를 평가해 실행할 Task를 고릅니다. | 직접 모든 Task 코드를 실행하지 않습니다. |
| Executor | Scheduler가 선택한 Task를 실행 환경에 전달하는 방식입니다. | 독립 서비스가 아니라 Scheduler의 설정 및 실행 구성입니다. |
| Worker | 실제 Task 코드를 실행합니다. | 실행 방식에 따라 프로세스·큐·Pod 구조가 달라집니다. |
| API Server / Triggerer | UI·REST와 비동기 deferrable 작업의 대기를 각각 담당합니다. | Triggerer는 해당 기능을 사용할 때 필요합니다. |

## 한 번의 실행을 따라가 보겠습니다

1. DAG Processor가 DAG Bundle의 코드를 읽고 정의를 직렬화합니다.
2. Scheduler는 일정에 맞는 **DagRun**을 만들고 의존성이 충족된 **Task Instance**를 찾습니다. `@daily`와 같은 데이터 구간 기반 일정은 보통 구간이 끝난 뒤 실행됩니다.
3. Executor가 실행 가능한 Task를 Worker로 전달합니다. Worker는 지정된 DAG 코드 버전을 가져와 Task를 수행합니다.
4. Worker가 외부 시스템을 읽거나 쓰고, 실행 상태가 메타데이터 DB에 반영됩니다. UI는 API Server를 통해 상태를 보여 줍니다.

`Task`는 작업의 정의이고 `Task Instance`는 특정 DagRun에서 실제로 실행되는 한 번의 작업입니다. 실패 재시도는 동일한 Task Instance의 시도 횟수를 늘립니다. XCom은 작은 작업 간 값 전달에 적합하지만, 대용량 데이터 전달에는 외부 저장소의 주소를 건네는 편이 이해하기 쉽습니다.

## 실행 모델의 핵심 원리

### DAG는 데이터가 아니라 의존성을 표현합니다

DAG의 노드는 Task이고 간선은 선후 관계입니다. 간선이 있다고 해서 Task A의 출력 데이터가 Task B로 자동 이동하는 것은 아닙니다. 두 Task가 공유해야 하는 값은 XCom처럼 작은 메타데이터로 전달하거나, 오브젝트 스토리지·웨어하우스에 저장하고 참조를 넘겨야 합니다. 이 구분은 Worker를 여러 머신으로 늘릴 때 특히 중요합니다. 두 Task가 같은 로컬 디스크를 본다는 보장이 없기 때문입니다.

### DagRun은 시간 구간을 처리하는 실행 인스턴스입니다

시간표 기반 DAG는 특정 순간 하나만 가리키는 대신 보통 `data interval`을 처리합니다. `logical date`는 그 실행이 대표하는 구간을 식별하는 값이며 실제 시작 시각과 같지 않을 수 있습니다. 예를 들어 하루 단위 DAG는 해당 날짜 구간이 끝난 후 실행되어 그 구간의 데이터를 처리합니다. 백필은 과거 구간에 대한 DagRun을 여러 개 생성하는 작업입니다.

### 재시도는 데이터 작업의 멱등성과 함께 설계해야 합니다

Airflow는 Task 실행 상태와 재시도 시점을 관리하지만, 외부 API 호출이나 DB 적재를 자동으로 되돌려 주지는 않습니다. Task가 목적지에 일부 데이터를 쓴 뒤 Worker가 종료되면 재시도 때 중복이 생길 수 있습니다. 따라서 파티션 교체, 고유 키 기반 upsert, 완료 마커, 트랜잭션처럼 다시 실행해도 결과가 같도록 처리하는 방식이 필요합니다. 실행 상태 저장소와 업무 데이터 저장소는 서로 다른 시스템입니다.

### Airflow를 선택할 때의 경계

Airflow는 시작과 끝이 있는 배치 워크플로와 외부 작업의 순서 제어에 적합합니다. 초당 이벤트마다 상태를 갱신하며 무한히 실행되는 스트림 처리 엔진은 아닙니다. 스트림 처리는 Kafka·Flink 같은 런타임에 맡기고, Airflow는 배포·정기 검증·백필·재처리 같은 유한한 작업을 조정하는 구성이 자연스럽습니다.

## 운영할 때 확인할 것

작업이 시작되지 않으면 DAG 파싱 오류 → DagRun 생성 여부 → 의존성·Pool·동시성 → Executor 대기열 → Worker 로그 순서로 좁혀 보시면 됩니다. Scheduler를 여러 개 운영할 수 있지만, 메타데이터 DB의 처리 능력도 함께 살펴야 합니다. DAG 코드와 Task가 실제로 접근하는 데이터 경로를 구분하면 장애 지점을 찾기 쉽습니다.

## Kubernetes에서 실행하는 구조

Airflow를 Kubernetes에 올린다는 말에는 두 층위가 있습니다. 첫째는 API Server, Scheduler, DAG Processor, Triggerer 같은 Airflow 상시 구성요소를 Kubernetes Pod로 배포하는 것입니다. 둘째는 각 Task를 어떤 실행기로 실행할지 정하는 것입니다. 공식 Helm Chart는 첫 번째 배포를 구성해 주며, `KubernetesExecutor`를 선택하면 Task Instance마다 별도의 임시 Worker Pod를 생성하는 두 번째 실행 방식도 사용합니다. 따라서 **Kubernetes에 Airflow를 배포했다고 해서 자동으로 Task마다 Pod가 생기는 것은 아닙니다.**

![Airflow KubernetesExecutor의 제어 경로와 작업 Pod 흐름](/images/posts/data-platform-theory/airflow-kubernetes-architecture.svg)

다음 공식 그림은 Kubernetes 클러스터에 분산 배포된 Airflow 구성 예입니다. 이어지는 개념도는 그중 특히 `KubernetesExecutor`가 Task Pod를 만드는 경로에 초점을 맞췄습니다.

![Airflow 공식 문서의 Kubernetes 분산 배포 예시](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/_images/arch-diag-kubernetes2.png)

[그림 출처: Kubernetes Executor — distributed deployment example](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html)

### 두 개의 스케줄러는 역할이 다릅니다

| 역할 | 담당 | 결정하는 것 |
|---|---|---|
| Airflow Scheduler | Airflow 제어 영역 | DAG 일정, Task 의존성, Pool·동시성 조건을 평가해 어떤 Task Instance를 실행할지 결정합니다. |
| Kubernetes Scheduler | Kubernetes 컨트롤 플레인 | API에 생성된 Pod의 CPU·메모리 요청, 노드 여유 자원, 제약 조건을 보고 어느 노드에 배치할지 결정합니다. |

Airflow Scheduler가 `Task A`를 실행 가능 상태로 만들면 `KubernetesExecutor`가 Kubernetes API에 Pod 생성을 요청합니다. 그 다음 Kubernetes Scheduler가 노드를 정합니다. 둘은 이름만 비슷할 뿐, 전자는 **업무 작업의 실행 순서**, 후자는 **컨테이너의 노드 배치**를 담당합니다.

### KubernetesExecutor의 Task 한 건 흐름

1. DAG Processor가 DAG를 파싱하고, Airflow Scheduler가 일정과 선행 Task 상태를 바탕으로 Task Instance를 실행 대기열에 넣습니다.
2. Scheduler 안에서 동작하는 `KubernetesExecutor`가 Kubernetes API를 통해 Worker Pod를 생성합니다. Scheduler 프로세스가 Kubernetes 밖에 있어도 클러스터 API에 접근할 수 있으면 구성할 수 있습니다.
3. Kubernetes Scheduler가 Pod를 노드에 배치하고, kubelet이 컨테이너를 시작합니다. Pod는 DAG 코드와 Airflow 설정·연결 정보에 접근할 수 있어야 합니다. DAG는 이미지에 포함하거나, `git-sync` 또는 공유 볼륨 등으로 제공할 수 있습니다.
4. Worker 컨테이너가 실제 Task 코드를 실행해 외부 DB·API·파일 저장소를 읽거나 씁니다. 이 데이터 처리 경로와 Pod 생성·상태 감시 경로는 구분됩니다.
5. 작업 결과와 Pod 종료 상태가 Airflow에 반영되면 Task Instance가 성공 또는 실패로 기록되고 Worker Pod는 종료됩니다. 로그를 원격 저장소에 보내거나 영속 볼륨에 보관하도록 구성하지 않으면, 종료 후 로그를 잃을 수 있습니다.

공식 문서의 설명대로 `KubernetesExecutor` 자체는 Airflow Scheduler 프로세스에서 동작하며, Task Instance별 Pod를 생성합니다. 반면 Helm Chart를 이용한 배포는 Airflow의 상시 구성요소를 Kubernetes 리소스로 배치하는 방법입니다. 운영 구성에서는 메타데이터 DB를 외부의 내구성 있는 PostgreSQL/MySQL 서비스로 두는 것을 권장합니다. Chart의 내장 PostgreSQL은 테스트·간단한 설치 용도입니다.

### Executor 선택과 KubernetesPodOperator 구분

| 방식 | Worker 형태 | 적합한 상황과 고려점 |
|---|---|---|
| `KubernetesExecutor` | Task마다 생성 후 종료하는 Pod | Task별 이미지·CPU·메모리 요구가 크게 다르거나 실행 환경을 분리하고 싶을 때 유용합니다. Pod 시작 시간이 추가되며, DAG·설정·로그 제공 방식을 맞춰야 합니다. |
| `CeleryExecutor`를 Kubernetes에 배포 | 큐를 소비하는 상시 Worker Pod | Worker가 미리 떠 있어 Task 시작 지연이 적습니다. 브로커가 필요하며 여러 Task가 같은 Worker Pod의 자원을 나눠 쓰므로 메모리·동시성을 조정해야 합니다. |
| `KubernetesPodOperator` | 해당 Operator가 만든 별도의 작업 Pod | Executor가 Celery여도 특정 Task만 별도 이미지의 Pod에서 실행할 수 있습니다. 이것은 Executor 전체를 `KubernetesExecutor`로 바꾸는 것과 다릅니다. |

Pod 템플릿과 Task별 설정으로 이미지, 리소스 요청·제한, 볼륨, 환경 변수를 조정할 수 있습니다. 다만 이를 적용할 때는 Worker 서비스 계정에 필요한 Kubernetes 권한만 부여하고, Task가 쓸 Secret과 외부 데이터 자격 증명도 해당 실행 Pod에서 접근 가능하도록 준비해야 합니다. Pod가 OOM으로 종료되거나 노드가 교체되는 등 Kubernetes 수준의 실패가 Airflow 재시도를 일으킬 수 있으므로, 외부 데이터 쓰기는 멱등하게 설계해야 합니다.

## 실무 적용: 사내 플랫폼에서는 이렇게 씁니다

사내에서는 Airflow 3.3을 데이터 파이프라인 전체의 **유일한 오케스트레이터**로 운영하고 있습니다. 로그 ETL, 외부 API 수집(Airbyte), Doris 적재, dbt 변환, 데이터 검증 알림이 모두 하나의 Airflow에서 돕니다. 위에서 설명한 구성요소가 실제로 어떻게 배치되어 있는지 이론과 대응해 정리합니다.

### 배포 구성과 DAG Bundle

| 이론의 구성요소 | 사내 구성 |
|---|---|
| Executor | `CeleryExecutor` + Redis 브로커. Worker concurrency 16, 전체 parallelism 32 |
| 프로세스 | api-server, scheduler, dag-processor, triggerer, worker를 docker compose로 분리 기동 |
| Metadata DB | 별도 PostgreSQL. 업무 데이터는 Doris·SeaweedFS에 있고 이 DB에는 실행 상태만 있습니다 |
| DAG Bundle | 운영은 `GitDagBundle`이 Git `master/dags`를 60초마다 확인, 개발은 `LocalDagBundle` |

Airflow 3의 DAG Bundle을 도입하면서 **DAG 코드를 이미지에 굽지 않게** 되었습니다. DAG 변경은 머지만 하면 이미지 재빌드 없이 반영되고, 각 DagRun이 어떤 Git commit으로 실행되었는지 기록됩니다. 개발 서버는 로컬 폴더 번들이라 `git checkout <branch>`만으로 브랜치 단위 테스트가 가능합니다. 같은 서버에서 운영용 compose 파일을 실수로 띄우지 않도록, compose 파일 자체에 필수 환경변수가 없으면 즉시 실패하는 가드를 걸어 두었습니다.

Task마다 필요한 라이브러리가 충돌하는 문제는 **Worker 이미지 안에 전용 가상환경을 분리**해 해결했습니다. Airbyte 추출은 `@task.external_python`으로 Airbyte 전용 venv에서, dbt는 dbt 전용 venv를 활성화한 뒤 실행합니다. Airflow 본체의 constraint와 PyAirbyte·dbt-doris의 의존성이 서로 영향을 주지 않습니다.

### 메타데이터 기반 DAG 팩토리

DAG 파일을 하나씩 쓰지 않습니다. Airflow Variable에 JSON 설정을 등록하면 **설정 1건이 DAG 1개**로 생성되는 팩토리 구조입니다.

- `airbyte_metadata_config` → 매체·스트림별 추출·적재 DAG ([Airbyte 장](./airbyte) 참고)
- `dbt_metadata_config` → dbt 모델별 변환 DAG ([dbt 장](./dbt) 참고)

설정 편집은 Airflow 플러그인으로 만든 FastAPI 기반 폼 화면에서 합니다. 필수 필드가 빠진 설정은 해당 DAG만 건너뛰고 나머지는 계속 파싱하며, 같은 `dag_id`가 두 번 나오면 조용히 덮어쓰지 않고 에러 로그를 남깁니다. DAG Processor가 파싱 단계에서 Variable을 읽으므로, 설정 오류가 전체 DAG 파싱을 깨뜨리지 않게 하는 것이 중요했습니다. 이 구조로 넘어온 과정은 [Cron 기반 ETL을 Airflow Dynamic DAG로 전환하기](../de/cron-etl-to-airflow-dynamic-dag)에 정리했습니다.

### Asset 체인과 partition_key — "DAG는 데이터가 아니라 의존성"의 실제

이론에서 DAG 간선은 데이터를 옮기지 않는다고 했습니다. 사내 파이프라인은 이 원칙을 DAG 사이에도 그대로 적용합니다. DAG끼리는 **Asset 이벤트와 partition_key(처리 날짜)만** 주고받고, 실제 데이터는 SeaweedFS와 Doris에 있습니다.

```text
fastlog_hourly_etl (매시 25분, 로그 파일 센서)
  └─ Asset 이벤트 (extra: 실제로 쓴 Parquet 파티션 목록)
      → doris_fastlog_hourly_load (Asset 스케줄)
          └─ Asset 이벤트 (partition_key = 처리 날짜)
              → dbt 변환 DAG (PartitionedAssetTimetable, partition_key 상속)
```

- 체인 최상위 DAG는 `CronPartitionTimetable`로 매 실행에 partition_key를 찍습니다. 하류 DAG는 그 키를 상속하므로 "몇 시에 실행됐는가"가 아니라 **"어느 날짜를 처리하는가"**로 동작합니다. 지연 확정되는 원천(AppsFlyer 등)은 `n_days_ago`로 D-3을 처리합니다.
- ETL 컨테이너가 실제로 쓴 파티션 목록을 stdout 마커로 내보내고, 이를 Asset 이벤트 `extra`에 실어 하류 적재 DAG에 넘깁니다. 대용량 데이터가 아니라 **데이터의 주소**를 넘긴다는 이론 그대로입니다.

### 재시도와 멱등성을 위한 장치

| 문제 | 사내 대응 |
|---|---|
| 상류가 같은 partition_key 이벤트를 여러 번 발행 | dbt DAG 첫 Task `skip_if_already_processed`가 REST API로 "내 이후에 시작해 성공한 run"을 찾아 중복 실행을 건너뜀. 조회 실패 시에는 그냥 실행(fail-open) |
| 재시도 시 목적지 중복 | 적재는 모두 "처리 구간 DELETE → 재적재" 또는 트랜잭션 교체 방식으로 설계 |
| Doris 노드 장애로 dbt가 소켓을 물고 무한 대기 | 기본 `execution_timeout` 30분 + dbt를 새 프로세스 그룹으로 띄워 타임아웃 시 자식 프로세스까지 종료 |
| 로그 파일이 아직 없을 때 Worker 슬롯 점유 | `@task.sensor(mode="reschedule")`로 대기 중에는 슬롯 반환 |
| `catchup=True` DAG를 재배포할 때 과거 전체 백필 폭주 | DAG별 `start_date` 하한을 명시하고, 누락 없이 순차 처리되도록 `max_active_runs=1` |

### XCom과 계보

이론에서는 XCom을 작은 값 전달용이라고 설명했습니다. 실제로 Airbyte 추출 Task는 pandas DataFrame을 반환하기 때문에, **커스텀 XCom Backend**를 두어 DataFrame이면 Parquet으로 외부 SFTP 저장소에 쓰고 메타데이터 DB에는 경로 문자열만 남깁니다. 결과적으로 메타데이터 DB에는 여전히 "주소"만 저장됩니다.

XCom은 Task 사이에 작은 값을 건네는 기능이고, **OpenLineage는 데이터 처리 과정의 입·출력을 서로 다른 도구가 같은 방식으로 설명하고 전달하도록 만든 개방형 표준**입니다. OpenLineage 자체는 계보를 저장하는 데이터베이스가 아닙니다.

OpenLineage 이벤트를 간단히 보면 세 가지 정보가 중심입니다.

- **Job:** 어떤 작업인지 — 예를 들어 Airflow DAG와 Task입니다.
- **Run:** 그 작업이 이번에 실행된 한 번의 실행 정보와 결과·시각입니다.
- **Dataset:** 작업이 읽은 입력과 만든 출력입니다.

실행 이벤트는 보통 작업 시작과 종료 시점에 발행됩니다. 종료 이벤트에는 성공(`COMPLETE`), 실패(`FAIL`), 중단(`ABORT`) 같은 상태가 담길 수 있습니다. 예를 들어 `orders_raw`를 읽어 `orders_daily`를 만든 실행은 “이 Task가 이번 실행에서 이 입력을 읽고 이 출력을 만들었다”는 이벤트를 보냅니다. 테이블 데이터 자체는 이벤트에 포함되지 않습니다. Airflow Provider가 이벤트를 만들고 Transport가 OpenMetadata로 전달하며, 저장되어 계보 화면에 보이는 연결은 OpenMetadata에 있습니다.

### 예전 Airflow 2 방식과 현재 방식

예전에는 Airflow 2와 OpenMetadata 신규 버전 사이에 OpenLineage 연동 호환 문제가 있어, Task 실행이 끝날 때마다 별도 로직이 `inlets`와 `outlets`를 읽어 OpenMetadata로 직접 보냈습니다. 현재는 OpenLineage Provider가 표준 이벤트를 만들고 Transport가 전달합니다.

| 구분 | 예전 Airflow 2 연동 | 현재 OpenLineage 연동 |
|---|---|---|
| 정보 가져오기 | Task 완료 시 `inlets`/`outlets`를 직접 읽었습니다. | Provider가 Operator Extractor·Hook에서 자동 수집하고, 부족할 때 `inlets`/`outlets`를 보조 정보로 쓸 수 있습니다. |
| 전달 단위 | 사내 로직이 OpenMetadata에 직접 보내는 계보 정보였습니다. | Job·Run·Dataset을 표현하는 OpenLineage 이벤트를 Transport로 보냅니다. |
| OpenMetadata 반영 | Task 완료마다 기존 방식으로 직접 갱신했습니다. | 현재는 커스텀 Transport가 OpenMetadata의 이전 연결을 정리한 다음 표준 이벤트를 보냅니다. |
| 계보를 저장하는 곳 | OpenMetadata | OpenMetadata |

따라서 현재 방식에서도 `inlets`와 `outlets`가 쓰일 수는 있지만, 예전처럼 이 값만 무조건 가져오는 방식은 아닙니다. Provider는 자동 Extractor나 Hook에서 입력·출력을 찾으면 그 정보를 우선하므로, `inlets`를 바꿨는데도 이벤트의 입력이 예상과 다를 수 있습니다. 최종 기준은 DAG 설정 자체가 아니라 **실제로 OpenLineage 이벤트에 담긴 `inputs`와 `outputs`**입니다.

예를 들어 변환 Task가 `orders_raw`를 읽어 `orders_daily`를 만들면 OpenMetadata에는 다음처럼 표시됩니다.

```text
orders_raw ──[daily_orders DAG]──> orders_daily
```

![사내 Airflow OpenLineage Transport의 계보 갱신 흐름](/images/posts/data-platform-theory/airflow-openlineage-architecture.svg)

### 완료할 때 이전 연결을 정리하는 이유

같은 Task가 다음 실행에서는 다른 입력 테이블을 읽을 수 있습니다. 이전 연결을 그대로 둔 채 새 연결을 추가하면 OpenMetadata 화면에 옛 입력과 새 입력이 모두 남을 수 있습니다. 이를 막기 위해 **Airflow에서 실행되는 커스텀 Transport가 OpenMetadata Lineage API를 호출해**, 성공한 Task의 최신 입력·출력 관계를 반영하기 전에 OpenMetadata에 저장된 **현재 DAG의 이전 연결만** 찾아 정리합니다.

1. Task가 `COMPLETE`로 끝나고 입력과 출력이 모두 확인될 때만 정리를 시작합니다.
2. 출력 테이블의 기존 상류 연결을 조회합니다.
3. 그중 현재 DAG가 만든 연결만 삭제합니다. 같은 테이블을 사용하는 다른 DAG의 연결은 남겨 둡니다.
4. 정리가 끝나면 새 OpenLineage 이벤트를 OpenMetadata에 전송해 최신 연결을 표시합니다.

여기서 Task 하나는 `dag_id.task_id` 형태의 Job으로 식별하고, 소속 Pipeline은 `openlineage.dag_id`로 맞춥니다. Dataset 이름은 데이터베이스 주소와 테이블 이름을 합쳐 OpenMetadata Table 이름으로 변환합니다. 예를 들어 `mysql://Doris:3306`과 `default.s.t`는 `Doris.default.s.t`로 연결됩니다.

정리에는 안전장치가 있지만, 그 대가로 계보가 틀리게 남을 수 있습니다. 첫 적재라 기존 테이블이 없으면 지울 연결이 없으므로 넘어갑니다. 반면 입력을 전혀 찾지 못했거나 OpenMetadata 조회·삭제 API가 실패하면 이전 연결을 보존하고 새 이벤트 전송은 계속합니다. 이때 새 이벤트에 올바른 입력이 없으면 OpenMetadata 화면에는 **이미 바뀌었거나 사라진 예전 upstream이 계속 표시될 수 있습니다.** 또한 현재 코드는 입력이 하나라도 있는지만 확인하고 완전성을 검증하지 않습니다. 일부 입력만 추출된 상태라면 기존 연결을 모두 정리한 뒤 일부 새 연결만 보낼 수 있습니다. 즉 이 동작은 “계보 누락”을 줄이는 대신 “낡은 계보 표시” 또는 “일부 계보 누락”을 허용하는 fail-open 방식입니다. 계보가 실제 현재 입력과 다른지 판단할 때는 화면만 보지 말고 Airflow 이벤트의 `inputs`와 Transport 경고 로그도 함께 확인해야 합니다.

전송 호환성을 위한 구현도 있습니다. OpenMetadata 2.0이 UTC 시각의 `+00:00` 표기를 거부해 전송 직전에 `Z` 형식으로 바꾸며, Transport 인증에는 OpenLineage Connection의 API Key를 사용합니다. 현재 Reset Transport 설정의 `verify` 기본값은 `False`이므로 TLS 인증서 검증이 필요한 환경에서는 실제 설정값을 확인해야 합니다.


**공식 문서:** [OpenLineage 개요](https://openlineage.io/docs/), [OpenLineage Run Cycle과 이벤트 상태](https://openlineage.io/docs/spec/run-cycle/), [OpenLineage Naming Convention](https://openlineage.io/docs/spec/naming/), [Airflow Architecture Overview](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html), [Scheduler](https://airflow.apache.org/docs/apache-airflow/stable/concepts/scheduler.html), [OpenLineage Provider — Operator 구현과 inlet/outlet](https://airflow.apache.org/docs/apache-airflow-providers-openlineage/stable/guides/developer.html), [OpenMetadata Lineage API](https://docs.open-metadata.org/v1.12.x/api-reference/lineage/index), [KubernetesExecutor](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html), [Helm Chart Production Guide](https://airflow.apache.org/docs/helm-chart/stable/production-guide.html)
