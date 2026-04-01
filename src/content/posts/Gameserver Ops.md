# Gameserver Ops



Gameserver Ops란?

게임 서버(band,billboard,decalcomanie 등)가 안정적으로 운영될 수 있도록 지원하는 업무를 말합니다.

### 주요업무

1. 서버 모니터링 ( cpu, memory )
-  서버의 cpu, memory 부하를 모니터링 및 대응
1. 서버 컨텐츠 배포(업데이트)
- 업데이트 요청에 따라 Production에 새로운 버전을 배포합니다.
1. 개발 테스트 서버 지원
- 클라이언트 개발자 PC에서 서버를 테스트 할 수 있도록 서포트 합니다.
### 클라이언트

1. 퍼즐원 스튜디오 서버 개발자 ( 은우님 )
- 서버 컨텐츠 업데이트 요청
1. 퍼즐원 스튜디오 클라이언트 개발자
- 개발 테스트 서버 관련 요청
# Game Server 구조

### Production

production 서버는 이름 그대로 운영중인 서버 환경을 의미합니다.

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/d76c425a-a34a-4495-be08-3fc155a62b01/Untitled.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB46647HN54XN%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153159Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQDtPClruKbRCWIYlUtS7IOY4C%2B2pB3zES%2F8Ma4OY8RYqAIgJ7G0PrfLSqhxc7J38%2B35v32ufTTwg%2BHBWuV%2FCuYDgqUqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDKTMBdZDjJPtAKh1PCrcA8TnWEHoC%2FxI6HyqaWGNglEBuJFb%2FlGIn9LkpllbqK5SwIMvGENrP7MkpvKFmsoUFRXyUjGX%2F5a%2FGNVo0uO4iQnZxa7aboCA5e%2BvZ4ri7rfYqC%2BgHecECtM8lVDLa6BgN%2FoHnXZ2S14KzB6pJvmtz%2FG%2B11F5vM4Pow8QO0zJ3fY87VwJj3eqRaA4evvyaqAg08jPR%2FCJ2lyVOYUyyeAvCopqpGbHtqzeNqeo5dED7xGRQDlcVI4f3NdgKR2XMsyyIzAn7axosJRsLSJp3LKV6GcDtyBiwK%2FS0v9NZWVHTA2NmoEuLk%2Fi%2FBr3qIFTA4EwfC4F9nPVXF9OPY4y0l5eaaYuZNtr9udaCm3Urpe%2Fg%2FMMaOZVQKhYqNQpiYZyy35d7E6aZa9CkdEb66X2F9ukkIUKNeTeIMxQymvBjMNFmQHhS%2BAxeg7dde%2BiXQWjISQXMrDuGxzHK3FPRtGGSPij65Gt8qUKP6HqdZLQ6pO9u%2BDgFY3h6i8GVtKYZ3AYaFjd3x4oz%2FIRVnPdJoK5kA1jvt0cFAKlgpNSO8RQ07Dk81pTtieYHrJeiBgAtFUZC31wXxwgIpdHvkI3Fu3i1MXqNj6em4rhYDbNDnCfcBA15pRqhBmLRyw2ujW0kSzPMIu9z80GOqUBrf4N8iauaEB3BlMH472c7bfIiQJwRm0WS2oZ2ZxKSiJRpYSsXdj5JdtnCW7tGP0qBf3ab12Mjuh4ocEo7RpZin2JiGyjCl8prCkg9DRXMNesrLrKMypcFWvw0wDRRuCwFPCkaT6gwb%2BsUTFAKG8pkXJGj%2Fmjm1R7LuGYqMDn%2Fc5dd9d79%2Fs%2Febb2RkWXciTVERs8aMRSEjaM%2FUNh7QnCOZuHN2v0&X-Amz-Signature=898e78d212fa67811acf753f1f31e8d9a8cd6ffcdf17fdaebcd9d81be52c11f6&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

gs0-gd4, gs1-gd1, gs2-gd2, gs3-gd3, gs4-gd4 쌍으로 API서버와 데이터베이스 서버가 연결되어 있습니다.
(gs0-gd4의 경우 gs4부하 분산을 위해 gs0로 api 서버를 이전하여 특별한 케이스가 발생하였습니다.)


