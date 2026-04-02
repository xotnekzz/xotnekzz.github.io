---
title: 데이터 거버넌스 프로젝트
description: OpenMetadata 도입을 통한 전사 데이터 디스커버리 및 거버넌스 인프라 구축 — Airflow Lineage 커스텀 플러그인 개발
date: 2026-02-01
tags:
  - OpenMetadata
  - Airflow
  - Python
  - Data Governance
  - Lineage
featured: true
---

> **기간:** 2026.2 ~ 현재 진행중
**역할:** Project Lead / Data Engineer
**기술 스택:** OpenMetadata, Apache Airflow, Python (Custom Plugin), Data Governance Framework

## 1. Background & Challenges

- **인력 부족과 레거시 파이프라인의 한계:** 3명의 소규모 데이터 엔지니어 팀으로 수년간 부서별(마케팅, 재무, 게임 개발 등)로 흩어진 방대한 도메인 데이터를 관리해야 했습니다. 특히 과거 퇴사자들이 구축해 둔 파이프라인들은 제대로 인수인계가 이루어지지 않아 구조 파악 및 유지보수에 큰 어려움이 있었습니다.
- **AX 전환과 신뢰도 높은 데이터 환경의 필요성:** 전사적으로 AX(AI Transformation) 전환을 위한 백오피스용 AI 에이전트 개발이 요구되면서, 이러한 신규 시스템을 안전하게 지원할 수 있는 검증된 고품질 데이터 환경 구축이 시급해졌습니다.
- **거버넌스의 부재와 데이터 파편화:** 부서별로 독립적인 데이터 파이프라인과 테이블이 중구난방으로 급증하여 **데이터 파편화(Silo)** 현상이 심화되었습니다. 데이터 계보(Lineage) 추적조차 불가능해 정합성 이슈 발생 시 원인 파악에 막대한 리소스가 소모되었습니다.
- **오픈소스 도입 및 거버넌스 주도:** 적은 인원의 엔지니어는 데이터 파이프라인의 '안정성'과 '신뢰성' 시스템 개발에만 집중하고, 데이터 관리 및 활용의 주체는 각 현업 부서가 주인의식을 가져야 한다고 판단했습니다. 이에 데이터 디스커버리를 돕는 **오픈소스(OpenMetadata) 도입**과 **전사 데이터 거버넌스 문화 정착 프로젝트**를 주도적으로 제안했습니다.
## 2. Why OpenMetadata?

이미 시장에는 **DataHub,** **Amundsen ** 같은 훌륭한 대안이 있었지만, 소규모 팀으로서 지속 가능한 운영과 전사 확산력을 고려해 **OpenMetadata**를 최종 선택했습니다.

1. **낮은 운영 복잡도 (Low Operational Overhead):** DataHub는 Kafka, MySQL, Elasticsearch, GMS 등 수많은 마이크로서비스를 관리해야 하는 부담이 컸지만, OpenMetadata는 비교적 간결한 아키텍처(Docker/K8s 기반)로 엔지니어 1명이 충분히 운영할 수 있는 환경을 제공했습니다.
1. **통합 거버넌스 경험 (Unified Experience):** 단순히 검색(Discovery) 기능만 제공하는 것이 아니라, 리니지, 프로파일링, 데이터 품질 테스트 결과까지 하나의 UI에서 유기적으로 연결되어 있어 '데이터 신뢰도'를 즉각적으로 파악하기에 최적화되어 있습니다.
1. **비개발자 친화적 협업 UI (Social & Collaborative):** 데이터 소유자가 직접 설명(Description)을 달고, 협업 툴처럼 스레드로 질의응답을 하거나 태스크(Task)를 할당하는 등 '사람 중심의 거버넌스'를 실천하기에 매우 직관적인 UI를 가졌습니다.
1. **API-First 기반 확장성:** 모든 객체가 JSON Schema로 표준화되어 있어, 이번 프로젝트에서 구현한 커스텀 Python Decorator와 같은 자체 자동화 도구와의 연동이 매우 용이했습니다.
## 3. Project Goal & Architecture: Data Discovery & Governance



