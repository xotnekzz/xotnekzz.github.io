---
title: "Kafka KRaft Cluster 구축하기 with Ansible"
date: "2025-12-13"
tags: ["Kafka", "KRaft", "Ansible", "DataEngineering"]
featured: false
draft: true
---

## 1. 들어가며

지난 포스팅에서 Starrocks 고성능 OLAP 분석환경을 구축하였습니다. [(이전 글: Starrocks 클러스터 구축하기 with Ansible)](./starrocks-cluster-ansible.md)

하지만 고성능 DB가 준비되었다고 해서 데이터 플랫폼이 완성된 것은 아닙니다. DB에 실시간으로 데이터를 안정적으로 공급해 줄 **파이프라인** 이 필요합니다. 저는 이 프로젝트의 최종 목표로 CDC(Capture Data Capture)나 로그 스트림을 처리하여 Starrocks에 적재하는 데이터 파이프라인 아키텍처를 완성하는 것이며 그 중심에 Apache kafka를 배치하고자 합니다.

#### 왜 Kafka인가?

**1. 시스템 간 결합도 감소 (Decoupling):** Web Server와 Starrocks가 직접 연결할 경우, 한쪽의 장애가 전체의 장애로 전파됩니다. Kafka는 이들 사이에서 완충재 역할을 하여 시스템을 독립적으로 운영할 수 있게 합니다.

**2. 트래픽 스파이크 대응 (Buffering):** 이벤트나 로그가 폭증 할 때, Starrocks가 이를 직접 감당하면 부하가 걸릴 수 있습니다. Kafka는 높은 처리량(Throughput)으로 데이터를 일단 받아내고, Cousumer 속도를 조절하여 다운시스템을 보호합니다.

**3. 데이터 재생 및 재처리 (Replayability)**: 데이터를 즉시 소비하고 사라지지 않고, Kafka는 디스크에 데이터를 저장합니다. 덕분에 로직이 변경되거나 장애 발생했을 때 과거 데이터를 다시 읽어와 재처리 할 수 있습니다.

## 2. 아키텍처 및 환경 구성