게임서버는 {게임명-서비스명-배포버전} 으로 이름 규칙을 가지고  각 컨테이너로 띄워져 있으며,
컨테이너 마다 node js 어플리케이션(nest js포함)을 관리해주는 pm2라는 daemon이 실행되어 있습니다.

pm2 CLI를 통해 api 서버의 클러스터링을 통한 로드밸런싱, 무중단 배포(업데이트)가 가능합니다.


> 💡 production 서버는 [kong.bitmango.com](http://dev-kong.bitmango.com/)  도메인을 사용하며 `v1`  배포 버전을 사용합니다.


주소형식: https://dev-kong.bitmango.com/{서비스명}/{게임명}/{배포버전}/api_endpoint 

ex) https://kong.bitmango.com/band/blockpuzzlestarfinder/v1/teams/list

### Staging

staging서버는  production으로 배포하기 이전에 production 과 가장 유사한 배포환경에서 마지막 테스트를 진행하기 위해 사용하는 테스트 서버입니다.

gtest0 host 하나에서 모든 게임 서비스의 api 서버, db 서버를 모두 띄워져 있으며, 테스트를 위해 클러스터는 1개만 유지합니다.


> 💡 staging 서버는 [dev-kong.bitmango.com](http://dev-kong.bitmango.com/) 이라는 도메인을 사용하며 `test`  배포 버전을 사용합니다.

주소형식: https://dev-kong.bitmango.com/{서비스명}/{게임명}/{배포버전}/api_endpoint 

ex) https://dev-kong.bitmango.com/band/blockpuzzlestarfinder/test/band/teams/list

# Game Server 모니터링

### Munin 

