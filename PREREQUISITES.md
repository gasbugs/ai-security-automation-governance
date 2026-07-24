# AI 기반 보안 업무 자동화와 거버넌스 사전 준비 가이드

이 문서는 AI 기반 보안 업무 자동화와 거버넌스 과정에서 다음 두 실습을 운영하기
전에 AWS 계정 관리자와 강사가 확인해야 할 권한, 인스턴스, 네트워크, Quota 및
운영 준비 사항을 정리합니다.

- AWS Network Firewall + Transit Gateway 실습
- OWASP Top 10 for LLM GPU 실습

두 프로젝트는 같은 저장소에 있지만 서로 독립된 Terraform 프로젝트입니다.
한 프로젝트를 제거한 후 다른 프로젝트를 실행하며, 두 환경을 동시에 생성하지
않습니다.

## 1. 필요한 IAM 권한 수준

### AdministratorAccess 필요 여부

상시 `AdministratorAccess`는 필요하지 않습니다. 아래의 단일 고객 관리형 정책을
Terraform 실행 역할에 연결하면 두 프로젝트를 모두 배포하고 제거할 수 있습니다.

다만 다음 항목은 계정 관리자 또는 클라우드 운영팀의 최초 1회 협조가 필요할 수
있습니다.

- 고객 관리형 정책과 Terraform 실행 역할 생성
- Network Firewall 및 CloudWatch Logs 서비스 연결 역할 생성 허용
- EC2 GPU Service Quota 상향 신청
- AWS Organizations SCP 또는 Permissions Boundary 예외 처리

권장 운영 방식은 다음과 같습니다.

1. `AWS-Security-Lab-Deployer`와 같은 실습 전용 역할을 생성합니다.
2. 아래 통합 정책을 이 역할에 연결합니다.
3. 강사는 역할을 AssumeRole하여 Terraform을 실행합니다.
4. 실습 종료 후 `terraform destroy`를 수행하고 역할의 정책 연결을 해제합니다.

수강생에게는 관리자 권한이나 Terraform 배포 권한을 부여하지 않습니다. 수강생이
AWS CLI를 직접 사용하는 경우에도 본인 인스턴스에 대한 SSM 접속과 EC2
시작·중지 권한만 별도로 부여합니다.

### 필요한 AWS 서비스

| 서비스 | 사용 목적 |
|---|---|
| EC2 | 실습 인스턴스, 보안 그룹, EBS 및 Elastic IP |
| VPC | VPC, Subnet, IGW, NAT Gateway 및 Route Table |
| Transit Gateway | 중앙 집중식 방화벽 트래픽 라우팅 |
| AWS Network Firewall | 방화벽, 정책, Stateful Rule Group 및 로그 설정 |
| IAM | EC2/Lambda 역할, Instance Profile 및 PassRole |
| Systems Manager | SSH 없이 Session Manager로 인스턴스 접속 |
| CloudWatch Logs | Network Firewall와 Lambda 로그 |
| Lambda | OWASP 실습 인스턴스 자동 종료 |
| EventBridge | 자동 종료 스케줄 |
| SNS | 예산 경보 이메일 |
| AWS Budgets | 일별 및 강의 전체 예산 경보 |
| Service Quotas | 현재 Quota 조회 및 증설 요청 |
| STS | Terraform 실행 계정 확인 |

### 통합 IAM 정책

아래 정책의 `<ACCOUNT_ID>`를 실제 12자리 AWS 계정 ID로 변경한 후 고객 관리형
정책으로 생성합니다. 이 정책은 실습 전용 계정 또는 실습 전용 배포 역할에만
연결하는 것을 전제로 합니다.

지역 서비스는 명시적 Deny를 사용해 버지니아 북부 `us-east-1`에서만
허용합니다. IAM, STS, AWS Budgets는 글로벌 서비스이므로 이 리전 차단에서
제외합니다. 이 Deny는 같은 역할에 연결된 다른 정책보다 우선하므로 다른 정책으로
타 리전 권한을 우회할 수 없습니다.

