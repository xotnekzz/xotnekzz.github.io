# Columstore To StarRocks 전환

> **기간:** 2024
**참여인원**: 2명
**역할:** Senior Data Engineer (StarRocks 클러스터 구축 및 데이터 이관 주도)
**기술 스택:** StarRocks, MariaDB Columnstore, SQL, Python, ETL Pipeline

## 1. Background & Challenges

마케팅 데이터 분석의 핵심 저장소였던 **MariaDB Columnstore** 기반 환경이 확장성과 성능 한계에 직면했습니다. 특히 오픈소스 개발 중단으로 인한 유지보수 리스크가 대두되었고, 데이터 로드 시 실제 데이터 크기보다 비정상적으로 용량이 팽창(뻥튀기)하여 스토리지 관리 리소스가 비대해지는 문제가 발생했습니다.

# 2. Tech Selection: Why StarRocks?

기존 MariaDB Columnstore의 한계를 극복하기 위해 ClickHouse, Apache Doris, Druid 등 주요 OLAP 엔진을 비교 분석하여 최적의 솔루션을 선정했습니다.

**[선정 이유]**

- **비즈니스 연속성:** MySQL 프로토콜 호환성 덕분에 기존 마케팅 도구와의 통합 비용 최소화.
- **분석 유연성:** 단순 조회를 넘어 수십억 건 규모의 다차원 분석(Join 포함) 쿼리에서 가장 안정적인 응답 속도 제공.
- **운영 효율성:** Apache Druid 대비 컴포넌트 구조가 단순하여 관리 리소스 절감 및 유지보수성 확보.
## 3. Architecture: Migration Focus

기존의 비효율적인 레거시 OLAP 환경을 고성능 StarRocks 독립 클러스터로 전면 전환하는 프로젝트를 수행했습니다.

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/3dfdc305-68b0-4dbd-8abc-e7473611582a/StarRocks.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB4665KSKGCJD%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153143Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIGd84QK0mJo8qxIipxi9eXcqWXNGNIVZ7uO4q0ab6M0PAiEApGPMdSqRpoihwrxAMpAGf%2B47Zo9fsj2DK7g7sQuwpoMqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDKMCLCvatwAGLiOHFSrcA7WqCBZoHu89r4mwVLoJMqBwWOHN0HZtMZ7isFx%2F1WJ8rai3jCM5LUbcibJXqrCmnOmATevaD81GFFgF3dK4dL4bHkxYGbCq4TYQ9tRf9kdbVXo0XRuRB3YEGTHDw2PK69jZMHLKT%2FRH%2FlNZ%2BgrFZ8NgpqCS8Z4ty6wCtQsAuigyKo%2F5PQCKeKO3jVEtXAfzY8ndfV%2BKtsLlgSZCccown8DaUqAMja5QVkTDOMQd3fYaujnjSlBZWUFiZ9d9FhcZI5xAhUCpLHr3Vr%2FedkaI5ga8A3aoZzE7gLt776BKSuWPe3Znn0B4H0VZk1Paj0F7sXoQvMCrSLBA%2BRqq0hxaxnepS%2Fg5y6e3FABkd58S%2BXwM0yQXSMwDXtv%2F4PiEJkd1tOnXLFodWZTcpWjF1%2FArx0ql0XiqEq%2F7yYyNRN0Z5r5cELx8Vzt90fYVJHiVW%2BJRW2%2FjYq1dba9gOGFsS03hkJ105S1g5fHFPbeM5r6b2qzecRn9HWmrD9qBucgpu4GdVjR8%2FxSlQ7v5kku4tooNVBzIINoiNVKeripr07EzhYIpAlH%2F3Q1eHIr%2BOJlStOmAe0K0%2Fx1RziF4Ry%2B9sY%2FoaLlafFunTH0U3SyDGoaeHxeNLJNbGHOcbFgspCIWMLq9z80GOqUBItzJYFgG0zU5aZzwDOysSpwtLNL3FAAbMf3wsvUCMs7v23X0PLjaXK5MOYBkNO0GtrWyITM1HIWDK4VLg21g6gIXTGr2HueREpaWMxr4UJcpniBG95cZsEbY%2BKWogOoikuTY8d5nv5rX%2FkoC8GCN2qaoZq5ZNliQnACfjUvkgRVx5KeodHonYpnMicxoCC8qZRmQzKKdg6pOv9xdK5bxHSJaDq9t&X-Amz-Signature=a93845b897dc467c3840f789cd41a79e7e367f699d347c0922e1a1e473154c8a&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

## 4. Solution & Technical Insights

1. **대규모 독립 StarRocks 클러스터 설계 및 구축**
- **[Issue]** 수십억 건 규모의 마케팅 데이터를 실시간으로 조회하고 분석하기 위한 고성능 독립 환경이 필요했습니다. (로그 분석용 Doris 클러스터와는 별도 운영 목적)
- **[Solution]** **최신 서버 장비 10대 규모의 StarRocks 독립 클러스터**를 신규 구축하고 최적화했습니다. 이를 통해 로그 데이터와 마케팅 성과 데이터를 물리적으로 분리하여 분석 쿼리 간의 간섭을 차단하고 안정적인 서빙 환경을 확보했습니다.
1. **30억 건 대규모 데이터 이관 및 최적화**
- **[Issue]** MariaDB Columnstore의 비정상적인 데이터 팽창 문제로 인해 스토리지 효율이 극히 낮았습니다.
- **[Solution]** StarRocks의 압축 알고리즘과 인덱스 전략을 활용하여 **30억 건 규모의 데이터를 안정적으로 이관**했습니다. 이 과정에서 스토리지 사용량을 획기적으로 줄이고, 대규모 OLAP 처리에 최적화된 테이블 스키마 재설계를 주도했습니다.
1. **쿼리 성능 및 운영 효율 개선**
- StarRocks 도입 후, 복잡한 Join과 집계 연산이 포함된 마케팅 성과 분석 쿼리의 응답 속도를 비약적으로 단축시켰습니다.
## 5. Impact & Result

- 🚀 **쿼리 속도 12.4배 향상:** 30억 건 데이터 기준, 기존 MariaDB 대비 쿼리 성능을 **최대 12.4배 단축**하여 실시간 마케팅 의사결정 체계를 고도화했습니다.
- 💰 **스토리지 효율 증대:** 데이터 팽창 문제를 해결하고 압축 효율을 높여 관리 인프라 리소스를 최적화했습니다.
- 🦾 **시스템 안정성 확보:** 레거시의 기술 부채를 청산하고 향후 수백억 건 규모로의 성장에 대응 가능한 현대적 OLAP 기반을 마련했습니다.




