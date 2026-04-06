---
personal:
  name: 김태수
  title: Senior Data Engineer
  email: xotnekzz@gmail.com
  github: github.com/xotnekzz
  githubUrl: https://github.com/xotnekzz

experiences:
  - company: 비트망고
    companyEn: BitMango
    period: "2019.08 ~ 현재 (7년 차)"
    role: Senior Data Engineer
    projects:
      - title: "[Modernization] 전사 대규모 로그 플랫폼 & OLAP 현대화"
        period: "2025 ~ 현재"
        problem: "레거시 40대 노드(HDFS/Impala)의 과도한 운영 리소스 및 노후 인프라 성능 한계"
        bullets:
          - "역인덱스 기술로 단순 집계 최대 1,715배(50ms 이내) 단축. 총 12대 노드로 17대 연산 노드 성능 상회"
          - "Fluentd → SeaweedFS → Apache Doris Broker Load 병렬 적재 파이프라인 최적화"
          - "수동 파티셔닝/통계수집 제거로 운영 리소스 제로화"
        accent: true
      - title: "[AI Automation] Ad-Tech AI Agent & 전사 AI 플랫폼"
        period: "2024 ~ 현재"
        problem: "1,500개 캠페인의 수동 운영 한계 및 AI 도입에 대한 전사적 기술 장벽"
        bullets:
          - "Gemini CLI Agent: 프롬프트 기반 룰 관리 + Human-in-the-loop 검증 구조로 할루시네이션 리스크 제거"
          - "마케터 생산성 1,000배 혁신: 수 명의 운영 인력 → 마케터 1명 전담 가능"
          - "WorkwithAI 플랫폼: LibreChat/MCP/Milvus 기반 RAG 인프라 구축"
        accent: true
      - title: "[Governance] 전사 데이터 관리 체계 및 자동화"
        period: "2025 ~ 현재"
        problem: "데이터 사일로 현상 및 Airflow 버전 제약으로 인한 리니지 수집 자동화 불가"
        bullets:
          - "OpenMetadata 전사 도입 리드, Custom API 기반 Decorator 자체 개발"
          - "Metadata-driven ETL: DAG 설정을 DB화하여 수십 개의 파이프라인을 단일 코드베이스로 관리"
        accent: true
      - title: "[Architecture] 마케팅 ROI 최적화 & 이벤트 드리븐 시스템"
        period: "2022 ~ 2025"
        bullets:
          - "pROAS 파이프라인: 딥러닝 기반 조기 성과 예측 시스템, 마케팅 최적화 주기 단축(Day 3~7)"
          - "KRaft Kafka 도입: 비동기 메시징 아키텍처 설계 및 광고 API 오케스트레이션 고도화"
        accent: true
      - title: "[Other] 백엔드 & BI"
        period: "2019 ~ 2022"
        bullets:
          - "게임 서버 백엔드(NestJS) 고도화 지원"
          - "Apache Superset 기반 전사 BI 체계 구축"
        accent: false
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
    skills: [Python, SQL, Java, TypeScript, Bash]
  - category: Data Infra
    skills: [Apache Doris, StarRocks, SeaweedFS, Apache Airflow, PyAirbyte, Kafka, HDFS, Impala]
  - category: AI
    skills: ["Gemini API", MCP, LangChain, Milvus, LibreChat]
  - category: "BI & Governance"
    skills: [OpenMetadata, "Apache Superset", "Google Sheets (Apps Script)"]
  - category: "Backend & DevOps"
    skills: [NestJS, Django, MariaDB, MongoDB, Docker, "Git/GitLab CI-CD"]

education:
  - school: 성공회대학교
    major: 컴퓨터공학과
    period: "2012.02 ~ 2017.02 (졸업)"
---

30억 건 규모의 마케팅 데이터 마트와 수백억 건의 게임 로그 인프라를 StarRocks 및 Doris 기반으로 현대화하여, 쿼리 응답 속도를 최대 1,715배 향상시키며 엔지니어링 운영 리소스 최적화 및 TCO 대폭 절감을 달성했습니다. 특히 Gemini 기반 AI 에이전트를 개발하며 데이터 품질이 AI 비즈니스의 핵심임을 체감한 후, 현재는 데이터 사일로 제거와 신뢰도 확보를 위한 전사적 데이터 거버넌스 체계 구축을 주도하고 있습니다. 기술적 탁월함을 비즈니스 수익으로 연결하며, 견고한 데이터 거버넌스 기반의 'AI-Native 전문가'로 성장하고 있습니다.
