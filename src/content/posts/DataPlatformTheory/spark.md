---
title: Apache Spark 이론 — Driver·Executor와 Job·Stage·Task
description: Spark 클러스터의 제어 경로, 파티션 처리, 셔플과 장애 복구를 설명합니다.
date: 2026-09-23
tags: [Spark, DistributedProcessing, Architecture]
draft: false
---

Apache Spark는 여러 머신에 데이터를 나누어 병렬 처리하는 엔진입니다. **Driver는 계획과 조정**, **Executor는 계산**을 맡습니다. Spark SQL·DataFrame·RDD의 API는 달라도 클러스터 실행 구조를 이해할 때 이 구분이 출발점입니다.

![Spark의 Driver, Cluster Manager, Executor와 데이터 경로](/images/posts/data-platform-theory/spark-architecture.svg)

아래 공식 그림은 Spark 애플리케이션 하나가 Driver를 중심으로 자원을 요청하고 Executor를 사용하는 구성을 보여 줍니다. 이 그림의 작업 흐름과 위의 Job·Stage·Task 개념을 연결해 보세요.

![Apache Spark 공식 문서의 클러스터 실행 구조](/images/posts/data-platform-theory/official/spark-official.png)

[그림 출처: Spark Cluster Mode Overview](https://spark.apache.org/docs/latest/cluster-overview.html)

## 실행 단위를 정확히 구분해 보겠습니다

| 요소 | 역할 |
|---|---|
| Application | 하나의 Driver와 이 애플리케이션 전용 Executor 집합입니다. |
| Driver / SparkContext | 사용자 프로그램을 실행하고 작업 계획·스케줄을 관리합니다. |
| Cluster Manager | Standalone, YARN, Kubernetes 등의 환경에서 실행 자원을 할당합니다. 데이터 처리 자체를 담당하지 않습니다. |
| Executor | Task를 실행하고 중간 데이터를 메모리·디스크에 보관하는 프로세스입니다. |
| Job | `save`, `collect` 같은 Action에서 촉발되는 병렬 계산입니다. |
| Stage | 셔플 경계 등으로 나뉜 Task 집합입니다. 앞 단계 출력이 필요한 경우 Stage 사이에 의존성이 생깁니다. |
| Task | 파티션 하나에 대한 계산의 기본 실행 단위입니다. |

## 파일을 집계해 저장하는 흐름

1. Driver에서 `read → filter → groupBy → write` 변환을 기술합니다. Spark는 최적화 가능한 실행 계획을 구성합니다.
2. `write` 같은 Action이 실행을 촉발합니다. Driver가 Job을 Stage와 Task로 나눕니다.
3. Cluster Manager가 확보한 Executor에 Task가 배정됩니다. 각 Task는 입력 파티션을 읽고 필터링합니다.
4. 그룹 키를 기준으로 데이터가 다른 Executor로 이동하는 **Shuffle**이 생길 수 있습니다. 다음 Stage가 집계해 결과를 저장합니다.

셔플은 네트워크와 디스크 I/O를 늘리므로 느린 작업의 주요 단서입니다. `cache`는 반복 사용 데이터의 재계산을 줄이지만 메모리를 차지합니다. Executor가 실패하면 Spark는 잃은 Task나 중간 결과를 다시 계산할 수 있습니다. 다만 최종 외부 시스템 쓰기의 멱등성까지 자동으로 보장하는 것은 아니므로 재시도 가능한 출력 설계가 필요합니다.

## 지연 실행과 계보(Lineage)

DataFrame 변환은 일반적으로 즉시 모든 행을 계산하지 않고 논리적 계획을 쌓습니다. Action이 호출될 때 계획을 최적화하고 실제 Job을 실행합니다. 따라서 코드가 성공적으로 DataFrame을 구성했다는 사실은 원천 파일을 모두 읽었다는 뜻이 아닙니다. 실제 오류가 `show`, `count`, `write` 같은 Action에서 늦게 드러날 수 있습니다.

RDD의 경우 변환 계보는 각 파티션을 어떻게 다시 만들 수 있는지 표현합니다. Executor 손실 시 계보를 따라 일부 연산을 재계산할 수 있어 중간 결과를 항상 복제해 둘 필요가 없습니다. `persist`는 재사용 비용을 줄이는 캐시 정책이고, `checkpoint`는 계보를 끊고 저장 지점에서 복구하도록 하는 기능입니다. 캐시와 체크포인트는 같은 기능이 아닙니다.

## 셔플과 파티션은 분산 계산의 비용 모델입니다

셔플 이전의 좁은 변환은 입력 파티션 안에서 처리되는 경우가 많지만, `groupByKey`, 조인, 전역 정렬처럼 키별 데이터를 모으는 연산은 네트워크 경계를 만듭니다. 데이터가 직렬화되어 디스크와 네트워크를 통과하고 다음 Stage가 시작되므로, CPU 계산량보다 이 비용이 더 클 수 있습니다. 파티션 수를 늘리면 병렬 실행 기회가 늘지만 Task 관리·파일 수·셔플 블록도 많아집니다. 반대로 줄이면 한 Task가 처리하는 작업이 커져 편향과 메모리 압박이 커질 수 있습니다.

## 실패 경계

Spark의 재계산은 입력이 다시 읽을 수 있고 변환이 재실행 가능하다는 가정에 기대고 있습니다. 외부 시스템에 부수 효과를 내는 UDF나 중복 허용이 안 되는 API 호출은 Task 재시도와 맞지 않을 수 있습니다. 분산 계산의 재시도 정책, Source의 재현 가능성, Sink의 원자성·멱등성을 하나의 처리 보장으로 묶어 설계해야 합니다.

Driver 메모리 부족, 입력 파티션 불균형, 특정 Stage의 긴 셔플, Executor 메모리 압박을 각각 구분해 Spark UI와 로그를 살펴보세요. Driver 위치는 client/cluster 배포 모드에 따라 달라집니다.

**공식 문서:** [Cluster Mode Overview](https://spark.apache.org/docs/latest/cluster-overview.html), [Job Scheduling](https://spark.apache.org/docs/latest/job-scheduling/)
