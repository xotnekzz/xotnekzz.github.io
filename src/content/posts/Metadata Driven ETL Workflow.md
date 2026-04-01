# Metadata Driven ETL Workflow

> **기간:** 2023
**참여인원**: 1명
**역할:** Senior Data Engineer (아키텍처 설계 및 구현 주도)
**기술 스택:** Apache Airflow, Python, Metadata-driven Architecture, SQL

## 1. Background & Challenges

데이터 파이프라인 개수가 기하급수적으로 늘어남에 따라, 유사한 ETL 패턴이 반복되는 수십 개의 DAG 코드가 중복적으로 생성되었습니다. 단순한 스케줄 변경, 담당자 수정, 알림 설정 등 사소한 튜닝 작업조차 매번 코드를 수정하고 배포해야 하는 물리적인 운영 부담과 휴먼 에러의 리스크가 발생했습니다.

## 2. Architecture: Single Codebase (Metadata-driven)

복잡하고 중복적인 DAG 생성 방식을 탈피하여, 설정 데이터를 기반으로 동적으로 파이프라인을 생성하는 아키텍처를 구현했습니다.

![image|48](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/75296cf8-81d0-4d26-a0ad-256bc71b5671/airflow.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466QZW2MYVE%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153146Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQD0KerAFx%2B1CUZmyolHnf4DBbaua8ETs5Y%2BQhB2M3eSBwIgT%2FX0ZnzyooETWdeybbFyiPl9wsfSwlRbnQis0H71UDMqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDB8Upk6SnuZSFp2rZSrcA0g27hYa8GF%2B%2FlG1x3GLw%2FgBQ2GZ9jcn%2BiK7R%2FDSpHn0RCdpEUyEWbyexwj6KzKND6jf9O4MxUCm1EIPhD0HORnE%2BPtIqO1Vg1%2F2P9%2B5rT9yaKB3fUVPrd5gaIvRbCzHDfMzhrKSw57bohPU%2FWiOF4H576p2n7kPQfl38bzUZKd9N92KSGD1BH81NLMNyV95AVHgf299ROiTAZPLUnJnOZuWdS5I4V9pR7IzOfQoTk07SnCZuBOKSgzKv%2BYmDDSc2T3HAuJKt6fu0Yka5t6PuBLC8SJaFl%2F%2FACj2fxmKIF0p1YsQSK%2F6MQ%2BhAv8DyE4lwf5JxEPVkCKrG9JHyB2nMh84v2gePiwSvjRRg9T6nDauEtN5XrSV3onTORUvGUJndQWi7wb9V0V%2BTZntI9UwA6z30Kf5R7WyCjyVarVuK5RjSE63kGUd1QpTB1JYeGLgDo3ZJ%2FEgj4%2FEZ2WlZ%2B%2BXnNnH%2FeGUPxW%2BqusL9H%2FuQonLAbLELD9bsx8dUA6Tm88ck0Rk6KRsyLSbwLMN1rv2gDeQiZY%2Ff3BBU5C41dD1bZIKqf4oEwuvSGLloKZbPhaCMcyRsHqkp0ySvlTVERGGG7n2HiFce5wk2XFe3DOWwSpiMab3Y2VUqG3ybfk0MKm9z80GOqUB4EmXDda0udqb5v%2BqXfDVYFOZOlrwKXMGbUQeo6atzQNW29jeNJdeWUzFibditqEndyMwzJK13o0uO7%2B2w3E7ogNMWCW5Q%2BnmB7lVRWVom89tRT5n%2FcdRonYWI4vUP41e5if%2BcqOl0LALB6SECPOTT1wPrkXTOEsmtu8UfgSIwpXbqubesrZPrVN16%2FhzrzjGcr8W%2B6SdA9EhMvP8Q2uKzJI100K1&X-Amz-Signature=d1db0421c84843a6b3e335a607f05a7b85a0ec642f99ce2af3e1a2a357e9a211&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

## 3. Solution & Technical Insights

1. **설정 기반 파이프라인 설계**
- **[Issue]** 유사한 ETL 패턴의 반복적인 코드 추가로 인한 유지보수 복잡성 증대.
- **[Solution]** 파이프라인의 모든 설정 요소(SQL 쿼리, 스케줄 주기, 담당자 정보, 알림 수신처 등)를 메타데이터화하여 관리하는 구조를 설계했습니다. 이를 통해 **단일 코드 베이스**만으로 수십 개의 파이프라인을 동적으로 생성하고 관리할 수 있게 되었습니다.
1. **코드 수정 없는 파이프라인 튜닝 환경 구축**
- **[Issue]** 스케줄이나 단순 설정 변경 시에도 Git Merge Request 및 배포 절차를 거쳐야 하는 번거로움이 있었습니다.
- **[Solution]** 메타데이터 변경만으로 파이프라인의 동작을 즉각 튜닝할 수 있는 환경을 구축했습니다. 이를 통해 운영 생산성을 획기적으로 개선하고, 엔지니어가 불필요한 배포 작업 대신 핵심 로직 개선에 집중할 수 있도록 했습니다.
1. **휴먼 에러 차단 및 표준화**
- 표준화된 템플릿 코드를 통해 파이프라인이 생성되므로 개별 엔지니어의 코딩 스타일에 따른 파편화를 방지하고, 설정 오류에 따른 장애 발생 가능성을 최소화했습니다.
## 4. Impact & Result

- **운영 생산성 획기적 향상:**  코드 하나로 수십 개의 파이프라인을 통합 관리함으로써 관리 공수를 70% 이상 절감했습니다.
- **배포 리드타임 단축:** 코드 변경 없는 메타데이터 기반 튜닝으로 신규 파이프라인 생성 및 설정 변경 시간을 분 단위로 단축시켰습니다.
- **지속 가능한 아키텍처:** 파이프라인 개수 증가에도 선형적으로 비례하지 않는 관리 리소스를 확보하여 조직의 확장성을 뒷받침했습니다.
