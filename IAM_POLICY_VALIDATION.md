# IAM 정책 실측 검증 기록

## 검증 범위

- 정책 원본: `policies/lab-deployer-policy.json`
- 실제 배포 검증일: 2026-07-24 (Asia/Seoul)
- 보조 리전 정책 반영일: 2026-07-25 (Asia/Seoul)
- AWS CLI: 2.34.32
- Terraform: 1.14.8
- 대상 계정: 실습용 AWS 계정(계정 ID 비공개)
- 실행 주체: 위 정책만 부착한 임시 STS 역할
- 실제 배포: Firewall 84개 리소스, OWASP 23개 리소스
- 정리: 두 프로젝트의 Terraform destroy와 AWS API 잔존 감사를 완료

## 최종 실측 결과

| 검증 | 실측 결과 | 판정 |
|---|---|---|
| `jq` JSON 파싱 | Statement 10개, Allow Action 172개, 글로벌 `NotAction` 예외 3개 | 통과 |
| 압축 정책 크기 | 6,081바이트 / 최대 6,144바이트 | 통과 |
| 허용 리전 조건 검사 | `us-east-1`, `us-west-2`만 허용 목록에 존재 | 통과 |
| Access Analyzer `ValidatePolicy` | Error, Security Warning, Warning, Suggestion 모두 0개 | 통과 |
| 보조 리전 사전 조회 | `us-west-2`의 4개 AZ에서 `g6.xlarge` 제공, 기본 DLAMI 조회 성공 | 통과 |
| `us-east-1` Policy Simulator | EC2, SSM, IAM, Budgets, STS 모두 `allowed` | 통과 |
| 미승인 서울 리전 Policy Simulator | EC2·SSM `explicitDeny`, IAM·Budgets·STS `allowed` | 통과 |
| 최종 리전 제한 정책 실제 배포 | 제한 역할로 `us-east-1` Firewall 84개 apply/destroy | 통과 |
| 타 리전 실제 API 호출 | 서울 리전 `ec2:DescribeInstances`가 identity policy의 `explicit deny` | 통과 |
| 글로벌 서비스 실제 API 호출 | 같은 역할에서 IAM Account Summary와 Budgets 조회 성공 | 통과 |
| Firewall 실제 배포 | `Apply complete! Resources: 84 added` | 통과 |
| Network Firewall 상태 | 2개 AZ endpoint 모두 `READY` | 통과 |
| Firewall 허용 규칙 | `aws.amazon.com` HTTP 200 | 통과 |
| Firewall 차단 규칙 | `example.com` 연결 시간 초과, curl exit 28 | 통과 |
| Firewall 차단 로그 | FLOW 5건, ALERT 1건, TLS SNI `example.com`, `action=blocked`, `verdict=drop` | 통과 |
| Firewall 내부 통신 | 두 spoke EC2 간 ping 성공 | 통과 |
| Firewall SSM | 두 인스턴스 `Online`, Session Manager와 Run Command 성공 | 통과 |
| Firewall 실제 삭제 | `Destroy complete! Resources: 84 destroyed` | 통과 |
| Firewall 삭제 감사 | Terraform state, EIP, NAT Gateway, Network Firewall, 테스트 EC2 모두 0개 | 통과 |
| OWASP 실제 배포 | `Apply complete!`, 최종 Terraform 리소스 23개 | 통과 |
| OWASP 공인 주소 | EC2 자동 공인 IPv4 할당, Course 태그 EIP 0개 | 통과 |
| OWASP 경계 통제 | 모든 공개 서비스 포트가 `127.0.0.1/32`, 외부 접속은 HTTP 000/timeout | 통과 |
| OWASP SSM Session Manager | `ssm-user` 대화형 세션에서 `SSM_SESSION_OK` | 통과 |
| OWASP SSM Run Command | `NVIDIA L4`, 드라이버 `595.71.05`, 외부 HTTPS 성공 | 통과 |
| 전체 실습 설치 | 공식 설치 스크립트 0.1.9, 9분 59초, exit 0 | 통과 |
| 실습 서비스 | 컨테이너 11개 실행, 포털·Ollama·Day 1~5·Agent·Registry·LLMGoat·DVLA 모두 HTTP 200 | 통과 |
| 자동 종료 | Lambda 직접 호출 200, 대상 인스턴스가 `stopped_instance_ids`에 포함되고 실제 `stopped` 전환 | 통과 |
| OWASP 실제 삭제 | `Destroy complete! Resources: 23 destroyed` | 통과 |
| OWASP 삭제 감사 | EC2, VPC, SNS, Lambda, EventBridge, Logs, Budgets, IAM 역할·프로파일 모두 0개 | 통과 |
| 검증용 IAM 정리 | 임시 역할 0개, 고객 관리형 정책 0개 | 통과 |

## 실제 배포에서 발견한 권한 공백과 보강

