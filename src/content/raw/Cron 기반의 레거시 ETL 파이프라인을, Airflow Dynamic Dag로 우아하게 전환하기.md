---
title: "Cron 기반의 레거시 ETL 파이프라인을, Airflow Dynamic Dag로 우아하게 전환하기"
source: "https://tedi.tistory.com/46"
author:
  - "[[Tedi__]]"
published: 2025-12-02
created: 2026-05-12
description: "1. 들어가며안녕하세요. 글로벌 모바일 게임사 BI팀에서 데이터 엔지니어링 및 백오피스 개발을 담당하고 있습니다. 제가 처음 입사했을 당시, 사내 ETL 파이프라인은 Bash와 Python 스크립트로 작성되어 Cron 서버 스케줄러를 통해 운영되고 있었습니다. 초기에는 문제가 없었지만, 서비스가 성장하며 ETL 파이프라인이 수십 개 이상으로 늘어나자 유지보수 비용이 기하급수적으로 증가하는 문제에 직면했습니다. 당시 저희 팀을 가장 괴롭혔던 문제들은 다음과 같았습니다.가시성 부재: 터미널에 접속하지 않으면 현재 ETL이 돌고 있는지, 실패했는지 파악이 불가능함.높은 진입장벽: 간단한 로직 수정에도 Bash 쉘 스크립트 지식이 필수적임.복구의 어려움: 작업 실패 시 재시도(Retry)나 특정 시점부터의 재처.."
tags:
  - "clippings"
---
## 1\. 들어가며

안녕하세요. 글로벌 모바일 게임사 BI팀에서 데이터 엔지니어링 및 백오피스 개발을 담당하고 있습니다.

제가 처음 입사했을 당시, 사내 ETL 파이프라인은 Bash와 Python 스크립트로 작성되어 Cron 서버 스케줄러를 통해 운영되고 있었습니다. 초기에는 문제가 없었지만, 서비스가 성장하며 ETL 파이프라인이 수십 개 이상으로 늘어나자 유지보수 비용이 기하급수적으로 증가하는 문제에 직면했습니다.

당시 저희 팀을 가장 괴롭혔던 문제들은 다음과 같았습니다.

- **가시성 부재:** 터미널에 접속하지 않으면 현재 ETL이 돌고 있는지, 실패했는지 파악이 불가능함.
- **높은 진입장벽:** 간단한 로직 수정에도 Bash 쉘 스크립트 지식이 필수적임.
- **복구의 어려움:** 작업 실패 시 재시도(Retry)나 특정 시점부터의 재처리(Backfill)가 매우 까다로움.
- **비효율적인 확장:** 파이프라인 하나를 추가할 때마다 기존 코드를 '복사/붙여넣기' 해야 하는 구조적 한계.

결국 우리는 Airflow 도입을 결정했고, 기존 Cron 기반의 파이프라인을 전면 이관해야 하는 과제를 안게 되었습니다. 단순히 옮기는 것을 넘어, **"어떻게 하면 이 비효율을 반복하지 않을까?"** 를 고민했습니다.

이번 포스팅에서는 레거시 시스템을 **Airflow Dynamic DAG** 구조로 전환하여, **"코드 수정 없이 설정(Config)만으로 파이프라인을 찍어내는 시스템"** 을 구축한 PoC 및 적용 과정을 공유하고자 합니다.

## 2\. 목표

단순히 Cron을 Airflow로 옮기는 것 뿐만 아니라 앞으로도 계속 늘어날 파이프라인을 고려하여 다음과 같은 요구사항을 세웠습니다.

1\. Code-less Expansion: 파이프라인 추가 및 변경시 Python 코드를 수정하지 않는다.

2\. High Visibility: DAG별 진행 사항을 UI에서 직관적으로 확인해야 한다.

3\. Data Quality: 데이터 적재 후 검증 로직을 추가해야 한다.

4\. Easy Management: 파이프 라인 추가/삭제 등 관리가 편해야 한다.  
  
이를 위해 선택한 전략은 Dynamic Dag(동적 DAG 생성) 입니다. 수십 개의 개별 파이프라인을 하나의 Template 코드와 MetaData로 관리하는 방식입니다.  

## 3\. 설계 및 구현: Metadata Driven Architecture

**3.1 Metadata 구조 (JSON)**

