---
title: "[Data Engineering Lab] #2. Docker Container에 고정 IP 할당하기"
date: 2025-12-21
tags:
  - Docker
  - Network
  - DataEngineering
  - Lab
featured: false
draft: false
---

보통 Docker를 쓸 때는 `localhost:9092` `localhost:9093` 처럼 포트 번호로 서비스를 구분하곤 합니다. 하지만 저는 이 방식이 마음에 들지 않았습니다. 실제 운영 환경에서는 서버마다 각자의 IP가 있고, 그 IP를 기반으로 통신하기 때문입니다.

## 1. 물리적으로 분리된 서버

제가 굳이 고정 IP를 할당하려는 이유는 단순합니다. **진짜 클러스터답게 만들고 싶었기 때문** 입니다.

- **현실감 있는 아키텍처:** `localhost` 에 포트만 바꿔서 접속하는 건 가짜처럼 느껴졌습니다. `10.100.0.4x` 대역은 kafka, `10.100.0.2x` 대역은 Starrocks FE 식으로 **물리적 주소** 를 부여하고 싶었습니다.
- **설정 파일의 명확성:** Docker 포트 포워딩이 꼬이기 시작하면 설정 파일이 저저분해집니다. 고정 IP를 쓰면 실제 IDC 서버를 세팅하듯 깔끔한 환경 설정을 유지할 수 있습니다.

## 2. 도커 네트워크 생성 (10.100.0.0/24)

가장 먼저 우리만의 사설 대역을 생성합니다. 넉넉한 대역인 `10.100.0.0/16` 을 지정하겠습니다.

```lua
# create_network.sh
docker network create \
  --driver bridge \
  --subnet=10.100.0.0/24 \
  --gateway=10.100.0.1 \
  dataplatform-net
```

## 3. Mac 환경의 제약: "컨테이너로 IP로 핑이 안가요"

Linux와 달리 Docker Desktop for MAC은 가상 머신(VM)위에서 돌아가기 떄문에 Mac 호스트에서 Container IP(10.100.0.x)로 직접 접근하는 것이 기본적으로 차단되어 있습니다.

## 4. 해결책: docker-mac-net-connect

[Docker Container IP로 직접 접근하는 방법 - (docker-mac-net-connect)](docker-container-direct-ip-access.md)

## 5. Docker Compose에서 고정 IP 적용 예시

`docker-compose.yml`

```yaml
services:
  starrocks-fe-0:
    image: starrocks/fe-ubuntu:latest
    container_name: starrocks-fe-0
    networks:
      default:
        ipv4_address: 10.100.0.21  # "너는 오늘부터 21번 서버다"
    # ... 생략

networks:
  default:
    name: dataplatform-net
    external: true  # 미리 만든 네트워크 사용
```

## 마치며

이제 컨테이너들은 이름뿐만 아니라 **물리적인 주소** 까지 사용할 수 있게되었습니다. 맥북에서 어떤 컨테이너로든 ip로 들어갈 수 있습니다.
