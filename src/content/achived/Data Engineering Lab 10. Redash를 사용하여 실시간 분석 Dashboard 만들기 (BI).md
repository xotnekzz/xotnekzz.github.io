---
title: "[Data Engineering Lab] #10. Redash를 사용하여 실시간 분석 Dashboard 만들기 (BI)"
source: "https://tedi.tistory.com/63"
author:
  - "[[Tedi__]]"
published: 2026-01-26
created: 2026-05-12
description: "0. 서론우리는 지금까지 꽤 먼길을 달려왔습니다. MacBook의 리소스 한계를 극복하기 위해 Vagrant를 버리고 Docker로 전환했고,실제 서버환경 처럼 사용하기 위해 컨테이너마다 고정 IP를 부여했습니다.그리고 MariaDB의 변화를 감지해 StarRocks까지 0.1초 단위로 데이터를 밀어 넣는 실시간 CDC 파이프라인을 설계했습니다. 하지만 데이터 엔지니어링의 끝은 '적재'가 아닙니다. 아무리 정교한 파이프라인이라도 숫자가 담긴 테이블에 머물러 있다면 의사결정자에게는 데이터 조각일 뿐입니다.이번 시리즈의 마지막 포스팅에서는 StarRocks에 쌓이는 실시간 데이터를 Redash BI와 연동하여, 주문 즉시 지표가 요동치는 운영 대시보드를 만들어 보겠습니다.1. Redash 선택 이유대시보드 .."
tags:
  - "clippings"
---
## 0\. 서론

우리는 지금까지 꽤 먼길을 달려왔습니다. MacBook의 리소스 한계를 극복하기 위해 Vagrant를 버리고 Docker로 전환했고,  
실제 서버환경 처럼 사용하기 위해 컨테이너마다 고정 IP를 부여했습니다.

그리고 MariaDB의 변화를 감지해 StarRocks까지 0.1초 단위로 데이터를 밀어 넣는 실시간 CDC 파이프라인을 설계했습니다.

하지만 데이터 엔지니어링의 끝은 '적재'가 아닙니다. 아무리 정교한 파이프라인이라도 숫자가 담긴 테이블에 머물러 있다면 의사결정자에게는 데이터 조각일 뿐입니다.

이번 시리즈의 마지막 포스팅에서는 **StarRocks** 에 쌓이는 실시간 데이터를 Redash BI와 연동하여, 주문 즉시 지표가 요동치는 운영 대시보드를 만들어 보겠습니다.

## 1\. Redash 선택 이유

대시보드 도구(BI Tool)에는 Tableau, Power BI, Metabase, Apache Superset, Redash 등 다양한 선택지가 있습니다.  
이번 포스팅에서는 Redash를 중점으로 다루고자 합니다.

##### 1\. 빠르게 띄워볼 수 있다

Redash는 오픈소스로 Docker를 통해 쉽게 띄울 수 있습니다.

##### 2\. SQL\_first

SQL 쿼리만으로 단 몇 분만에 대시보드를 제작할 수 있습니다.

##### 3\. StarrRocks 커넥터지원

StarRocks는 MySQL프로토콜을 지원하여, 해당 커넥터로 StarRocks를 대시보드에서 사용할 수 있습니다.

## 2\. Redash 인프라 구축하기