가장 먼저 한일은 기존 ETL 파이프라인을 추상화하여 설정값으로 정의하는 것이었습니다. YAML을 사용하는 것을 고려했으나 Airflow Variable 저장의 편의성을 위해 JSON으로 구현하였습니다.

데이터 구조는 크게 Category > Source 2단계 계층으로 구성하였습니다.

```javascript
{
  "ad_network_A": {
    "api_group_config": "group_v1",
    "metrics": ["revenue", "impressions", "clicks"],
    "common_args": {
      "owner": "data_engineering",
      "retries": 3
    },
    "sources": {
      "unity_ads": {
        "accounts": ["account_1", "account_2"],
        "schedule": "0 9 * * *",
        "description": "Unity Ads Daily ETL",
        "tags": ["marketing", "external_api"],
        "catchup": false
      },
      "google_ads": {
        "accounts": ["account_x", "account_y"],
        "schedule": "30 9 * * *",
        "description": "Google Ads Daily ETL",
        "tags": ["marketing", "google"],
        "catchup": false
      }
    }
  }
}
```

성향이 비슷한 ETL Source를 Category로 그룹화하여 공통 속성을 만들고, 개별 소스별로 Airflow Dag Config 또는 ETL에 필요한 속성을 추가하였습니다.

**3.2 DAG Factory 구현**

단 하나의 Python 파일이 위의 메타데이터(JSON)을 순회하며 DAG 객체를 동적으로 생성합니다.  
Airflow가 주기적으로 Python 파일을 읽어 메타데터의 업데이트가 있다면 DAG를 생성 및 변경 합니다.  

```python
from __future__ import annotations
import logging
import os
import json
import subprocess
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from airflow import DAG
from airflow.decorators import task, dag
from airflow.models import Variable, Param
from airflow.utils.dates import days_ago
from airflow.operators.python import get_current_context

# 1. Airflow Variable에서 메타데이터 로드
dags_info = Variable.get("marketing_pipeline_meta", deserialize_json=True)

# 2. 메타데이터 순회하며 DAG 생성
for category in dags_info.keys():
    category_info = dags_info[category]
    
    for pid, pid_info in category_info["pids"].items():
        # DAG ID 및 설정값 준비
        dag_id = f"marketing_etl_{category}_{pid}"
        
        # Default Args 병합
        default_args = {
            'owner': 'data_engineering',
            'retries': 1,
            'retry_delay': timedelta(minutes=5)
        }
        if "common_args" in category_info:
            default_args.update(category_info["common_args"])

        # Manual Run을 위한 파라미터 설정
        params = {
            "date": Param(
                default=datetime.today().strftime("%Y-%m-%d"),
                description="Target Date (YYYY-MM-DD)",
                type="string",
                format="date"
            )
        }

        # 3. TaskFlow API를 사용한 DAG 정의 및 생성
        @dag(
            dag_id=dag_id,
            default_args=default_args,
            schedule=pid_info.get("schedule", "@daily"),
            tags=pid_info.get("tags", []),
            catchup=pid_info.get("catchup", False),
            params=params,
            max_active_runs=category_info.get("max_active_runs", 1)
        )
        def marketing_pipeline_etl(pid, category, category_info, pid_info):
            
            @task(task_id="initialize_date")
            def initialize_date(n_days_ago: int):
                """Manual Run(파라미터)과 Scheduled Run(자동 계산) 모두 지원"""
                context = get_current_context()
                if context["dag_run"].external_trigger:
                    return context["params"].get("date")
                else:
                    return (context["execution_date"] - timedelta(days=n_days_ago)).strftime("%Y-%m-%d")

            @task(task_id="extract")
            def extract(target_date, pid):
                # API 데이터 추출 로직 (Requests 등 활용)
                logging.info(f"Extracting {pid} data for {target_date}")
                return pd.DataFrame(...) # 예시 데이터프레임

            @task(task_id="transform")
            def transform(df: pd.DataFrame, category: str):
                # 데이터 변환 로직
                return df

            @task(task_id="validate")
            def validate(df: pd.DataFrame):
                # 데이터 매핑 검증 로직
                return df

            @task(task_id="convert_to_long_format")
            def convert_to_long_format(df: pd.DataFrame, metrics: list):
                # Wide -> Long Format 변환 (Melt), Schema 고정
                id_vars = [col for col in df.columns if col not in metrics]
                return df.melt(id_vars=id_vars, value_vars=metrics, var_name="metric", value_name="value").query("value > 0")

            @task(task_id="delete_and_load")
            def delete_and_load(df: pd.DataFrame, target_date, pid):
                # 멱등성 보장 (Delete) 및 StarRocks Stream Load (Curl)
                pass

            # --- Task Flow ---
            target_date = initialize_date(category_info.get("n_days_ago", 1))
            
            raw_data = extract(target_date, pid)
            transformed = transform(raw_data, category)
            validated = validate(transformed)
            final_data = convert_to_long_format(validated, category_info.get("metrics", []))
            
            delete_and_load(final_data, target_date, pid)

        # 4. DAG 함수 호출하여 등록 (Loop 내부에서 즉시 실행)
        marketing_pipeline_etl(pid, category, category_info, pid_info)
```

