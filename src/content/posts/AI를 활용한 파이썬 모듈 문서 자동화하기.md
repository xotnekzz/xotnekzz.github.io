---
title: AI를 활용한 파이썬 모듈 문서 자동화하기
description: GitLab CI/CD와 Gemini API를 연동하여 사내 Python 모듈 문서를 자동 생성하는 파이프라인 구축
date: 2024-01-01
tags:
  - Python
  - CI-CD
  - LLM
  - Gemini
  - Sphinx
featured: false
---

> **기간:** 2024
**역할:** Senior AI Engineer & Infrastructure (CI/CD 및 LLM 파이프라인 설계)
**기술 스택:** Python, GitLab CI/CD, Sphinx, LLM (Gemini API), RST (ReStructuredText), Git

## 1. Background & Challenges

방대하게 구축된 사내 파이썬 모듈 코드의 **문서화(Documentation)** 부재로 인해 동료 엔지니어들의 코드 이해 및 재사용 난이도가 상승했습니다. 수동 문서화는 엔지니어에게 큰 리소스 부담을 주었고, 코드가 변경될 때마다 문서를 최신 상태로 유지하는 데 실패하는 경우가 빈번했습니다. 이로 인해 사내 기술 자산의 가시성과 재사용성이 저하되는 '기술 부채'가 누적되었습니다.

## 2. Architecture: Doc-as-Code Automation

GitLab CI/CD 파이프라인에 LLM 분석 단계를 추가하여, 코드 변경 시 자동으로 문서가 생성되고 정적 웹 페이지로 배포되는 구조를 설계했습니다.



![image|37](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/f452a5da-afdf-4363-b555-1f75b723dded/Fluentd_to_HDFS_Data-2026-03-13-142259.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB466UZJHHKYU%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153151Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJIMEYCIQC2AVeSOqUHAKXT2J9TqcYXSGAOkFDJu7LjKkW1x70LigIhAPwNIICw%2B3LdnhseF2NRLb%2Fg01QHPx%2BBTUKph7yqfmChKogECIv%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQABoMNjM3NDIzMTgzODA1IgxHraSzPawlzPOs2VUq3AMfRmatF4bL8LJqzXOfCWChKnJiEoMPBZWQE4etMM%2B8SBc8KyLsY3mKyxo0EImbVH6Cnm9WimU5LnFCzS6I91vdvstpzrCE7PC%2FkLULODpyVGDF0MqUGM7iCllwzson%2FR97zo3dUs%2B3MXnXRBYDl9fDB%2F%2FUhvByHRoCzCjK%2FRi6IZPx8Q1LZ7YSO6LAU2vUjjmwXQwZxS2WNKjKaj9n2U%2FaHiNobnAm8CzZ5KajGumUKZy80tGTLdSVDXK3Cw2Ussg8jfDPGe8HUc9otaBTaXxAy2O0g1L8lTfFCtS7KuYNhQ6kE0j1LfcRowoQ6BhkxkFMJs4fwUUyeJnOoXEVNB4UNpSKQz3P3j19ivN6pZPcD48v4qUja2uAx2JJ7KlujR82h2wG0W%2B%2BvxLPAEx3BxFybPlDbnc0q5dmXV%2FuVQcw%2By0jre6XBgUxpEX2NrKB78wcAZlxSwGALPpgpTr5lkMhIobcV%2FVWd8CqTBrq%2F3lDb8Y3v2uyYBuR4AmeWppNS6fKjMLGaHyv8WpzLT3TK7jRSDA6T5%2FWl95ffKvD7N2OV6oDO%2BTkZMPqfDW8I1aX%2Ftd7svh0hq3P6RsN%2FFmLhHDyohrmLLpANzuNiwoMRZv1yJhT4DrW4myUr%2F4w4DD1vc%2FNBjqkAX%2FYYEM9P9lm%2BcEa8q7xx%2BvBHDJtOrxA%2BzlxmbwkZKos0xdUE%2FXu3RyuLmEbMs%2FLP2I%2FeheJw4h7JI3H4c61xKt8CiDtlbkGdt7FGaMRKyb6A814GIzes21gmKFdrLX%2BrN4FsnZUipY8jTvkzwCW%2BojdNzTbZo0joqhbecM10aEwf%2FSzh2G8xrAyf3NN1nP6FCA6rPmItGdjZRVca1AQ15aPhbXf&X-Amz-Signature=2c1e21d6d22519671f421f948eeddfed6d1a06fbc4e83b77dbd4db806f8a2c8b&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)

## 3. Solution & Technical Insights

1. **LLM 기반 자동 Docstring 생성 및 주입**
- **[Issue]** 엔지니어들이 개별 함수나 클래스에 상세한 설명을 작성하는 리소스 부담이 컸습니다.
- **[Solution]** Merge Request 발생 시 **Gemini API**를 활용하여 변경된 코드를 분석하고, 함수의 역할, 파라미터 정보, 리턴값 등을 요약한 **Python Docstring을 자동 생성**하도록 파이프라인을 구축했습니다. 이를 통해 코드 자체의 가독성을 즉각적으로 향상시켰습니다.
1. **Sphinx 및 GitLab CI/CD 연동을 통한 문서 배포 자동화**
- **[Issue]** 문서가 코드와 분리되어 관리되면 최신성을 유지하기 어렵습니다.
- **[Solution]** 생성된 Docstring을 기반으로 **Sphinx** 도구를 사용하여 **RST(ReStructuredText) 문서**를 자동으로 작성하고, 이를 GitLab Pages를 통해 정적 웹 페이지로 배포하는 전 과정을 자동화했습니다. 엔지니어는 별도의 문서 작업 없이 코드 커밋만으로 최신 기술 문서를 동료들에게 공유할 수 있게 되었습니다.
1. **학습 비용 최소화 및 코드 재사용성 극대화**
- 동료들이 사내 라이브러리를 사용할 때, 소스 코드를 일일이 분석할 필요 없이 자동으로 생성된 문서를 즉시 참고할 수 있는 환경을 조성하여 팀 전체의 개발 생산성을 높였습니다.
## 4. Impact & Result

- 🚀 **문서화 리소스 90% 이상 절감:** 엔지니어가 직접 문서를 작성하고 업데이트하는 물리적 시간을 획기적으로 줄였습니다.
- 🦾 **기술 자산의 가시성 확보:** 사내에 흩어져 있던 파이썬 모듈들을 중앙 집중화된 문서 포털에서 검색하고 활용할 수 있는 체계를 완성했습니다.
- 💰 **협업 효율 증대:** 신규 입사자나 타 부서 엔지니어들의 코드 이해 비용을 최소화하고, 기술 자산의 재사용률을 높여 중복 개발을 방지했습니다.
- 🎯 **지속 가능한 기술 부채 관리:** 코드가 변하면 문서도 자동으로 변하는 선순환 구조를 통해 문서 최신화 문제를 원천적으로 해결했습니다.


