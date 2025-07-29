#!/bin/bash
# teardown.sh
# Purpose: To automate the removal of all created CloudFormation resources.

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
LOG_FILE="${LOG_DIR}/teardown_$(date +%Y-%m-%d_%H%M).log"

# --- Functions ---

# Function to log messages
function log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# Function to delete a CloudFormation stack
function delete_stack() {
  local stack_name="$1"
  log_message "Deleting stack: ${stack_name}"
  
  aws cloudformation delete-stack \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}" \
    --stack-name "${stack_name}" &>> "${LOG_FILE}"

  if [ $? -eq 0 ]; then
    log_message "Stack deletion initiated successfully for ${stack_name}."
  else
    log_message "ERROR: Stack deletion failed to initiate for ${stack_name}."
    # Check if stack exists before failing completely
    local stack_status
    stack_status=$(aws cloudformation describe-stacks --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --stack-name "${stack_name}" --query "Stacks[0].StackStatus" --output text 2>/dev/null)
    if [[ -z "$stack_status" ]]; then
        log_message "Stack ${stack_name} does not exist. Considering it deleted."
        return 0
    else
        exit 1
    fi
  fi
}

# Function to wait for stack deletion to complete
function wait_for_stack_deletion() {
    local stack_name="$1"
    log_message "Waiting for stack ${stack_name} to be deleted..."
    aws cloudformation wait stack-delete-complete --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --stack-name "${stack_name}"
    if [ $? -eq 0 ]; then
        log_message "Stack ${stack_name} deleted successfully."
    else
        log_message "ERROR: Stack ${stack_name} deletion failed."
        aws cloudformation describe-stack-events --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --stack-name "${stack_name}" --query "StackEvents[?ResourceStatus=='DELETE_FAILED'].[ResourceStatus, ResourceType, LogicalResourceId, ResourceStatusReason]" --output table &>> "${LOG_FILE}"
        exit 1
    fi
}

# --- Main Execution ---
function main() {
  mkdir -p "${LOG_DIR}"
  log_message "--- Starting CloudFormation Teardown ---"

  # Delete IAM Role and User Stack
  delete_stack "${ROLE_USER_STACK_NAME}"
  wait_for_stack_deletion "${ROLE_USER_STACK_NAME}"

  # Delete IAM Policy Stack
  delete_stack "${POLICY_STACK_NAME}"
  wait_for_stack_deletion "${POLICY_STACK_NAME}"

  log_message "--- CloudFormation Teardown Complete ---"
  
  log_message "--- Starting Teardown Verification ---"
  "${SCRIPT_DIR}/verify.sh" teardown
  if [ $? -eq 0 ]; then
    log_message "--- Teardown Verification Successful ---"
  else
    log_message "--- Teardown Verification Failed ---"
    exit 1
  fi
}

main
