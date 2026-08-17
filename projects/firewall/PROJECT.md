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

최초 apply에서 6자리 `deployment_id`가 자동 생성되어 state에 고정됩니다. IAM Role과
Instance Profile처럼 계정 전역에서 이름이 겹치는 리소스는 이 ID가 포함된 prefix를
사용합니다.

## 실행

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 `aws_profile`, region, CIDR 중복 여부를 확인합니다.

같은 계정에 east/west를 동시에 배포할 때는 프로젝트를 리전별 작업 디렉터리로
복사해 각각 별도 `terraform.tfstate`를 사용합니다. 하나의 state에서 region 값만
바꾸면 기존 리전 리소스를 이동·교체하는 계획이 만들어집니다.

apply 전에 리전별로 VPC 3개, EIP 2개, NAT Gateway 2개, Transit Gateway 1개와
Network Firewall 1개를 추가할 쿼터가 있는지 확인합니다. 다계정 배포는 방화벽을
한 번에 5~10개씩 실행해 API throttling과 endpoint 생성 지연을 줄입니다.

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
