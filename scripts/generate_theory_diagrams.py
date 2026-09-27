"""Generate self-contained SVG architecture maps for the data platform theory series."""

from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "public/images/posts/data-platform-theory"
ROOT.mkdir(parents=True, exist_ok=True)

# Each map separates coordination (upper lane) from bytes/records (lower lane).
MAPS = {
    "airflow": ("Apache Airflow 3", [
        ("DAG Bundle", "버전별 DAG 코드"), ("DAG Processor", "파싱·직렬화"),
        ("Metadata DB", "실행 상태·일정"), ("Scheduler", "실행 가능 작업 선택")], [
        ("원천 시스템", "DB·API·파일"), ("Worker Task", "데이터 읽기·명령 실행"),
        ("외부 처리", "변환·계산 작업"), ("목적지", "DB·객체 저장소")],
        ["DAG 코드를 파싱해 DB에 저장", "Scheduler가 DagRun과 Task를 선정", "Executor가 Worker에 작업 전달", "Worker가 외부 시스템을 호출"]),
    "doris": ("Apache Doris · 통합형 FE/BE", [
        ("SQL 클라이언트", "MySQL 프로토콜"), ("FE", "파싱·최적화·메타데이터"),
        ("FE 리더/팔로어", "메타데이터 고가용성"), ("트랜잭션", "적재 가시성 관리")], [
        ("원천 데이터", "파일·스트림·SQL"), ("BE 적재", "분산 데이터 쓰기"),
        ("BE 클러스터", "샤드 저장·MPP 실행"), ("분석 결과", "FE를 거쳐 반환")],
        ["FE가 쿼리·적재를 조정", "BE가 데이터를 샤드로 저장", "BE가 분산 쿼리 조각 실행", "FE가 결과를 클라이언트에 전달"]),
    "seaweedfs": ("SeaweedFS", [
        ("S3 Gateway", "S3 API 진입점"), ("Filer", "경로·파일 메타데이터"),
        ("Metadata Store", "디렉터리·청크 참조"), ("Master", "볼륨 위치·파일 ID")], [
        ("클라이언트", "객체 업로드·읽기"), ("Filer/S3", "경로 조회·청크 분할"),
        ("Volume Server", "needle·볼륨 저장"), ("복제/EC", "볼륨 단위 내구성")],
        ["Filer가 경로 메타데이터 조회", "Master에서 파일 ID·볼륨 위치 획득", "Volume Server에 바이트 기록", "읽기 시 위치를 찾아 데이터 반환"]),
    "dbt": ("dbt Core", [
        ("프로젝트", "SQL·YAML·매크로"), ("Parser", "ref·source 의존성"),
        ("DAG", "모델 실행 순서"), ("Adapter", "DB별 SQL·연결")], [
        ("원천 테이블", "source()로 참조"), ("SQL 컴파일", "Jinja·materialization"),
        ("웨어하우스", "쿼리·테이블 생성"), ("Mart·테스트", "결과 검증·문서화")],
        ["프로젝트의 모델 의존성 해석", "SQL·Jinja를 DB용 SQL로 컴파일", "웨어하우스가 변환 실행", "테스트와 문서 산출물 생성"]),
    "airbyte": ("Airbyte · 데이터 복제", [
        ("Config API", "Connection·Job 설정"), ("Config & Jobs DB", "설정·실행 이력"),
        ("Temporal", "Workflow·Task Queue"), ("Worker / Launcher", "Connector Pod 실행")], [
        ("Source Connector", "DB·API에서 읽기"), ("Socket / Middleware", "레코드·제어 메시지"),
        ("Destination Connector", "레코드 적재"), ("대상 시스템", "분석용 저장소")],
        ["API가 Connection 설정과 Job을 기록", "Temporal이 실행 Workflow를 관리", "Worker가 workload를 시작하고 Connector 실행", "Connector가 레코드를 복제하고 State를 보고"]),
    "duckdb": ("DuckDB · 내장형 분석 DB", [
        ("호스트 프로세스", "Python·CLI·애플리케이션"), ("SQL Parser", "구문·바인딩"),
        ("Optimizer", "논리 계획 최적화"), ("Physical Plan", "실행 연산자 선택")], [
        ("파일/테이블", "Parquet·CSV·DB 파일"), ("스캔", "필요한 열·행 읽기"),
        ("Vectorized Engine", "DataChunk 단위 연산"), ("결과", "호스트로 반환·저장")],
        ["호스트가 SQL 제출", "바인딩·최적화 후 물리 계획 생성", "DataChunk를 연산자에 전달", "결과를 앱 또는 파일로 반환"]),
    "spark": ("Apache Spark · 클러스터 실행", [
        ("spark-submit", "애플리케이션 제출"), ("Driver", "SparkContext·계획"),
        ("Cluster Manager", "리소스 할당"), ("Scheduler", "Job→Stage→Task")], [
        ("원천 데이터", "분산 파일·테이블"), ("Executor", "파티션별 Task 실행"),
        ("Shuffle/Cache", "중간 데이터 교환"), ("출력", "파일·테이블·결과")],
        ["Driver가 변환 DAG 구성", "Action이 Job 실행을 촉발", "Stage의 Task를 Executor에 배분", "Shuffle 후 결과를 저장·반환"]),
    "flink": ("Apache Flink · 상태 기반 데이터 흐름", [
        ("Client", "JobGraph 제출"), ("Dispatcher", "JobMaster 생성"),
        ("JobMaster", "스케줄·체크포인트"), ("ResourceManager", "Task Slot 할당")], [
        ("Source", "이벤트·오프셋"), ("TaskManager", "연산자·네트워크 버퍼"),
        ("State", "키별 상태·윈도"), ("Sink", "외부 시스템 기록")],
        ["JobGraph를 Task Slot에 배치", "이벤트가 연산자 체인을 통과", "상태와 입력 위치를 체크포인트", "장애 시 일관된 지점부터 복구"]),
    "kafka": ("Apache Kafka · KRaft", [
        ("KRaft Controller", "메타데이터 quorum"), ("Topic", "논리적 이벤트 이름"),
        ("Partition Leader", "쓰기·읽기 담당"), ("Replica", "파티션 복제")], [
        ("Producer", "키별 파티션 선택"), ("Broker", "append-only 로그 기록"),
        ("Consumer Group", "파티션 분담·offset"), ("Downstream", "처리·저장")],
        ["Producer가 리더 파티션에 기록", "Broker가 로그를 복제·보존", "Consumer가 offset 기준으로 pull", "그룹별로 독립적으로 처리"]),
    "nifi": ("Apache NiFi", [
        ("Web UI/API", "흐름 설계·관리"), ("Flow Controller", "스레드·실행 일정"),
        ("Controller Service", "공유 연결·설정"), ("Provenance Repo", "이벤트·계보")], [
        ("외부 원천", "파일·API·메시지"), ("Processor", "수집·변환·라우팅"),
        ("Connection Queue", "FlowFile·역압 제어"), ("외부 대상", "전송·저장")],
        ["Processor가 FlowFile 생성", "Relationship에 따라 큐로 이동", "후속 Processor가 읽고 처리", "저장소가 내용·상태·계보를 기록"]),
    "aws-eks": ("Amazon EKS · 관리형 Kubernetes", [
        ("AWS IAM", "사용자·워크로드 인증"), ("EKS API Endpoint", "Kubernetes API 진입점"),
        ("Control Plane", "API·Scheduler·etcd 관리"), ("Controllers", "원하는 상태 조정")], [
        ("데이터 입력", "요청·이벤트·파일"), ("Pod / Job", "EKS 노드에서 처리"),
        ("AWS 데이터 서비스", "S3·RDS·MSK 예시"), ("결과·상태", "저장·응답·관측")],
        ["사용자·자동화가 IAM으로 인증", "Kubernetes API에 리소스 선언", "Control Plane이 Pod를 노드에 배치", "워크로드 Pod가 AWS 데이터 경로를 처리"]),
    "aws-dms": ("AWS DMS · Full load와 CDC", [
        ("DMS API", "마이그레이션 관리"), ("Replication Task", "테이블·이동 방식"),
        ("Source Endpoint", "접속·로그 설정"), ("Target Endpoint", "접속·적재 규칙")], [
        ("Source Database", "스냅샷·변경 로그"), ("Replication Instance", "읽기·변환·버퍼"),
        ("Apply Changes", "Full load 후 CDC 반영"), ("Target Database", "초기 데이터·변경분")],
        ["Endpoint와 Task가 이동 범위를 정의", "Full load가 기존 테이블을 복사", "복사 중 변경은 캐시해 적용", "CDC가 로그 변경을 계속 반영"]),
    "aws-msk": ("Amazon MSK · 관리형 Kafka", [
        ("AWS MSK API", "클러스터 수명주기"), ("Cluster Metadata", "KRaft 또는 ZooKeeper"),
        ("Topic / Partition", "논리적 로그·분할 단위"), ("Leader Election", "파티션 리더 지정")], [
        ("Producer", "키·파티션으로 전송"), ("Leader Broker", "파티션 로그 추가"),
        ("Follower Brokers", "복제본·장애 복구"), ("Consumer Group", "파티션·Offset 소비")],
        ["AWS API가 클러스터 설정을 관리", "Producer가 파티션 리더에 기록", "브로커가 로그를 복제·보존", "Consumer Group이 offset부터 읽기"]),
}


