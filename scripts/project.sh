#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="${1:-list}"
PROJECT="${2:-}"
ACTIVE_FILE="$ROOT_DIR/.active-project"
PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT_DIR/.terraform-plugin-cache}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/project.sh list
  ./scripts/project.sh init <firewall|owasp-top10>
  ./scripts/project.sh fmt <firewall|owasp-top10>
  ./scripts/project.sh validate <firewall|owasp-top10>
  ./scripts/project.sh plan <firewall|owasp-top10>
  CONFIRM_AWS_COSTS=YES ./scripts/project.sh setup <firewall|owasp-top10>
  ./scripts/project.sh destroy <firewall|owasp-top10>

Only one project may be active at a time.
EOF
}

terraform_root() {
  case "$PROJECT" in
    firewall)
      printf '%s/projects/firewall\n' "$ROOT_DIR"
      ;;
    owasp-top10)
      printf '%s/projects/owasp-top10/infrastructure/terraform\n' "$ROOT_DIR"
      ;;
    *)
      echo "Unknown or missing project: $PROJECT" >&2
      usage >&2
      exit 2
      ;;
  esac
}

other_terraform_root() {
  case "$PROJECT" in
    firewall)
      printf '%s/projects/owasp-top10/infrastructure/terraform\n' "$ROOT_DIR"
      ;;
    owasp-top10)
      printf '%s/projects/firewall\n' "$ROOT_DIR"
      ;;
  esac
}

ensure_tools() {
  local tool

  for tool in terraform aws; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Required command not found: $tool" >&2
      exit 2
    fi
  done
}

ensure_tfvars() {
  local path="$1"

  if [[ ! -f "$path/terraform.tfvars" ]]; then
    echo "Missing local variables: $path/terraform.tfvars" >&2
    echo "Copy terraform.tfvars.example, then replace every course-specific value." >&2
    exit 2
  fi
}

ensure_aws_identity() {
  local path="$1"
  local profile
  local profile_args=()

  profile="${AWS_PROFILE:-}"
  if [[ -z "$profile" ]]; then
    profile="$(
      sed -nE 's/^[[:space:]]*aws_profile[[:space:]]*=[[:space:]]*"([^"]+)".*$/\1/p' \
        "$path/terraform.tfvars" | head -n 1
    )"
  fi

  if [[ -n "$profile" ]]; then
    profile_args=(--profile "$profile")
  fi

  echo "Verifying AWS identity before operating project: $PROJECT (profile=${profile:-default})"
  aws sts get-caller-identity "${profile_args[@]}" --output json
}

managed_resources() {
  local path="$1"

  terraform -chdir="$path" state list 2>/dev/null || true
}

ensure_other_project_inactive() {
  local other_path
  local other_resources

  if [[ -f "$ACTIVE_FILE" ]]; then
    local active
    active="$(<"$ACTIVE_FILE")"
    if [[ "$active" != "$PROJECT" ]]; then
      echo "Refusing setup: project '$active' is marked active." >&2
      echo "Destroy it before setting up '$PROJECT'." >&2
      exit 2
    fi
  fi

  other_path="$(other_terraform_root)"
  other_resources="$(managed_resources "$other_path")"
  if [[ -n "$other_resources" ]]; then
    echo "Refusing setup: the other project still has managed Terraform resources." >&2
    printf '%s\n' "$other_resources" >&2
    exit 2
  fi
}

run_init() {
  local path="$1"

  mkdir -p "$PLUGIN_CACHE_DIR"
  export TF_PLUGIN_CACHE_DIR="$PLUGIN_CACHE_DIR"
  terraform -chdir="$path" init -input=false
}

case "$COMMAND" in
  list)
    printf '%-16s %s\n' "firewall" "projects/firewall"
    printf '%-16s %s\n' "owasp-top10" "projects/owasp-top10"
    ;;
  init)
    ensure_tools
    run_init "$(terraform_root)"
    ;;
  fmt)
    terraform -chdir="$(terraform_root)" fmt -recursive
    ;;
  validate)
    ensure_tools
    TF_ROOT="$(terraform_root)"
    run_init "$TF_ROOT"
    terraform -chdir="$TF_ROOT" validate
    ;;
  plan)
    ensure_tools
    TF_ROOT="$(terraform_root)"
    ensure_tfvars "$TF_ROOT"
    ensure_aws_identity "$TF_ROOT"
    run_init "$TF_ROOT"
    terraform -chdir="$TF_ROOT" plan -input=false -lock=false
    ;;
  setup)
    ensure_tools
    if [[ "${CONFIRM_AWS_COSTS:-}" != "YES" ]]; then
      echo "Refusing to create billable resources without CONFIRM_AWS_COSTS=YES." >&2
      exit 2
    fi
    TF_ROOT="$(terraform_root)"
    ensure_tfvars "$TF_ROOT"
    ensure_other_project_inactive
    ensure_aws_identity "$TF_ROOT"
    run_init "$TF_ROOT"
    terraform -chdir="$TF_ROOT" apply -input=false -auto-approve
    printf '%s\n' "$PROJECT" >"$ACTIVE_FILE"
    echo "Active project: $PROJECT"
    ;;
  destroy)
    ensure_tools
    TF_ROOT="$(terraform_root)"
    ensure_tfvars "$TF_ROOT"
    ensure_aws_identity "$TF_ROOT"
    run_init "$TF_ROOT"
    terraform -chdir="$TF_ROOT" destroy -input=false -auto-approve
    REMAINING="$(managed_resources "$TF_ROOT")"
    if [[ -n "$REMAINING" ]]; then
      echo "Resources remain in Terraform state:" >&2
      printf '%s\n' "$REMAINING" >&2
      exit 1
    fi
    if [[ -f "$ACTIVE_FILE" && "$(<"$ACTIVE_FILE")" == "$PROJECT" ]]; then
      rm -f "$ACTIVE_FILE"
    fi
    echo "Cleanup verified: no managed resources remain for $PROJECT."
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
