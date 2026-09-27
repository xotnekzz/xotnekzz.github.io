---
title: Amazon EKS 이론 — 관리형 Kubernetes의 경계와 데이터 워크로드
description: EKS 컨트롤 플레인, 데이터 플레인, 노드 방식, 네트워크와 Pod 실행 흐름을 설명합니다.
date: 2026-09-26
tags: [AWS, EKS, Kubernetes, DataEngineering, Architecture]
draft: false
---

Amazon Elastic Kubernetes Service(EKS)는 Kubernetes API와 클러스터 제어 영역을 AWS가 운영하도록 맡기고, 사용자는 그 위에 Pod와 애플리케이션을 배포하는 관리형 Kubernetes 서비스입니다. EKS는 Airflow, Spark, Flink, Kafka Connect 같은 컨테이너형 데이터 워크로드를 실행할 기반이 될 수 있습니다. EKS 자체가 데이터 수집·변환 엔진이나 데이터 저장소인 것은 아닙니다.

![Amazon EKS의 관리형 제어 경로와 워크로드 경로](/images/posts/data-platform-theory/aws-eks-architecture.svg)

![AWS 공식 문서의 EKS Standard와 Auto Mode 구성 그림](https://docs.aws.amazon.com/images/eks/latest/userguide/images/whatis.png)

[공식 그림 출처: What is Amazon EKS?](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)

## 관리 책임을 두 영역으로 나눕니다

EKS 클러스터는 Kubernetes의 두 영역, **Control Plane**과 **Data Plane**으로 이해할 수 있습니다. AWS는 Control Plane을 관리하지만, 표준 클러스터에서는 애플리케이션 Pod를 실행할 노드 용량과 그 위의 워크로드 운영 책임이 사용자에게 남습니다.

| 영역 | 주요 구성요소 | 담당하는 일 |
|---|---|---|
| Control Plane | Kubernetes API Server, Scheduler, etcd, Controller Manager | 클러스터 API를 제공하고 선언된 리소스 상태를 저장·조정하며 Pod 배치 결정을 관리합니다. EKS는 이 영역의 가용성과 패치를 운영합니다. |
| Data Plane | EC2 노드 또는 Fargate 실행 환경, kubelet, 컨테이너 런타임 | 컨테이너를 실제로 실행하고 로컬 볼륨을 연결하며 상태 확인을 수행합니다. |
| AWS 연결 계층 | VPC, 서브넷, 보안 그룹, IAM, 로드 밸런서 | Control Plane과 노드의 연결, 사용자·워크로드 인증, 애플리케이션 트래픽 경로를 구성합니다. |

AWS 공식 아키텍처 문서는 관리형 Control Plane이 여러 가용 영역에 분산되어 있다고 설명합니다. 이는 사용자가 API Server와 etcd를 직접 설치·패치하지 않아도 된다는 의미입니다. 클러스터에 실행하는 애플리케이션의 장애, 잘못된 Pod 설정, 데이터베이스 용량 문제까지 AWS가 대신 해결한다는 뜻은 아닙니다.

## Pod가 실행되기까지의 요청 흐름

1. 운영자나 배포 자동화가 `kubectl`, AWS API 또는 배포 도구를 사용해 Kubernetes API에 Deployment, Job, Service 같은 리소스를 제출합니다.
2. API Server가 인증·인가와 리소스 검증을 거쳐 원하는 상태를 저장합니다. 사용자의 AWS IAM 권한은 AWS에서 신원을 확인하는 데 쓰이고, Kubernetes RBAC은 해당 신원이 어떤 Kubernetes 리소스를 조작할 수 있는지 제한합니다.
3. Kubernetes Scheduler가 각 Pod의 CPU·메모리 요청, 노드 조건, Affinity, 가용 자원을 보고 배치할 노드를 정합니다. 노드가 부족하면 Cluster Autoscaler나 Karpenter 등의 용량 조정 구성요소가 새 노드를 요청할 수 있습니다.
4. 노드의 kubelet이 컨테이너 이미지를 가져와 컨테이너를 시작하고, 준비 상태와 생존 상태를 Control Plane에 보고합니다.
5. Service와 Ingress 또는 Load Balancer가 준비된 Pod로 트래픽을 전달합니다. 데이터 파이프라인의 작업 Pod는 이 경로와 별도로 VPC 라우팅·보안 그룹·IAM 권한을 통해 S3, RDS, MSK 등의 AWS 리소스에 접근합니다.

이 흐름에서 Kubernetes API는 **상태를 선언하고 조정하는 제어 경로**입니다. 원본 데이터가 API Server를 통과하는 것이 아닙니다. 업무 데이터는 애플리케이션 Pod에서 목적지 서비스까지의 네트워크 경로를 따라갑니다.

## 노드 공급 방식은 운영 책임이 다릅니다

| 방식 | 노드 운영 특징 | 데이터 플랫폼에서의 고려사항 |
|---|---|---|
| Managed Node Groups | AWS가 EC2 노드 그룹의 생성·업데이트·종료 절차를 통합합니다. 인스턴스 유형과 용량 정책은 사용자가 선택합니다. | 고정형 Worker, Spark Executor, Flink TaskManager처럼 인스턴스 자원 요구가 분명한 작업에 맞춰 노드 그룹을 나눌 수 있습니다. |
| Self-managed Nodes | EC2 노드의 생명주기와 부트스트랩을 더 직접 제어합니다. | 커널·AMI·노드 설정을 세밀하게 통제할 수 있지만 패치와 교체 자동화 책임도 커집니다. |
| EKS Auto Mode | AWS가 관리하는 범위를 Control Plane에서 노드·스케일링·일부 핵심 클러스터 기능까지 넓힙니다. | 인프라 운영을 줄이는 대신 Auto Mode가 지원하는 정책과 제약에 맞는지 확인해야 합니다. |
| AWS Fargate | 선택된 Pod를 서버리스 실행 환경에서 구동합니다. 사용자가 EC2 노드를 직접 관리하지 않습니다. | 짧거나 분리된 작업 Pod에 유용할 수 있습니다. DaemonSet, 스토리지, 네트워크 및 리소스 제약을 검토해야 합니다. |

EKS의 정확한 제공 기능과 지원 범위는 클러스터 모드와 Kubernetes 버전에 따라 달라집니다. 표준 EKS는 관리형 Control Plane을 제공하며, Auto Mode는 노드 등 Data Plane 관리도 서비스 범위에 포함합니다. 둘을 같은 운영 모델로 간주하지 않는 편이 중요합니다.

## 네트워크와 권한은 데이터 경로의 일부입니다

EKS의 Control Plane은 AWS 관리 영역에서 실행되고, 워커 노드는 고객 VPC 안에 있습니다. API Endpoint는 공개 접근 또는 VPC 내부 접근으로 구성할 수 있습니다. 노드와 API Endpoint 간 통신은 EKS가 설정한 네트워크 연결을 거치므로, 서브넷·라우팅·보안 그룹과 DNS가 맞지 않으면 Pod 스케줄링 자체는 성공해도 이미지 가져오기나 AWS 서비스 접근이 실패할 수 있습니다.

데이터 워크로드에서는 권한을 사용자와 Pod로 분리해 생각합니다. 운영자의 IAM Role은 클러스터 관리 권한을 부여하고, Pod에 연결된 Kubernetes ServiceAccount 및 IAM 연동은 S3 버킷이나 Secrets Manager 같은 AWS 자원 접근을 제한합니다. 애플리케이션의 모든 Pod에 노드 IAM Role의 광범위한 권한을 공유시키면 권한 경계가 흐려집니다.

컨테이너 이미지 저장소(ECR), 영속 볼륨(EBS/EFS 등), Load Balancer, CloudWatch 같은 서비스는 EKS 외부의 별도 구성요소입니다. EKS API를 생성했다고 이 서비스들이 자동으로 필요한 권한과 네트워크를 갖추는 것은 아니므로, 각 연동의 IAM Role·CSI/Controller·네트워크 정책을 따로 확인합니다.

## 데이터 파이프라인에서 맡는 역할

- Airflow를 EKS에 배포하면 Scheduler·API Server·DAG Processor 등의 상시 Pod를 실행할 수 있습니다. KubernetesExecutor를 선택할 때는 Task별 Pod가 추가로 생성됩니다.
- Spark on Kubernetes는 Driver와 Executor Pod를 사용해 분산 배치를 실행할 수 있습니다.
- Flink Kubernetes Operator 등의 방식은 JobManager와 TaskManager 생명주기를 Kubernetes 위에서 관리할 수 있습니다.
- MSK Connect 대신 자체 Kafka Connect Worker를 운영하거나, DMS가 제공하지 않는 특수 연결·변환 애플리케이션을 실행할 수 있습니다.

이때 EKS가 관리하는 것은 컨테이너 실행 환경의 일부입니다. 데이터의 체크포인트·재처리 가능성·중복 제거·테이블 스키마 진화는 Airflow, Spark, Flink, Kafka, 애플리케이션이 제공하는 기능과 설계에 달려 있습니다.

## 장애와 용량을 분리해 진단합니다

Pod가 `Pending`이면 노드 용량, PVC 바인딩, 리소스 요청, 스케줄 제약을 먼저 확인합니다. `ImagePullBackOff`는 레지스트리 자격 증명·네트워크·이미지 태그 문제일 수 있고, Pod가 `Running`인데 업무 데이터 연결이 실패한다면 VPC 경로·보안 그룹·DNS·IAM을 살펴봅니다. 노드가 `NotReady`인 문제와 애플리케이션 프로세스가 오류를 낸 문제도 구분해야 합니다.

데이터 워크로드의 CPU와 메모리 Request/Limit은 스케줄링과 안정성의 입력값입니다. 지나치게 낮은 요청은 같은 노드에 Pod가 과밀 배치되게 하고, 지나치게 높은 요청은 유휴 자원을 늘리거나 스케줄을 막을 수 있습니다. Spark의 Executor 수나 Flink의 병렬도만 높여서는 실제 노드 용량과 네트워크 처리량이 따라오지 않을 수 있습니다.

## 핵심 정리

EKS는 Kubernetes Control Plane 운영을 AWS에 맡기는 클러스터 서비스입니다. Pod가 실행될 Data Plane은 선택한 노드 방식에 따라 AWS와 사용자의 운영 경계가 달라집니다. EKS를 데이터 파이프라인에 도입할 때는 Kubernetes 제어 흐름과 애플리케이션 데이터 경로를 분리하고, 네트워크·권한·컴퓨팅 자원·영속성 책임을 각 계층에서 확인해야 합니다.

**공식 문서:** [What is Amazon EKS?](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html), [Amazon EKS architecture](https://docs.aws.amazon.com/eks/latest/userguide/eks-architecture.html), [Kubernetes concepts](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-concepts.html), [EKS Control Plane best practices](https://docs.aws.amazon.com/eks/latest/best-practices/control-plane.html)
