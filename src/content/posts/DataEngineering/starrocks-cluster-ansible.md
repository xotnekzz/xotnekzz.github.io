---
title: StarRocks 클러스터 구축하기 with Ansible
date: 2025-12-11
tags:
  - StarRocks
  - Ansible
  - Cluster
  - DataEngineering
featured: false
draft: false
---

## 1. 들어가며

지난 포스팅 [[Ansible 실습] 맥북에 리눅스 서버 5대 구성하기](https://tedi.tistory.com/48) 에서는 Vagrant와 Ansible을 이용해 로컬 환경에 리눅스 서버 5대를 구축했습니다.

이번에는 이 인프라 위에 [StarRocks의 압도적 퍼포먼스 경험기](./starrocks-performance-experience.md) 에서 다룬 Starrocks 클러스터를 구축해보겠습니다. Starrocks는 분산 OLAP 데이터베이스로 FE노드의 고가용성(HA) 구성 BE 노드의 등록과정이 필요합니다.

이를 일일이 수동으로 설정하지 않고, Ansible Playbook을 작성하여 "코드 한 줄로 클러스터를 띄우는" 자동화 과정을 진행해보겠습니다.

## 2. 아키텍처 및 구성도



5대의 가상 서버 자원을 FE 3대(HA), BE 5대(전체)를 구성합니다. 모는 노드는 Docker로 배포하며, 네트워크 설정 편의를 `Host Network` 를 사용합니다.

- **Frontend(FE)**: 3대(`server-1`,`server-2`,`server-3`)
	- `server-1`: Leader
		- `server-2`, `server-4`: Follower
- **Backend(BE)**: 5대 전원 (`server-1` ~ `server-6`)
- **Network**: Vagrant Private Network (`192.168.56.0/24`)대역을 사용하여 노드 간 통신을 보장합니다.

## 3. 프로젝트 폴더 구조

전체 프로젝트는 역할(Role) 기반으로 관리하기 쉽도록 구성했습니다.

```csharp
├── rocky9
│   ├── ansible.cfg
│   ├── initial_setup.yml
│   ├── inventory.ini
│   └── Vagrantfile
├── roles
│   ├── base               # OS 튜닝 및 공통 설정
│   └── docker             # Docker 설치 및 설정
└── starrocks
    ├── ansible.cfg        # StarRocks 전용 Ansible 설정
    ├── hosts.ini          # 클러스터 인벤토리
    ├── playbook
    │   ├── cleanup.yml
    │   ├── restart_fe.yml
    │   ├── roles
    │   │   ├── base       # ../../roles/base와 별도로 StarRocks용 튜닝
    │   │   │   └── tasks
    │   │   │       └── main.yml
    │   │   ├── be         # Backend 배포 Role
    │   │   │   ├── tasks
    │   │   │   │   └── main.yml
    │   │   │   └── templates
    │   │   │       └── be.conf.j2
    │   │   └── fe         # Frontend 배포 Role
    │   │       ├── tasks
    │   │       │   └── main.yml
    │   │       └── templates
    │   │           └── fe.conf.j2
    │   ├── site.yml       # [Main] 배포 시나리오 정의
    │   └── update_be.yml
    ├── restart.sh
    ├── ssh_config         # SSH 접속 정보
    └── start.sh
```

## 4. 사전 준비: 연결 및 인벤토리 설정

### 1) hosts.ini

FE와 BE 그룹을 나누고, 노드 간 통신을 위한 네트워크 대역(prioirty_network_cidr)을 변수로 선언합니다.

```csharp
├── rocky9
│   ├── ansible.cfg
│   ├── initial_setup.yml
│   ├── inventory.ini
│   └── Vagrantfile
├── roles
│   ├── base               # OS 튜닝 및 공통 설정
│   └── docker             # Docker 설치 및 설정
└── starrocks
    ├── ansible.cfg        # StarRocks 전용 Ansible 설정
    ├── hosts.ini          # 클러스터 인벤토리
    ├── playbook
    │   ├── cleanup.yml
    │   ├── restart_fe.yml
    │   ├── roles
    │   │   ├── base       # ../../roles/base와 별도로 StarRocks용 튜닝
    │   │   │   └── tasks
    │   │   │       └── main.yml
    │   │   ├── be         # Backend 배포 Role
    │   │   │   ├── tasks
    │   │   │   │   └── main.yml
    │   │   │   └── templates
    │   │   │       └── be.conf.j2
    │   │   └── fe         # Frontend 배포 Role
    │   │       ├── tasks
    │   │       │   └── main.yml
    │   │       └── templates
    │   │           └── fe.conf.j2
    │   ├── site.yml       # [Main] 배포 시나리오 정의
    │   └── update_be.yml
    ├── restart.sh
    ├── ssh_config         # SSH 접속 정보
    └── start.sh
```

### 2) ssh_config

Ansible이 Vagrant VM에 올바르게 접속 할 수 있도록 포트와 키 경로를 지정합니다.

```bash
Host server-1
  HostName 127.0.0.1
  User vagrant
  Port 2222
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/tskim/Project/devops/rocky9/.vagrant/machines/server-1/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

Host server-2
  HostName 127.0.0.1
  User vagrant
  Port 2200
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/tskim/Project/devops/rocky9/.vagrant/machines/server-2/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

Host server-6
  HostName 127.0.0.1
  User vagrant
  Port 2201
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/tskim/Project/devops/rocky9/.vagrant/machines/server-6/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

Host server-4
  HostName 127.0.0.1
  User vagrant
  Port 2202
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/tskim/Project/devops/rocky9/.vagrant/machines/server-4/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

Host server-5
  HostName 127.0.0.1
  User vagrant
  Port 2203
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/tskim/Project/devops/rocky9/.vagrant/machines/server-5/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa
```

### 3) ansible.cfg

위에서 만든 `ssh_conifg` 를 사용하도록 설정합니다.

```
[defaults]
roles_path = ../roles
inventory = ./hosts.ini
host_key_checking = False

[ssh_connection]
# 방금 만든 ssh_config 파일을 사용하여 접속 정보를 가져옴
ssh_args = -F ./ssh_config -o ControlMaster=auto -o ControlPersist=60s
```

## 5. 구현 상세 1: Docker 설치 (Role: Docker)

Starrocks를 Docker로 배포할 것이기 때문에 모든 가상서버에 도커를 설치합니다.

Rocky Linux 9에 기본으로 `podman` 이 설치되어 있어 Docker와 충돌이 날 수 있어, 이를 제거하고 Docker CE를 설치합니다.

또한 Ansible 제어를 위해 Python SDK도 설치합니다.

`roles/docker/tasks/main.yml`

```yaml
---
- name: Remove conflicting packages (podman, buildah)
  dnf:
    name:
      - podman
      - buildah
    state: absent

- name: Add Docker CE repository
  get_url:
    url: https://download.docker.com/linux/centos/docker-ce.repo
    dest: /etc/yum.repos.d/docker-ce.repo

- name: Install Docker packages
  dnf:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-compose-plugin
      - python3-pip  # Ansible 모듈용
    state: present

- name: Install Python Docker SDK (Required for Ansible docker_container module)
  pip:
    name: docker
    executable: pip3

- name: Start and Enable Docker service
  service:
    name: docker
    state: started
    enabled: yes

- name: Add 'vagrant' user to docker group
  user:
    name: vagrant
    groups: docker
    append: yes
```

## 6. 구현 상세 2: OS 튜닝 및 공통 설정 (Role: Base)

DB 성능 최적화와 안정성을 위해 Swap 메모리를 비활성화하고, 분산 시스템 필수 요소인 시간 동기화(Chrony)를 설정합니다.  
BE 노드를 위해 `vm.max_map_count` 값도 조정합니다.

`starrocks/playbook/roles/base/tasks/main.yml`

```yaml
---
- name: Disable Swap (Runtime)
  command: swapoff -a
  when: ansible_facts['swaptotal_mb'] > 0

- name: Disable Swap (Permanent)
  replace:
    path: /etc/fstab
    regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
    replace: '# \1'

- name: Set vm.max_map_count (Required for BE)
  sysctl:
    name: vm.max_map_count
    value: '2000000'
    state: present
    reload: yes

#  Chrony 설치 (시간 동기화)
- name: Install chrony
  package:
    name: chrony
    state: present

- name: Enable and start chronyd
  service:
    name: chronyd
    state: started
    enabled: yes

#  강제로 시간 동기화 수행 (즉시 보정)
- name: Force time synchronization
  shell: chronyc -a makestep
  ignore_errors: yes # 이미 동기화된 경우 에러 무시
```

## 7. 구현 상세 3: Frontend(FE)배포 (Role: FE)

FE 배포의 핵심을 Leader와 Follower의 역할 분배입니다. `fe.conf` 설정을 배포하고, Follwer 노드는 기동 후 자동으로 Leader에게 자신을 등록하도록 구성합니다.

`starrocks/playbook/role/fe/tasks/main.yml`

```yaml
---
- name: Create FE Directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /data/starrocks/fe/meta
    - /data/starrocks/fe/conf
    - /data/starrocks/fe/log

- name: Deploy fe.conf
  template:
    src: fe.conf.j2
    dest: /data/starrocks/fe/conf/fe.conf

- name: Pre-register this Follower to Leader
  delegate_to: server-1  # 이 작업은 server-1에서 실행
  shell: |
    # 리더(server-1)에게 접속해서 현재 노드(inventory_hostname)를 등록
    docker exec starrocks-fe mysql -h 127.0.0.1 -P9030 -uroot -e "ALTER SYSTEM ADD FOLLOWER '{{ inventory_hostname }}:9010';"
  # 리더 자신은 등록할 필요 없으므로 제외
  when: inventory_hostname != 'server-1'
  ignore_errors: true  # 이미 등록되어 있으면 에러 무시

- name: Run FE Container
  docker_container:
    name: starrocks-fe
    image: starrocks/fe-ubuntu:latest
    network_mode: host
    restart_policy: unless-stopped
    hostname: "{{ inventory_hostname }}"
    command: >
      {% if inventory_hostname == 'server-1' %}
      /opt/starrocks/fe/bin/start_fe.sh
      {% else %}
      /opt/starrocks/fe/bin/start_fe.sh --helper server-1:9010
      {% endif %}
    recreate: yes
    volumes:
      - /data/starrocks/fe/meta:/opt/starrocks/fe/meta
      - /data/starrocks/fe/conf/fe.conf:/opt/starrocks/fe/conf/fe.conf
      - /data/starrocks/fe/log:/opt/starrocks/fe/log
    env:
      TZ: "Asia/Seoul"
      HOST_TYPE: "FQDN"
      JAVA_OPTS_FE: "-Dfrontend_ip={{ hostvars[inventory_hostname].private_ip }}"
```

`starrocks/playbook/roles/fe/tempaltes/fe.copf/j2`

```
LOG_DIR = ${STARROCKS_HOME}/log
meta_dir = /opt/starrocks/fe/meta
priority_networks = {{ hostvars[inventory_hostname].private_ip }}

# Ports
http_port = 8030
rpc_port = 9020
query_port = 9030
edit_log_port = 9010
```

## 8. 구현 상세4: Backend(BE)배포 (Role: BE)

BE 노드는 FE와 동일한 서버에 뜰 때 포트 충돌이 나지 않도록 포트를 변경해주어야 합니다.

`starrocks/playbook/roles/be/tasks/main.yml`

```yaml
---
- name: Create BE Directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /data/starrocks/be/storage
    - /data/starrocks/be/conf
    - /data/starrocks/be/log

- name: Deploy be.conf
  template:
    src: be.conf.j2
    dest: /data/starrocks/be/conf/be.conf

- name: Run BE Container
  docker_container:
    name: starrocks-be
    image: starrocks/be-ubuntu:latest
    network_mode: host
    privileged: true  # 성능 최적화
    restart_policy: unless-stopped
    hostname: "{{ inventory_hostname }}"
    command: >
      /opt/starrocks/be/bin/start_be.sh server-1:9010
    recreate: yes
    volumes:
      - /data/starrocks/be/storage:/opt/starrocks/be/storage
      - /data/starrocks/be/conf/be.conf:/opt/starrocks/be/conf/be.conf
      - /data/starrocks/be/log:/opt/starrocks/be/log
    env:
      TZ: "Asia/Seoul"
      HOST_TYPE: "FQDN"
      JAVA_OPTS_BE: "-Dbe_host={{ inventory_hostname }}"
      BE_HOST: "{{ inventory_hostname }}"
```

`starrocks/playbook/roles/be/templates/be.conf.j2`

```
storage_root_path = /opt/starrocks/be/storage
priority_networks = 192.168.56.0/24
# FE와 같은 서버일 경우 포트 충돌 방지
be_port = 9060
web_server_port = 8040
heartbeat_service_port = 9050
brpc_port = 8060
```

## 9. 구현 상세 5: 오케스트레이션 (Site,yml)

가장 핵심인 메인 플레이북입니다. **OS 튜닝 및 공통 설정 -> Leader FE 배포 -> Leader 상태 확인 -> Follower FE 배포 및 조인 -> BE 배포 -> BE 리더에 조인**

```yaml
---
# 1. OS 튜닝 및 공통 설정
- name: Apply Base Tuning
  hosts: starrocks_cluster
  become: true
  roles:
    - base

# 2. [Step 1] Leader FE 배포 (server-1만 먼저 실행)
- name: Deploy Leader FE
  hosts: server-1
  become: true
  roles:
    - fe
  vars:
    fe_role: "leader"  # Role 내부에서 분기 처리용 변수

# 3. [Step 2] Leader 상태 확인 (Health Check)
- name: Wait for Leader FE Ready
  hosts: server-1
  become: true
  tasks:
    - name: Wait for TCP port 9030
      wait_for:
        port: 9030
        host: '127.0.0.1'
        delay: 5
        timeout: 120

# 4. [Step 3] Follower FE 배포 및 조인 (Leader가 뜬 후 실행)
- name: Deploy Follower FEs
  hosts: fe_servers:!server-1
  become: true
  roles:
    - fe
  vars:
    fe_role: "follower"

# 5. [Step 4] BE 배포
- name: Deploy BE Nodes
  hosts: be_servers
  become: true
  roles:
    - be

# 6. [Step 5] BE 노드 Leader FE에 등록
- name: Register BE Nodes to Leader
  hosts: server-1  # 등록 명령은 Leader FE에서 수행
  become: true
  gather_facts: false # server-1 팩트는 이미 수집되었으므로 생략 가능
  vars:
    fe_query_port: 9030
    be_heartbeat_port: 9050
  tasks:
    - name: Add Backend nodes to StarRocks Cluster
      shell: |
        docker exec starrocks-fe mysql -h 127.0.0.1 -P9030 -uroot -e "ALTER SYSTEM ADD BACKEND '{{ hostvars[item]['ansible_host'] | default(item) }}:{{ be_heartbeat_port }}'"
      loop: "{{ groups['be_servers'] }}"
      register: add_be_result
      # 이미 등록된 경우 에러를 무시하거나, 멱등성을 위해 실패 처리 조건을 완화
      failed_when:
        - add_be_result.rc != 0
        - '"Same backend already exists" not in add_be_result.stderr'
        - '"Same backend already exists" not in add_be_result.stdout'
```

## 11. 배포하기

```bash
cd starrocks/

ansible-playbook -i starrocks/hosts.ini starrocks/playbook/site.yml
```

명령어를 실행하면 서버 5대 Starrocks 클러스터 세팅을 시작합니다.

```markdown
PLAY [Apply Base Tuning] **************************************************************************************

TASK [Gathering Facts] ****************************************************************************************
[WARNING]: Host 'server-5' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-5]
[WARNING]: Host 'server-6' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-6]
[WARNING]: Host 'server-4' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-4]
[WARNING]: Host 'server-1' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-1]
[WARNING]: Host 'server-2' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
ok: [server-2]

TASK [base : Disable Swap (Runtime)] **************************************************************************
skipping: [server-1]
skipping: [server-2]
skipping: [server-4]
skipping: [server-5]
skipping: [server-6]

TASK [base : Disable Swap (Permanent)] ************************************************************************
ok: [server-5]
ok: [server-4]
ok: [server-1]
ok: [server-6]
ok: [server-2]

TASK [base : Set vm.max_map_count (Required for BE)] **********************************************************
[WARNING]: Deprecation warnings can be disabled by setting \`deprecation_warnings=False\` in ansible.cfg.
[DEPRECATION WARNING]: Importing 'to_native' from 'ansible.module_utils._text' is deprecated. This feature will be removed from ansible-core version 2.24. Use ansible.module_utils.common.text.converters instead.
ok: [server-1]
ok: [server-6]
ok: [server-2]
ok: [server-5]
ok: [server-4]

TASK [base : Install chrony] **********************************************************************************
ok: [server-5]
ok: [server-6]
ok: [server-2]
ok: [server-1]
ok: [server-4]

TASK [base : Enable and start chronyd] ************************************************************************
ok: [server-6]
ok: [server-5]
ok: [server-4]
ok: [server-2]
ok: [server-1]

TASK [base : Force time synchronization] **********************************************************************
changed: [server-2]
changed: [server-6]
changed: [server-4]
changed: [server-5]
changed: [server-1]

PLAY [Deploy Leader FE] ***************************************************************************************

TASK [Gathering Facts] ****************************************************************************************
ok: [server-1]

TASK [fe : Create FE Directories] *****************************************************************************
changed: [server-1] => (item=/data/starrocks/fe/meta)
ok: [server-1] => (item=/data/starrocks/fe/conf)
changed: [server-1] => (item=/data/starrocks/fe/log)

TASK [fe : Deploy fe.conf] ************************************************************************************
ok: [server-1]

TASK [fe : Pre-register this Follower to Leader] **************************************************************
skipping: [server-1]

TASK [fe : Run FE Container] **********************************************************************************
changed: [server-1]

PLAY [Wait for Leader FE Ready] *******************************************************************************

TASK [Gathering Facts] ****************************************************************************************
ok: [server-1]

TASK [Wait for TCP port 9030] *********************************************************************************
ok: [server-1]

PLAY [Deploy Follower FEs] ************************************************************************************

TASK [Gathering Facts] ****************************************************************************************
ok: [server-2]
ok: [server-4]

TASK [fe : Create FE Directories] *****************************************************************************
changed: [server-4] => (item=/data/starrocks/fe/meta)
changed: [server-2] => (item=/data/starrocks/fe/meta)
ok: [server-2] => (item=/data/starrocks/fe/conf)
ok: [server-4] => (item=/data/starrocks/fe/conf)
changed: [server-2] => (item=/data/starrocks/fe/log)
changed: [server-4] => (item=/data/starrocks/fe/log)

TASK [fe : Deploy fe.conf] ************************************************************************************
ok: [server-4]
ok: [server-2]

TASK [fe : Pre-register this Follower to Leader] **************************************************************
changed: [server-2 -> server-1]
changed: [server-4 -> server-1]

TASK [fe : Run FE Container] **********************************************************************************
changed: [server-4]
changed: [server-2]

PLAY [Deploy BE Nodes] ****************************************************************************************

TASK [Gathering Facts] ****************************************************************************************
ok: [server-1]
ok: [server-5]
ok: [server-4]
ok: [server-6]
ok: [server-2]

TASK [be : Create BE Directories] *****************************************************************************
changed: [server-5] => (item=/data/starrocks/be/storage)
changed: [server-6] => (item=/data/starrocks/be/storage)
changed: [server-1] => (item=/data/starrocks/be/storage)
changed: [server-2] => (item=/data/starrocks/be/storage)
changed: [server-4] => (item=/data/starrocks/be/storage)
ok: [server-6] => (item=/data/starrocks/be/conf)
ok: [server-1] => (item=/data/starrocks/be/conf)
ok: [server-5] => (item=/data/starrocks/be/conf)
ok: [server-2] => (item=/data/starrocks/be/conf)
ok: [server-4] => (item=/data/starrocks/be/conf)
changed: [server-6] => (item=/data/starrocks/be/log)
changed: [server-1] => (item=/data/starrocks/be/log)
changed: [server-5] => (item=/data/starrocks/be/log)
changed: [server-2] => (item=/data/starrocks/be/log)
changed: [server-4] => (item=/data/starrocks/be/log)

TASK [be : Deploy be.conf] ************************************************************************************
ok: [server-1]
ok: [server-2]
ok: [server-5]
ok: [server-6]
ok: [server-4]

TASK [be : Run BE Container] **********************************************************************************
changed: [server-5]
changed: [server-1]
changed: [server-4]
changed: [server-6]
changed: [server-2]

PLAY [Register BE Nodes to Leader] ****************************************************************************

TASK [Add Backend nodes to StarRocks Cluster] *****************************************************************
changed: [server-1] => (item=server-1)
changed: [server-1] => (item=server-2)
changed: [server-1] => (item=server-4)
changed: [server-1] => (item=server-5)
changed: [server-1] => (item=server-6)

PLAY RECAP ****************************************************************************************************
server-1                   : ok=17   changed=6    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
server-2                   : ok=15   changed=6    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
server-4                   : ok=15   changed=6    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
server-5                   : ok=10   changed=3    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
server-6                   : ok=10   changed=3    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

이렇게 나오면 성공!

## 11. 핵심 설정 Deep Dive: FQDN과 Prioirty Network

Starrocks 클러스터 구축할 때 FE, BE 노드가 서로를 어떻게 식별하는지 아는 것이 중요합니다.

### 1) IP 대신 FQDN(Fully Qualified Domain Name) 사용하기

```bash
...
env:
  HOST_TYPE: "FQDN" # IP 대신 호스트네임으로 클러스터 등록
```

서버의 IP가 바뀌더라도 `/etc/hosts` 또는 DNS만 업데이트하면 클러스터 설정을 고칠 필요가 없습니다.

### 2) Priority Networks 지정

Starocks가 자동으로 IP를 감지하게 하면 Doker 내부 IP 또는 Vagrant NAT IP를 잡아서 노드간 통신이 단절 될 수 있습니다.

- `fe.conf`, `be.conf` 템플릿에 `prioirity_networks` 를 명시하여 사용할 대역을 강제했습니다.
```makefile
...
# 192.168.56.x 대역을 사용하는 인터페이스를 무조건 사용해라!
priority_networks = 192.168.56.0/24
```

### 3) FE의 frontend_address 바인딩

```yaml
# roles/fe/tasks/main.yml
...
env:
  # 내 IP는 inventory에 적힌 private_ip야! 라고 알려줌
  JAVA_OPTS_FE: "-Dfrontend_ip={{ hostvars[inventory_hostname].private_ip }}"
```

FE 노드는 자신의 IP를 정확히 알고 있어야 리더 선출 투표나 팔로워 통신에 참여할 수 있습니다. docker_container 태스크에서 frontend_ip를 명시적으로 주입해 주었습니다.

## 12. 클러스터 확인

클러스터 배포가 완료되면 `http://192.168.56.11:8030` 에 접속하여 FE 노드의 클러스터 정보(메타데이터)를 확인할 수 있습니다.

![](/images/posts/starrocks-cluster-ansible/img-2.png)

또는 FE 노드에 접속하여 확인 가능합니다.

- FE (HA)
```sql
# mysql클라이언트로  FE노드(9030) 접속
SHOW FRONTENDS;
```
- BE
```sql
# mysql클라이언트로  FE노드(9030) 접속
SHOW BACKENDS;
```
