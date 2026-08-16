# 원본 저장소

두 프로젝트는 서로 다른 원본 저장소의 커밋된 setup 코드에서 가져왔습니다.
로컬 원본의 수정 파일, Terraform state, plan, `terraform.tfvars`는 복사하지 않았습니다.

## 방화벽 프로젝트

- 원본: <https://github.com/gasbugs/mulcam-aws-cloud-security-terraform>
- 커밋: `8e5d4032088e17050008daa2e15ab508e0f0c5c1`
- 참고한 원본 경로:
  `terraform/fa01hc/day03-compute-and-network-security`
- 새 경로: `projects/firewall`

원본의 강의용 lifecycle 패턴을 사용하되, 이번 의뢰에 맞춰 두 Spoke VPC,
Inspection VPC, Transit Gateway, AWS Network Firewall, NAT Gateway, 모든 route
table과 테스트 인스턴스까지 Terraform으로 완성하도록 확장했습니다.

## OWASP Top 10 프로젝트

- setup 원본: <https://github.com/gasbugs/owasp-llm-lab-setup-guide>
- 동기화 기준 커밋: `3beef6a7c567750c732434bc138c5f5657cf5715`
- 원본 경로:
  - `infrastructure/terraform`
  - `infrastructure/scripts/student`
  - `docs/STUDENT-QUICKSTART.md`
  - `docs/ARCHITECTURE.md`
  - `docs/LAB-RESET-POLICY.md`
  - `docs/SECURE-CODING-WORKSHOPS.md`
  - `docs/TROUBLESHOOTING.md`
- 새 경로: `projects/owasp-top10`

강의 콘텐츠 저장소 `gasbugs/owasp-top-10-for-llm`이 가리키는 실제 AWS GPU
setup 원본을 사용했습니다.

이번 동기화에는 bootstrap 설치기 `0.2.8`, 컨테이너 writable layer의
`/app/app` 편집, `podman restart`를 통한 수정 코드 재실행, `reset-lab`의
allowlist 기반 배포 이미지 재생성, 모든 앱의 명시적 port publish와 LLMGoat
준비 상태 안정화가 포함됩니다. LLM02의 인증 정책은 전용 workshop과 실제
8010 UI의 `/api/chat`이 같은 실행 함수를 사용하므로 안전 호출 전환 후 인증
없는 UI 요청도 모델 호출 전에 차단합니다. 이 저장소가 별도로 제공하는 계정별
GPU AZ 분산, 최소 권한 IAM, 18:00 KST 자동 중지 정책은 유지합니다.

## 라이선스

- 저장소 전체 라이선스는 루트의 `LICENSE`(GPL-3.0)를 따릅니다.
- `projects/owasp-top10`에 복사한 setup 코드는 해당 디렉터리의
  `LICENSE`(MIT) 원문과 저작권 고지를 유지합니다.
