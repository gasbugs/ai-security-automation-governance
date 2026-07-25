# AI 기반 보안 업무 자동화와 거버넌스

> **과정명:** AI 기반 보안 업무 자동화와 거버넌스
>
> **과정 주제:** 기술 및 생산성 · 거버넌스 및 통제

이 저장소는 생성형 AI와 LLM을 활용해 보안 업무를 자동화하고, 안전하게 통제하는
방법을 다루는 강의용 실습 프로젝트입니다. 특정 회사명이나 조직 내부 정보는
과정명과 공개 문서에 사용하지 않습니다.

## 커리큘럼 방향

1. **기술 및 생산성:** AI를 활용해 보안 업무를 자동화하고 효율화하는 방법
2. **거버넌스 및 통제:** AI 사용 과정의 데이터 유출 방지와 보안 가이드 및
   법적 규제 대응 체계 수립

현재 저장소에는 위 주제를 실습하기 위한 두 개의 독립 프로젝트가 있습니다.
각 프로젝트의 Terraform root, 변수, 상태, setup/destroy 진입점은 완전히
분리되어 있습니다.

AWS 계정 권한, 인스턴스 사양, GPU Quota와 강의 전 점검 사항은
[사전 준비 가이드](PREREQUISITES.md)를 먼저 확인하세요.

```text
ai-security-automation-governance/
├── projects/
│   ├── firewall/       # AWS Network Firewall + Transit Gateway
│   └── owasp-top10/    # OWASP Top 10 for LLM AWS GPU lab
└── scripts/
    └── project.sh      # 반드시 프로젝트 하나를 지정하는 실행 가드
```

## 중요한 실행 원칙

- 두 환경을 한 번에 생성하는 명령은 없습니다.
- 두 프로젝트의 지역 서비스는 기본 `us-east-1`, GPU 수용량 부족 시
  보조 `us-west-2`에서만 실행합니다.
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
