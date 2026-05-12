---
title: Docker Container IP로 직접 접근하는 방법
description: 맥북(macOS)환경에서 도커를 사용할 때 컨테이너 IP(172.17.0.x) 로는 직접 접근하지 못합니다. 그래서 매번 -p 옵션으로 포트 포워딩을 통해 localhost(127.0.0.1)로 접속해야만 했습니다.
date: 2025-12-18
tags:
  - Docker
  - Network
  - DataEngineering
featured: false
draft: false
---

맥북(macOS)환경에서 도커를 사용할 때 **컨테이너 IP(172.17.0.x)** 로는 직접 접근하지 못합니다. 그래서 매번 `-p` 옵션으로 포트 포워딩을 통해 localhost(127.0.0.1)로 접속해야만 했습니다.

[**docker-mac-net-connect**](https://github.com/chipmk/docker-mac-net-connect "docker-mac-net-connect") 을 사용하면 macOS에서도 컨테이너 IP에 직접 접근할 수 있습니다.



출처 - https://github.com/chipmk/docker-mac-net-connect

\`docker-mac-net-connect\`는 macOS 호스트에서 실행되어 \`Mac\`과 \`Docker Desktop Linux VM\` 간의 링크 역할을 하는 가상 네트워크 인터페이스( utun )를 생성합니다.

#### 어디에 쓰일까?

> 1. kafka, zookeeper 등 클러스터 통시을 하는 서비스를 띄울 때  
> 2. 마이크로서비스(MSA) 여러 개를 띄웠는데 포트 번호 충돌나서 매번 바꿔야할 때  
> 3. 스크립트나 테스트 코드에서 컨테이너 IP를 동적으로 받아와서 접속해야 할 때

위와 같은 상황을 내 개발 환경에서 테스트해보고 싶을 때 유용하게 쓰일 수 있습니다.

#### 설치 방법

```bash
# 1. 탭 추가 및 설치
brew install chipmk/tap/docker-mac-net-connect

# 2. 서비스 실행 (sudo 필요)
sudo brew services start chipmk/tap/docker-mac-net-connect

# 3. Ping 날리기
ping 10.100.0.21
```

#### 🚨 Ping이 안날려진다면

```
ERROR: ... Failed to setup VM: failed to pull setup image:
Error response from daemon: client version 1.41 is too old.
Minimum supported API version is 1.44, please upgrade your client to a newer version
```

Docker Desktop 최신버전에서 docker-mac-net-connect 플러그인 내부의 docker 버전과 호환되지 않아 동작하지 않을 수 있습니다.

#### 해결 방법

**1. <key>EnvironmentVariables</key> 블럭 추가하여 도커 버전 명시**

```bash
sudo vi /opt/homebrew/Cellar/docker-mac-net-connect/*/homebrew.mxcl.docker-mac-net-connect.plist
```

**2. 서비스 재시작**

```sql
sudo brew services stop chipmk/tap/docker-mac-net-connect
sudo brew services start chipmk/tap/docker-mac-net-connect
```

**3. Ping 날리기**

```python
> ping 10.100.0.21

PING 10.100.0.21 (10.100.0.21): 56 data bytes
64 bytes from 10.100.0.21: icmp_seq=0 ttl=63 time=2.499 ms
64 bytes from 10.100.0.21: icmp_seq=1 ttl=63 time=2.501 ms
64 bytes from 10.100.0.21: icmp_seq=2 ttl=63 time=3.369 ms
64 bytes from 10.100.0.21: icmp_seq=3 ttl=63 time=1.032 ms
```