![](https://blog.kakaocdn.net/dna/dKrQx7/dJMcad1QlPV/AAAAAAAAAAAAAAAAAAAAABgm5i4YF9br2fR5DfiZmCPV774uHra-ztIorC9ySXrP/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=L8ZwszBwEtmJnj1gS%2FUowyYlbJU%3D)

우리 랩(Lab)의 핵심은 고정 IP 기반의 컨테이너 네트워크입니다. Redash 역시 미리 생성해둔 `dataplatfor-net` 대역에 배치하여 다른 서비스들과 원할하게 통신하도록 설정합니다. 고정 IP는 `10.100.0.5x` 대역을 사용합니다.

## 2.1. Docker Compose

REDASH\_COOKIE\_SECRET은 모든 서비스가 공유해야 하는 필수 보안 값입니다. 이를 공용 설정으로 묶어 실수를 방지합니다.

```yaml
version: "3.7"

# 공용 설정 정의
x-redash-common: &x-redash-common
  image: redash/redash:10.1.0.b50633
  environment:
    PYTHONUNBUFFERED: 1
    REDASH_LOG_LEVEL: "INFO"
    REDASH_REDIS_URL: "redis://10.100.0.52:6379/0"
    REDASH_DATABASE_URL: "postgresql://postgres:password123@10.100.0.53/postgres"
    REDASH_COOKIE_SECRET: "redash-lab-secret" # 모든 서비스가 이 값을 공유합니다.
  networks:
    default:

services:
  # 1. Redash Main Server
  redash-server:
    <<: *x-redash-common
    container_name: redash-server
    command: server
    ports:
      - "5000:5000"
    networks:
      default:
        ipv4_address: 10.100.0.51

  # 2. Redash Scheduler
  redash-scheduler:
    <<: *x-redash-common
    container_name: redash-scheduler
    command: scheduler
    networks:
      default:
        ipv4_address: 10.100.0.54

  # 3. Redash Worker
  redash-worker:
    <<: *x-redash-common
    container_name: redash-worker
    command: worker
    networks:
      default:
        ipv4_address: 10.100.0.55

  # 4. Redis (Cache & Queue)
  redash-redis:
    image: redis:6.2-alpine
    container_name: redash-redis
    networks:
      default:
        ipv4_address: 10.100.0.52

  # 5. PostgreSQL (Metadata Storage)
  redash-postgres:
    image: postgres:12-alpine
    container_name: redash-postgres
    environment:
      POSTGRES_PASSWORD: "password123"
    networks:
      default:
        ipv4_address: 10.100.0.53
    volumes:
      - redash-data:/var/lib/postgresql/data

networks:
  default:
    name: dataplatform-net
    external: true

volumes:
  redash-data:
```

## 2.2. Redash Metadata 테이블 생성하기

워커 로그에서 relation "queries" does not exist 같은 에러가 발생한다면, PostgreSQL 내부에 테이블이 생성되지 않았기 때문입니다. 서버가 실행 중인 상태에서 아래 명령어를 꼭 실행해야하합니다.

```applescript
# Redash 메타데이터 테이블 생성
docker exec -it redash-server /app/manage.py database create_tables
```

## 3\. Redash 접속

설정한 고정 IP/Port를 접속하면 Redash 계정 생성 창이 나옵니다. 계정 설정을 마치고 로그인하면 아래와 같은 메인화면이 나옵니다.

[http://10.100.0.51:5000/](http://10.100.0.51:5000/)

![](https://blog.kakaocdn.net/dna/bssCjx/dJMcabbV43f/AAAAAAAAAAAAAAAAAAAAAIFNLTcNgWBNDiG-B_Lz55bb7xAzeRlJFba6KmAtIL7P/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=QvHe1aOHZwnnEWuZE7dO7zsFdVk%3D)

## 4\. Redash에 StarRocks 커넥터 설정하기

Settings / Data Sources 메뉴에서 MySQL 타입을 선택후 이전에 띄운 StarRocks연결정보를 입력하여 커넥터를 설정합니다.

![](https://blog.kakaocdn.net/dna/nR2PQ/dJMcahb8T4K/AAAAAAAAAAAAAAAAAAAAAM5Z5PVUaDxb7eDKno3R8KwMn5H-qT_iLe_WuNFh5JLY/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=pVIOc9Qjsq2PG4SE3zDPb3HzCZk%3D)

## 5\. 실시간 분석용 쿼리 작성 및 대시보드 등록

이전 포스팅에서 작업했던 StarRocks의 Routine Load 기능을 통해 StarRocks에 Mariadb의 실시간으로 업데이트되는 데이터를 카프카를 통해 가져와 업데이트되고 있습니다.  
  
이 테이블을 활용하여 실시간 분석 대시보드를 만들어 보도록 하겠습니다.  
  
먼저 Redash 대시보드를 만들기 위해서는 쿼리를 생성해야합니다.

### 5.1 쿼리 생성

http://10.100.0.51:5000/queries/new 또는 쿼리 메뉴를 통해 새로운 분석 쿼리를 추가합니다.  

```bash
SELECT 
    COUNT(order_id) AS "오늘의 총 주문 건수",
    SUM(order_amount) AS "오늘의 총 매출",
    MAX(order_date) AS "최근 업데이트"
FROM demo_db.orders_analytics
WHERE order_date >= CURDATE();
```

실시간으로 데이터가 변화하는 것을 감지하기 위해 위 쿼리를 사용하겠습니다.  

![](https://blog.kakaocdn.net/dna/expVqn/dJMcaaKRZpQ/AAAAAAAAAAAAAAAAAAAAAHxYHrTXl2WDDZpRJgG9zEET7WqD5q_RIIV5170Kskvz/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=cqhPUviYQNdrQJuNQWz4s3Lhze4%3D)

상단의 New Query 부분을 눌러 이름을 변경할 수 있으며, 위의 사진과같이 쿼리를 만들어 실행 후 Save 버튼을 눌러 쿼리를 저장합니다.

Add Visualization 버튼을 눌러 쿼리데이터를 가지고 시각화 차트를 생성할 수도 있습니다.

### 5.2 대시보드 생성 및 쿼리 연동하기

http://10.100.0.51:5000/dashboards 또는 왼쪽 대시보드 눌러 대시보드 화면으로 이동합니다.

오른쪽 New Dashboard 를 눌러 새로운 대시보드를 생성합니다.

![](https://blog.kakaocdn.net/dna/k8eLi/dJMcafFpPXe/AAAAAAAAAAAAAAAAAAAAAJCDNzKnsXHZP_JSoczdIJkTqUY8i4PyAI521KsdRRKi/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=Ewt2Yl5rKmFLFzT%2FCcCCYhQqK6A%3D)

대시보드를 누른 후 오른쪽 상단 메뉴 버튼에서 Edit을 누른 후 하단의 Add Widget을 눌러 앞서 만든 쿼리 데이터를 불러와 대시보드에 추가합니다.  
  
저는 포스팅에 제공하지 않았지만 미리 만들어둔 쿼리들을 사용하여 위젯을 추가하겠습니다.

![](https://blog.kakaocdn.net/dna/dUaLSS/dJMcacu9aYu/AAAAAAAAAAAAAAAAAAAAAE2YZ0_lFL2GZYYwS6YIXg_vwQUZkqjpB4CLH_5yhl_m/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=Q0eBg7u%2FWmBIfARp9NOZFigacfM%3D)

분석용 쿼리를 추가하여 아래와 같이 실시간 대시보드를 구축하였습니다. 리프레시 버튼을 눌러 실시간으로 데이터가 변화하는 대시보드가 완성되었습니다.

![](https://blog.kakaocdn.net/dna/bo1TDz/dJMcajgHpzj/AAAAAAAAAAAAAAAAAAAAANazS7RK_l4IiJjrUJ8SVFSwXLNKSsm_pxOVnhgqjqKe/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1780239599&allow_ip=&allow_referer=&signature=tVnxnH%2Bh%2BZe46MV9XAOvP4yavb4%3D)

## 6\. 마치며: 데이터 엔지니어링 랩을 졸업하며

"맥북 한 대라는 한정된 운동장"에서 시작한 도전이 드디어 결실을 보았습니다.

- **인프라:** 고정 IP와 Docker로 베어메탈급 직관성 확보.
- **파이프라인:** Debezium → Kafka → StarRocks의 강력한 CDC 흐름 완성.
- **시각화:** Redash를 통해 1초 지연의 실시간 가치 증명.

데이터가 흐르고, 그 흐름이 숫자로 바뀌어 화면에 실시간으로 찍히는 과정을 직접 구축해 보는 경험은 그 무엇과도 바꿀 수 없는 엔지니어의 자산입니다.

#### 'Data Engineering' 카테고리의 다른 글

| [\[Data Engineering Lab\] #9. Routine Load를 사용하여 Kafka 데이터를 StarRocks에 실시간으로 적재하기](https://tedi.tistory.com/62) (0) | 2026.01.16 |
| --- | --- |
| [\[Data Engineering Lab\] #8. Debezium 커넥터 등록하기: MariaDB와 Kafka CDC 구현하기](https://tedi.tistory.com/61) (1) | 2026.01.13 |
| [\[Data Engineering Lab\] #7. 실시간 이커머스 트래픽 생성기](https://tedi.tistory.com/60) (0) | 2026.01.02 |
| [\[Data Engineering Lab\] #6. 실시간 이커머스 CDC 파이프라인 설계](https://tedi.tistory.com/59) (0) | 2025.12.28 |
| [\[Data Engineering Lab\] #5. CDC의 시작: Binlog 활성화된 MariaDB 띄우기 (docker)](https://tedi.tistory.com/58) (0) | 2025.12.27 |