| 프로젝트 | 거부된 작업 | 최종 조치 |
|---|---|---|
| Firewall | `ec2:GetTransitGatewayRouteTableAssociations`, `ec2:SearchTransitGatewayRoutes` | Terraform이 사용하는 Transit Gateway 조회·관리 작업을 `ec2:*TransitGateway*`로 포함 |
| Firewall | 방화벽 로그 실측 조회 | `logs:DescribeLogStreams`, `logs:GetLogEvents`, `logs:FilterLogEvents` 추가 |
| Firewall 삭제 | `ec2:DisassociateAddress` | EIP 수명주기에 `ec2:AssociateAddress`, `ec2:DisassociateAddress` 추가 |
| OWASP | `lambda:GetFunctionCodeSigningConfig` | Lambda 상태 새로고침 권한 추가 |
| OWASP | `events:ListTagsForResource` | EventBridge 태그 조회 권한 추가 |
| OWASP | `sns:GetSubscriptionAttributes` | 이메일 구독 상태 조회 권한 추가 |
| OWASP | `budgets:TagResource`, `budgets:UntagResource` | Budget 생성·삭제 시 태그 처리 권한 추가 |
| OWASP | `budgets:ListTagsForResource` | Budget 상태 새로고침 권한 추가 |
| 최종 리전 검증 | 역할 생성 직후 첫 `AssumeRole`이 일시 거부 | IAM 전파 후 재시도 성공. 자동화에서는 짧은 재시도 적용 |

보강한 최종 JSON으로 두 프로젝트를 다시 적용하고 삭제했습니다. 따라서 이 표는
Policy Simulator 추정이 아니라 실제 AWS API의 `AccessDenied`와 후속 성공 결과를
기준으로 작성했습니다.

## 구성에서 함께 수정한 동작 오류

Network Firewall의 기본 `HOME_NET`은 검사 VPC CIDR만 포함해 spoke VPC에서 전달된
트래픽이 stateful 도메인 규칙의 대상으로 분류되지 않았습니다.
`projects/firewall/firewall.tf`에 검사 VPC와 두 spoke VPC CIDR을 명시한 뒤 다시
적용했습니다. 재검증에서 허용 도메인은 HTTP 200, 차단 도메인은 시간 초과로
동작했습니다.

## EIP와 SSM 결론

- Firewall 프로젝트는 NAT Gateway 두 개 때문에 EIP 두 개를 실제 생성합니다.
  따라서 Allocate, Associate, Disassociate, Release 권한이 모두 필요합니다.
- OWASP 프로젝트의 EC2 공인 IPv4는 서브넷의 자동 할당 주소이며 EIP가 아닙니다.
  이 프로젝트만 배포할 때는 EIP 생성 권한을 사용하지 않았습니다.
- 최종 배포자 정책은 SSM 대화형 Session Manager와 Run Command를 모두 사용할 수
  있습니다. 실제 세션 시작, 명령 전송, 상태 조회와 출력 조회까지 성공했습니다.
- EC2 인스턴스 역할에는 `AmazonSSMManagedInstanceCore`가 부착되어 SSM Agent가
  `Online`으로 등록됐습니다.

## 리전 통제

최종 정책에는 `DenyOutsideLabRegions` 문장을 추가했습니다.
`aws:RequestedRegion`이 기본 리전 `us-east-1` 또는 GPU 수용량 부족 시 사용하는
보조 리전 `us-west-2`가 아니면 지역 서비스 작업을 명시적으로 거부합니다.
IAM, STS, AWS Budgets는 글로벌 서비스이므로 `NotAction`으로 제외했습니다.

AWS Policy Simulator에서 `us-east-1`의 EC2와 SSM은 `allowed`, 서울 리전의 같은
작업은 `explicitDeny`였습니다. 이어서 최종 정책만 부착한 STS 역할로
`us-east-1` Firewall 84개 리소스를 실제 apply하고 기능을 검증한 뒤 같은 역할로
84개를 destroy했습니다.

실제 역할에서 서울 리전의 `ec2:DescribeInstances`는 identity policy의 명시적
Deny로 거부됐습니다. 같은 역할의 IAM Account Summary와 AWS Budgets 조회는
성공해 글로벌 서비스 예외도 실제 API로 확인했습니다.

위 실제 apply/destroy 기록은 `us-east-1` 기준입니다. `us-west-2`는 G6 수용량
부족에 대비한 보조 리전으로 정책과 Terraform 입력 검증에 추가했으며, 강의 전
별도의 quota와 실제 가용 용량을 확인해야 합니다.

## 정리 감사

삭제 후 Terraform state는 두 프로젝트 모두 0개였습니다. AWS API 교차 감사에서도
검증 Course ID에 해당하는 활성 EC2, VPC, EIP, NAT Gateway, Network Firewall,
SNS Topic, Lambda, EventBridge Rule, CloudWatch Log Group, Budget, IAM 역할과
Instance Profile이 모두 0개였습니다. 검증 전에 존재하던 별도 중지 인스턴스는
삭제하지 않았고 상태가 그대로 `stopped`임을 확인했습니다.

## 남은 한계

- SNS 이메일은 테스트 주소를 사용했으므로 구독 확인 링크를 승인하지 않았습니다.
- EventBridge의 정시 실행 시각을 기다리는 대신 대상 연결과 Lambda 권한을 확인하고
  같은 Lambda를 직접 호출해 중지 동작을 검증했습니다.
- 리소스는 모두 삭제했지만 실제 사용 시간에 대한 AWS 비용 데이터는 지연 집계될 수
  있습니다.