def text(x, y, value, size=20, color="#13243a", weight=400):
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(value)}</text>'


def box(x, y, title, detail, control):
    fill = "#e8efff" if control else "#e1f6ee"
    stroke = "#5271b8" if control else "#258264"
    return (f'<rect x="{x}" y="{y}" width="265" height="91" rx="15" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'
            + text(x + 17, y + 34, title, 21, "#13243a", 700)
            + text(x + 17, y + 66, detail, 16, "#45566c"))


for slug, (title, controls, data, steps) in MAPS.items():
    legend = ("파란색: 제어·메타데이터    초록색: 워크로드·서비스 데이터 평면"
              if slug == "aws-eks" else
              "파란색: 제어·메타데이터    초록색: 실제 데이터 경로")
    data_lane = "데이터 평면 · 컨테이너 실행과 서비스 연결" if slug == "aws-eks" else "실제 데이터 경로"
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="690" viewBox="0 0 1280 690" role="img" aria-labelledby="title desc" font-family="Arial, Apple SD Gothic Neo, Noto Sans CJK KR, sans-serif">',
             f'<title id="title">{escape(title)} 아키텍처</title>',
             f'<desc id="desc">제어·메타데이터 계층과 데이터 처리 계층을 구분합니다. 처리 순서: {escape("; ".join(steps))}</desc>',
             '<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#278568"/></marker><marker id="ctrl" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#5271b8"/></marker></defs>',
             '<rect width="1280" height="690" rx="24" fill="#f8fafc"/>',
             text(46, 57, title, 32, "#13243a", 700),
             text(47, 89, legend, 17, "#52647a"),
             '<rect x="40" y="120" width="1200" height="150" rx="18" fill="#f1f5fc"/>',
             '<rect x="40" y="300" width="1200" height="150" rx="18" fill="#eef8f4"/>',
             text(57, 149, "제어 · 메타데이터", 17, "#5271b8", 700),
             text(57, 329, data_lane, 17, "#258264", 700)]
    xs = [65, 370, 675, 980]
    for i, (name, detail) in enumerate(controls):
        parts.append(box(xs[i], 166, name, detail, True))
    for i, (name, detail) in enumerate(data):
        parts.append(box(xs[i], 346, name, detail, False))
    for i in range(3):
        parts.append(f'<line x1="{xs[i]+268}" y1="391" x2="{xs[i+1]-12}" y2="391" stroke="#278568" stroke-width="3" marker-end="url(#arrow)"/>')
    parts.append('<line x1="650" y1="273" x2="650" y2="333" stroke="#5271b8" stroke-width="2" stroke-dasharray="6 5" marker-end="url(#ctrl)"/>')
    parts += [text(48, 496, "한눈에 보는 실행 순서", 22, "#13243a", 700)]
    for i, step in enumerate(steps):
        y = 535 + i * 36
        parts.append(f'<circle cx="64" cy="{y-6}" r="13" fill="#278568"/>')
        parts.append(text(59, y, str(i+1), 15, "#ffffff", 700))
        parts.append(text(91, y, step, 18, "#26384b"))
    parts.append('</svg>')
    (ROOT / f"{slug}-architecture.svg").write_text("\n".join(parts), encoding="utf-8")


