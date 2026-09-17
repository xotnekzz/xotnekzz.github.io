---
title: OpenBao란 무엇인가 — Vault에서 갈라져 나온 오픈소스 시크릿 매니저
description: OpenBao가 시크릿을 저장·발급·폐기하는 방식과 Barrier, Seal/Unseal, Secret Engine 구조를 살펴보고 온프레미스 도입 전 확인할 점을 정리합니다.
date: 2026-09-17
tags:
  - OpenBao
  - Security
  - SecretsManagement
  - Kubernetes
  - DataEngineering
featured: true
draft: false
---
### 1. 들어가며

애플리케이션이 늘어나면 비밀번호와 API 키도 함께 늘어납니다. 처음에는 환경 변수나 Kubernetes Secret만으로 충분해 보이지만, 운영 규모가 커지면 다른 문제가 생깁니다.

- 누가 어떤 시크릿을 읽을 수 있는가?
- DB 비밀번호는 언제, 어떻게 교체할 것인가?
- 퇴사자나 장애가 발생했을 때 관련 권한만 즉시 폐기할 수 있는가?
- 인증서와 암호화 키의 사용 기록을 감사할 수 있는가?

중요한 것은 비밀 값을 한곳에 모으는 일이 아닙니다. **시크릿의 발급부터 사용, 갱신, 폐기까지 수명주기를 통제하는 것**이 핵심입니다.

