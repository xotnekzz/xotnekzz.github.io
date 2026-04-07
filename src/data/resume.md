---
personal:
  name: 김태수
  title: Senior Data Engineer
  email: xotnekzz@gmail.com
  github: github.com/xotnekzz
  githubUrl: https://github.com/xotnekzz
  portfolio: Portfolio
  portfolioUrl: https://xotnekzz.github.io/portfolio/

experiences:
  - company: 비트망고
    companyEn: BitMango
    period: "2019.08 ~ 현재 (약 7년)"
    role: Senior Data Engineer
    projects:
      - title: "데이터 인프라 & 플랫폼"
        problem: "레거시 40대 노드(HDFS/Impala)의 과도한 운영 리소스 및 노후 인프라 성능 한계"
        bullets:
          - "단순 집계 쿼리 응답 최대 1,715배 단축 (50ms 이내)"
          - "복잡한 Join 집계 쿼리 최대 5배 단축 (250s → 40s)"
        tags: ["Apache Doris", "SeaweedFS", "Fluentd", "Kafka", "HDFS / Impala", "온프레미스 40대"]
        accent: true

      - title: "분석 엔지니어링 & 데이터 마트"
        problem: "규제 없는 데이터 민주화로 인한 raw 데이터 무분별 접근 — 주인 없는 테이블 난립, 예측 불가한 시스템 부하, 데이터 신뢰도 저하"
        bullets:
          - "메달리온 아키텍처 도입 — Silver 레이어에서 raw 데이터를 정제·통제하고 Gold 레이어로 서빙하는 구조 설계"
          - "pyairbyte·Airflow·dbt 기반 ELT 파이프라인으로 마케팅(pLTV, ROAS) 및 게임 로그 분석 마트 구축"
          - "Metadata-driven ETL: DAG 설정을 DB화하여 수십 개 파이프라인을 단일 코드베이스로 관리"
        tags: ["Apache Airflow", "dbt", "pyairbyte", "Silver / Gold 레이어", "pLTV · ROAS"]
        accent: true

      - title: "데이터 민주화 & 의사결정 지원"
        problem: "예측 데이터 기반 의사결정 지원 및 현업 self-BI 환경 부재"
        bullets:
          - "pROAS 파이프라인: 딥러닝 기반 조기 성과 예측 시스템으로 마케팅 최적화 주기 단축 (Day 3~7)"
          - "Apache Superset 기반 전사 BI 체계 구축 및 현업 자립 분석 환경 조성"
        tags: ["Apache Superset", "Metabase", "Redash", "pROAS"]
        accent: true

      - title: "AX/AI Engineering"
        problem: "급변하는 AI 기술 환경 속에서 전사적 AI 전환(AX)을 실질적으로 실행할 방법론과 내재화 전략 부재"
        bullets:
          - "LangChain 기반 멀티 LLM 모듈 개발 (OpenAI·Claude·Gemini API·Local LLM) + Milvus Semantic Search 연동, Streamlit으로 사내 배포"
          - "LibreChat 오픈소스 도입 — 마케팅 증분 분석 도구·RAG 도구를 MCP 서버로 연결하여 누구나 커스텀 에이전트를 생성할 수 있는 사내 AI 플랫폼 구축"
          - "Gemini CLI·Claude Code 기반 마케팅 캠페인 운영 에이전트 개발 — 지침·스크립트 자동 실행으로 마케터 생산성 1,000배 혁신 (수 명 운영 인력 → 마케터 1명 단독 운영)"
          - "에이전트 스킬·하네스 엔지니어링 도입 — GitLab 이슈 및 시간 관리 자동화 백오피스 사이트 개발·제공"
        tags: ["LangChain", "OpenAI API", "Claude API", "Gemini API", "Local LLM", "Milvus", "LibreChat", "MCP", "RAG", "Streamlit"]
        accent: true

      - title: "데이터 거버넌스 & 품질"
        problem: "데이터 사일로 현상 및 Airflow 버전 제약으로 인한 리니지 수집 자동화 불가"
        bullets:
          - "OpenMetadata 전사 도입 리드 — Custom API 기반 Decorator 자체 개발로 Airflow 버전 제약 우회"
          - "데이터 리니지·품질 관리·카탈로그 통합 운영으로 전사 데이터 신뢰도 확보"
          - "AI 에이전트 기반 데이터 품질 관리 및 내부 업무 프로세스 자동화 주도"
        tags: ["OpenMetadata", "Custom Decorator", "Data Lineage", "Data Catalog", "Metadata-driven ETL"]
        accent: true

  - company: 우암코퍼레이션
    companyEn: Wooam Corp
    period: "2018 ~ 2019"
    role: Backend Developer
    projects:
      - title: ""
        period: ""
        bullets:
          - "10만 세대 규모 전력 데이터 수집 API(Java) 및 FastDR 시스템 구축"
        accent: false

