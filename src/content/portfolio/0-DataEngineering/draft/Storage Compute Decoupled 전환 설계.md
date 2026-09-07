---
title: Storage Compute Decoupled 전환 설계
description: ""
date: 2026-09-08
tags: []
featured: false
# draft: true 로 설정 시 프로덕션 빌드(사이트)에서 노출되지 않습니다. 개발 모드에서는 DRAFT 배지와 함께 보입니다.
draft: true
---
> **기간:** 
> **참여인원:** 
> **역할:** 
> **기술 스택:**

## 1. Background & Challenges

31대의 Doris 서버 하드웨어 스펙이 avx2 지원하지 않는 등 MPP 기반 OLAP 클러스터로 쓰기엔 불안정함.

31대 이 장비를 seaweedFS 볼륨서버로 이관하여 약 670TB 스토리지 용량을 확보
avx2 지원, ssd가 있는 고성능 컴퓨트로 분리

## 2. Solution & Architecture

<!-- 이미지는 images/파일명.svg 형식 사용 (Obsidian 미리보기 + 웹 빌드 모두 동작)
예: ![설명](images/architecture.svg) -->

## 3. Results & Impact

## 4. Lessons Learned