[OpenBao](https://openbao.org/)는 이 문제를 해결하는 오픈소스 시크릿 관리 시스템입니다. HashiCorp Vault의 오픈소스 코드를 기반으로 출발했고, 현재는 Linux Foundation 산하 OpenSSF가 관리하는 커뮤니티 프로젝트입니다. 소스 코드는 [MPL 2.0](https://github.com/openbao/openbao/blob/main/LICENSE)으로 배포됩니다.

### 2. OpenBao는 비밀번호 보관함이 아니다

OpenBao를 단순한 암호화 저장소로 이해하면 기능의 절반만 보는 셈입니다. OpenBao는 클라이언트의 신원을 확인하고, 정책으로 권한을 제한하고, 필요한 시크릿을 발급한 뒤, 정해진 시간이 지나면 이를 폐기합니다.

| 기능 | 역할 | 운영 효과 |
| --- | --- | --- |
| KV Secret Engine | API 키와 비밀번호 같은 정적 시크릿 저장 | 파일·코드·환경별로 흩어진 값을 중앙에서 관리 |
| Database Secret Engine | 요청 시점에 DB 계정을 동적으로 생성 | 장기 고정 계정 공유를 줄이고 사용자·인스턴스 단위 추적 가능 |
| Transit Secret Engine | 데이터의 암호화·복호화·서명 수행 | 애플리케이션 밖으로 키를 노출하지 않고 암호화 기능 사용 |
| PKI Secret Engine | 짧은 수명의 X.509 인증서 발급 | 인증서 발급과 갱신을 자동화하고 장기 인증서 의존 완화 |
| Auth Method와 Policy | 사람과 워크로드의 신원 확인 및 경로 단위 권한 부여 | 최소 권한과 일관된 접근제어 적용 |
| Lease와 Revocation | 토큰·동적 시크릿의 만료, 갱신, 폐기 관리 | 유출된 자격 증명이 계속 살아 있는 시간을 제한 |
| Audit Device | 요청과 응답의 감사 이벤트 기록 | 누가 언제 어떤 경로를 사용했는지 추적 |

예를 들어 애플리케이션 여러 대가 하나의 DB 계정을 공유하면 로그에서 실제 호출 주체를 구분하기 어렵습니다. OpenBao의 [Database Secret Engine](https://openbao.org/docs/secrets/databases/)은 역할에 따라 고유한 계정을 만들고 lease를 부여합니다. lease가 끝나면 OpenBao가 해당 계정을 폐기하므로, 비밀번호를 배포한 뒤 사람이 회수하는 절차를 줄일 수 있습니다.

### 3. 핵심 아키텍처: 스토리지를 신뢰하지 않는다

OpenBao 아키텍처의 출발점은 **Storage Backend를 신뢰하지 않는 것**입니다. 서버 외부의 스토리지에는 평문 시크릿을 쓰지 않고, Barrier라는 암호화 경계에서 데이터를 암호화한 뒤 저장합니다.

```text
Client · CLI · UI
        │ HTTPS API
        ▼
┌──────────────────── OpenBao Server ────────────────────┐
│  Auth Method → Core → Policy · Token · Lease           │
│                    ├─ Secret Engine (KV/DB/PKI/Transit) │
│                    └─ Audit Device                      │
│                                                        │
│  ─────────────── Security Barrier ───────────────────   │
└────────────────────────┬───────────────────────────────┘
                         │ encrypted data only
                         ▼
              Storage Backend (Raft/PostgreSQL)
```

[공식 아키텍처 문서](https://openbao.org/docs/internals/architecture/)에 따르면 Core는 요청 흐름을 제어하고 ACL을 적용하며 감사 로깅을 보장합니다. 인증 요청은 Auth Method로, 시크릿 요청은 경로에 맞는 Secret Engine으로 전달됩니다. 외부 스토리지로 나가는 데이터는 Barrier에서 암호화되므로 스토리지 파일이나 DB 행만 확보해서는 원문을 읽을 수 없습니다.

다만 이것이 스토리지 보안과 백업 정책을 생략해도 된다는 뜻은 아닙니다. 설정 파일에는 TLS 개인키나 Auto Unseal에 사용하는 토큰이 포함될 수 있습니다. 따라서 데이터 스냅샷뿐 아니라 설정 백업도 별도의 민감 자산으로 취급해야 합니다.

#### 요청은 어떻게 처리되는가

1. 클라이언트가 Kubernetes, JWT/OIDC, LDAP 같은 Auth Method로 인증합니다.
2. Auth Method가 신원을 확인하고 연결된 Policy를 반환합니다.
3. Core가 Policy를 가진 토큰을 발급합니다.
4. 클라이언트가 토큰으로 `database/creds/app-role` 같은 경로를 요청합니다.
5. Core가 ACL을 확인한 뒤 요청을 Secret Engine으로 보냅니다.
6. 동적 시크릿이라면 Expiration Manager가 lease를 등록합니다.
7. 만료되거나 명시적으로 revoke하면 OpenBao가 대상 자격 증명을 폐기합니다.

이 구조에서 Policy는 사후 필터가 아니라 요청 경로 앞에 놓인 기본 거부 장치입니다. 명시적으로 허용하지 않은 작업은 실행되지 않습니다.

### 4. Seal과 Unseal: 암호화 키를 어떻게 보호하는가

OpenBao 서버는 기본적으로 `sealed` 상태로 시작합니다. 이 상태에서는 스토리지에 암호화된 데이터가 있어도 복호화에 필요한 키를 사용할 수 없습니다.

초기화할 때 OpenBao는 데이터 암호화 키를 보호하는 키 계층을 만들고, 기본 설정에서는 Shamir's Secret Sharing으로 unseal key를 여러 조각으로 나눕니다. 예를 들어 5개 조각 중 3개를 임계값으로 정하면 서로 다른 관리자가 가진 3개 조각이 모여야 서버를 열 수 있습니다.

```bash
bao operator init -key-shares=5 -key-threshold=3

# 서로 다른 key holder가 임계값만큼 수행
bao operator unseal
```

수동 Unseal은 키 한 개를 한 사람에게 맡기지 않는다는 장점이 있지만, 노드 재시작 때마다 운영 절차가 필요합니다. 프로덕션에서는 KMS나 HSM을 이용한 Auto Unseal도 검토할 수 있습니다. 어느 방식을 선택하든 unseal key, recovery key, root token을 같은 장소에 보관하면 키 분리의 의미가 사라집니다.

### 5. 정적 시크릿보다 동적 시크릿이 중요한 이유

정적 비밀번호를 중앙에서 관리하면 코드 하드코딩은 줄일 수 있습니다. 하지만 같은 비밀번호가 몇 달 동안 유지된다면 유출 위험은 여전히 남습니다. OpenBao의 강점은 시크릿을 **보관할 값**이 아니라 **필요할 때 잠시 빌리는 자격 증명**으로 바꾸는 데 있습니다.

```text
Application → OpenBao에 DB 자격 증명 요청
            → 역할에 맞는 임시 DB 계정 생성
            → username/password + lease_id 반환
            → 애플리케이션이 lease 동안 사용
            → 만료 또는 revoke 시 DB 계정 폐기
```

이 방식은 다음 차이를 만듭니다.

- 서비스 인스턴스마다 다른 계정을 사용해 감사 추적이 쉬워집니다.
- 유출된 자격 증명이 유효한 시간을 TTL로 제한할 수 있습니다.
- 서비스 종료나 사고 대응 시 lease 계층을 기준으로 관련 자격 증명을 폐기할 수 있습니다.
- 사람이 공유 비밀번호를 만들고 전달하고 회수하는 작업이 줄어듭니다.

물론 동적 시크릿이 공짜로 얻어지는 것은 아닙니다. OpenBao가 DB 계정을 생성·변경·삭제할 권한을 가져야 하므로, OpenBao 자체의 DB 관리 계정과 Policy를 더 엄격하게 설계해야 합니다. 애플리케이션도 lease 갱신 실패와 자격 증명 교체를 처리할 수 있어야 합니다.

### 6. 로컬에서 KV Secret Engine 사용해 보기

다음 예시는 기능을 확인하기 위한 개발 환경입니다. Dev Server는 메모리에 데이터를 저장하고 처음부터 unsealed 상태로 실행되므로 **실제 시크릿이나 프로덕션 환경에 사용하면 안 됩니다.**

```bash
# 터미널 1: 개발용 서버 시작
bao server -dev -dev-root-token-id="openbao-dev-token"

# 터미널 2: 접속 정보 설정
export BAO_ADDR="http://127.0.0.1:8200"
export BAO_TOKEN="openbao-dev-token"

# KV v2 엔진 활성화
bao secrets enable -path=secret kv-v2

# 시크릿 저장
bao kv put secret/my-app \
  db_username="app" \
  db_password="change-me"

# 시크릿 조회
bao kv get secret/my-app
```

여기까지는 암호화된 중앙 저장소의 기능만 확인한 것입니다. 실제 PoC라면 다음 단계로 Kubernetes Auth 또는 JWT/OIDC를 붙이고, 애플리케이션별 Policy를 분리한 뒤, Database Secret Engine의 TTL과 revoke 동작까지 검증해야 합니다.

### 7. Vault와 무엇이 다른가

OpenBao는 Vault 1.14 계열의 MPL 2.0 코드에서 출발했기 때문에 CLI와 HTTP API의 많은 부분이 비슷합니다. `vault` 명령을 `bao`로 바꾸는 수준에서 동작하는 워크플로도 있지만, 두 프로젝트는 이미 독립적으로 발전하고 있습니다.

특히 OpenBao에는 오픈소스 [Namespace](https://openbao.org/docs/concepts/namespaces/)와 Raft·PostgreSQL 기반의 읽기 가능한 Standby 노드가 있습니다. Namespace는 한 클러스터 안에서 팀별 Secret Engine, Auth Method, Policy, Token을 격리하는 멀티테넌시 경계를 제공합니다. Standby Read는 읽기 부하를 여러 노드로 분산할 수 있지만, 복제 지연 구간에는 방금 쓴 값을 즉시 읽지 못할 수 있으므로 [eventual consistency](https://openbao.org/docs/concepts/consistency/)를 고려해야 합니다.

반대로 기존 Vault에서 사용하던 모든 플러그인과 엔터프라이즈 기능이 그대로 존재한다고 가정해서는 안 됩니다. 마이그레이션 전에는 다음을 실제 구성 기준으로 대조해야 합니다.

- 사용 중인 Auth Method와 Secret Engine의 지원 여부
- 플러그인 ABI와 API 호환성
- Namespace와 Policy 경로 차이
- Seal/HSM/FIPS 요구사항
- 클러스터 간 복제와 재해 복구 목표
- 백업 복원 및 롤백 절차

즉, OpenBao는 단순한 이름 변경판이 아니라 **호환성을 출발점으로 삼은 별도 프로젝트**로 보는 편이 안전합니다.

### 8. 지금 도입해도 되는가

프로젝트의 성숙도를 GitHub Star 하나로 판단하기는 어렵습니다. 더 유용한 신호는 실제 제품 통합과 운영 주체입니다.

OpenBao는 2025년 6월 [OpenSSF Sandbox 프로젝트](https://openbao.org/blog/openbao-joins-the-openssf/)로 편입됐습니다. GitLab은 자체 Secrets Manager의 저장·수명주기 관리 엔진으로 OpenBao를 선택했고, [GitLab 19.0에서 Public Beta](https://docs.gitlab.com/administration/secrets_manager/)로 전환했습니다. 이는 생태계가 성장하고 있다는 분명한 신호지만, 모든 환경에서 장기간 검증됐다는 뜻은 아닙니다. GitLab 문서 역시 업그레이드 중단 시간 같은 알려진 제약을 별도로 안내합니다.

온프레미스 환경이라면 다음 조건에서 PoC 가치가 큽니다.

- DB 비밀번호와 API 키가 서버·CI/CD·Kubernetes에 흩어져 있다.
- 고정 계정 공유 때문에 실제 접근 주체를 추적하기 어렵다.
- 인증서와 크리덴셜의 만료·교체를 사람이 관리하고 있다.
- SaaS가 아닌 내부 통제 영역에 키와 시크릿을 두어야 한다.
- Vault 호환 생태계를 활용하면서 MPL 2.0 기반의 커뮤니티 거버넌스를 원한다.

반대로 단일 애플리케이션의 값 몇 개를 보관하는 환경이라면 OpenBao 클러스터, Seal, Policy, 감사 로그, 백업까지 운영하는 비용이 더 클 수 있습니다. 시크릿 관리 시스템은 장애가 나면 여러 서비스의 시작과 인증을 동시에 막는 핵심 인프라가 되기 때문입니다.

### 9. PoC에서 반드시 확인할 것

기능 데모보다 실패 시나리오를 먼저 검증하는 편이 좋습니다.

1. **인증**: 장기 토큰 대신 Kubernetes ServiceAccount 또는 OIDC/JWT로 워크로드를 식별할 수 있는가?
2. **권한**: 서비스마다 읽을 수 있는 경로와 수행할 수 있는 작업이 분리되는가?
3. **수명주기**: 동적 DB 계정이 TTL 만료와 강제 revoke 때 실제 DB에서 삭제되는가?
4. **가용성**: Active 노드 장애와 리더 선출 중 애플리케이션이 어떻게 재시도하는가?
5. **키 관리**: Shamir와 Auto Unseal 중 어떤 방식이 사내 복구 절차에 맞는가?
6. **감사**: Audit Device 장애 시 요청 처리 정책과 로그의 민감정보 마스킹이 적절한가?
7. **백업**: Raft snapshot 또는 PostgreSQL 백업만이 아니라 설정·플러그인까지 복원되는가?
8. **성능**: 부팅 시 다수의 Pod가 동시에 시크릿을 요청해도 지연과 부하를 감당하는가?

PoC의 성공 기준도 “시크릿 저장에 성공했다”가 되어서는 안 됩니다. **노드 장애, 키 분실, lease 만료, Audit Device 장애, 백업 복원 상황에서도 통제 가능한가**가 실제 도입 여부를 가릅니다.

### 10. 마치며

OpenBao의 핵심 가치는 비밀 값을 암호화해서 보관하는 데만 있지 않습니다. 신원을 확인하고, 최소 권한으로 짧은 수명의 자격 증명을 발급하고, 사용 기록을 남기고, 필요할 때 즉시 폐기하는 운영 체계를 제공합니다.

온프레미스나 Kubernetes 환경에서 시크릿이 여러 시스템에 흩어져 있다면 OpenBao는 충분히 검토할 만합니다. 다만 중앙 시크릿 매니저를 도입하는 순간 그 시스템은 새로운 핵심 의존성이 됩니다. 따라서 작은 KV 데모에서 끝내지 말고, 동적 시크릿 하나를 선택해 인증·Policy·Lease·Audit·백업·장애 복구까지 한 흐름으로 검증하는 것이 좋은 출발점입니다.

### 참고 자료

- [OpenBao 공식 사이트](https://openbao.org/)
- [OpenBao Architecture](https://openbao.org/docs/internals/architecture/)
- [OpenBao Security Model](https://openbao.org/docs/internals/security/)
- [Database Secrets Engine](https://openbao.org/docs/secrets/databases/)
- [Transit Secrets Engine](https://openbao.org/docs/secrets/transit/)
- [Integrated Storage와 PostgreSQL 비교](https://openbao.org/docs/configuration/storage/)
- [GitLab Secrets Manager](https://docs.gitlab.com/administration/secrets_manager/)