흐름만 이해할 수 있도록 POC 코드만 제공합니다.  
  
**\[디테일에 신경 쓴 부분들\]  
  
**단순히 "돌아가는 코드"가 아니라, 운영 안정성을 위해 몇가지를 고려하였습니다.

**1\. 유연한 날짜 처리 (initialize\_date)**  
스케쥴러에 의해 자동으로 돌 때는 execution\_date를 사용하지만, 장애 발생으로 재입력이 필요한 경우 수동으로 특정 날짜를 돌려야 할 때 Airflow Params(date)를 우선순위로 받고 입력하도록 처리하였습니다. 이를 통해 Backfill이 매우 간편해졌습니다.  
  
**2\. 데이터 무결성 검증 (validate)  
**데이터를 무작정 적재하지 않습니다. 태스크내에 검증로직을 추가하여 오염된 지표가 입력되지 않도록 합니다.  
이는 BI 대시보드의 신뢰도를 높이는 일이라고 생각합니다.  
  
**3\. 멱등성 및 대용량 처리 ( delete\_and\_load )**

\- 멱등성: DELETE 후 LOAD 하는 트랜잭션 패턴을 추가하여 데이터 중복을 방지 합니다.  
\- Stream Load: INSERT문을 사용하지 않고 데이터프레임을 CSV로 변환하여 Starrocks의 Stream Load를 사용하여 대량의 데이터를 수 초내로 적재합니다.  

## 4\. Custom Management UI (Airflow Plugin)

Airflow Variable (JSON)을 직접 수정 하는 것은 문법 에러 등 실수할 위험 있으며 이 실수 하나로 모든 DAG에 장애를 일으킬 수 있습니다. Airflow의 Plugin 기능을 활용하여 Flask Appbuilder를 통해 metadata를 관리 할 수 있는 전용 UI를 개발하였습니다.
![[다운로드.png]]
파이프라인 운영자는 복잡한 코드를 이해하지 않아도 UI를 통해 파이프라인의 설정 변경을 쉽게 할 수 있습니다. ( ex: 스케쥴 시간 변경, 담당자 변경, 기타 설정 변경 등)  

## 5\. 마치며

자세한 내용은 많이 생략하였지만 이 작업을 통해서 코드 작업 없이 수십개의 ETL 파이프라인을 운영을 안정적이고 쉽게 할 수 있도록 기여하였습니다.

특히 Airflow DAG의 스케쥴시간을 바꾸려고만 해도 코드 수정이 필요했는데 이 작업을 통해 몇 번 클릭 만으로 누구나 쉽게 설정할 수 있게되었습니다.  
  
※ 본 포스팅에 사용된 코드와 데이터 구조는 보안을 위해 실제 운영 환경과는 다르게 일반화(Sanitized) 되었습니다.

#### 'Data Engineering' 카테고리의 다른 글

| [Apache Kafka \[1\] - 카프카의 배경과 근본](https://tedi.tistory.com/52) (0) | 2025.12.17 |
| --- | --- |
| [StarRocks의 압도적 퍼포먼스 경험기](https://tedi.tistory.com/37) (0) | 2025.12.05 |
| [Airflow 살펴보기](https://tedi.tistory.com/31) (0) | 2025.12.01 |
| [MongoDB 설정파일 세팅 및 Mongod 실행 방법](https://tedi.tistory.com/7) (0) | 2019.07.03 |
| [MongoDB 계정 설정 방법](https://tedi.tistory.com/6) (0) | 2019.07.03 |