[(이전 글: 맥북에 리눅스 서버 5대 구성하기 - Ansible, Vagrant)](https://tedi.tistory.com/48) 에서 구축한 4,5,6번 서버 3대를 활용하여 Kafka Cluster를 구축합니다.



- OS: Rocky Linux 9
- Deployment: Docker Compose
- Kafka Mode: KRaft Combined Mode
	- 하나의 컨테이너에서 Broker와 Controller 역할을 동시에 수행합니다.
- Image: confluentinc/cp-kafka:7.6.1
- Monitoring: Kafka UI (Server-4에 배포)

이전과 마찬가지로 Ansible Playbook을 작성하여 Kafka Cluster 배포를 진행하겠습니다.

Kafka에 대한 자세한 개념 및 클러스터 관련한 내용은 따로 포스팅을 작성하도록 하겠습니다.

## 3. Ansible 프로젝트 구조

```
.
├── kafka
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── roles
│   │   └── kafka_container
│   │       ├── tasks
│   │       │   └── main.yml
│   │       └── templates
│   │           └── docker-compose.yml.j2
│   ├── site.yml
│   └── ssh_config
```

## 4. 설정 및 연결 준비

### 4-1) SSH 접속 설정 (kafka/ssh_config)

Vagrant 가상머신에 Ansible이 원활하게 접속하기 위해, 접속 정보를 별도 파일로 추출하여 프로젝트에 포함시켰습니다.

(vagrant ssh-config > ssh_config)

### 4-2) 설정 파일 (kafka/ansible.cfg)

```
[defaults]
inventory = inventory.ini
remote_user = vagrant
host_key_checking = False
roles_path = ./roles:../roles

[ssh_connection]
# ssh_config 파일을 참조하도록 설정 (vagrant ssh 전용 설정)
ssh_args = -F ./ssh_config -o ControlMaster=auto -o ControlPersist=60
```

상위 폴더(../roles)의 롤을 참조하기 위해 roles_path를 설정했습니다.

그리고 ansible이 vagrant 서버에 ssh 연결 인증을 위해 ssh_config 경로도 설정해주었습니다.

### 4-3) 인벤토리 (kafka/inventory.ini)

```csharp
[kafka_cluster]
server-4
server-5
server-6
```

## 5. Playbook 및 변수 설정

### 5-1) Main Playboook (kafka/site.yml)

각 서버의 Node ID 매핑과 Cluster ID 설정이 중요합니다. KRaft모드는 초기화 시 모든 노드가 동일한 Cluster UUID를 공유해야합니다.

```yaml
---
- name: Setup Kafka Cluster (KRaft Combined Mode) & UI
  hosts: kafka_cluster
  become: yes
  vars:
    # 1. 노드 식별자 (KRaft 필수)
    kafka_node_ids:
      server-4: 1
      server-5: 2
      server-6: 3

    # 2. 클러스터 ID (고정된 UUID, 변경 금지)
    kafka_cluster_id: "MkU3OEVBNTcwNTJENDM2Qk"

    # 3. 데이터 저장 경로 (호스트)
    kafka_data_dir: "/data/kafka"

  roles:
    - docker             # ../roles/docker (Docker 설치)
    - kafka_container    # ./roles/kafka_container (Kafka 배포)
```

## 6. Role 구현

### 6-1) Task 정의 (kafka/roles/kafka_container/task/main.yml)

Confluent 이미지는 내부적으로 appuser(UID 1000)를 사용하므로, 호스트의 데이터 디렉토리 권한을 이에 맞춰줘야 `Permission Denied` 에러를 방지할 수 있습니다.

```yaml
---
- name: Create Kafka data directory with correct permissions
  file:
    path: "{{ kafka_data_dir }}"
    state: directory
    mode: '0755'
    owner: 1000  # Confluent 'appuser' UID
    group: 1000

- name: Create Docker Compose working directory
  file:
    path: "/opt/kafka-docker"
    state: directory

- name: Deploy docker-compose.yml template
  template:
    src: docker-compose.yml.j2
    dest: "/opt/kafka-docker/docker-compose.yml"
    mode: '0644'
  register: compose_config  # [핵심] 실행 결과를 'compose_config' 변수에 저장

# 설정 파일이 변경되었을 때만 기존 컨테이너를 내림
- name: Tear down existing services (only if config changed)
  command: docker compose down
  args:
    chdir: "/opt/kafka-docker"
  when: compose_config.changed  # [핵심] 변경 감지 시 실행

- name: Pull Docker images
  command: docker compose pull
  args:
    chdir: "/opt/kafka-docker"

- name: Start Kafka Cluster (and UI on server-4)
  command: docker compose up -d
  args:
    chdir: "/opt/kafka-docker"
```

### 6-2) Docker Compose 템플릿 (kafka/roles/kafka_container/templates/docker-compose.yml.j2)

Kafka 클러스터 배포에 필요한 설정을 포함하여 docker-compose.yml을 템플릿화 합니다.

Sever-4에는 Kafka-UI를 추가하기 위해 if문으로 구분해주었습니다.

#### Key Point (Config)

- `KAFKA_PROCESS_ROLES=broker,contoller`: Combined 모드 설정
- `KAFKA_CONTROLLER_QUORUM_VOTER`: 3대 서버 모두 투표권을 부여
- `KAFKA_LISTNERS`: 외부 포트(9092)와 내부 컨트롤러 포트 (9093)분리
```ruby
version: '3.8'
services:
  # ==========================================
  # Apache Kafka (All Nodes)
  # ==========================================
  kafka:
    image: confluentinc/cp-kafka:7.6.1
    container_name: kafka
    restart: always
    network_mode: host
    user: "1000:1000"
    environment:
      # --- 1. 역할 설정 (Combined Mode: Broker + Controller) ---
      - KAFKA_NODE_ID={{ kafka_node_ids[inventory_hostname] }}
      - KAFKA_PROCESS_ROLES=broker,controller
      - KAFKA_CONTROLLER_QUORUM_VOTERS=1@server-4:9093,2@server-5:9093,3@server-6:9093

      # --- 2. 리스너 설정 ---
      # 9092: Client(Producer/Consumer/UI) 통신
      # 9093: Controller/Broker 간 내부 통신
      - KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://{{ inventory_hostname }}:9092
      - KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT

      # --- 3. KRaft 초기화 및 데이터 ---
      - CLUSTER_ID={{ kafka_cluster_id }}
      - KAFKA_LOG_DIRS=/var/lib/kafka/data

      # --- 4. 안정성 옵션 (데이터 복제) ---
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=3
      - KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2

    volumes:
      - {{ kafka_data_dir }}:/var/lib/kafka/data

# ==========================================
# Kafka UI (Only on Server-4)
# ==========================================
{% if inventory_hostname == 'server-4' %}
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    restart: always
    network_mode: host  # 8080 포트로 서비스됨
    environment:
      - KAFKA_CLUSTERS_0_NAME=devops-project
      # UI가 접속할 브로커 목록 (하나가 죽어도 UI는 살도록 전체 명시)
      - KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=server-4:9092,server-5:9092,server-6:9092
      - DYNAMIC_CONFIG_ENABLED=true
{% endif %}
```

## 7. 실행 및 검증

### 7.1) 실행

```
ansible-playbook site.yml
```
```markdown
tskim@adminui-MacBookPro kafka % ansible-playbook -i inventory.ini site.yml

PLAY [Setup Kafka Cluster (KRaft Combined Mode) & UI] ***************************************************************

TASK [Gathering Facts] **********************************************************************************************
[WARNING]: Host 'server-5' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-5]
[WARNING]: Host 'server-6' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-6]
[WARNING]: Host 'server-4' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-4]

TASK [docker : Remove conflicting packages (podman, buildah)] *******************************************************
ok: [server-6]
ok: [server-5]
ok: [server-4]

TASK [docker : Add Docker CE repository] ****************************************************************************
ok: [server-6]
ok: [server-5]
ok: [server-4]

TASK [docker : Install Docker packages] *****************************************************************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [docker : Install Python Docker SDK (Required for Ansible docker_container module)] ****************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [docker : Start and Enable Docker service] *********************************************************************
ok: [server-6]
ok: [server-5]
ok: [server-4]

TASK [docker : Add 'vagrant' user to docker group] ******************************************************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [kafka_container : Create Kafka data directory with correct permissions] ***************************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [kafka_container : Create Docker Compose working directory] ****************************************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [kafka_container : Deploy docker-compose.yml template] *********************************************************
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [kafka_container : Tear down existing services (only if config changed)] ***************************************
skipping: [server-4]
skipping: [server-5]
skipping: [server-6]

TASK [kafka_container : Pull Docker images] *************************************************************************
changed: [server-5]
changed: [server-6]
changed: [server-4]

TASK [kafka_container : Start Kafka Cluster (and UI on server-4)] ***************************************************
changed: [server-6]
changed: [server-5]
changed: [server-4]

PLAY RECAP **********************************************************************************************************
server-4                   : ok=12   changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
server-5                   : ok=12   changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
server-6                   : ok=12   changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 7.2) CLI 검증 (Quorum 상태)

설치 후 `server-4` 에 접속하여 클러스터가 정상 적으로 합의(Quorum)를 이루었는지 확인합니다.

```sql
docker exec kafka kafka-metadata-quorum --bootstrap-server server-4:9092 describe --status
```
```makefile
[vagrant@server-4 ~]$ docker exec kafka kafka-metadata-quorum --bootstrap-server server-4:9092 describe --status
ClusterId:              MkU3OEVBNTcwNTJENDM2Qg
LeaderId:               3
LeaderEpoch:            32
HighWatermark:          53592
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   472
CurrentVoters:          [1,2,3]
CurrentObservers:       []
```

### 7-3) Kafka UI 확인

[http://server-4:8080](http://server-4:8080/) 으로 접속합니다.

![](/images/posts/kafka-kraft-cluster-ansible/img-2.png)

#### 'DevOps' 카테고리의 다른 글

| [Docker Container IP로 직접 접근하는 방법 - (docker-mac-net-connect)](docker-container-direct-ip-access.md) (0) | 2025.12.18 |
| --- | --- |
| [Starrocks 클러스터 구축하기 with Ansible](./starrocks-cluster-ansible.md) (1) | 2025.12.11 |
| [맥북에 리눅스 서버 5대 구성하기 - Ansible, Vagrant](https://tedi.tistory.com/48) (0) | 2025.12.10 |
| [Ansible을 사용한 Provisioning](https://tedi.tistory.com/39) (0) | 2025.12.09 |
| [Icinga2 Monitoring Basic](https://tedi.tistory.com/29) (4) | 2022.12.21 |