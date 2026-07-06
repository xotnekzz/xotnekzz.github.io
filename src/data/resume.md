---
personal:
  name: 김태수
  title: Data Part Lead / Senior Data Engineer
  email: xotnekzz@gmail.com
  github: github.com/xotnekzz
  githubUrl: https://github.com/xotnekzz
  portfolio: Portfolio
  portfolioUrl: https://xotnekzz.github.io/portfolio/

experiences:
  - company: 비트망고
    companyEn: BitMango
    period: "2019.08 ~ 현재 (약 7년)"
    role: Data Part Lead / Senior Data Engineer
    projects:
      - title: "데이터 레이크하우스 전환"
        problem: "온프레미스 HDFS 레거시 데이터 웨어하우스의 운영 리소스 부담 및 실시간 수집 파이프라인의 안정성 한계"
        bullets:
          - "온프레미스 HDFS 레거시 데이터 웨어하우스를 SeaweedFS 기반 데이터레이크하우스로 전환 구축"
          - "게임 이벤트 로그 파이프라인을 fluentd 실시간 수집에서 시간 단위 배치로 재설계 주도 — 사내 네트워크 이슈 하에서 온프레미스 서비스 안정성 확보"
          - "아키텍처 재설계: 로그서버 시간 단위 로테이트 압축 → SeaweedFS rsync → 매시간 Airflow + DuckDB ETL로 Parquet 변환·저장 → Airflow Asset 이벤트 발행으로 Doris ETL 파이프라인 트리거"
          - "파이썬 코드 레벨 로그 ETL로 손쉬운 코드 변경 및 백필(backfill) 멱등성(idempotency) 보장 — 파이프라인 안정성 강화"
          - "단순 집계 쿼리 응답 최대 1,715배 단축 (50ms 이내), 복잡한 Join 집계 쿼리 최대 5배 단축 (250s → 40s)"
        tags: ["Apache Doris", "SeaweedFS", "DuckDB", "Apache Airflow", "Parquet", "HDFS / Impala", "온프레미스"]
        accent: true

      - title: "데이터 플랫폼 모니터링"
        problem: "데이터 플랫폼 확장에 따른 장애 가시성 부재 및 미사용 자산 방치"
        bullets:
          - "Grafana·Prometheus 기반 메트릭 수집 및 모니터링 대시보드 구축"
          - "AuditLog 기반 쿼리 모니터링 및 미사용 자산 추적 체계 마련"
          - "장애 알림 체계 구축으로 데이터 플랫폼 운영 안정성 확보"
        tags: ["Grafana", "Prometheus", "AuditLog", "Observability"]
        accent: true

      - title: "분석 엔지니어링 & 의사결정 지원"
        problem: "규제 없는 raw 데이터 무분별 접근으로 인한 데이터 신뢰도 저하 및 예측 데이터 기반 의사결정 체계 부재"
        bullets:
          - "메달리온 아키텍처를 도입하여 게임·마케팅 도메인의 데이터 분석 레이어 전환을 리딩 — Silver 레이어에서 raw 데이터를 정제·통제하고 Gold 레이어로 서빙하는 구조 설계 (Airflow + dbt)"
          - "Google Ads·Meta·IronSource·Appsflyer 등 주요 광고 채널 데이터 통합 — pyairbyte·Airflow·dbt 기반 마케팅 도메인 마트(pLTV, ROAS) 및 게임 로그 분석 마트 구축"
          - "pROAS 파이프라인: 딥러닝 기반 캠페인 수익 조기 예측 — 90% 이상 정확도로 마케팅 최적화 의사결정 주기 단축 (Day 3~7)"
          - "ML 모델 데이터(pRevenue)와 통합 데이터소스를 결합하여 Superset·Metabase BI 대시보드 서빙 및 업무 자동화 지원"
          - "Metadata-driven ETL: DAG 설정을 DB화하여 수십 개 파이프라인을 단일 코드베이스로 관리"
        tags: ["Apache Airflow", "dbt", "pyairbyte", "Medallion", "Silver / Gold 레이어", "pROAS · pLTV", "Apache Superset", "Metabase"]
        accent: true

      - title: "데이터 거버넌스 & AI Ready Data"
        problem: "AI 활용의 근간이 되는 신뢰 가능한 데이터 자산·계보·품질 체계 부재 및 데이터 사일로 현상"
        bullets:
          - "OpenMetadata 전사 도입 리드 — 데이터 자산 카탈로그 및 파이프라인 계보(lineage) 연동"
          - "사내 비즈니스 흐름을 Glossary로 정의하고 데이터 자산과 연동하여 데이터 온톨로지(ontology) 구축"
          - "Data Quality as Code 도입 — 데이터 입력 전 오염 방지로 전사 데이터 신뢰도 확보"
          - "AI Ready Data를 기반으로 데이터 민주화 제공 — 전담 분석가 없이도 업무 담당자가 직접 데이터 분석·리포팅 가능한 환경 마련"
        tags: ["OpenMetadata", "Data Lineage", "Data Catalog", "Glossary", "Data Quality", "AI Ready Data"]
        accent: true

      - title: "AI Engineering (AX)"
        problem: "반복적이고 지루한 업무(grunt work)에 소모되는 조직 리소스 — AI가 이를 대체하도록 전사적 AI 전환(AX)을 실행"
        bullets:
          - "Apple Silicon MLX 기반 로컬 LLM 서버 구축 — GitLab hook 연동 코드리뷰·릴리즈 문서 자동 작성 에이전트 운영"
          - "인프라 장애 처방전 에이전트(Hermes) 개발 — Slack 장애 알림을 읽고 매시간 대응 처방전 발행"
          - "Data Analyst 에이전트 개발 — OpenMetadata(OM API·MCP) 기반 자연어 요청을 fact 기반으로 분석·리포팅"
        tags: ["LangChain", "OpenAI API", "Claude API", "Gemini API", "Local LLM (MLX)", "Milvus", "LibreChat", "MCP", "RAG", "Streamlit"]
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
    skills: [Apache Doris, SeaweedFS, DuckDB, Apache Airflow, PyAirbyte, dbt, Kafka, Parquet, HDFS, Impala]
  - category: AI
    skills: ["LLM API (OpenAI·Claude·Gemini)", "Local LLM (MLX)", LangChain, MCP, "Agent Skills", LibreChat, Streamlit]
  - category: "BI & Governance"
    skills: ["Apache Superset", Metabase, Redash, OpenMetadata, Glossary, "Data Quality"]
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

