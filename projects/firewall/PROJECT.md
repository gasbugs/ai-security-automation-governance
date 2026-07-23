# AWS Network Firewall + Transit Gateway 프로젝트

두 개의 Spoke VPC 트래픽을 중앙 Inspection VPC로 모아 AWS Network Firewall에서
검사하는 완성형 실습입니다. 수강생이 콘솔에서 핵심 인프라를 추가로 만들 필요가
없습니다.

## 완성되는 구성

```text
Spoke A VPC ─┐
             ├─ Transit Gateway ─ TGW attachment subnet
Spoke B VPC ─┘                       │
                                    ▼
                           Network Firewall endpoint
                                    │
                       ┌────────────┴────────────┐
                       ▼                         ▼
                 다른 Spoke VPC          NAT Gateway → IGW
```

- 2개 가용 영역
- Spoke A/B VPC와 private subnet
- Inspection VPC의 TGW, firewall, public subnet
- AWS Transit Gateway와 3개 VPC attachment
- Spoke용/Inspection용 TGW route table
- Inspection attachment의 appliance mode
- AZ별 AWS Network Firewall endpoint와 NAT Gateway
- 대칭 라우팅용 subnet route table
- 상태 기반 도메인 차단 rule group
- CloudWatch FLOW/ALERT 로그
- SSM 전용 테스트 EC2 2대

## 실행

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 `aws_profile`, region, CIDR 중복 여부를 확인합니다.

```bash
make validate
make plan
CONFIRM_AWS_COSTS=YES make setup
terraform output
```

테스트 인스턴스 접속 명령:

```bash
terraform output -json session_manager_commands
```

SSM 세션 안에서 허용/차단 비교:

```bash
curl -I https://aws.amazon.com
curl -I https://example.com
```

Spoke 간 통신은 상대 인스턴스 private IP로 확인합니다. 인바운드 ICMP를 허용하려면
`allow_spoke_icmp = true`를 사용합니다.

## 정리

Network Firewall endpoint, NAT Gateway, Transit Gateway는 시간당 비용이 발생합니다.
실습 직후 반드시 제거합니다.

```bash
make destroy
```

OWASP 프로젝트가 활성 상태이면 이 프로젝트의 `setup`은 실행되지 않습니다.
