provider "aws" {
  region = var.region
  # profile = var.aws_profile

  default_tags {
    # Provider configuration must contain only plan-time-known values.
    tags = local.provider_default_tags
  }
}

locals {
  deployment_id = random_id.deployment.hex

  provider_default_tags = {
    Project   = "owasp-top-10-for-llm"
    Course    = var.course_id
    ManagedBy = "Terraform"
  }

  # random_id is unknown during the initial plan, so it must stay out of
  # provider.default_tags and be applied at the resource level instead.
  deployment_tags = {
    Deployment = local.deployment_id
  }

  # IAM Role은 64자 제한이다. role marker(6) + student ID(30)를 보존할 수 있도록
  # course 부분만 자르고, 충돌 방지용 deployment ID는 항상 온전히 유지한다.
  name_prefix = "${substr("owasp-llm-${var.course_id}", 0, 21)}-${local.deployment_id}"

  # 실제로 설치되는 앱만 허용한다. 8003~8009 같은 미사용 포트는 열지 않는다.
  # 18080은 LLM08 학습자 미니 앱이며 allowed_ingress_cidr /32로만 접근한다.
  lab_app_ports = toset([8000, 8001, 8002, 8010, 8011, 8012, 8013, 18080])
}

resource "random_id" "deployment" {
  byte_length = 3

  keepers = {
    course_id = var.course_id
    region    = var.region
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
