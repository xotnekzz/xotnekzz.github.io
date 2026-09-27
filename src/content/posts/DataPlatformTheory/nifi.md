---
title: Apache NiFi 이론 — FlowFile과 Processor·Queue
description: NiFi의 흐름 제어, FlowFile 저장소, 역압과 데이터 계보를 설명합니다.
date: 2026-09-23
tags: [NiFi, DataIntegration, Architecture]
draft: false
---

Apache NiFi는 시각적으로 데이터 흐름을 연결해 수집·라우팅·변환·전송하는 플랫폼입니다. 화면의 화살표는 단순한 호출 순서가 아니라, **FlowFile이 대기할 수 있는 Connection Queue**를 포함한 처리 경로입니다.

![NiFi의 Flow Controller와 FlowFile 데이터 경로](/images/posts/data-platform-theory/nifi-architecture.svg)

공식 문서 그림은 한 JVM 안의 Web Server, Flow Controller, Extension, Repository 배치와 클러스터의 노드 간 역할을 보여 줍니다. 위 개념도와 함께 보면 Processor 그래프와 NiFi 런타임 저장소가 서로 다른 층이라는 점을 확인하기 쉽습니다.

![Apache NiFi 공식 문서의 단일 노드 아키텍처](/images/posts/data-platform-theory/official/nifi-official.png)