![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/c11ca625-89d8-4f7e-addd-2cc1920855a3/openmetadata.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466XYMBLUF4%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153138Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJGMEQCIBHUAVrUVtiN6nSwBh51UuuE0P8Y2cHJYSejbd2OKAVBAiA9qHf1ELpiHtZ%2FbtrQlAYHWW37VP3Z%2FL9TKIKFFVlrJyqIBAiL%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDYzNzQyMzE4MzgwNSIMZkaWDJfXQ6q5oup%2BKtwDup%2FsFdaVp%2BdUQ%2Bo%2FkUD%2BxaqfBoMyb%2FTImh3kIj7gIR22EyeLo7s6CRiJbQayyCNpiAaMOdv7SzX1k1U6YoOgWg3CyTIJoamFPwNK6wTPQiYRo%2BmoVJnGtOsQXEItgp3evn6XIE02g%2BYp0%2FalsGRx9d8p7Clwu92SMvG1jVPlxC4S%2BJlWDKpklsQep1qvobu%2FUZcWSoTERSHG11BUGriyv%2FD%2B8OHNoujt4E%2BwbmU9o%2FGEMbANN02i9ksJK7eKdDTF3zWb1I4Rsj1%2FRHJtlaSD1Zv3M%2FOc7feDxi85OYLCn%2BVB44J85rHdVD8ddquSWD%2FF5yQCRbP%2BnlQLgsqomNJ8TQNcv3dDJNlbGhb%2Fyi2fjyylFzgeSir19mmDoRVq2Ha6crnl5iFq5ata79%2BmuKal8pQvAnzAdX3vWumeZOcad5vZBbnI62w9Yge8EJLkvgO9b%2FqzV1%2Fl6lPh7J8ZBN4DuZp0ifPfaw814zkiezLgF953s%2BOLy0%2BSpZo9uvvatN8MFswvmYsYv8EgB1m3gyPN3aCIHnYckB88vC3ku1z3YxOSEv%2Fm3dlUh1xWLZDgagszKSZId07yEM7YilMCdYjrK6ug%2FqU5OZ3TwT%2Fd45sGifQts9sv3nBVivFrICAwrb7PzQY6pgEuScORQK4%2FBmuD5RruZLBViRU%2FA%2FkRudZtfhuderNyqDUYwkgW5P3l8V2aldBvfpmsps5UOyWZLJALNg8XQrt%2FCo%2FS%2FMp1LR%2BccoM%2FybrLhS23sGJGioL6F48cU%2Btw9RQ1wRf2ykRD3tU8T%2FMgKeejt04lSkfi1C%2BXipQtJgX0nvf087NGjeQOeEyWS9%2BLKibdh%2FDTfJRrJmMp2X358asap4SZN4Xw&X-Amz-Signature=92b8d18bdc09905ba9fd7a1ae86b7461b033b986cac42200fe8c87213c745c34&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



이 프로젝트의 궁극적인 목표는 OpenMetadata를 중심으로 한 **전사 데이터 디스커버리 및 거버넌스 인프라를 구축**하는 것입니다. 

사내에서 사용하는 각종 데이터베이스와 파이프라인(Airflow)을 연동하여 메타데이터와 계보(Lineage), 스키마 설명(Description)을 중앙 집중화하고, 이에 더해 거버넌스 체계(Human Governance) 도입하여 각 부서가 데이터의 소유권(Ownership)을 명확히 하고 생명주기를 관리하며, 품질 지표(Quality Metrics)를 지속적으로 검사할 수 있는 신뢰도 높은 데이터 환경을 조성하는 것입니다.

## 4. Solution & Technical Insights

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/a7be87ec-1b9a-43ba-9d54-2ce3d9133812/om_lineage.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466XYMBLUF4%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153138Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJGMEQCIBHUAVrUVtiN6nSwBh51UuuE0P8Y2cHJYSejbd2OKAVBAiA9qHf1ELpiHtZ%2FbtrQlAYHWW37VP3Z%2FL9TKIKFFVlrJyqIBAiL%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDYzNzQyMzE4MzgwNSIMZkaWDJfXQ6q5oup%2BKtwDup%2FsFdaVp%2BdUQ%2Bo%2FkUD%2BxaqfBoMyb%2FTImh3kIj7gIR22EyeLo7s6CRiJbQayyCNpiAaMOdv7SzX1k1U6YoOgWg3CyTIJoamFPwNK6wTPQiYRo%2BmoVJnGtOsQXEItgp3evn6XIE02g%2BYp0%2FalsGRx9d8p7Clwu92SMvG1jVPlxC4S%2BJlWDKpklsQep1qvobu%2FUZcWSoTERSHG11BUGriyv%2FD%2B8OHNoujt4E%2BwbmU9o%2FGEMbANN02i9ksJK7eKdDTF3zWb1I4Rsj1%2FRHJtlaSD1Zv3M%2FOc7feDxi85OYLCn%2BVB44J85rHdVD8ddquSWD%2FF5yQCRbP%2BnlQLgsqomNJ8TQNcv3dDJNlbGhb%2Fyi2fjyylFzgeSir19mmDoRVq2Ha6crnl5iFq5ata79%2BmuKal8pQvAnzAdX3vWumeZOcad5vZBbnI62w9Yge8EJLkvgO9b%2FqzV1%2Fl6lPh7J8ZBN4DuZp0ifPfaw814zkiezLgF953s%2BOLy0%2BSpZo9uvvatN8MFswvmYsYv8EgB1m3gyPN3aCIHnYckB88vC3ku1z3YxOSEv%2Fm3dlUh1xWLZDgagszKSZId07yEM7YilMCdYjrK6ug%2FqU5OZ3TwT%2Fd45sGifQts9sv3nBVivFrICAwrb7PzQY6pgEuScORQK4%2FBmuD5RruZLBViRU%2FA%2FkRudZtfhuderNyqDUYwkgW5P3l8V2aldBvfpmsps5UOyWZLJALNg8XQrt%2FCo%2FS%2FMp1LR%2BccoM%2FybrLhS23sGJGioL6F48cU%2Btw9RQ1wRf2ykRD3tU8T%2FMgKeejt04lSkfi1C%2BXipQtJgX0nvf087NGjeQOeEyWS9%2BLKibdh%2FDTfJRrJmMp2X358asap4SZN4Xw&X-Amz-Signature=b515d9620ff8af47195926224b851a74624d802c46c73f47c54f52deceefa8e1&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

1. **Airflow 계보(Lineage) 커스텀 플러그인(Decorator) 개발**
- **[Issue]** 최신 OpenMetadata 모듈과 사내 운영 중인 Airflow(v2.9.3) 간의 리니지 연동 라이브러리 버전이 충돌하여 사용이 불가능한 상태였습니다. 전사 Airflow 버전을 업그레이드하기에는 운영 리스크와 소요 시간이 너무 컸습니다.
- **[Solution]** 버전의 의존성을 해결하기 보단 OpenMetadata의 Lineage API를 직접 호출하는 **Python Decorator 기반 커스텀 플러그인**을 자체 개발했습니다. 이를 통해 Airflow 버전 변경 없이도 전사 DAG에 즉시 적용 가능한 환경을 구축했습니다.
## 5. Impact & Result

- **데이터 가시성 확보:** 전사 테이블에 대한 통합 카탈로그 및 End-to-End 리니지를 시각화하여 데이터 탐색 시간을 획기적으로 단축했습니다.
- **장애 대응 속도 향상:** 데이터 정합성 이슈 발생 시 상위 파이프라인으로의 역추적(Back-trace)이 가능해져 원인 분석 리소스를 최소화했습니다.
## 6. Next Steps

- **표준 용어 사전(Glossary) 구축 및 공인 데이터 관리**
- 전사 공통 **Glossary**를 정의하고 검증된 테이블에 **'Official' 태그**를 부여하여, 산재한 유사 지표의 로직 통합 및 데이터 신뢰도(SSOT) 확보
- **AI 기반 메타데이터 및 태깅 자동화**
- **LLM을 활용하여** 방대한 레거시 테이블의 Description을 생성하고, 데이터 성격에 맞는 **태그(Tagging)를 자동 추천**하여 관리 공수 최소화
- **데이터 소유권(Ownership) 및 자율 거버넌스 안착**
- 도메인별 데이터 소유자를 명확히 지정하여, 현업 주체들이 직접 메타데이터를 관리하고 책임지는 **선순환 거버넌스 체계** 구축
- **데이터 민주화 및 셀프서비스 환경 실현**
- 엔지니어 개입 없이 현업이 용어 사전과 태그를 통해 스스로 데이터를 탐색·활용할 수 있는 **데이터 디스커버리 환경** 완성