복사해서 사용할 JSON 원본은
[`policies/lab-deployer-policy.json`](policies/lab-deployer-policy.json)에
있습니다. AWS 실계정 검증 결과와 검증 한계는
[`IAM_POLICY_VALIDATION.md`](IAM_POLICY_VALIDATION.md)를 확인하세요.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRegionalActionsOutsideUsEast1",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "sts:*",
        "budgets:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    },
    {
      "Sid": "ReadAccountInfrastructureAndQuotaInformation",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "ec2:Describe*",
        "iam:GetAccountSummary",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "ssm:GetParameter",
        "servicequotas:Get*",
        "servicequotas:List*",
        "servicequotas:RequestServiceQuotaIncrease"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageEC2VpcNatTransitGatewayAndInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:ReplaceRouteTableAssociation",
        "ec2:CreateRoute",
        "ec2:ReplaceRoute",
        "ec2:DeleteRoute",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:AllocateAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:ReleaseAddress",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:*TransitGateway*",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:MonitorInstances",
        "ec2:UnmonitorInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyInstanceMetadataOptions",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageAWSNetworkFirewall",
      "Effect": "Allow",
      "Action": [
        "network-firewall:CreateFirewall",
        "network-firewall:DeleteFirewall",
        "network-firewall:DescribeFirewall",
        "network-firewall:ListFirewalls",
        "network-firewall:CreateFirewallPolicy",
        "network-firewall:DeleteFirewallPolicy",
        "network-firewall:DescribeFirewallPolicy",
        "network-firewall:ListFirewallPolicies",
        "network-firewall:UpdateFirewallPolicy",
        "network-firewall:AssociateFirewallPolicy",
        "network-firewall:CreateRuleGroup",
        "network-firewall:DeleteRuleGroup",
        "network-firewall:DescribeRuleGroup",
        "network-firewall:DescribeRuleGroupMetadata",
        "network-firewall:ListRuleGroups",
        "network-firewall:UpdateRuleGroup",
        "network-firewall:AssociateSubnets",
        "network-firewall:DisassociateSubnets",
        "network-firewall:DescribeLoggingConfiguration",
        "network-firewall:UpdateLoggingConfiguration",
        "network-firewall:UpdateFirewallDeleteProtection",
        "network-firewall:UpdateFirewallPolicyChangeProtection",
        "network-firewall:UpdateSubnetChangeProtection",
        "network-firewall:TagResource",
        "network-firewall:UntagResource",
        "network-firewall:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageCloudWatchLogsAndFirewallLogDelivery",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:PutRetentionPolicy",
        "logs:DeleteRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
        "logs:TagLogGroup",
        "logs:UntagLogGroup",
        "logs:ListTagsForResource",
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageLabRolesAndInstanceProfiles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateRoleDescription",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:ListInstanceProfilesForRole",
        "iam:TagInstanceProfile",
        "iam:UntagInstanceProfile",
        "iam:ListInstanceProfileTags"
      ],
      "Resource": [
        "arn:aws:iam::<ACCOUNT_ID>:role/aws-firewall-tgw-*",
        "arn:aws:iam::<ACCOUNT_ID>:role/owasp-llm-*",
        "arn:aws:iam::<ACCOUNT_ID>:instance-profile/aws-firewall-tgw-*",
        "arn:aws:iam::<ACCOUNT_ID>:instance-profile/owasp-llm-*"
      ]
    },
    {
      "Sid": "PassOnlyLabRolesToEC2AndLambda",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::<ACCOUNT_ID>:role/aws-firewall-tgw-*",
        "arn:aws:iam::<ACCOUNT_ID>:role/owasp-llm-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": [
            "ec2.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    },
    {
      "Sid": "CreateRequiredServiceLinkedRoles",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "network-firewall.amazonaws.com",
            "delivery.logs.amazonaws.com"
          ]
        }
      }
    },
    {
      "Sid": "ManageOwaspAutomationBudgetAndNotifications",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:GetFunctionCodeSigningConfig",
        "lambda:GetPolicy",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:ListVersionsByFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:ListTags",
        "events:PutRule",
        "events:DeleteRule",
        "events:DescribeRule",
        "events:PutTargets",
        "events:RemoveTargets",
        "events:ListTargetsByRule",
        "events:ListTagsForResource",
        "events:TagResource",
        "events:UntagResource",
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:ListTopics",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:GetSubscriptionAttributes",
        "sns:ListSubscriptionsByTopic",
        "sns:TagResource",
        "sns:UntagResource",
        "sns:ListTagsForResource",
        "sns:Publish",
        "budgets:ViewBudget",
        "budgets:ModifyBudget",
        "budgets:ListTagsForResource",
        "budgets:TagResource",
        "budgets:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "OperateInstancesWithSystemsManager",
      "Effect": "Allow",
      "Action": [
        "ssm:*Session*",
        "ssm:*Command*",
        "ssm:GetConnectionStatus",
        "ssm:DescribeInstanceInformation",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    }
  ]
}
```

Network Firewall은 최초 생성 시 서비스 연결 역할을 자동 생성할 수 있습니다.
`iam:CreateServiceLinkedRole`은 Network Firewall와 로그 전달 서비스에만 제한되어
있습니다.

참고 자료:

- [AWS Network Firewall 서비스 연결 역할](https://docs.aws.amazon.com/network-firewall/latest/developerguide/using-service-linked-roles.html)
- [IAM PassRole 권한 제한](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_passrole.html)
- [Network Firewall CloudWatch Logs 권한](https://docs.aws.amazon.com/network-firewall/latest/developerguide/logging-cw-logs.html)

## 2. 인스턴스 및 리소스 요건

### AWS Firewall 실습

Firewall 환경은 수강생별 환경이 아니라 강의 전체에서 공유하는 하나의 실습
환경입니다.

| 항목 | 요구사항 |
|---|---|
| EC2 | `t3.micro` 2대 |
| 인스턴스당 사양 | 2 vCPU, 1GiB 메모리 |
| EBS | 인스턴스당 8GB |
| EC2 공인 IP | 없음 |
| 인스턴스 접속 | AWS Systems Manager Session Manager |
| VPC | Inspection VPC 1개, Spoke VPC 2개 |
| 가용 영역 | 2개 AZ |
| NAT Gateway | 2개 |
| Elastic IP | NAT Gateway용 2개 |
| Transit Gateway | 1개 |
| TGW VPC Attachment | 3개 |
| TGW Route Table | 2개 |
| Network Firewall | 1개, 2개 AZ Endpoint |
| Firewall Policy | 1개 |
| Stateful Rule Group | 1개, capacity 100 |
| CloudWatch Log Group | Flow/Alert 로그용 2개 |

기본 리전은 버지니아 북부 `us-east-1`입니다. EC2에는 공인 IP를 할당하지 않으며,
아웃바운드 인터넷 트래픽은 NAT Gateway와 Network Firewall을 통과합니다.

### OWASP Top 10 실습

OWASP 환경은 수강생마다 독립적인 GPU 인스턴스를 한 대씩 제공합니다.

| 항목 | 1인당 요구사항 |
|---|---|
| EC2 | `g6.xlarge` 1대 |
| CPU/메모리 | 4 vCPU, 16GiB |
| GPU | NVIDIA L4 1개 |
| GPU 메모리 | 24GB |
| EBS | 암호화된 gp3 100GB |
| 공인 IPv4 | 1개 |
| Security Group | 1개 |
| IAM Role/Instance Profile | 1세트 |
| 접속 | SSM Session Manager 및 포트 포워딩 |

공유 리소스는 다음과 같습니다.

- VPC 1개
- Public Subnet 1개
- Internet Gateway 1개
- Route Table 1개
- SNS Topic 1개
- AWS Budget 2개
- 자동 종료용 Lambda 1개
- EventBridge 스케줄 1~2개

기본 리전은 버지니아 북부 `us-east-1`입니다. 인스턴스는 패키지, 컨테이너
이미지와 AI 모델을 내려받기 위해 공인 IPv4를 사용합니다.

실습 애플리케이션은 기본적으로 인터넷 전체에 공개하지 않습니다.
`allowed_ingress_cidr`의 기본값은 `127.0.0.1/32`이며 SSM 포트 포워딩을
사용합니다. 직접 브라우저로 접속해야 할 때만 강사 또는 교육장의 현재 공인
IPv4를 `/32`로 지정합니다. `0.0.0.0/0` 사용은 금지합니다.

AWS의 공식 `g6.xlarge` 사양은 다음 문서에서 확인할 수 있습니다.

- [Amazon EC2 G6 인스턴스](https://aws.amazon.com/ec2/instance-types/g6/)

## 3. 사전 준비 사항

### 3.1 필수: GPU Quota 상향

`g6.xlarge`는 EC2의 `Running On-Demand G and VT instances` Quota를
사용합니다. 신규 계정에서는 기본값이 0 vCPU일 수 있으므로 반드시 실습 대상
리전의 현재 적용 값을 확인해야 합니다.

```text
필요 G/VT vCPU = 기존 G/VT 사용량 + (동시 실행 수강생 수 × 4)
```

| 동시 실행 수강생 수 | 최소 필요량 | 20% 여유를 둔 권장 요청량 |
|---:|---:|---:|
| 1명 | 4 vCPU | 8 vCPU |
| 5명 | 20 vCPU | 24 vCPU |
| 10명 | 40 vCPU | 48 vCPU |
| 20명 | 80 vCPU | 96 vCPU |
| 30명 | 120 vCPU | 144 vCPU |

- Quota 이름: `Running On-Demand G and VT instances`
- Service code: `ec2`
- Quota code: `L-DB2E81BA`
- 적용 범위: AWS 계정 및 리전별
- 권장 신청 시점: 강의 최소 1주 전

현재 적용 값을 확인합니다.

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-DB2E81BA \
  --region us-east-1
```

