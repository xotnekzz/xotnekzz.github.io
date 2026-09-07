---
title: Grafana × Prometheus 기반 모니터링 시스템 구축
description: 분산되어 있던 서버·컨테이너·애플리케이션 메트릭과 장애 알림을 Prometheus와 Grafana로 통합
date: 2026-09-05
tags:
  - Prometheus
  - Grafana
  - Monitoring
featured: true
draft: false
---
> **기간:** 2026.2
> **참여인원:** 1명
> **역할:** 모니터링 시스템 도입
> **기술 스택:** Promethues, Grafana, Node Exporter, cAdvisor, Ansible

## 1. Background & Challenges

기존에는 **Munin**으로 서버의 하드웨어 메트릭을 수집하고, 장애 알림은 **Icinga2**에서 별도로 운영했습니다. 그러나 Munin은 하드웨어 지표 중심이라 컨테이너와 애플리케이션 상태를 함께 파악하기 어려웠고, 초 단위 변화 감지와 대시보드 유지보수에도 한계가 있었습니다.

- **관측 범위의 한계:** 서버 메트릭만으로는 컨테이너의 자원 사용량이나 Apache Doris·SeaweedFS 같은 데이터 플랫폼의 내부 상태를 함께 확인하기 어려웠습니다.
- **도구 분산:** 메트릭 조회와 장애 알림 인터페이스가 Munin과 Icinga2로 분리되어 장애 상황에서 여러 시스템을 오가야 했습니다.
- **감지 지연:** 짧은 시간에 발생하는 자원 사용량 변화와 이상 징후를 초 단위로 관찰하기 어려웠습니다.

서버·컨테이너·애플리케이션 메트릭을 중앙에서 수집하고, 조회와 장애 알림을 하나의 인터페이스로 통합하는 것이 목표였습니다.

## 2. Architecture: As-Is vs To-Be

### As-Is Architecture

![Munin의 하드웨어 중심 모니터링과 별도로 운영되는 Icinga2 장애 알림 구조](/images/monitoring-as-is-munin-icinga.svg)

1. **서버 메트릭 수집:** Munin Agent를 통해 CPU·메모리·디스크 등 하드웨어 중심 지표 수집
2. **메트릭 조회:** Munin Server와 전용 UI에서 서버 상태 확인
3. **장애 감지 및 알림:** Icinga2에서 별도의 설정과 인터페이스로 장애 알림 운영
4. **운영 한계:** 컨테이너·애플리케이션 메트릭의 통합 조회가 어렵고, 초 단위 이상 징후 감지와 도구 간 연계에 제약 발생

### To-Be Architecture

![node_exporter와 cAdvisor 및 데이터 플랫폼 자체 메트릭을 Prometheus에서 수집하고 Grafana에서 조회와 장애 알림을 통합하는 구조](/images/monitoring-to-be-prometheus-grafana.svg)

1. **서버 메트릭:** 각 서버에 `node_exporter`를 설치하여 CPU·메모리·디스크·네트워크 지표 노출
2. **컨테이너 메트릭:** 각 서버에 `cAdvisor`를 설치하여 컨테이너별 자원 사용량과 실행 상태 노출
3. **애플리케이션 메트릭:** Apache Doris·SeaweedFS 등이 자체 제공하는 Prometheus 형식의 메트릭 엔드포인트 연동
4. **중앙 수집:** 단일 모니터링 서버의 Prometheus가 모든 대상의 메트릭을 초 단위 주기로 수집·저장
5. **통합 조회 및 알림:** Grafana에서 서버·컨테이너·애플리케이션 대시보드와 장애 알림을 하나의 인터페이스로 운영

## 3. Solution & Technical Insights

1. **계층별 Exporter 표준화**
    - **[Issue]** 기존 Munin의 하드웨어 중심 수집 방식만으로는 호스트, 컨테이너, 데이터 플랫폼의 상태를 같은 기준에서 관찰하기 어려웠습니다.
    - **[Solution]** 모든 서버에 `node_exporter`와 `cAdvisor`를 기본 설치하고, Apache Doris·SeaweedFS는 제품이 제공하는 Prometheus 메트릭 엔드포인트를 직접 연결했습니다. 수집 방식을 Prometheus 생태계로 통일하여 인프라 전 계층의 지표를 한곳에서 조회할 수 있게 했습니다.
2. **Pull 기반 중앙 메트릭 수집**
    - **[Issue]** 도구와 대상마다 모니터링 방식이 달라 설정과 상태 확인 경로가 분산되어 있었습니다.
    - **[Solution]** 중앙 Prometheus가 등록된 대상을 주기적으로 scrape하도록 구성했습니다. 서버·컨테이너·애플리케이션 메트릭의 수집 상태와 시계열 데이터를 하나의 서버에서 관리하도록 단순화했습니다.
3. **대시보드와 장애 알림 인터페이스 통합**
    - **[Issue]** Munin에서 메트릭을 조회하고 Icinga2에서 알림을 관리해야 해 장애 분석과 유지보수 과정이 단절되어 있었습니다.
    - **[Solution]** Grafana를 공통 운영 인터페이스로 사용하여 대시보드와 장애 알림을 통합했습니다. 이상 징후를 확인한 화면에서 관련 서버·컨테이너·애플리케이션 지표를 연속해서 탐색할 수 있게 구성했습니다.

## 4. Impact & Result

- 🔎 **관측 범위 확대:** 모든 서버와 컨테이너의 자원 지표뿐 아니라 Apache Doris·SeaweedFS의 애플리케이션 메트릭까지 상시 조회할 수 있게 되었습니다.
- 🚨 **장애 대응 체계 통합:** 데이터 플랫폼 모니터링과 장애 알림을 Grafana 인터페이스로 통합하여 상태 확인과 원인 분석 경로를 단순화했습니다.
- ⚡ **감지 주기 개선:** 기존 Munin 환경에서 확인하기 어려웠던 초 단위 메트릭 변화를 수집하여 짧은 이상 징후도 관찰할 수 있게 되었습니다.
- 🦾 **운영 표준화:** `node_exporter`, `cAdvisor`, Prometheus 메트릭 엔드포인트를 공통 수집 방식으로 정해 신규 서버와 서비스도 같은 패턴으로 편입할 수 있게 되었습니다.
