---
title: Apache Doris 백업 및 복구 전략 수립
description: Storage/Compute Coupled 구조의 Snapshot 데이터와 FE Metadata를 SeaweedFS S3 Repository에 분리 백업하는 복구 체계 설계
date: 2026-09-05
tags:
  - Apache Doris
  - SeaweedFS
  - Backup
  - Disaster Recovery
featured: false
draft: true
---
> **기간:** 
> **참여인원:** 
> **역할:** 
> **기술 스택:**

## 1. Background & Challenges

Apache Doris 클러스터는 **Storage/Compute Coupled** 구조로 운영되기 때문에 데이터가 연산 노드의 로컬 스토리지와 결합되어 있습니다. 클러스터 내부 복제만으로는 운영 실수, 논리적 데이터 손상, 다중 노드 장애와 같은 클러스터 단위 복구 시나리오에 대응하기 어려워 별도의 백업 체계가 필요했습니다.

- **데이터 복구 경로 부재:** 운영 테이블을 클러스터 외부에서 복원할 수 있는 백업 데이터가 필요했습니다.
- **FE 복구 수단 필요:** Frontend(FE) 장애 또는 클러스터 재구성 시 메타데이터를 복원할 수 있도록 FE Metadata를 별도로 보관해야 했습니다.
- **백업 비용 관리:** Doris 3.x는 네이티브 증분 백업을 지원하지 않으므로 전체 데이터베이스를 반복 백업하지 않고 파티션 단위 Snapshot으로 백업 범위를 관리할 필요가 있었습니다.

데이터와 메타데이터의 특성에 맞춰 백업 경로와 주기를 분리하고, Doris 클러스터 외부의 SeaweedFS를 공통 백업 저장소로 사용하는 것을 목표로 했습니다.

## 2. Architecture: As-Is vs To-Be

### As-Is Architecture

![Apache Doris 클러스터 내부 복제만 존재하고 외부 데이터 및 FE Metadata 백업 경로가 없는 기존 구조](/images/doris-backup-as-is.svg)

1. **데이터 저장:** Apache Doris BE의 로컬 스토리지에 운영 데이터 저장
2. **클러스터 내부 보호:** Doris의 내부 복제 정책으로 노드 장애에 대응
3. **복구 한계:** 클러스터 외부 백업이 없어 운영 실수나 클러스터 단위 장애 시 별도 복구 지점 부재
4. **FE Metadata:** FE 고가용성은 구성되어 있으나 독립된 메타데이터 백업본은 별도로 관리되지 않음

### To-Be Architecture

![Apache Doris 파티션 Snapshot을 SeaweedFS S3 Repository에 저장하고 FE Metadata는 매주 압축하여 분리 보관하는 백업 구조](/images/doris-backup-to-be.svg)

1. **S3 Repository 등록:** SeaweedFS S3 Gateway의 endpoint와 백업 bucket을 Apache Doris Repository로 등록
2. **Snapshot 생성:** 데이터베이스·테이블·파티션 중 복구 단위에 맞는 범위를 `BACKUP SNAPSHOT`으로 백업
3. **파티션 단위 운영:** 시간 파티션 테이블은 신규 또는 백업 대상 파티션만 선택하여 증분에 가까운 백업 주기 구성
4. **상태 확인:** `SHOW BACKUP`으로 작업 완료 여부를 확인하고 `SHOW SNAPSHOT ON <repository>`로 저장된 복구 지점 점검
5. **메타데이터 백업:** FE Metadata를 압축하여 매주 1회 SeaweedFS에 저장
6. **복구 검증:** 데이터 Snapshot과 FE Metadata를 각각 복원하여 정합성과 복구 소요 시간 측정

## 3. Solution & Technical Insights

1. **운영 데이터와 FE Metadata의 백업 경로 분리**
    - **[Issue]** Doris의 운영 데이터와 FE Metadata는 변경 주기와 복구 역할이 다르므로 하나의 백업 정책으로 관리하면 불필요한 저장 비용이 발생하거나 필요한 복구 지점을 확보하지 못할 수 있습니다.
    - **[Solution]** 운영 데이터는 SeaweedFS의 S3 호환 API를 Doris Repository로 등록하여 Snapshot 형태로 저장하고, FE Metadata는 압축하여 매주 1회 별도 경로에 보관합니다. 데이터 복구와 클러스터 제어 정보 복구를 독립적으로 수행할 수 있는 구조를 설계했습니다.
2. **클러스터 외부 백업 저장소 확보**
    - **[Issue]** Storage/Compute Coupled 구조에서는 클러스터 내부 복제본만으로 클러스터 단위 장애와 논리적 손상에 대응하기 어렵습니다.
    - **[Solution]** SeaweedFS를 외부 백업 저장소로 사용하여 운영 Doris 클러스터와 장애 도메인을 분리합니다. Doris 노드 상태와 무관하게 접근할 수 있는 복구 지점을 유지하도록 구성할 계획입니다.