[https://munin.datawave.co.kr/report/00-view.php?res=cpu&dur=day](https://munin.datawave.co.kr/report/00-view.php?res=cpu&dur=day)

host의  cpu, memory, disk 등 사용량을 daily, weekly, monthly, yearly 로 확인이 가능합니다.

### Kong Dashboard (Kibana)

[https://kibana.datawave.co.kr/app/dashboards#/view/a5139c20-a7ad-11ed-bc9b-b7b35d0e69c9?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now)](https://kibana.datawave.co.kr/app/dashboards#/view/a5139c20-a7ad-11ed-bc9b-b7b35d0e69c9?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))
Kong Gateway의 access, error log를 기반으로 게임 서비스 별로  실시간 응답 상태를 쉽게 확인 가능합니다.

### APM (kibana)

[https://kibana.datawave.co.kr/app/apm/traces?rangeFrom=now-15m&rangeTo=now&kuery=not service.name : *chat*](https://kibana.datawave.co.kr/app/apm/traces?rangeFrom=now-15m&rangeTo=now&kuery=not%20service.name%20%3A%20*chat*)
애플리케이션 성능 모니터링 기능으로 API Endpoint 별로 tpm(분당 처리량) , latency(응답시간) 등 성능을 확인할 수 있습니다.

# Game Server 배포 프로세스

### 1. 게임, 서비스 별 배포 현황 확인하기 ( idb_gameserverops )

- gameserverops.dbinfo
데이터 베이스 서버의 hostname, port 정보를 기록합니다. 데이터는 수동으로 관리합니다.
![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/abf18c34-3a03-4fbe-ba1c-d27d1ca34164/Untitled.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB46647HN54XN%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153159Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQDtPClruKbRCWIYlUtS7IOY4C%2B2pB3zES%2F8Ma4OY8RYqAIgJ7G0PrfLSqhxc7J38%2B35v32ufTTwg%2BHBWuV%2FCuYDgqUqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDKTMBdZDjJPtAKh1PCrcA8TnWEHoC%2FxI6HyqaWGNglEBuJFb%2FlGIn9LkpllbqK5SwIMvGENrP7MkpvKFmsoUFRXyUjGX%2F5a%2FGNVo0uO4iQnZxa7aboCA5e%2BvZ4ri7rfYqC%2BgHecECtM8lVDLa6BgN%2FoHnXZ2S14KzB6pJvmtz%2FG%2B11F5vM4Pow8QO0zJ3fY87VwJj3eqRaA4evvyaqAg08jPR%2FCJ2lyVOYUyyeAvCopqpGbHtqzeNqeo5dED7xGRQDlcVI4f3NdgKR2XMsyyIzAn7axosJRsLSJp3LKV6GcDtyBiwK%2FS0v9NZWVHTA2NmoEuLk%2Fi%2FBr3qIFTA4EwfC4F9nPVXF9OPY4y0l5eaaYuZNtr9udaCm3Urpe%2Fg%2FMMaOZVQKhYqNQpiYZyy35d7E6aZa9CkdEb66X2F9ukkIUKNeTeIMxQymvBjMNFmQHhS%2BAxeg7dde%2BiXQWjISQXMrDuGxzHK3FPRtGGSPij65Gt8qUKP6HqdZLQ6pO9u%2BDgFY3h6i8GVtKYZ3AYaFjd3x4oz%2FIRVnPdJoK5kA1jvt0cFAKlgpNSO8RQ07Dk81pTtieYHrJeiBgAtFUZC31wXxwgIpdHvkI3Fu3i1MXqNj6em4rhYDbNDnCfcBA15pRqhBmLRyw2ujW0kSzPMIu9z80GOqUBrf4N8iauaEB3BlMH472c7bfIiQJwRm0WS2oZ2ZxKSiJRpYSsXdj5JdtnCW7tGP0qBf3ab12Mjuh4ocEo7RpZin2JiGyjCl8prCkg9DRXMNesrLrKMypcFWvw0wDRRuCwFPCkaT6gwb%2BsUTFAKG8pkXJGj%2Fmjm1R7LuGYqMDn%2Fc5dd9d79%2Fs%2Febb2RkWXciTVERs8aMRSEjaM%2FUNh7QnCOZuHN2v0&X-Amz-Signature=a47a4fb1198618306998b454583f42b3cb4eef2a827fde6ffb5b4bfcf31256ae&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



- gameserverops.serverinfo
- ETL : [https://airflow.datawave.co.kr/dags/idb_gameserverops_serverinfo/grid](https://airflow.datawave.co.kr/dags/idb_gameserverops_serverinfo/grid)
30분마다 게임서버 내 컨테이너로 부터 서버의 배포정보를 가져와 테이블을 업데이트 합니다.
- system versioned table이라 업데이트 히스토리를 확인할 수 있습니다.
![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/4883aa54-47e3-48cd-a5a0-69f74be464fb/Untitled.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB46647HN54XN%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153159Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQDtPClruKbRCWIYlUtS7IOY4C%2B2pB3zES%2F8Ma4OY8RYqAIgJ7G0PrfLSqhxc7J38%2B35v32ufTTwg%2BHBWuV%2FCuYDgqUqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDKTMBdZDjJPtAKh1PCrcA8TnWEHoC%2FxI6HyqaWGNglEBuJFb%2FlGIn9LkpllbqK5SwIMvGENrP7MkpvKFmsoUFRXyUjGX%2F5a%2FGNVo0uO4iQnZxa7aboCA5e%2BvZ4ri7rfYqC%2BgHecECtM8lVDLa6BgN%2FoHnXZ2S14KzB6pJvmtz%2FG%2B11F5vM4Pow8QO0zJ3fY87VwJj3eqRaA4evvyaqAg08jPR%2FCJ2lyVOYUyyeAvCopqpGbHtqzeNqeo5dED7xGRQDlcVI4f3NdgKR2XMsyyIzAn7axosJRsLSJp3LKV6GcDtyBiwK%2FS0v9NZWVHTA2NmoEuLk%2Fi%2FBr3qIFTA4EwfC4F9nPVXF9OPY4y0l5eaaYuZNtr9udaCm3Urpe%2Fg%2FMMaOZVQKhYqNQpiYZyy35d7E6aZa9CkdEb66X2F9ukkIUKNeTeIMxQymvBjMNFmQHhS%2BAxeg7dde%2BiXQWjISQXMrDuGxzHK3FPRtGGSPij65Gt8qUKP6HqdZLQ6pO9u%2BDgFY3h6i8GVtKYZ3AYaFjd3x4oz%2FIRVnPdJoK5kA1jvt0cFAKlgpNSO8RQ07Dk81pTtieYHrJeiBgAtFUZC31wXxwgIpdHvkI3Fu3i1MXqNj6em4rhYDbNDnCfcBA15pRqhBmLRyw2ujW0kSzPMIu9z80GOqUBrf4N8iauaEB3BlMH472c7bfIiQJwRm0WS2oZ2ZxKSiJRpYSsXdj5JdtnCW7tGP0qBf3ab12Mjuh4ocEo7RpZin2JiGyjCl8prCkg9DRXMNesrLrKMypcFWvw0wDRRuCwFPCkaT6gwb%2BsUTFAKG8pkXJGj%2Fmjm1R7LuGYqMDn%2Fc5dd9d79%2Fs%2Febb2RkWXciTVERs8aMRSEjaM%2FUNh7QnCOZuHN2v0&X-Amz-Signature=0b7f9a86723d73416ddbac4017348e73038e5432473dc6b7226e79514eac3aa0&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



- gameserverops.view_summary
![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/a75e97b1-44cd-4df9-94ee-c6b488e27125/Untitled.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB46647HN54XN%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153159Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQDtPClruKbRCWIYlUtS7IOY4C%2B2pB3zES%2F8Ma4OY8RYqAIgJ7G0PrfLSqhxc7J38%2B35v32ufTTwg%2BHBWuV%2FCuYDgqUqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDKTMBdZDjJPtAKh1PCrcA8TnWEHoC%2FxI6HyqaWGNglEBuJFb%2FlGIn9LkpllbqK5SwIMvGENrP7MkpvKFmsoUFRXyUjGX%2F5a%2FGNVo0uO4iQnZxa7aboCA5e%2BvZ4ri7rfYqC%2BgHecECtM8lVDLa6BgN%2FoHnXZ2S14KzB6pJvmtz%2FG%2B11F5vM4Pow8QO0zJ3fY87VwJj3eqRaA4evvyaqAg08jPR%2FCJ2lyVOYUyyeAvCopqpGbHtqzeNqeo5dED7xGRQDlcVI4f3NdgKR2XMsyyIzAn7axosJRsLSJp3LKV6GcDtyBiwK%2FS0v9NZWVHTA2NmoEuLk%2Fi%2FBr3qIFTA4EwfC4F9nPVXF9OPY4y0l5eaaYuZNtr9udaCm3Urpe%2Fg%2FMMaOZVQKhYqNQpiYZyy35d7E6aZa9CkdEb66X2F9ukkIUKNeTeIMxQymvBjMNFmQHhS%2BAxeg7dde%2BiXQWjISQXMrDuGxzHK3FPRtGGSPij65Gt8qUKP6HqdZLQ6pO9u%2BDgFY3h6i8GVtKYZ3AYaFjd3x4oz%2FIRVnPdJoK5kA1jvt0cFAKlgpNSO8RQ07Dk81pTtieYHrJeiBgAtFUZC31wXxwgIpdHvkI3Fu3i1MXqNj6em4rhYDbNDnCfcBA15pRqhBmLRyw2ujW0kSzPMIu9z80GOqUBrf4N8iauaEB3BlMH472c7bfIiQJwRm0WS2oZ2ZxKSiJRpYSsXdj5JdtnCW7tGP0qBf3ab12Mjuh4ocEo7RpZin2JiGyjCl8prCkg9DRXMNesrLrKMypcFWvw0wDRRuCwFPCkaT6gwb%2BsUTFAKG8pkXJGj%2Fmjm1R7LuGYqMDn%2Fc5dd9d79%2Fs%2Febb2RkWXciTVERs8aMRSEjaM%2FUNh7QnCOZuHN2v0&X-Amz-Signature=8032b70b27136f2dffcea464ea2f82a521e738cc15c7f9873fe9aa34b1a46a3b&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



### 2.  배포 프로세스

1. **신규 서비스 배포 **
`level-patch` 를 새로 추가한다고 가정하자.


1. Gamification Server Ops [https://docs.google.com/spreadsheets/d/1MbvHYnvOnWwkSKoLc4yZiIExckZHejQ9cmmjoEYAEnc/edit#gid=2140106422](https://docs.google.com/spreadsheets/d/1MbvHYnvOnWwkSKoLc4yZiIExckZHejQ9cmmjoEYAEnc/edit#gid=2140106422)
시트에 Info 탭에서 새로운 서비스를 등록하고 app Index에 맞게 port를 추가합니다.
1. docker-compose.yaml 업데이트 (production)
gameserver-ops/03-web/bin/template/production/docker-compose.yaml
```yaml
...
level-patch-%GAMEID%-%APIVERSION%:
    container_name: %GAMEID%-level-patch-%APIVERSION%
    ports:
      - %GAMEPORT%20:10004
    image: docker.bitmango.com/baseimg-nodejs:2023.07
    environment:
      GITURL: https://etckeeper:otvvQPQMHS_ShY6TxHbg@gitlab.bitmango.com/games/p1sserver/microservices/level-patch.git
      BRANCH: master
      SERVICE: level-patch
      TAG: v1.0.9
      CORECOUNT: 1
      TZ: UTC
      DB_URL: mongodb://%DBHOST%.datawave.co.kr:%DBPORT%10/level-patch
      NODE_ENV: production
      GAMEID: %GAMEID%
    command: sh -c "/app/start.sh"
    networks:
      - gamification-network
```

      자세한 내용은 일단 생략

c. docker-compose.yaml 업데이트 (staging)
    gameserver-ops/03-web/bin/template/staging/docker-compose.yaml

```yaml
level-patch-%GAMEID%-%APIVERSION%:
    container_name: %GAMEID%-level-patch-%APIVERSION%
    ports:
      - %GAMEPORT%20:10004
    image: docker.bitmango.com/baseimg-nodejs:2023.07
    environment:
      GITURL: https://etckeeper:otvvQPQMHS_ShY6TxHbg@gitlab.bitmango.com/games/p1sserver/microservices/level-patch.git
      BRANCH: master
      SERVICE: level-patch
      TAG: v1.0.9
      CORECOUNT: %CORECOUNT%
      TZ: UTC
      DB_URL: mongodb://%DBHOST%.datawave.co.kr:%DBPORT%10/level-patch
      NODE_ENV: staging
      GAMEID: %GAMEID%
    command: sh -c "/app/start.sh"
    networks:
      - gamification-network
```

 자세한 내용은 일단 생략

d. 템플릿을 기반으로 docker-compose.yaml 생성하기

```bash
sh 01.generate.sh
```

a,b에 기록한 템플릿을 기준으로 host내 게임별로 docker-compose 파일을 생성합니다.

games 디렉토리 내 게임별로 docker-compose 파일이 업데이트 되어있습니다.

d. level-patch 컨테이너 실행

```bash
91.start_compose.sh -s level-patch
```



1. **버전 업데이트**
```bash
sh 12.update-version.sh -v v1 -a wordcookies -s chat -t v1.5.3 -i 68 -e tskim@bitmango.com
```

```bash
sh 11.update-version-allapp.sh.sh -s chat -t v1.5.3 -i 68 -e tskim@bitmango.com
```

deploy-queue에 등록된 이슈 번호와 배포담당자 이메일을 기록하여 배포 기록을 이슈에 기록합니다.

[https://gitlab.bitmango.com/bitmango/BI/deploy/-/issues/68](https://gitlab.bitmango.com/bitmango/BI/deploy/-/issues/68) 



1. **배포관리 룰**
- 클라이언트가 요청한 내용은 스스로 파악해야함(이슈에 진행상황 공유될필요있음)
- 버전별 정보는 tag에 (좀더자세히)staging은 이슈내에서 처리한다.
- production은 deploy에 넣되 changelog(이슈링크)staging에서 production으로 올라가기전에 deploy-queue 이슈 생성하여 배포 요청 -> 선 배포 및 타이틀 공유 -> 전체배포 공유
- feature는 develop에서 branch를 생성하고 develop으로 머지
- hotfix는 master에서 branch를 생성하고 develop, master머지
- Develop <> master diff확인
- tag는 마스터에서 딴다
# Game Server 배포 방법



