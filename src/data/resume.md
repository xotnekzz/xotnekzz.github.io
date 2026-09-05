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
    role: "Senior Data Engineer → Data Part Lead (2026~)"
    projects:
      - title: "데이터 플랫폼 구축 및 운영"
        problem: "수년간 운영해온 HDFS/Impala 환경의 한계에서 출발 — 클라우드 관리형 서비스 없이 온프레미스에서 성능·안정성·확장성을 갖춘 데이터 플랫폼을 직접 구축·운영"
        bullets:
          - "단순 집계 쿼리 85s → 50ms, 복잡한 Join 집계 쿼리 250s → 40s"
          - "온프레미스 HDFS 레거시 데이터 웨어하우스를 SeaweedFS + Apache Doris 기반 데이터레이크하우스로 전환 — 스토리지·컴퓨팅 분리"
          - "게임 이벤트 로그 수집을 fluentd 실시간에서 시간 단위 배치로 재설계 — DuckDB로 정제해 Parquet 변환·적재, 네트워크 불안정 환경에서 수집 안정성 확보"
          - "DAG Factory 패턴: 유형이 같은 파이프라인을 단일 코드베이스로 묶고, 설정을 DB화해 UI에서 등록·운영 — 신규 파이프라인 추가 시 코드 배포 없이 대응"
          - "Airflow 3 Asset Partition 기반 업스트림 이벤트 트리거로 파이프라인 간 의존성 관리, 백필(backfill) 멱등성 보장"
          - "Grafana·Prometheus 기반 플랫폼 관측 체계 및 장애 알림 구축, AuditLog 쿼리 모니터링으로 미사용 자산 추적·정리"
        tags: ["Apache Doris", "SeaweedFS", "DuckDB", "Apache Airflow", "Parquet", "HDFS / Impala", "Grafana / Prometheus", "온프레미스"]
        accent: true

      - title: "분석 엔지니어링"
        problem: "외부 데이터소스 ETL 직접 구현에 따른 유지보수 부담, 작업자마다 개별 생성된 분석 데이터의 파편화로 담당자 부재 시 대응 불가"
        bullets:
          - "메달리온 아키텍처 도입 리딩 — 파편화된 게임·마케팅 도메인 데이터를 레이어별로 통합·표준화 (Airflow + dbt)"
          - "주요 광고 채널(Google Ads·Meta·IronSource·Appsflyer) 수집을 자체 구현에서 PyAirbyte 커넥터로 전환 — 채널 추가·API 변경 대응 부담 절감"
          - "pRevenue: 딥러닝 캠페인 매출 조기 예측 모델의 피처·서빙 파이프라인 설계 — 마케팅 의사결정 주기 Day 7 → Day 3 단축"
          - "Superset·Metabase 구축·운영 — 현업이 직접 지표를 조회하는 셀프서비스 분석 환경 제공"
        tags: ["Apache Airflow", "dbt", "PyAirbyte", "Medallion", "Silver / Gold 레이어", "pRevenue · pLTV", "Apache Superset", "Metabase"]
        accent: true

      - title: "데이터 거버넌스"
        problem: "AI 활용의 근간이 되는 데이터 자산·계보·품질 체계 부재 및 도메인 간 데이터 사일로"
        bullets:
          - "OpenMetadata 도입 리드 — 데이터 자산 카탈로그 및 파이프라인 계보(lineage) 연동"
          - "사내 비즈니스 흐름을 Glossary로 정의하고 데이터 자산과 연결해 데이터 온톨로지(ontology) 구축"
          - "Data Quality as Code 도입 — 적재 이전 단계와 입력 이후 단계 모두 퀄리티 게이트를 통한 신뢰도 확보"
        tags: ["OpenMetadata", "Data Lineage", "Data Catalog", "Glossary", "Data Quality"]
        accent: true

      - title: "AI Engineering (LLM)"
        problem: "반복적인 단순 업무(grunt work)에 소모되는 조직 리소스 — AI 에이전트로 대체하는 전사 AI 전환 실행"
        bullets:
          - "Apple Silicon MLX 기반 로컬 LLM 서버 구축 — GitLab hook 연동 코드리뷰·릴리즈 문서 자동 작성 에이전트 운영"
          - "인프라 장애 처방전 에이전트 개발 — Slack 장애 알림을 해석해 매시간 대응 처방전 발행"
          - "Data Analyst 에이전트 개발 — OpenMetadata(OM API·MCP) 기반으로 자연어 요청만으로 분석·리포팅"
        tags: ["LLM API (OpenAI·Claude·Gemini)", "Local LLM (MLX)", "MCP", "RAG", "Milvus", "Openrouter", "Hermes Agent"]
        accent: true

  - company: 우암코퍼레이션
    companyEn: Wooam Corp
    period: "2018 ~ 2019"
    role: Backend Developer
    projects:
      - title: "전력 데이터 수집 시스템"
        bullets:
          - "10만 세대 규모 전력 데이터 수집 API(Java) 및 FastDR 시스템 구축"
        accent: false

techStack:
  - category: Data Platform
    skills: [Apache Doris,  DuckDB, SeaweedFS, MariaDB, Postgresql, Apache Airflow]
  - category: Analytics Engineering
    skills: [dbt, airbyte]
  - category: "BI & Data Governance"
    skills: [Metabase, Apache Superset, OpenMetadata]
  - category: AI & Agent Engineering
    skills: ["Local LLM (MLX)", MCP, "Agent Skills", "Hermes Agent"]
  - category: Backend
    skills: [FastAPI, Django]
  - category: Languages
    skills: [Python, SQL, Bash]
  - category: DevOps & Observability
    skills: [Docker, Docker Compose, Ansible, Grafana, Prometheus, CI/CD]

education:
  - school: 성공회대학교
    major: 컴퓨터공학과
    period: "2012.02 ~ 2017.02 (졸업)"
---

비트망고 데이터 파트 리드로서 온프레미스 데이터레이크하우스 전환을 주도하고, 데이터 거버넌스 기반의 AI 에이전트 분석 환경 구축을 통해 조직의 데이터 민주화 실현을 향해 나아가고 있습니다

3명의 팀원과 함께 데이터 플랫폼 전반(인프라·분석 파이프라인·거버넌스)의 구조 개선과 실행을 담당하고 있습니다. 10년 이상 된 HDFS/Impala 레거시 환경을 SeaweedFS와 Apache Doris 기반으로 전환해 리포트 대기시간 5분 → 30초 이내로 성능을 개선하였습니다. 또한 메달리온 아키텍처를 도입해 전사 도메인 마트를 표준화했습니다.

현재는 OpenMetadata 기반으로 데이터 자산의 계보·품질 검증(DQ) 체계를 구축하여 추측이 아닌 사실에 근거한 데이터 환경을 조성하고 있습니다. 나아가 이 거버넌스 위에서 동작하는 데이터 분석 에이전트 및 인프라 장애 처방·코드리뷰 자동화 에이전트를 개발하며 전사 업무 효율을 극대화하는 AI 전환을 이끌고 있습니다.