[그림 출처: Apache NiFi Overview — NiFi Architecture](https://nifi.apache.org/nifi-docs/overview.html)

![Apache NiFi 공식 문서의 클러스터 아키텍처](/images/posts/data-platform-theory/official/nifi-cluster.png)

[그림 출처: Apache NiFi Overview — NiFi Cluster Architecture](https://nifi.apache.org/nifi-docs/overview.html)

## FlowFile을 중심으로 이해해 보겠습니다

| 요소 | 역할 |
|---|---|
| FlowFile | 속성(attribute)과 내용(content)을 참조하는 처리 단위입니다. 데이터 전체를 항상 메모리에 들고 있는 객체로 생각하면 안 됩니다. |
| Processor | 외부에서 읽거나, 변환·분기하거나, 외부로 보냅니다. |
| Relationship | Processor의 결과 종류입니다. `success`, `failure` 같은 결과별로 다음 경로를 연결합니다. |
| Connection Queue | Relationship으로 나온 FlowFile을 다음 Processor가 가져갈 때까지 보관합니다. 큐 한도를 이용해 역압을 걸 수 있습니다. |
| Flow Controller | 스레드와 실행 일정을 관리하며 Processor를 구동합니다. |
| Controller Service | 여러 Processor가 공유하는 연결·설정·기능을 제공합니다. |
| Repositories | FlowFile Repository는 현재 흐름의 상태, Content Repository는 내용 바이트, Provenance Repository는 처리 이력을 맡습니다. |

## API 응답을 파일로 보내는 흐름

1. 수집 Processor가 API에서 데이터를 받아 FlowFile을 만듭니다.
2. 속성에 따라 라우팅 Processor가 Relationship을 선택하고 FlowFile을 해당 Connection Queue로 옮깁니다.
3. 후속 Processor가 큐에서 FlowFile을 가져와 내용을 변환하거나 외부 대상에 보냅니다.
4. 흐름의 현재 상태·실제 바이트·이력 이벤트가 서로 다른 Repository에 기록됩니다. Provenance로 어느 단계에서 들어오고 바뀌고 나갔는지 추적할 수 있습니다.

**역압(back pressure)**은 후속 단계가 느릴 때 큐 증가를 제한해 원천 처리 속도를 조절하는 장치입니다. 큐가 길어진 이유가 수집량 증가인지 목적지의 느린 쓰기인지 먼저 구분해 보세요. `failure` Relationship을 연결하지 않고 자동 종료하면 재처리할 데이터가 사라질 수 있으므로 흐름 설계 시 명시적으로 확인하시는 것이 좋습니다.

NiFi는 FlowFile의 이동을 관리하지만, 외부 API 호출과 목적지 기록을 포함한 전체 파이프라인의 정확히 한 번 처리 보장은 별도 설계가 필요합니다. 장애 분석에는 큐 크기, Bulletin, Processor 상태, Provenance 이벤트를 함께 사용합니다.

## FlowFile과 Repository의 저장 모델

FlowFile은 실제 바이트를 직접 품은 메모리 객체가 아니라 Attribute와 Content에 대한 참조를 가진 흐름 데이터 단위입니다. Attribute는 파일명, 원천, 라우팅 결과 같은 작은 키·값이고 Content는 큰 본문입니다. FlowFile Repository는 현재 처리 중인 FlowFile의 상태와 Content 참조를 기록하고, Content Repository는 실제 바이트를 저장하며, Provenance Repository는 과거 처리 사건을 보존합니다. 저장 위치와 보존 기간이 다르기 때문에 세 저장소의 용량과 디스크 상태를 따로 관찰해야 합니다.

공식 설계 문서는 Content를 불변 데이터로 다루고 수정 시 copy-on-write를 하는 원리를 설명합니다. Processor가 Content를 바꾸면 기존 파일을 덮어쓰는 대신 새 Content를 기록하고 FlowFile의 참조를 갱신합니다. 이 방식은 이전 처리 상태의 데이터 계보와 재생 가능성을 돕지만, Content·Provenance 보존 정책이 길면 저장 공간도 늘어납니다.

## ProcessSession은 NiFi 내부 작업을 묶습니다

Processor는 ProcessSession에서 FlowFile을 가져와 생성·복제·수정·전달하고, 마지막에 커밋하거나 롤백합니다. 커밋되면 FlowFile 상태 변경과 Provenance 이벤트가 Repository에 확정됩니다. 실패하면 세션의 미커밋 변경을 롤백할 수 있습니다. 이것은 **NiFi 내부 저장소의 처리 단위**입니다. Processor가 외부 DB에 쿼리를 실행하거나 HTTP 요청을 보낸 효과까지 항상 원자적으로 취소하는 분산 트랜잭션은 아닙니다.

예를 들어 외부 DB INSERT가 성공한 직후 NiFi 세션 커밋 전에 프로세스가 종료되면, 재시작 후 같은 FlowFile이 다시 처리될 가능성이 있습니다. 중복 방지가 필요하면 목적지의 고유 키, upsert, 수신 ID 멱등성 등을 고려해야 합니다.

## Queue는 흐름 제어 장치입니다

Connection Queue는 서로 다른 속도로 동작하는 Processor 사이의 버퍼입니다. 큐가 채워지면 Back Pressure 임계치가 upstream Processor의 실행을 멈춰 메모리·디스크 고갈을 막습니다. 큐 우선순위는 처리 순서를 조절할 수 있고, 클러스터에서 Load Balancing 전략은 FlowFile을 노드 사이에 분배할 수 있습니다. 다만 분배 전략은 데이터 지역성과 순서, 재처리 위치에 영향을 주므로 목적지 요구와 맞춰야 합니다.

## 클러스터는 데이터와 제어 책임을 분산합니다

NiFi의 zero-leader clustering에서는 모든 노드가 데이터 처리에 참여하고, ZooKeeper가 Cluster Coordinator와 Primary Node 선출을 지원합니다. Coordinator는 노드 연결 상태와 클러스터 상태를 조정하고, Primary Node는 Primary Node 전용 Processor를 실행할 때 기준이 됩니다. Flow 설정 변경은 클러스터 노드에 동기화되지만, 큐에 있는 데이터와 Processor 실행은 노드별로 나뉩니다. 즉 “같은 Flow를 실행한다”와 “같은 FlowFile 복제본을 공유한다”는 뜻은 아닙니다.

이 설계에서 클러스터 확장 효과는 원천 입력의 분배 방식에도 달려 있습니다. 하나의 단일 입력만 한 노드로 보내면 다른 노드가 유휴 상태일 수 있습니다. Source partitioning, site-to-site, load-balanced Connection 등을 이용해 입력을 병렬로 분배해야 합니다. 클러스터 상태 합의는 Coordinator가 담당하지만, 파일·API·DB 쪽 외부 상태는 해당 시스템의 가용성과 재시도 규칙을 따릅니다.

## Provenance는 관측성과 계보입니다

Provenance 이벤트는 FlowFile이 생성·복제·라우팅·수정·전송된 흔적을 기록합니다. 이를 이용하면 특정 레코드가 어느 프로세서를 거쳐 왔는지 조사하고, 보존 설정 내에서 이전 단계부터 재생할 수 있습니다. 다만 Provenance 저장 기간과 Content 보존은 별도 설정이며, 모든 과거 데이터를 무기한 보관하는 감사 저장소라고 가정해서는 안 됩니다.

**공식 문서:** [NiFi Overview](https://nifi.apache.org/nifi-docs/overview.html), [User Guide](https://nifi.apache.org/nifi-docs/user-guide.html), [Developer's Guide](https://nifi.apache.org/nifi-docs/developer-guide.html), [NiFi In Depth](https://nifi.apache.org/nifi-docs/nifi-in-depth.html)