techStack:
  - category: Languages
    skills: [Python, Java, SQL, Bash]
  - category: Data Infra
    skills: [Apache Doris, SeaweedFS, Apache Airflow, PyAirbyte, dbt, Kafka, HDFS, Impala]
  - category: AI
    skills: ["LLM API (OpenAI·Claude·Gemini)", LangChain, MCP, "Agent Skills", LibreChat, Streamlit]
  - category: "BI & Governance"
    skills: ["Apache Superset", Metabase, Redash, OpenMetadata]
  - category: Database
    skills: [MariaDB, MongoDB, Milvus]
  - category: Backend
    skills: [FastAPI, Django]
  - category: DevOps
    skills: [Docker, "Docker Compose", Ansible, Grafana, Prometheus, "Git/GitLab CI-CD"]

education:
  - school: 성공회대학교
    major: 컴퓨터공학과
    period: "2012.02 ~ 2017.02 (졸업)"
---

저는 온프레미스 환경에서 데이터 인프라 현대화부터 분석 파이프라인 설계, 데이터 민주화, 거버넌스 체계 수립, AI 기반 자동화까지 데이터의 전 생애주기를 직접 다루어온 풀스택 데이터 엔지니어입니다.

첫 번째 전환점은 10년 넘은 HDFS/Impala 환경을 SeaweedFS와 Apache Doris 기반으로 현대화한 경험이었습니다. 40대 규모의 온프레미스 서버 자원을 직접 최적화하며 쿼리 응답 속도를 최대 1,715배 향상시켰고, 인프라가 비즈니스 속도를 결정하는 핵심 변수임을 실감했습니다. 그러나 성능 개선만으로는 충분하지 않았습니다. 누구나 raw 데이터에 직접 접근하여 분석 테이블을 생성하던 환경은 주인 없는 테이블과 뷰의 난립, 예측 불가한 시스템 부하, 데이터 신뢰도 저하라는 구조적 문제로 이어졌습니다. 이를 해결하기 위해 데이터 팀이 raw 데이터를 직접 관리·통제하고, pyairbyte·Airflow·dbt를 도입하여 Silver 레이어에서 정제한 뒤 Gold 레이어로 서빙하는 메달리온 아키텍처를 설계·구축했습니다. 나아가 딥러닝 기반 pROAS 파이프라인으로 예측 데이터를 현업에 제공하고, Apache Superset 기반 self-BI 환경을 조성하여 현업이 신뢰할 수 있는 데이터로 직접 의사결정할 수 있는 구조를 만들었습니다.

두 번째 전환점은 AI 에이전트 개발에 참여하며 데이터 품질이 AI 서비스의 근간임을 직접 체감한 것이었습니다. 이 경험이 OpenMetadata 기반 전사 거버넌스 체계 수립을 주도하는 동력이 되었고, 현재는 데이터 리니지·품질 관리·카탈로그 통합 운영과 AI 기반 업무 자동화를 함께 이끌고 있습니다. 기술적 성과를 비즈니스 가치로 연결하고, 신뢰할 수 있는 데이터로 조직의 AI 전환을 실질적으로 뒷받침하는 엔지니어로 성장하고자 합니다.