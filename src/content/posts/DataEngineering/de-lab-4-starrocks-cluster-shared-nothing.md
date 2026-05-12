---
title: "[Data Engineering Lab] #4. StarRocks Cluster 구축하기 (Shared Nothing)"
description: "[Data Engineering Lab] #3. KRaft 모드로 Kafka Cluster 로컬에 구축하기안녕하세요"
date: 2025-12-27
tags:
  - StarRocks
  - OLAP
  - Cluster
  - DataEngineering
  - Lab
featured: false
draft: false
---
[[Data Engineering Lab] #3. KRaft 모드로 Kafka Cluster 로컬에 구축하기](/posts/DataEngineering/de-lab-3-kafka-kraft-cluster-local)

지난 포스팅 Kafka Cluster 구축기 ([이전 글](/posts/DataEngineering/de-lab-3-kafka-kraft-cluster-local))에 이어 차세대 OLAP 엔진으로 부상하고 있는 **StarRocks** 클러스터를 구축해보겠습니다.

## 1. StarRocks Architecture 선정

![](/images/posts/de-lab-4-starrocks-cluster-shared-nothing/img-1.png)

출처: https://docs.starrocks.io/docs/introduction/Architecture/

StarRocks는 **Shared-Data**, **Shared Nothing** 두 방식으로 클러스터를 구축할 수 있습니다.

**Shared-Data** 는 이미 구축되어있는 S3, HDFS와 같은 데이터 레이크의 데이터를 가져와 Caching을 통해 빠르게 데이터를 조회하는 방법이고,

**Shared Nothing** 은 직접 스토리지를 구축하는 방식으로 StarRocks 자체 MPP (Massively Parallel Processing) 기반으로 대규모 데이터를 빠르게 조회하는 장점이 있습니다.

저는 로컬스토리지를 구축 할 것이기 때문에 **Shared Nothing** 방식으로 StarRocks 클러스터를 구축하도록 하겠습니다.

## 2. StarRocks Cluster

![](/images/posts/de-lab-4-starrocks-cluster-shared-nothing/img-2.png)

StarRocks Cluster

클러스터는 FE 노드와 BE노드 각각 3개씩 총 6개의 컨테이너로 구성합니다.

**FE (FrontEnd):** 사용자의 쿼리를 받고, 실행 계힉을 짜며, 클러스터의 메타데이터를 관리합니다. (10.100.21-23 번대 주소 사용)  
**BE(BackEnd):** 실제로 데이터를 저장하며, FE가 보낸 실행 계획에 따라 병렬로 연산을 수행합니다. (10.100.31-33 번대 주소 사용)

데이터가 많아지면 BE노드를, 접속자 많아지면 FE노드를 추가하여 Scale-Out을 할 수 있는 구조입니다.

## 3. Docker Compose

```bash
starrocks/
├── fe/
│   └── docker-compose.yml  # 10.100.0.21~23
└── be/
    └── docker-compose.yml  # 10.100.0.31~33
```

fe, be를 구분하여 관리할 수 있도록 디렉토리를 분리후 docker-compose 파일을 작성합니다.

### - FE (docker-compose.yml)

```yaml
version: "3.9"

# [공통 설정] command는 여기서 뺐습니다.
x-fe-common: &fe-common
  image: starrocks/fe-ubuntu:latest
  restart: always
  environment:
    - HOST_TYPE=FQDN
    - TZ=Asia/Seoul
    # 팔로워는 entrypoint를 쓰므로 이 환경변수가 필수입니다.
    - STARROCKS_PRIORITY_NETWORKS=10.100.0.0/24
    - JAVA_OPTS=-Xmx2g -Xms2g
  logging:
    driver: "json-file"
    options:
      max-size: "200m"
      max-file: "5"

services:
  # ==========================================
  # FE Node 0 (Leader) - 수동 스크립트로 즉시 실행
  # ==========================================
  starrocks-fe-0:
    <<: *fe-common
    hostname: starrocks-fe-0
    container_name: starrocks-fe-0
    networks:
      default:
        ipv4_address: 10.100.0.21
    # [핵심] 리더는 설정 파일 직접 수정 후 바로 실행 (대기 없음)
    command:
      - /bin/bash
      - -c
      - |
        /opt/starrocks/fe_entrypoint.sh starrocks-fe-0
    volumes:
      - ./data/fe-0/meta:/opt/starrocks/fe/meta
      - ./data/fe-0/log:/opt/starrocks/fe/log

  # ==========================================
  # FE Node 1 (Follower) - 엔트리포인트 사용
  # ==========================================
  starrocks-fe-1:
    <<: *fe-common
    hostname: starrocks-fe-1
    container_name: starrocks-fe-1
    networks:
      default:
        ipv4_address: 10.100.0.22
    # [핵심] 팔로워는 리더(starrocks-fe-1)를 바라보며 엔트리포인트 실행
    command:
      - /bin/bash
      - -c
      - |
        /opt/starrocks/fe_entrypoint.sh starrocks-fe-0
    volumes:
      - ./data/fe-1/meta:/opt/starrocks/fe/meta
      - ./data/fe-1/log:/opt/starrocks/fe/log
    depends_on:
      - starrocks-fe-0

  # ==========================================
  # FE Node 2 (Follower) - 엔트리포인트 사용
  # ==========================================
  starrocks-fe-2:
    <<: *fe-common
    hostname: starrocks-fe-2
    container_name: starrocks-fe-2
    networks:
      default:
        ipv4_address: 10.100.0.23
    # [핵심] 팔로워는 리더(starrocks-fe-1)를 바라보며 엔트리포인트 실행
    command:
      - /bin/bash
      - -c
      - |
        /opt/starrocks/fe_entrypoint.sh starrocks-fe-0
    volumes:
      - ./data/fe-2/meta:/opt/starrocks/fe/meta
      - ./data/fe-2/log:/opt/starrocks/fe/log
    depends_on:
      - starrocks-fe-0

networks:
  default:
    name: dataplatform-net
    external: true
```

FE노드는 클러스터의 메타데이터를 관리하므로 **데이터 영속성** 과 **리더-팔로워 구조** 가 중요합니다.

- **리더와 팔로워**: starrokcs-fe-0가 리더 역할을 수행하며 가장 먼저 기동됩니다. 나머지 fe-1, fe-2 노드는 /opt/starrocks/fe_entrypoint.sh starrocks-fe-0 커맨드를 통해 클러스터에 Join 합니다.
- **메타데이터 보존:** 볼륨 마운트를 통해 컨테이너 재시작에도 메타데이터를 보존합니다.

### - BE (docker-compose.yml)

```yaml
version: "3.9"

# [공통 설정] BE(Backend) 설정
x-be-common: &be-common
  image: starrocks/be-ubuntu:latest
  restart: always
  environment:
    - HOST_TYPE=FQDN
    - TZ=Asia/Seoul
    - STARROCKS_PRIORITY_NETWORKS=10.100.0.0/24
    # BE는 Java 힙 외에도 네이티브 메모리를 많이 사용하므로 리소스 제한에 유의해야 합니다.
    # 필요시 sysctl 설정을 호스트에서 확인해야 합니다 (vm.max_map_count 등)

  # [로그 설정] 요청하신 대로 1GB (200MB x 5개) 제한 유지
  logging:
    driver: "json-file"
    options:
      max-size: "200m"
      max-file: "5"

services:
  # ==========================================
  # BE Node 0
  # ==========================================
  starrocks-be-0:
    <<: *be-common
    hostname: starrocks-be-0
    container_name: starrocks-be-0
    networks:
      default:
        ipv4_address: 10.100.0.31  # FE(20대)와 구분을 위해 30대 할당
    command:
      - /bin/bash
      - -c
      - |
        # BE 시작 스크립트 실행 (데몬 모드)
        /opt/starrocks/be_entrypoint.sh starrocks-fe-0
    volumes:
      # BE는 meta가 아니라 storage에 데이터를 저장합니다.
      - ./data/be-0/storage:/opt/starrocks/be/storage
      - ./data/be-0/log:/opt/starrocks/be/log

  # ==========================================
  # BE Node 1
  # ==========================================
  starrocks-be-1:
    <<: *be-common
    hostname: starrocks-be-1
    container_name: starrocks-be-1
    networks:
      default:
        ipv4_address: 10.100.0.32
    command:
      - /bin/bash
      - -c
      - |
        /opt/starrocks/be_entrypoint.sh starrocks-fe-0
    volumes:
      - ./data/be-1/storage:/opt/starrocks/be/storage
      - ./data/be-1/log:/opt/starrocks/be/log

  # ==========================================
  # BE Node 2
  # ==========================================
  starrocks-be-2:
    <<: *be-common
    hostname: starrocks-be-2
    container_name: starrocks-be-2
    networks:
      default:
        ipv4_address: 10.100.0.33
    command:
      - /bin/bash
      - -c
      - |
        /opt/starrocks/be_entrypoint.sh starrocks-fe-0
    volumes:
      - ./data/be-2/storage:/opt/starrocks/be/storage
      - ./data/be-2/log:/opt/starrocks/be/log

networks:
  default:
    name: dataplatform-net
    external: true
```

BE는 실제로 쿼리 연산을 수행하고 데이터를 저장합니다.

**- FE 등록:** BE노드는 기동시 /opt/starrocks/fe_entrypoint.sh starrocks-fe-0 커맨드로 FE 리더노드에게 BE 노드를 등록 요청을 합니다. 별도의 SQL없이 자동으로 노드 확장이 가능합니다.

**- 데이터 저장:** BE노드는 로컬 스토리지 이므로 볼륨 마운트 설정을 통해 컨테이너 재시작에도 데이터를 유지할 수 있도록 합니다.

### - 공통 설정

**- YAML Anchor**: x-fe-common이나 x-be-common 이름의 앵커를 사용하여 공통 설정의 중복을 제거하였습니다.

**- 네트워크 우선순위:** **STARROCKS_PRIORITY_NETWORKS=10.100.0.0/24** 설정을 통해 컨테이너가 여러 네트워크에 물려있어도 반드시 우리 랩의 전용 망으로 통신하게끔 강제했습니다.

**- 로그 로테이트:** 컨테이너 로그가 무한정 커지는 것을 방지하기위해 파일당 200mb, 최대 5개로 제한하는 설정을 적용하였습니다.

## 4. Deploy

### 배포

```bash
cd starrocks/fe
docker compose up -d

cd starrocks/be
docker compose up -d
```

### 확인

```sql
SHOW FRONTENDS;
```

| Id | Name | IP | EditLogPort | HttpPort | Alive | ... |
| --- | --- | --- | --- | --- | --- | --- |
| 2 | starrocks-fe-2_9010_1766764824096 | starrocks-fe-2 | 9010 | 8030 | true | ... |
| 3 | starrocks-fe-1_9010_1766764824116 | starrocks-fe-1 | 9010 | 8030 | true | ... |
| 1 | starrocks-fe-0_9010_1766764815633 | starrocks-fe-0 | 9010 | 8030 | true | ... |

```sql
SHOW BACKENDS;
```

| BackendId | IP | BePort | HttpPort | LastHeartbeat | Alive | ... |
| --- | --- | --- | --- | --- | --- | --- |
| 10003 | starrocks-be-0 | 9060 | 8040 | 2025-12-27 01:02:07 | true | ... |
| 10002 | starrocks-be-1 | 9060 | 8040 | 2025-12-27 01:02:07 | true | ... |
| 10001 | starrocks-be-2 | 9060 | 8040 | 2025-12-27 01:02:07 | true | ... |