def airflow_kubernetes_map():
    """Show Kubernetes deployment and per-task Pod execution as separate layers."""
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="760" viewBox="0 0 1400 760" role="img" aria-labelledby="title desc" font-family="Arial, Apple SD Gothic Neo, Noto Sans CJK KR, sans-serif">',
        '<title id="title">Airflow on Kubernetes · KubernetesExecutor</title>',
        '<desc id="desc">Airflow Scheduler가 KubernetesExecutor를 통해 Kubernetes API에 Task Pod 생성을 요청합니다. Kubernetes Scheduler가 노드를 선택하고 Pod는 DAG를 실행해 업무 시스템에 접근한 뒤 상태를 보고하고 종료합니다.</desc>',
        '<defs><marker id="blueArrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#5271b8"/></marker><marker id="greenArrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#278568"/></marker></defs>',
        '<rect width="1400" height="760" rx="24" fill="#f8fafc"/>',
        text(48, 58, "Airflow on Kubernetes · KubernetesExecutor", 31, "#13243a", 700),
        text(49, 91, "Airflow Scheduler는 작업을 선택하고, Kubernetes Scheduler는 Pod를 실행할 노드를 선택합니다.", 17, "#52647a"),
        '<rect x="38" y="120" width="1324" height="210" rx="20" fill="#f1f5fc" stroke="#cbd7ec" stroke-width="2"/>',
        text(57, 151, "제어 경로 · Airflow Scheduler와 Kubernetes API의 상호작용", 17, "#5271b8", 700),
        '<rect x="38" y="358" width="1324" height="190" rx="20" fill="#eef8f4" stroke="#c7e6d9" stroke-width="2"/>',
        text(57, 389, "실행 경로 · Task Pod가 DAG 코드를 실행하고 실제 업무 데이터에 접근", 17, "#258264", 700),
    ]
    top = [(65, "Airflow Scheduler", "DAG·의존성 평가"), (385, "KubernetesExecutor", "Task Pod 생성 요청"), (705, "Kubernetes API", "Pod 객체·상태"), (1025, "Kubernetes Scheduler", "노드 배치")]
    lower = [(65, "DAG Bundle / Image", "Task 코드·런타임 제공"), (385, "임시 Worker Pod", "Task 한 건 실행"), (705, "외부 시스템", "DB·API·파일 저장소"), (1025, "Airflow 상태·로그", "성공·실패·로그 기록")]
    for x, name, detail in top:
        parts.append(box(x, 174, name, detail, True))
    for x, name, detail in lower:
        parts.append(box(x, 412, name, detail, False))
    for xs, yy, color, marker in [([65, 385, 705, 1025], 219, "#5271b8", "blueArrow"), ([65, 385, 705, 1025], 457, "#278568", "greenArrow")]:
        for i in range(3):
            parts.append(f'<line x1="{xs[i]+268}" y1="{yy}" x2="{xs[i+1]-14}" y2="{yy}" stroke="{color}" stroke-width="3" marker-end="url(#{marker})"/>')
    parts.append('<line x1="1158" y1="270" x2="535" y2="405" stroke="#5271b8" stroke-width="2.5" stroke-dasharray="7 6" marker-end="url(#blueArrow)"/>')
    parts.append(text(776, 320, "Pod 생성·배치", 15, "#5271b8", 700))
    parts.append('<path d="M520 505 C520 590 1158 590 1158 505" fill="none" stroke="#278568" stroke-width="2.5" stroke-dasharray="7 6" marker-end="url(#greenArrow)"/>')
    parts.append(text(655, 581, "Task 실행 결과와 로그가 Airflow에 반영된 뒤 Pod 종료", 16, "#258264", 700))
    parts.append(text(48, 640, "Kubernetes에 Airflow 구성요소를 배포하는 것과 KubernetesExecutor를 선택하는 것은 별도 결정입니다.", 18, "#26384b", 700))
    parts.append(text(48, 674, "Helm Chart는 API Server·Scheduler·DAG Processor 등 상시 구성요소의 배포를 돕고, Executor 설정이 Task의 실행 형태를 결정합니다.", 16, "#52647a"))
    parts.append('</svg>')
    (ROOT / "airflow-kubernetes-architecture.svg").write_text("\n".join(parts), encoding="utf-8")


