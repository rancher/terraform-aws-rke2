#!/usr/bin/env bash
set -euo pipefail

# This script is run by the run_tests.sh script to clean up AWS resources created during testing.
# It can also be run independently to clean up resources by providing a cleanup ID.
# If no cleanup ID is provided, it defaults to scanning AWS tags for Owner=terraform-ci@suse.com to locate leftover IDs.

# Maximum retry attempts for deleting resources
MAX_ATTEMPTS=3

# Global configuration
AWS_REGION="${AWS_REGION:-us-west-2}"

# Color definitions for logging
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

log_info() {
  printf "%b[INFO] [cleanup]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_success() {
  printf "%b[SUCCESS] [cleanup]%b %s\n" "${GREEN}" "${NC}" "$*"
}

log_warning() {
  printf "%b[WARNING] [cleanup]%b %s\n" "${YELLOW}" "${NC}" "$*"
}

log_error() {
  printf "%b[ERROR] [cleanup]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

# 1. Clear leftovers
clear_leftovers() {
  local id="$1"
  log_info "Clearing leftovers with Id ${id} in ${AWS_REGION}..."

  local attempts=0
  local resources_to_clear

  resources_to_clear=$(leftovers -d --iaas=aws --aws-region="${AWS_REGION}" --filter="Id:${id}" 2>/dev/null | grep -v 'AccessDenied' || true)

  while [[ -n "$resources_to_clear" ]] && [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    log_info "Found these leftovers resources to clear:\n${resources_to_clear}"

    if ! leftovers --iaas=aws --aws-region="${AWS_REGION}" --filter="Id:${id}" --no-confirm 2>/dev/null | grep -v 'AccessDenied'; then
      log_warning "leftovers command exited with warning/error status. Retrying..."
    fi

    sleep 10
    resources_to_clear=$(leftovers -d --iaas=aws --aws-region="${AWS_REGION}" --filter="Id:${id}" 2>/dev/null | grep -v 'AccessDenied' || true)

    if [[ -n "$resources_to_clear" ]]; then
      local delay=$((attempts * 10))
      log_info "Some leftovers resources failed to clear, retrying in ${delay} seconds..."
      sleep "${delay}"
    fi
    attempts=$((attempts + 1))
  done

  if [[ $attempts -eq $MAX_ATTEMPTS ]] && [[ -n "$resources_to_clear" ]]; then
    log_warning "Failed to clear all leftovers resources after ${MAX_ATTEMPTS} attempts."
  else
    log_success "Leftovers resources cleared for Id: ${id}"
  fi
}

# 2. Clear Secrets Manager secrets
clear_secrets() {
  local id="$1"
  log_info "Clearing Secrets Manager secrets for Id ${id}..."

  local attempts=0
  while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    local arns
    arns=$(aws resourcegroupstaggingapi get-resources \
      --no-cli-pager \
      --resource-type-filters "secretsmanager:secret" \
      --tag-filters "Key=Id,Values=${id}" \
      | jq -r '.ResourceTagMappingList[]?.ResourceARN' 2>/dev/null || true)

    local has_secrets=false
    while read -r arn; do
      if [[ -z "$arn" ]]; then
        continue
      fi
      has_secrets=true
      log_info "Removing secret: ${arn}..."
      if ! aws secretsmanager delete-secret --secret-id "$arn" --force-delete-without-recovery >/dev/null 2>&1; then
        log_warning "Failed to delete secret: ${arn}"
      fi
    done <<< "${arns}"

    if [[ "$has_secrets" = false ]]; then
      break
    fi

    local delay=$((attempts * 10))
    sleep "${delay}"
    attempts=$((attempts + 1))
  done
  log_success "Secrets clearance completed for Id: ${id}"
}

# 3. Clear S3 buckets
clear_s3_buckets() {
  local id="$1"
  log_info "Clearing S3 buckets for Id ${id}..."

  local attempts=0
  while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    local buckets_arns
    buckets_arns=$(aws resourcegroupstaggingapi get-resources \
      --no-cli-pager \
      --resource-type-filters "s3:bucket" \
      --tag-filters "Key=Id,Values=${id}" \
      | jq -r '.ResourceTagMappingList[]?.ResourceARN' 2>/dev/null || true)

    local has_buckets=false
    while read -r arn; do
      if [[ -z "$arn" ]]; then
        continue
      fi
      has_buckets=true
      local bucket_name="${arn##arn:aws:s3:::}"
      log_info "Removing S3 bucket: ${bucket_name}..."

      # Clear out DeleteMarkers
      local delete_markers
      delete_markers=$(aws s3api list-object-versions --bucket "${bucket_name}" 2>/dev/null | jq -r '.DeleteMarkers[]?.VersionId' || true)
      while read -r v; do
        if [[ -n "$v" ]]; then
          log_info "  Deleting DeleteMarker version ${v} from ${bucket_name}..."
          aws s3api delete-object --bucket "${bucket_name}" --key "tfstate" --version-id="${v}" >/dev/null 2>&1 || true
        fi
      done <<< "${delete_markers}"

      # Clear out Versions
      local versions
      versions=$(aws s3api list-object-versions --bucket "${bucket_name}" 2>/dev/null | jq -r '.Versions[]?.VersionId' || true)
      while read -r v; do
        if [[ -n "$v" ]]; then
          log_info "  Deleting Object version ${v} from ${bucket_name}..."
          aws s3api delete-object --bucket "${bucket_name}" --key "tfstate" --version-id="${v}" >/dev/null 2>&1 || true
        fi
      done <<< "${versions}"

      # Remove bucket
      if ! aws s3 rb "s3://${bucket_name}" --force >/dev/null 2>&1; then
        log_warning "Failed to force remove S3 bucket: s3://${bucket_name}"
      fi
    done <<< "${buckets_arns}"

    if [[ "$has_buckets" = false ]]; then
      break
    fi

    local delay=$((attempts * 10))
    sleep "${delay}"
    attempts=$((attempts + 1))
  done
  log_success "S3 clearance completed for Id: ${id}"
}

# 4. Clear EC2 key pairs
clear_key_pairs() {
  local id="$1"
  log_info "Clearing EC2 key pairs for Id ${id}..."

  local attempts=0
  while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    local key_arns
    key_arns=$(aws resourcegroupstaggingapi get-resources \
      --no-cli-pager \
      --resource-type-filters "ec2:key-pair" \
      --tag-filters "Key=Id,Values=${id}" \
      | jq -r '.ResourceTagMappingList[]?.ResourceARN' 2>/dev/null || true)

    local has_keys=false
    while read -r arn; do
      if [[ -z "$arn" ]]; then
        continue
      fi
      has_keys=true
      local key_id="${arn##*/}"
      log_info "Removing EC2 key pair: ${key_id}..."
      if ! aws ec2 delete-key-pair --key-pair-id "${key_id}" >/dev/null 2>&1; then
        log_warning "Failed to delete key pair: ${key_id}"
      fi
    done <<< "${key_arns}"

    if [[ "$has_keys" = false ]]; then
      break
    fi

    local delay=$((attempts * 10))
    sleep "${delay}"
    attempts=$((attempts + 1))
  done
  log_success "EC2 key pairs clearance completed for Id: ${id}"
}

# 5. Clear IAM server certificates
clear_server_certificates() {
  local id="$1"
  log_info "Clearing IAM server certificates for Id ${id}..."

  local attempts=0
  while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    local cert_names
    cert_names=$(aws iam list-server-certificates 2>/dev/null | jq -r '.ServerCertificateMetadataList[].ServerCertificateName' || true)

    local has_certs=false
    while read -r name; do
      if [[ -z "$name" ]]; then
        continue
      fi

      # IAM server certs tags are fetched individually as resourcegroupstaggingapi does not support them
      if aws iam list-server-certificate-tags --server-certificate-name "${name}" 2>/dev/null \
         | jq -e --arg ID "${id}" '.Tags[] | select(.Key=="Id" and (.Value | contains($ID)))' > /dev/null; then
        has_certs=true
        log_info "Removing IAM server certificate: ${name}..."
        if ! aws iam delete-server-certificate --server-certificate-name "${name}" >/dev/null 2>&1; then
          log_warning "Failed to delete IAM server certificate: ${name}"
        fi
      fi
    done <<< "${cert_names}"

    if [[ "$has_certs" = false ]]; then
      break
    fi

    local delay=$((attempts * 10))
    sleep "${delay}"
    attempts=$((attempts + 1))
  done
  log_success "IAM server certificates clearance completed for Id: ${id}"
}

# 6. Clear Load Balancer target groups
clear_target_groups() {
  local id="$1"
  log_info "Clearing Load Balancer target groups for Id ${id}..."

  local attempts=0
  while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
    local tg_arns
    tg_arns=$(aws resourcegroupstaggingapi get-resources \
      --no-cli-pager \
      --resource-type-filters "elasticloadbalancing:targetgroup" \
      --tag-filters "Key=Id,Values=${id}" \
      | jq -r '.ResourceTagMappingList[]?.ResourceARN' 2>/dev/null || true)

    local has_tgs=false
    while read -r arn; do
      if [[ -z "$arn" ]]; then
        continue
      fi
      has_tgs=true
      log_info "Removing ELB target group: ${arn}..."
      if ! aws elbv2 delete-target-group --target-group-arn "${arn}" >/dev/null 2>&1; then
        log_warning "Failed to delete target group: ${arn}"
      fi
    done <<< "${tg_arns}"

    if [[ "$has_tgs" = false ]]; then
      break
    fi

    local delay=$((attempts * 10))
    sleep "${delay}"
    attempts=$((attempts + 1))
  done
  log_success "ELB target groups clearance completed for Id: ${id}"
}

# Orchestrate clearance of all categories for a specific ID
cleanup_resources() {
  local id="$1"
  log_info "************************************************************************"
  log_info "Starting resource clearance for Id: ${id}"
  log_info "************************************************************************"

  # Look for distinct resources using leftovers to see if they need clearing
  # and parse out all matching IDs (such as sub-resources)
  local resources_to_clear
  resources_to_clear=$(leftovers -d --iaas=aws --aws-region="${AWS_REGION}" --filter="Id:${id}" 2>/dev/null | grep -v 'AccessDenied' || true)

  local resources_ids
  resources_ids=$(echo "${resources_to_clear}" | awk -F"Id:" '{print $2}' | awk -F"," '{print $1}' | awk -F")" '{print $1}' | sort | uniq | grep -v '^$')

  # If none found via leftovers, use the specified ID itself
  if [[ -z "${resources_ids}" ]]; then
    resources_ids="${id}"
  fi

  while read -r target_id; do
    if [[ -z "${target_id}" ]]; then
      continue
    fi
    clear_leftovers "${target_id}"
    clear_secrets "${target_id}"
    clear_s3_buckets "${target_id}"
    clear_key_pairs "${target_id}"
    clear_server_certificates "${target_id}"
    clear_target_groups "${target_id}"
  done <<< "${resources_ids}"

  log_success "Resource clearance finished for Id: ${id}"
}

# Auto-detect leftover resource IDs owned by CI tags
find_ci_resource_ids() {
  log_info "Scanning AWS tags for resources owned by 'terraform-ci@suse.com'..."

  # Query resourcegroupstaggingapi
  local resource_ids
  resource_ids=$(aws resourcegroupstaggingapi get-resources \
    --no-cli-pager \
    --tag-filters "Key=Owner,Values=terraform-ci@suse.com" 2>/dev/null \
    | jq -r '.ResourceTagMappingList[]?.Tags[] | select(.Key=="Id") | .Value' || true)

  # Check server certs individually since they do not support get-resources
  local cert_ids=""
  local cert_names
  cert_names=$(aws iam list-server-certificates 2>/dev/null | jq -r '.ServerCertificateMetadataList[].ServerCertificateName' || true)
  while read -r name; do
    if [[ -n "$name" ]]; then
      local cid
      cid=$(aws iam list-server-certificate-tags --server-certificate-name "${name}" 2>/dev/null \
        | jq -r '.Tags[] | select(.Key=="Id").Value' || true)
      if [[ -n "$cid" ]]; then
        cert_ids+=$'\n'"${cid}"
      fi
    fi
  done <<< "${cert_names}"

  # Combine, sort, and deduplicate IDs
  printf "%s\n%s\n" "${resource_ids}" "${cert_ids}" | sort | uniq | grep -v '^$'
}

main() {
  local target_id="${1:-}"

  if [[ -z "${target_id}" ]]; then
    log_info "No explicit cleanup ID provided."
    local ci_ids
    ci_ids=$(find_ci_resource_ids)
    if [[ -z "${ci_ids}" ]]; then
      log_warning "No leftover resources found with owner tag 'terraform-ci@suse.com'. Nothing to clean."
      return 0
    fi

    log_info "Detected the following leftover IDs to clean:"
    while read -r cid; do
      echo "  - ${cid}"
    done <<< "${ci_ids}"

    while read -r cid; do
      if [[ -n "${cid}" ]]; then
        cleanup_resources "${cid}"
      fi
    done <<< "${ci_ids}"
  else
    cleanup_resources "${target_id}"
  fi

  log_success "All cleanup operations completed successfully."
}

main "$@"
