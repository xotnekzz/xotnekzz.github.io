---
title: ELT 파이프라인 설계 (PyAirbyte)
description: PyAirbyte로 EL 자동화를 분리하고 StarRocks Materialized View로 Transform 단계 최적화
date: 2026-02-01
tags:
  - PyAirbyte
  - Airflow
  - StarRocks
  - Python
  - ELT
featured: false
---

> **기간:** 2026.2 ~ 2026.3
**역할:** Senior Data Engineer (아키텍처 설계 리딩)
**기술 스택:** PyAirbyte, Apache Airflow, StarRocks Materialized View (MV), Python, SQL

## 1. Background & Challenges

기존의 Python API 연동 방식의 ETL은 Transform 코드가 파이썬 API 내부에 숨어있는 구조라 디버깅이 어렵고 유지보수 난이도가 높으며 다양한 데이터 분석 확장이 어려운 구조였습니다. Airbyte와 같이 이미 구현되어 있는 오픈소스를 활용하여 Raw 데이터를 추출하고 EL(Extraction & Load) 과정을 자동화하여, 데이터 엔지니어가 데이터 가공과 비즈니스 로직에 더 집중할 수 있는 환경이 필요했습니다.

## 2. Architecture: As-Is vs To-Be

기존의 "가공 후 적재(ETL)" 방식을 지양하고, "적재 후 가공(ELT)" 방식을 통해 데이터 유연성을 확보하는 아키텍처로 전환했습니다.

## 3. Solution & Technical Insights

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/8994c290-6e7f-4854-be8a-3bfb3b186a79/pyairbyte.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466TUHTQFGM%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153141Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJIMEYCIQCJt9XdZqeTOwKMGHyi1%2FkHTOtbIr%2Bk03uuqck99N0nbwIhAN2W6pAeTByPC1%2FpcCG8bNTvsDsn%2FqyU%2BFtSclAc0ztzKogECIv%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQABoMNjM3NDIzMTgzODA1IgxjHhp5KeFTbJG20XQq3APujIainksEbWGXNHXcvyH56zXO6QBtr%2FrKIKLVlfQ%2BmeFYXhuEI7%2Fz7SzCoBFHEA5uIwDsv2d%2FoKZJ%2FdjoPAl9UOTqdkjrr8jVQnDAXkAp61qc5Vds4Ck5k7264dsj0QOGySKANrn23o6aCPuDSeLZ4pH8QTUTqc2PCufDjfr0hDDJZ3LE6uNeXsu8MjAybGSCVQ72zGL%2B9wZzHN7z315dKDJKLbIkwwXXd5iRMZXHdWDhw1AzwDyDRk1cCUBfaV4bYbqxEy7mZS5Gl8RRyG7ZoZS%2Bvwm7sOGIq9mKANH8fho6OQ%2FMR3%2BtVHFuqMVyAGhR3sdG0vu21H7W1sRj5f3dQ46VnZGuqDSOnRxFYJBL02tuAA65RcJrO2MobrvWs7RcRRFpQB7f10TRtsV3Bd0baV1CZz7kd9pBVYeTwukPYQCAlLquJb0uO%2BmoCziFR9kwx4kdU%2BOg8UMgitZ95yq4mD0KnVjiF7u7vWstiAEKQlw11RmhwXnnBd25Z9wcU4t2%2BoEG8YONSKU7UTUxn%2BnUwnTzVApq5A70wY%2FnJ0Nvlhby0qqoPS9qG%2FD4yeb5%2FneXfgs7ETEA2%2BbA9mrlfeTNINMMDJPJ0o9%2FFTZJaw%2B6FzyCPbNlfwKYF3sApjCvvc%2FNBjqkASlR3IZ4%2FgTu4dnIJNMEc7BQa9EjCT6yBqXpxvtjPyTX67eMUA1oRCHCEu%2B8cSvlnKFuduNH5vC5I15Q%2F9lAQBVGr9Qg1NnivkvwbIw8ZohCeP8Rh07mYmq5ldJ4tM%2B1CIlJUKbpoSJtEIS5J5zCPN9u0tkUpMHWlHOkXhOlmXcEHVBnLfKqZjgKNsL3bZIzaqok9VVzb2uUqbmUk%2FTS1fH34%2FI8&X-Amz-Signature=6c859c120d91e16030867cec4f0851ebc701d4d5d8280eb28893e268c18e69b6&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

1. **PyAirbyte + Airflow 결합을 통한 Ingestion 자동화**
- **[Issue]** API 연동 시마다 개별 커넥터를 작성하고 유지보수해야 하는 부담이 컸습니다.
- **[Solution]** **PyAirbyte**를 Airflow 환경에 도입하여 수천 개의 오픈소스 커넥터를 즉시 활용할 수 있는 기반을 마련했습니다. 이로 인해 신규 데이터 소스 추가 시 코딩 리소스를 80% 이상 절감하고 수집 프로세스의 표준화를 달성했습니다.
1. **아키텍처 설계 주도 및 팀 리딩 (Technical Mentoring)**
- **Dynamic DAG 기반 커넥터 통합 관리:** 과거 40개 이상의 ETL을 단일 코드로 관리했던 메타데이터 기반 Dynamic DAG 노하우를 전수했습니다. 이를 통해 주니어 엔지니어들이 수십 개의 PyAirbyte 커넥터를 각각의 코드가 아닌, **단일 Dynamic DAG 코드**로 효율적으로 관리할 수 있도록 가이드했습니다.
- **AI Agent Skills를 통한 커스텀 커넥터 개발 가속화:** 특정 API의 경우 직접 커스텀 커넥터를 작성해야 하는 리소스 부담을 인지하고, LLM 기반의 **Agent Skills**를 활용하여 누구나 쉽고 빠르게 커넥터 코드를 생성/패키징할 수 있는 환경을 구축하도록 피드백하고 리딩했습니다. 이를 통해 개발 진입 장벽을 낮추고 구현 속도를 혁신적으로 개선했습니다.
## 4. Impact & Result

- **유지보수 효율 극대화:** 신규 API 연동 리소스를 획기적으로 단축하여 데이터 엔지니어의 핵심 비즈니스 가공 집중도를 높였습니다.
- **현대적 ELT 패러다임 정착:** 인프라 유연성과 확장성을 확보하여 향후 데이터 규모 성장에 대비한 견고한 토대를 마련했습니다.
- **팀 기술 역량 상향 평준화:** 시니어의 설계 노하우와 AI 기술(Agent Skills)을 팀 워크플로우에 녹여내어, 주니어들이 복잡한 아키텍처를 안정적으로 운영하고 확장할 수 있는 기반을 마련했습니다.


