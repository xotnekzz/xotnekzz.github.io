---
title: <% tp.file.title %>
description: 
date: <% tp.date.now("YYYY-MM-DD") %>
tags:
  - 
featured: false
# draft: true 로 설정 시 프로덕션 빌드(사이트)에서 노출되지 않습니다. 개발 모드에서는 DRAFT 배지와 함께 보입니다.
draft: false
---
> **기간:** 
> **참여인원:** 
> **역할:** 
> **기술 스택:**

## 1. Background & Challenges

SeaweedFS가 온프레미스 서버에서 복제본 3개로 HA 구성이 되어있지만,
IDC 장애 대응을 위한 별도 백업 시스템 구축이 필요.

## 2. Solution & Architecture

SeaweedFS -> S3 or GCS 백업

제일 저렴한 티어로 백업 ( 비용을 고려하여  증분 백업 )

## 3. Results & Impact

## 4. Lessons Learned