저는 온프레미스 환경에서 데이터 인프라 현대화부터 분석 파이프라인 설계, 거버넌스 체계 수립, AI 기반 자동화까지 데이터의 전 생애주기를 다루어온 풀스택 데이터 엔지니어입니다. BI팀에서 마케팅(UA) 도메인의 데이터 통합(ETL), ML 모델 데이터(pRevenue) 기반 BI 서빙, 딥러닝 기반 pROAS 예측 파이프라인(90%+ 정확도) 구축으로 데이터 엔지니어링의 기초를 다졌고, 2026년부터 데이터파트 리드(Data Part Lead)를 맡으면서 10년 넘은 HDFS/Impala 환경을 SeaweedFS 데이터레이크하우스와 Apache Doris로 현대화(단순 집계 쿼리 최대 1,715배 단축)하며 메달리온 아키텍처 기반 도메인 마트를 구축했습니다. 이 과정에서 데이터 품질이 AI 서비스의 근간임을 체감하여 OpenMetadata 기반 전사 거버넌스를 주도했고, 여기에 AI Ready Data 환경을 더해 사실(fact)에 근거한 할루시네이션 없는 데이터 분석과 의사결정을 이끄는 것을 목표로 하고 있습니다. 더불어 반복적이고 지루한 업무(grunt work)를 AI로 대체하는 AX를 진행하여 — 로컬 LLM 서버, 장애 처방전 에이전트(Hermes), Data Analyst 에이전트 — 조직의 업무 생산성을 높이고 있습니다.
