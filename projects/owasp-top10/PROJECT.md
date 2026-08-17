# OWASP Top 10 프로젝트

이 디렉터리는 OWASP Top 10 for LLM 실습의 독립 프로젝트입니다.
Terraform root는 `infrastructure/terraform`이며 방화벽 프로젝트와 상태를 공유하지
않습니다.

최초 apply에서 6자리 `deployment_id`가 자동 생성되어 Terraform state에 고정됩니다.
IAM Role, Instance Profile, Budget처럼 계정 전역에서 이름이 겹칠 수 있는 리소스는
이 ID가 포함된 prefix를 사용합니다. 같은 계정의 east/west 배포는 반드시 별도
state를 사용해야 서로 다른 ID가 할당됩니다.

`availability_zone`을 지정하지 않으면 `g6.xlarge` 제공 AZ 중 하나를 무작위로
선택해 state에 고정합니다. AWS가 선택 AZ에서 장시간 인스턴스 ID를 할당하지 않으면
`docs/TROUBLESHOOTING.md` 절차대로 다른 offering AZ를 명시하고 다시 plan/apply합니다.
Terraform 단일 apply가 다른 AZ로 자동 이동하지는 않습니다.

## 실행

기본 AWS profile과 region으로 사전 검사를 수행합니다. 다른 profile을 사용할
때만 `AWS_PROFILE`을 덮어씁니다.

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-1
make preflight
```

로컬 변수를 준비하고 실제 수강생 정보, 날짜, 이메일, 예산으로 수정합니다.

```bash
cp infrastructure/terraform/terraform.tfvars.example \
  infrastructure/terraform/terraform.tfvars
```

계획과 생성:

```bash
make validate
make plan
CONFIRM_AWS_COSTS=YES make setup
```

매일 시작과 중지:

```bash
export STUDENT=student01
make start
make stop
```

강의 종료 후:

```bash
make destroy
```

방화벽 프로젝트가 활성 상태이면 이 프로젝트의 `setup`은 실행되지 않습니다.
전체 수강생 절차는 [Student Quickstart](docs/STUDENT-QUICKSTART.md)를 참고합니다.
