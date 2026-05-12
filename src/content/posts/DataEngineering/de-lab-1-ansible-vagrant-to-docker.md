---
title: "[Data Engineering Lab] #1. Ansible, Vagrant 환경을 Docker로 변경한 이유"
date: 2025-12-20
tags:
  - Docker
  - Ansible
  - Vagrant
  - DataEngineering
  - Lab
featured: false
draft: false
---

## 1. 나는 데이터 엔지니어인가, 서버 관리자인가?

지난 포스팅들에서는 Vagrant, Ansible을 사용한 이유는 **실제 베어메탈 서버** 와 가장 유사한 환경에서 데이터 엔지니어링 플랫폼을 구축하고 싶었기 때문입니다. 그러나 생각지 못한 변수들로 인해 데이터 엔지니어링 연구에 집중하기 보다 인프라 구축에 시간을 많이 쓰게 되었습니다.

- **맥북의 리소스한계:** 24GB 맥북에서 가상서버 5대에 빅데이터를 위한 클러스터를 띄우는데 리소스 부담이 컸습니다.
- **무한 반복되는 '삽질':** 네트워크 인터페이스가 꼬이거나 SSH 연결 오류 등으로 vagrant를 다시 올렸다 내리는데 시간을 많이 버렸습니다.
- **주객전도:** 데이터 파이프라인에 대한 연구를 하고 싶었으나, 하루종일 인프라 코드 설정에 시간을 많이 쓰고 있었습니다.

결국 **"이러다간 데이터 파이프라인 공부는 시작도 못하겠다"** 는 위기감이 들었습니다.

## 2. Docker로 전환

Docker Compose를 사용하여 인프라 환경 코드를 단순화 시켰고, 빠르게 내렸다 올릴 수 있도록 하였습니다.

**새로운 데이터 엔지니어링 랩(Lab) 구조**

```bash
.
├── create_network.sh       # 10.100.0.0/16 대역의 고정 브릿지 네트워크 생성
├── kafka/                  # Kafka Cluster (KRaft Mode, 3 Nodes)
├── starrocks/              # FE/BE 독립 클러스터 구축
│   ├── fe/ (10.100.0.21~23)
│   └── be/ (10.100.0.31~33)
├── mariadb/                # Source DB 및 Python 데이터 생성기
│   ├── gen_data.py         # 이커머스 트래픽 시뮬레이터
│   └── venv/               # 독립된 Python 환경
└── devezium/               # CDC (Change Data Capture) 엔진
    └── register_connector.sh
```

## 3. 왜 이렇게 구성했나?

"Ansbile로도 다 되는 거 아냐?"싶겠지만, 맥북 한 대라는 **한정된 운동장** 에서는 이야기가 달라집니다.

- **리소스 효율:** OS 커널을 공유하는 Container 방식이 리소르 효율을 높혀줍니다.
- **피드백 속도:** 분 단위의 Ansible 프로비저닝보다 수 초 단위의 클러스터를 올리고 내릴 수 있습니다.
- **베어메탈급 직관성:** `docker-mac-net-connect` 와 고정 IP 조합이면, 맥 터미널에서 `10.100.x.x.`로 바로 핑을 날려 실제 서버를 다루듯이 제어할 수 있습니다.

## 4. 앞으로는 무엇을 연구할 것인가?

Docker로 인프라 구축이 끝나면, 본격적으로 데이터 파이프라인의 여러 시나리오를 세워 하나씩 구축해 보고자 합니다.

- Scenario #1: MariaDB에서 발생한 변경사항이 Debezium을 거쳐 StarRocks에 실시간으로 꽂히는 CDC 파이프라인 구축.
- Scenario #2: Kafka 토픽에 쌓이는 데이터를 StarRocks의 Routine Load로 가져올 때 발생하는 지연(Latency)과 최적화 문제.
- Scenario #3: 클러스터 노드 하나가 죽었을 때(HA 테스트) 데이터 유실 없이 파이프라인이 유지되는지 검증.

시나리오는 변경 될 수 있습니다.

## 마치며

다음 포스팅에서는 Docker기반의 새로 구축한 데이터 엔지니어링 랩에 대해 하나씩 풀어나갈 예정입니다.

