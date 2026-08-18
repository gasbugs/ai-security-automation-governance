#!/bin/bash
set -euo pipefail

: "${AWS_PROFILE:?usage: AWS_PROFILE=<profile> AWS_REGION=<region> STUDENT=<id> bash asg-name.sh}"
: "${AWS_REGION:=us-east-1}"
: "${STUDENT:?STUDENT environment variable is required}"

ROWS=$(aws autoscaling describe-auto-scaling-groups \
  --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --query "AutoScalingGroups[?Tags[?Key=='Student' && Value=='$STUDENT']].AutoScalingGroupName" \
  --output text)
COUNT=$(printf "%s\n" "$ROWS" | awk '{ for (i = 1; i <= NF; i++) count++ } END { print count + 0 }')

if [ "$COUNT" -ne 1 ]; then
  echo "ERROR: expected one lab ASG for Student=$STUDENT, found $COUNT." >&2
  printf "%s\n" "$ROWS" >&2
  exit 1
fi
printf "%s\n" "$ROWS"
