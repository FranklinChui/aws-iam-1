#!/bin/bash
# verify.sh
# Purpose: To verify that the IAM resources have been provisioned or torn down correctly.

# --- Configuration ---
# Get the directory of the script
SCRIPT_DIR=$(dirname "$0")

# Load configuration from external file
if [ -f "${SCRIPT_DIR}/../config/app.conf" ]; then
  source "${SCRIPT_DIR}/../config/app.conf"
else
  echo "ERROR: Configuration file app.conf not found."
  exit 1
fi

LOG_DIR="logs"
VERIFY_MODE=${1:-deploy} # Default to 'deploy' mode if no argument is provided
LOG_FILE="${LOG_DIR}/verify_${VERIFY_MODE}_$(date +%Y-%m-%d_%H%M).log"

# --- Functions ---

# Function to log messages
function log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# Function to verify the IAM user
function verify_user() {
  log_message "Verifying IAM user: ${IAM_USER_NAME}..."
  local user
  user=$(aws iam get-user --user-name "${IAM_USER_NAME}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --query "User.UserName" --output text 2>/dev/null)
  
  if [ "${VERIFY_MODE}" == "deploy" ]; then
    if [ "${user}" == "${IAM_USER_NAME}" ]; then
      log_message "SUCCESS: IAM user ${IAM_USER_NAME} exists as expected."
    else
      log_message "ERROR: IAM user ${IAM_USER_NAME} does not exist."
      exit 1
    fi
  elif [ "${VERIFY_MODE}" == "teardown" ]; then
    if [ -z "${user}" ]; then
      log_message "SUCCESS: IAM user ${IAM_USER_NAME} does not exist as expected."
    else
      log_message "ERROR: IAM user ${IAM_USER_NAME} still exists."
      exit 1
    fi
  fi
}

# Function to verify the IAM role
function verify_role() {
  log_message "Verifying IAM role: ${IAM_ROLE_NAME}..."
  local role
  role=$(aws iam get-role --role-name "${IAM_ROLE_NAME}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --query "Role.RoleName" --output text 2>/dev/null)

  if [ "${VERIFY_MODE}" == "deploy" ]; then
    if [ "${role}" == "${IAM_ROLE_NAME}" ]; then
      log_message "SUCCESS: IAM role ${IAM_ROLE_NAME} exists as expected."
    else
      log_message "ERROR: IAM role ${IAM_ROLE_NAME} does not exist."
      exit 1
    fi
  elif [ "${VERIFY_MODE}" == "teardown" ]; then
    if [ -z "${role}" ]; then
      log_message "SUCCESS: IAM role ${IAM_ROLE_NAME} does not exist as expected."
    else
      log_message "ERROR: IAM role ${IAM_ROLE_NAME} still exists."
      exit 1
    fi
  fi
}

# Function to verify the IAM policy is attached to the role
function verify_policy_attachment() {
  # This check is only relevant for deploy verification
  if [ "${VERIFY_MODE}" != "deploy" ]; then
    return
  fi

  log_message "Verifying IAM policy attachment for role: ${IAM_ROLE_NAME}..."
  local policy_arn
  policy_arn=$(aws iam list-attached-role-policies --role-name "${IAM_ROLE_NAME}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --query "AttachedPolicies[?PolicyName=='${IAM_POLICY_NAME}'].PolicyArn" --output text 2>/dev/null)
  
  if [ -n "${policy_arn}" ]; then
    log_message "SUCCESS: Policy ${IAM_POLICY_NAME} is attached to role ${IAM_ROLE_NAME}."
  else
    log_message "ERROR: Policy ${IAM_POLICY_NAME} is not attached to role ${IAM_ROLE_NAME}."
    exit 1
  fi
}

# --- Main Execution ---
function main() {
  mkdir -p "${LOG_DIR}"
  log_message "--- Starting Verification in '${VERIFY_MODE}' mode ---"

  verify_user
  verify_role
  verify_policy_attachment

  log_message "--- Verification Complete ---"
}

main