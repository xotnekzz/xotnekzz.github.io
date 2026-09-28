# 서버 하드웨어 사양 조사

- 조사일: 2026-09-28 (KST)
- 대상: `sr-fe1~3`, `sr-be1~28`, `minio1~2`, `intra2`, `starrocks1~7`
- 접속 결과: 총 41대 모두 조회 성공
- 조사 명령: `lscpu`, `/proc/meminfo`, `lsblk`

## 전체 서버 사양

| 호스트        | CPU                           | 소켓 / 물리 코어 / 논리 CPU |           메모리 |        SSD |          HDD |
| ---------- | ----------------------------- | ------------------: | ------------: | ---------: | -----------: |
| sr-fe1     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-fe2     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-fe3     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be1     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be2     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be3     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB | **2 × 8 TB** |
| sr-be4     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be5     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be6     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be7     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be8     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be9     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be10    | Intel Xeon E5-2660 2.20GHz    |     **2 / 16 / 32** |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be11    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be12    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be13    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be14    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be15    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be16    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be17    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be18    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be19    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be20    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be21    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be22    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be23    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be24    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 | **109.6 GiB** | 1 × 250 GB |     3 × 8 TB |
| sr-be25    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be26    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be27    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| sr-be28    | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| minio1     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| minio2     | Intel Xeon E5-2660 2.20GHz    |         2 / 16 / 16 |     125.3 GiB | 1 × 250 GB |     3 × 8 TB |
| intra2     | Intel Xeon E5-2680 v2 2.80GHz |         2 / 20 / 40 |     251.3 GiB |         없음 |   1 × 960 GB |
| starrocks1 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |
| starrocks2 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |
| starrocks3 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |
| starrocks4 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB | **1 × 4 TB** |
| starrocks5 | Intel Xeon E5-2680 v4 2.40GHz |     **2 / 28 / 28** |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |
| starrocks6 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |
| starrocks7 | Intel Xeon E5-2680 v4 2.40GHz |         2 / 28 / 56 |     503.3 GiB |   1 × 2 TB |     2 × 4 TB |

## 확인이 필요한 차이점

| 호스트        | 확인 내용                                                              |
| ---------- | ------------------------------------------------------------------ |
| sr-be3     | HDD가 2개만 감지됨. 동급 서버는 일반적으로 3개 감지됨.                                 |
| sr-be10    | Hyper-Threading 활성화: 16코어 / 32스레드. 다른 동급 서버는 16코어 / 16스레드.         |
| sr-be24    | 인식 메모리가 109.6 GiB로, 다른 동급 서버의 125.3 GiB보다 적음.                      |
| starrocks4 | HDD가 1개만 감지됨. 다른 StarRocks 서버는 2개 감지됨.                             |
| starrocks5 | Hyper-Threading 비활성화: 28코어 / 28스레드. 다른 StarRocks 서버는 28코어 / 56스레드. |

## `intra2` 메모리 재검증

`hostname`과 `MemTotal`을 함께 재조회한 결과입니다.

| 호스트 | `/proc/meminfo`의 `MemTotal` | 환산값 | 명목 장착 용량 |
|---|---:|---:|---:|
| intra2 | 263,523,700 kB | 251.3 GiB | 약 256 GB |

참고로 화면에서 별도로 확인된 `intra4`의 `MemTotal`은 527,431,568 kB로, 503.0 GiB(명목 약 512 GB)입니다. `intra2`와 `intra4`의 값이 서로 다릅니다.

## 해석 기준

- 메모리는 `/proc/meminfo`의 `MemTotal`을 GiB 단위로 환산했습니다.
- 디스크는 제조사 표기 방식인 decimal GB/TB로 반올림했습니다.
- `lsblk`의 `ROTA=0`은 SSD, `ROTA=1`은 HDD로 분류했습니다.
- 대부분의 디스크 모델은 RAID 컨트롤러의 `LOGICAL VOLUME`으로 노출됩니다. 따라서 표는 운영체제가 인식한 논리 디스크 기준입니다.
- RAID 뒤의 실제 물리 디스크 제조사, 모델, 개수 및 RAID 레벨을 확인하려면 `storcli`, `perccli` 또는 서버 관리 인터페이스를 통한 추가 조사가 필요합니다.