예를 들어 10명이 동시에 실습할 경우 48 vCPU를 요청합니다.

```bash
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-DB2E81BA \
  --desired-value 48 \
  --region us-east-1
```

큰 Quota 증설 요청은 AWS Support 검토가 필요할 수 있고 승인 및 반영에 며칠
이상 걸릴 수 있습니다. 승인 시간은 보장되지 않으므로 강의 직전에 신청하지
않습니다.

참고 자료:

- [EC2 On-Demand 인스턴스 Quota](https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html)
- [Service Quota 증설 요청](https://docs.aws.amazon.com/servicequotas/latest/userguide/request-quota-increase.html)

### 3.2 Standard EC2 vCPU 확인

Firewall 실습의 `t3.micro` 2대에는 총 4 Standard vCPU가 필요합니다. 기존
인스턴스 사용량을 포함해 최소 4 vCPU 이상의 여유가 있어야 합니다.

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-1
```

### 3.3 VPC, EIP 및 Network Firewall Quota 확인

Firewall 실습 전에 다음 잔여량을 확인합니다.

- VPC 3개
- Elastic IP 2개
- AZ별 NAT Gateway 1개
- Transit Gateway 1개
- TGW VPC Attachment 3개
- Network Firewall 1개
- Firewall Policy 1개
- Stateful Rule Group 1개

일반적인 기본 Quota 안에 들어오지만, 기존 리소스가 있는 공유 계정에서는
부족할 수 있습니다. AWS Network Firewall의 기본값은 리전당 Firewall 5개,
Firewall Policy 20개, Stateful Rule Group 50개입니다.

참고 자료:

- [Amazon VPC Quota](https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html)
- [Transit Gateway Quota](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-quotas.html)
- [AWS Network Firewall Quota](https://docs.aws.amazon.com/network-firewall/latest/developerguide/quotas.html)

### 3.4 EBS gp3 Quota 확인

OWASP 환경은 수강생당 100GB의 gp3 EBS를 사용합니다.

```text
필요 gp3 용량 = 동시 실행 수강생 수 × 100GB
```

예를 들어 20명은 2TB, 30명은 3TB가 필요합니다. 기존 EBS 사용량을 포함하여
대상 리전의 gp3 스토리지 Quota를 확인합니다.

- [Amazon EBS Quota](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-resource-quotas.html)

### 3.5 G6 인스턴스 실제 실행 검증

Quota 승인은 특정 AZ의 `g6.xlarge` 수용량을 보장하지 않습니다. 강의 전에
다음을 실제로 검증합니다.

1. 대상 리전에서 `g6.xlarge` 테스트 인스턴스 1대를 생성합니다.
2. Terraform이 AWS Deep Learning AMI를 정상적으로 조회하는지 확인합니다.
3. `nvidia-smi`로 NVIDIA L4 GPU와 드라이버를 확인합니다.
4. 컨테이너 이미지와 Ollama 모델 다운로드를 확인합니다.
5. SSM 접속과 포트 포워딩을 확인합니다.
6. 검증 후 테스트 인스턴스를 종료하거나 삭제합니다.

용량 부족 오류가 발생하면 다른 AZ 또는 G6를 제공하는 다른 리전을 검토합니다.
Quota를 다른 리전에서 승인받았다면 원래 리전에는 적용되지 않으므로 주의합니다.

### 3.6 운영 및 보안 준비

강사 PC 또는 CI 실행 환경에 다음 도구를 설치합니다.

- Terraform
- AWS CLI v2
- AWS Session Manager Plugin
- Git

다음 값도 강의 전에 확정합니다.

- Terraform 실행용 AWS Profile 또는 AssumeRole 설정
- AWS 계정 ID와 대상 리전
- 수강생 ID 목록
- 예산 알림 수신 이메일
- 일별 및 강의 전체 예산
- 자동 종료 시간과 시간대
- 직접 접속이 필요한 경우 허용할 공인 IPv4 `/32`

SNS 구독 확인 이메일은 자동 승인되지 않습니다. 배포 후 수신자가 이메일의
구독 확인 링크를 눌러야 예산 알림을 받을 수 있습니다. AWS Budget은 비용을
자동 차단하지 않고 알림만 제공합니다.

공개 저장소에는 다음 파일을 커밋하지 않습니다.

- AWS Access Key 및 Secret Access Key
- 실제 계정 정보가 들어 있는 `terraform.tfvars`
- `.terraform/` 디렉터리
- `terraform.tfstate` 및 백업 파일
- 강사 또는 교육장의 공인 IP 목록

## 4. 권장 준비 일정

| 시점 | 준비 항목 |
|---|---|
| D-14~D-7 | GPU G/VT vCPU Quota 신청 |
| D-7 | IAM 배포 역할, SCP 및 Permissions Boundary 확인 |
| D-5 | `g6.xlarge`와 Deep Learning AMI 실제 생성 테스트 |
| D-3 | Firewall 환경 전체 `plan` 및 테스트 배포 |
| D-2 | OWASP 환경 전체 `plan` 및 수강생 수 기준 테스트 배포 |
| D-1 | SSM, GPU, 포트 포워딩, 예산 알림 및 자동 종료 최종 점검 |
| 강의 직후 | 실행 중 인스턴스 확인 후 `terraform destroy` |

## 5. 최종 체크리스트

### 계정 및 권한

- [ ] 상시 AdministratorAccess 없이 전용 배포 역할을 준비했다.
- [ ] 통합 IAM 정책의 `<ACCOUNT_ID>`를 실제 계정 ID로 변경했다.
- [ ] SCP와 Permissions Boundary가 필요한 작업을 차단하지 않는다.
- [ ] `aws sts get-caller-identity`로 올바른 계정을 확인했다.

### Quota 및 용량

- [ ] G/VT On-Demand vCPU Quota가 `수강생 수 × 4` 이상이다.
- [ ] Standard On-Demand vCPU에 최소 4 vCPU 여유가 있다.
- [ ] VPC 3개와 EIP 2개의 잔여 Quota가 있다.
- [ ] `수강생 수 × 100GB`의 gp3 EBS 여유가 있다.
- [ ] 대상 리전/AZ에서 `g6.xlarge` 테스트 생성에 성공했다.

### 접속 및 운영

- [ ] AWS CLI, Terraform 및 Session Manager Plugin을 설치했다.
- [ ] 수강생 목록과 허용 CIDR을 확정했다.
- [ ] SSM Session Manager 접속에 성공했다.
- [ ] GPU 드라이버와 모델 다운로드를 확인했다.
- [ ] SNS 예산 알림 이메일 구독을 승인했다.
- [ ] 자동 종료 스케줄과 시간대를 확인했다.
- [ ] 두 프로젝트를 동시에 실행하지 않는 운영 순서를 공유했다.
- [ ] 강의 종료 후 `destroy` 담당자를 지정했다.