3. **파티션 Snapshot을 통한 백업 범위 관리**
    - **[Issue]** 대용량 운영 테이블 전체를 매번 백업하면 네트워크와 저장소에 반복적인 부하가 발생합니다.
    - **[Solution]** Doris 3.x의 `BACKUP SNAPSHOT ... ON (table PARTITION (...))`을 사용하여 신규 또는 복구가 필요한 파티션만 선택합니다. 이는 네이티브 증분 백업이 아니라 파티션 범위를 제한하는 운영 방식이며, 파티션 변경과 백업 이력을 별도로 관리해야 합니다.
4. **백업 생성보다 복구 검증을 중심으로 운영**
    - **[Issue]** 백업 파일이 존재하더라도 실제 복원 절차와 소요 시간이 검증되지 않으면 장애 시 복구 가능성을 보장할 수 없습니다.
    - **[Solution]** 데이터 백업과 FE Metadata 백업에 각각 복구 절차를 정의하고 정기 복구 테스트를 수행할 계획입니다. 복구 성공 여부, 데이터 정합성, 복구 소요 시간을 기록하여 RPO와 RTO 기준을 구체화합니다.

### SeaweedFS S3 Repository 구성 초안

SeaweedFS S3 Gateway를 S3 호환 원격 저장소로 사용합니다. Doris 공식 문서의 S3/MinIO Repository 형식을 기준으로 하며, endpoint·region·인증 정보와 path-style 지원 여부는 실제 환경에서 POC 후 확정합니다.

```sql
CREATE REPOSITORY `seaweedfs_backup_repo`
WITH S3
ON LOCATION "s3://<backup-bucket>/doris-backup"
PROPERTIES
(
    "s3.endpoint" = "http://<seaweedfs-s3-endpoint>:8333",
    "s3.region" = "<region>",
    "s3.access_key" = "<access-key>",
    "s3.secret_key" = "<secret-key>",
    "use_path_style" = "true"
);
```

```sql
BACKUP SNAPSHOT <database>.`<snapshot-label>`
TO `seaweedfs_backup_repo`
ON (<table> PARTITION (<partition-list>));

SHOW BACKUP FROM <database>;
SHOW SNAPSHOT ON `seaweedfs_backup_repo`;
```

공식 문서상 Doris 3.x 백업·복구에는 다음 제약이 있으므로 운영 절차와 복구 테스트에 반영합니다.

- 네이티브 증분 백업은 지원하지 않으며, 특정 파티션 선택으로 백업 범위를 제한할 수 있습니다.
- 하나의 데이터베이스에서는 백업 또는 복구 작업을 동시에 하나만 실행할 수 있습니다.
- 비동기 Materialized View와 Storage Policy를 사용하는 테이블은 백업·복구 대상에서 제외됩니다.
- 복원 후 Dynamic Partition 속성은 다시 활성화해야 하며 `colocate_with` 속성도 재설정해야 합니다.

구현 기준은 [Apache Doris 3.x Backup 공식 문서](https://doris.apache.org/docs/3.x/admin-manual/data-admin/backup-restore/backup/)와 [Backup and Restore Overview](https://doris.apache.org/docs/3.x/admin-manual/data-admin/backup-restore/overview/)를 따릅니다.

## 4. Expected Impact & Validation Plan

> 이 문서는 적용 전 설계 초안입니다. 아래 항목은 구현 후 복구 테스트 결과로 검증하고 실제 수치로 갱신합니다.

- 🛡️ **클러스터 외부 복구 지점 확보:** 운영 Doris 클러스터와 분리된 SeaweedFS에 데이터와 FE Metadata 백업을 보관합니다.
- 📦 **백업 범위 최적화:** 파티션 Snapshot과 Metadata 압축을 통해 매번 전체 데이터베이스를 백업하지 않고 네트워크 전송량과 저장량을 관리합니다.
- 🔄 **복구 경로 분리:** 운영 데이터 복원과 FE Metadata 복구 절차를 분리하여 장애 범위에 맞는 대응이 가능하도록 합니다.
- 🧪 **검증 기준:** 백업 성공 여부뿐 아니라 정기 복구 테스트, 데이터 정합성 확인, 복구 소요 시간 측정을 운영 기준에 포함합니다.

### 후속 결정 항목

- 전체 Snapshot 기준점과 파티션 Snapshot 실행 주기
- 백업 대상 데이터베이스·테이블·파티션 범위
- SeaweedFS S3 endpoint·region·path-style 호환성 검증
- 백업 데이터 및 FE Metadata 보존 기간
- 백업 실패 감지와 재시도 정책
- 백업 데이터 암호화 및 접근 권한
- 복구 테스트 주기와 목표 RPO/RTO
