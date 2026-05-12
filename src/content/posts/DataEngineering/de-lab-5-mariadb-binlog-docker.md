---
title: "[Data Engineering Lab] #5. CDC의 시작 — Binlog 활성화된 MariaDB 띄우기 (Docker)"
description: 안녕하세요. 이번 포스팅은 OLTP DB인 MariaDB를 도커로 띄워볼건데요,CDC(capture data capture)활용을 고려하여 Binlog를 활성화하여 구축해보도록 하겠습니다.1.
date: 2025-12-27
tags:
  - CDC
  - MariaDB
  - Binlog
  - Docker
  - DataEngineering
  - Lab
featured: false
draft: false
---

안녕하세요. 이번 포스팅은 OLTP DB인 MariaDB를 도커로 띄워볼건데요,

CDC(capture data capture)활용을 고려하여 Binlog를 활성화하여 구축해보도록 하겠습니다.

## 1. CDC와 Binlog는 무엇인가?

먼저 **CDC** 는 Capture Data Capture의 약자로 데이터베이스 에서 발생하는 삽입(Insert), 수정(Update), 삭제(Delete)와 같은 변경을 실시간으로 감지하여 다른 시스템으로 전달하는 기술 입니다.

**Binlog** 는 Binary Log의 약자로 데이터베이스에서 일어나는 모든 변경 사항(Insert, Update, Delete)을 기록하는 로그파일 입니다. 기본설정은 비활성화 되어있기 때문에 MariaDB를 띄울 때 설정을 활성화 하겠습니다.

MariaDB의 변경사항이 있을 때마다 *SELECT* 쿼리를 날린다면 실시간성이 떨어지고, DB에 부하를 줄 수 있으므로 CDC는 Binlog를 읽고 Kafka와 같은 이벤트 스트리밍 플랫폼에 전달합니다.

## 2. 고정 IP 설정

MariaDB도 docker-mac-net-connect 설정이 되어있으면 맥에서도 컨테이너 IP에 직접 접근할 수 있습니다.

> IP: 10.100.0.11  
> Port: 3306

## 3. Binlog 활성화하기 (cdc.cnf)

MariaDB 컨테이너가 뜰 때 Binlog를 활성화하는 설정파일을 작성합니다.

```
# mariadb/conf.d/cdc.cnf
[mysqld]
server-id         = 223344
log_bin           = mysql-bin
binlog_format     = ROW
binlog_row_image  = FULL
expire_logs_days  = 10
```

> **server-id:** 클러스터 내에서 유일한 ID여야 합니다.  
> **binlog_format=ROW:** 가장 중요한 설정입니다. 쿼리 문장이 아니라 변경된 '데이터 값' 자체를 기록하게 하여 CDC 엔진이 정확한 데이터를 읽을 수 있게 합니다.  
> **expire_logs_days:** 로그가 무한정 커져서 하드를 다 채우지 않도록 10일 뒤에는 지우도록 설정했습니다.

.

## 4. Docker Compose

```bash
version: '3.8'

services:
  mariadb:
    image: mariadb:10.6
    container_name: mariadb-source
    restart: always
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_USER={user}
      - MYSQL_PASSWORD={passwoard}
      - MYSQL_DATABASE=demo_db
    volumes:
      - ./mariadb/conf.d:/etc/mysql/conf.d
    networks:
      - default
    # --- MariaDB 메모리 제한 설정 ---
    deploy:
      resources:
        limits:
          memory: 2G

# ==========================================
# Network Configuration
# ==========================================
networks:
  default:
    name: dataplatform-net
    external: true
```

## 5. 배포 및 Binlog 설정확인

**배포**

```
docker compose up -d
```

**Binlog 확인**

```sql
-- Binlog 활성화 여부 확인
SHOW VARIABLES LIKE 'log_bin';
-- 결과가 'ON'으로 나오면 성공!
```
