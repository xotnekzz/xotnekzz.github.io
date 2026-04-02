---
title: PROAS Prediction Data Pipeline
description: 딥러닝 기반 pROAS/pLTV 예측 모델을 위한 피처 데이터 공급 및 실시간 서빙 파이프라인 구축
date: 2022-01-01
tags:
  - Python
  - Airflow
  - Deep Learning
  - Data Pipeline
  - Marketing
featured: false
---

> **기간:** 2022 ~ 2023
**역할:** Data Engineer (딥러닝 학습용 데이터 피딩 및 서빙 파이프라인 구축)
**기술 스택:** Python, SQL, Deep Learning Model Integration, MariaDB (Data Mart), Airflow, Pandas, NumPy

## 1. Background & Challenges

마케팅 캠페인을 집행할 때 초기(3~7일) 성과를 정확히 예측하지 못하면 예산 낭비 리스크가 큽니다. 특히 딥러닝 모델을 활용한 **pLTV(Predicted Life Time Value)** 및 **pROAS(Predicted Return on Ad Spend)** 예측이 필요했지만, 모델 학습에 필요한 대규모 피처(Feature) 데이터를 정제하여 공급하고 예측 결과를 실시간으로 마케터에게 서빙하는 체계적인 데이터 루프(Data Loop)가 부재했습니다.

## 2. Architecture: Marketing Data & ML Feedback Loop

Ad-Network의 캠페인 퍼포먼스(Spend, Install, Impression, Click)와 MMP(Appsflyer)의 유저 행동 데이터(ROAS, Retention, Session 등)를 통합하여 마케팅 데이터 마트를 구축하고, 이를 기반으로 딥러닝 모델이 미래 매출을 예측하여 실무에 환류되는 구조를 설계했습니다.

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/9dde54c4-6364-4d39-ad48-07eb9409d439/ua_proas.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466YKD5Z3AR%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153153Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEMT%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJIMEYCIQDgpt%2FjSpLAhrRofnvYxW%2FjPr%2FbzvitJZ7FT0756mV7OAIhAOafXKVmqVW%2BK2V5aV5SytUrPmCA9Jb9Jj%2BnOeUz0qlyKogECI3%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQABoMNjM3NDIzMTgzODA1Igy5rJuw4FJiJ0UnE24q3AO8UHgvbevg9rU9LyOx5EZJcf5Iwah%2BaiOaWXQYSMRmRCk3eqSsegSBn28yRLy1XYqk5ychujCugZ5P9MPPfxAVmFx6oj0wAqA%2BhfZ5XjsR9bhEy5zj09SDqUV2Ean7epBxs7uq%2B%2B4w76xNy2GtS89Aaw7Enakj%2BrTiZL5wYOq02tuzHb%2FYL1tkD6TiIeW80Bl2%2FY2O16M7RCEegP%2BMRVpls%2FjNP%2B3gHJLwDwZDg36Vs8VJ4qd0KQFb5VqKZ8KucnWFJhzasWP6mLbpKx%2B3f5%2FUYeoMIJHAqPquumTeYLnbX2t9r6%2BfF%2BUNyeT8nSoFWDrc63IGtcOzYRcoZYt4rgLNhHPimYLOdi7pZjfvLuSF6XU%2F%2FV%2Fs%2FBQJ4pcStB4MAMVXMQk75X%2BVmIuGVrN0R60lwQfhFzkDiG3fjhcUyqzozB5%2FBdctca56l1sDqByGY61bKFZpx2WOTDUFwBH9X9z61HFjbi2kaWwBwYoPlv9Q1eU8ga5El72B3mZjwr1kpHZcYbhfydKrRlhZxUwwb98FUBxqyOS2yYIXMWqQrwWu5KRi8TKa630NYMMwQ2Vsnz7gYauyBryVIDSnR9bBmjK1WnjY1w%2BhVvONTuuINxW48Rq1XTH3Wf187RMwsjDv7M%2FNBjqkAWlIG%2FhylogepDfzCKe9QDCkBkvaAoMBn5%2Blv2bMjAVAofiboRCLauFwKlZRjSTxIWjCquZDQDrST28Htxn7UjBkgM6k%2BzhNMCTfwXAxGy%2BN9Bi5kwrmmFbNri9fhrkNZLWi2geHp%2FzwpOD%2Bjp8yTZk%2B0YVkwu5uF%2BE9IyQeNmOaztgWPEcbKJ6ouNuVhjpBenDKiyGZBjhxv3%2F4o2jv75PEIAls&X-Amz-Signature=e2f5013ed657f7d1cc735adb3847a50256cdfb1a8e87b95e3041ba1ab52ecc14&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



## 3. Solution & Technical Insights

1. **딥러닝 학습 최적화를 위한 데이터 피딩(Feeding) 파이프라인**
- **[Issue]** 매체별 Spend/Impression 데이터와 MMP의 정교한 유저 지표(Retention, ROAS 등)가 파편화되어 모델 학습을 위한 피처 생성에 많은 공수가 발생했습니다.
- **[Solution]** **Airflow**를 활용하여 다양한 API 및 Raw Data를 통합하고, 데이터 사이언티스트가 바로 학습에 사용할 수 있는 형태의 **정규화된 학습 데이터셋**을 공급하는 파이프라인을 구축했습니다.
1. **LTV 예측 모델(pRevenue 7, 28, 60, 90) 자동화 및 서빙**
- **[Issue]** 데이터 사이언티스트가 개발한 **pRevenue 7~90 모델**을 실무에 적용하기 위해서는 매일 대규모 인퍼런스와 결과 서빙이 필요했습니다.
- **[Solution]** 모델 예측 과정을 자동화하여 매일 오전 캠페인별 예측 매출 데이터를 **MariaDB 데이터 마트**로 역전송(Reverse ETL)했습니다. 이를 통해 마케터가 대시보드에서 예측값 기반의 예산 배분을 수행할 수 있는 환경을 제공했습니다.
1. **경영진 및 실무자를 위한 다각도 인사이트 제공**
- 예측된 매출 데이터를 집계하여 마케터는 세부 캠페인 운영을 최적화하고, 경영진은 미래 비즈니스 성과를 예측하여 전략적인 의사결정을 내릴 수 있도록 통합 BI 환경을 구축했습니다.
## 4. Impact & Result

- 🚀 **조기 최적화 의사결정 지원:** 캠페인 집행 초기 데이터만으로 성과를 예측하여 마케팅 예산 낭비 리스크를 최소화했습니다.
- 🦾 **딥러닝 실무 적용 가속화:** 모델 연구 단계에 머물던 딥러닝 기술을 실제 운영 파이프라인에 이식하여 비즈니스 가치를 창출했습니다.
- 💰 **마케팅 성과 개선:** 예측 모델을 기반으로 한 정교한 캠페인 운영을 통해 전반적인 ROAS 지표 향상에 기여했습니다.
- 🎯 **데이터 기반 조직 문화 확산:** 마케터들이 단순 감이 아닌 예측 데이터를 바탕으로 실험하고 검증하는 문화를 정착시켰습니다.
