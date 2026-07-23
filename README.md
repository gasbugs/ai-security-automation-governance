# AWS 보안 Terraform 실습

한 저장소 안에 두 개의 독립 프로젝트를 둔 강의용 workspace입니다. 두 프로젝트는
Terraform root, 변수, 상태, setup/destroy 진입점이 완전히 분리되어 있습니다.

```text
aws-security-terraform-practice/
├── projects/
│   ├── firewall/       # AWS Network Firewall + Transit Gateway
│   └── owasp-top10/    # OWASP Top 10 for LLM AWS GPU lab
└── scripts/
    └── project.sh      # 반드시 프로젝트 하나를 지정하는 실행 가드
```

## 중요한 실행 원칙

- 두 환경을 한 번에 생성하는 명령은 없습니다.
- `PROJECT=firewall` 또는 `PROJECT=owasp-top10` 중 하나를 반드시 지정합니다.
- 한 프로젝트가 활성화된 동안 다른 프로젝트의 `setup`은 거부됩니다.
- 각 프로젝트는 별도의 `terraform.tfstate`를 사용합니다.
- 유료 리소스 생성은 `CONFIRM_AWS_COSTS=YES`가 있어야 실행됩니다.

## 프로젝트 선택

```bash
make list
```

### 1. 방화벽 프로젝트만 실행

```bash
cd projects/firewall
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars의 aws_profile, region, CIDR 등을 수정

make plan
CONFIRM_AWS_COSTS=YES make setup
make destroy
```

### 2. OWASP Top 10 프로젝트만 실행

방화벽 프로젝트를 먼저 제거한 뒤 실행합니다.

```bash
cd projects/owasp-top10
cp infrastructure/terraform/terraform.tfvars.example \
  infrastructure/terraform/terraform.tfvars
# profile, student_ids, 날짜, 이메일, 예산을 수정

make preflight
make plan
CONFIRM_AWS_COSTS=YES make setup
make destroy
```

## 상위 디렉터리에서 실행

프로젝트 안의 Makefile과 같은 안전장치를 사용합니다.

```bash
make plan PROJECT=firewall
CONFIRM_AWS_COSTS=YES make setup PROJECT=firewall
make destroy PROJECT=firewall
```

`setup-all`이나 두 프로젝트를 연속 apply하는 target은 의도적으로 제공하지 않습니다.

## 비용과 보안

- 방화벽 프로젝트는 2개 AZ의 Network Firewall endpoint, NAT Gateway,
  Transit Gateway, 3개 VPC와 EC2 리소스를 생성합니다.
- OWASP 프로젝트는 기본적으로 `g6.xlarge` GPU EC2와 100GB EBS 등을 생성합니다.
- OWASP 환경은 본인 소유 또는 명시적으로 허가받은 실습 계정에서만 사용합니다.
- OWASP 프로젝트는 매일 `stop-lab.sh`로 EC2를 중지하고, 강의 종료 후 `destroy`합니다.
- Budget은 비용을 차단하지 않고 알림만 보냅니다.

원본과 고정 커밋은 [SOURCES.md](SOURCES.md)에 기록되어 있습니다.