airflow_kubernetes_map()


def airflow_openlineage_map():
    """Create a plain-language diagram of lineage refresh for one Airflow DAG."""
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="650" viewBox="0 0 1400 650" role="img" aria-labelledby="title desc" font-family="Arial, Apple SD Gothic Neo, Noto Sans CJK KR, sans-serif">',
        '<title id="title">Airflow에서 OpenMetadata로 계보 보내기</title>',
        '<desc id="desc">Airflow Task의 입력과 출력 정보를 OpenLineage 이벤트로 보내고, 성공 완료 시 현재 DAG가 만든 이전 연결만 정리한 뒤 최신 연결을 OpenMetadata에 기록합니다.</desc>',
        '<defs><marker id="olGreen" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#278568"/></marker><marker id="olBlue" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#5271b8"/></marker></defs>',
        '<rect width="1400" height="650" rx="24" fill="#f8fafc"/>',
        text(48, 58, "Airflow → OpenLineage → OpenMetadata", 31, "#13243a", 700),
        text(49, 91, "OpenLineage는 테이블 데이터 대신 ‘무엇을 읽고 무엇을 만들었는지’를 전달합니다.", 18, "#52647a"),
        '<rect x="38" y="120" width="1324" height="170" rx="20" fill="#f1f5fc" stroke="#cbd7ec" stroke-width="2"/>',
        text(57, 151, "Task가 성공적으로 끝나면 다음 순서로 계보를 갱신합니다", 18, "#5271b8", 700),
    ]
    cards = [
        (65, "1. 입력·출력 확인", "orders_raw → orders_daily"),
        (385, "2. 실행 기록 만들기", "DAG·Task·테이블·성공 여부"),
        (705, "3. 옛 연결 정리", "현재 DAG가 만든 연결만"),
        (1025, "4. 새 연결 저장", "OpenMetadata에 최신 상태 반영"),
    ]
    for x, title, detail in cards:
        parts.append(box(x, 178, title, detail, x != 1025))
    for x1, x2 in [(333, 371), (653, 691), (973, 1011)]:
        parts.append(f'<line x1="{x1}" y1="223" x2="{x2}" y2="223" stroke="#278568" stroke-width="3" marker-end="url(#olGreen)"/>')
    parts.append('<rect x="38" y="322" width="1324" height="245" rx="20" fill="#eef8f4" stroke="#c7e6d9" stroke-width="2"/>')
    parts.append(text(57, 355, "입력 테이블이 바뀌었을 때", 18, "#258264", 700))
    parts.append(box(65, 386, "이전 실행", "orders_old → orders_daily", True))
    parts.append(box(385, 386, "이번 실행", "orders_new → orders_daily", True))
    parts.append(box(705, 386, "정리 범위", "이 DAG의 옛 연결만 삭제", True))
    parts.append(box(1025, 386, "화면에 표시", "orders_new → orders_daily", False))
    for x1, x2 in [(333, 371), (653, 691), (973, 1011)]:
        parts.append(f'<line x1="{x1}" y1="431" x2="{x2}" y2="431" stroke="#278568" stroke-width="3" marker-end="url(#olGreen)"/>')
    parts.append(text(57, 510, "같은 테이블을 쓰는 다른 DAG의 연결은 그대로 둡니다.", 16, "#45566c"))
    parts.append(text(48, 612, "실패·입력 누락·OpenMetadata 오류가 있으면 옛 연결을 지우지 않아 계보가 통째로 사라지는 일을 막습니다.", 16, "#26384b", 700))
    parts.append('</svg>')
    (ROOT / "airflow-openlineage-architecture.svg").write_text("\n".join(parts), encoding="utf-8")


airflow_openlineage_map()
