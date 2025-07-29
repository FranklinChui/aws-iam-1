#!/bin/bash
# deploy.sh
# Purpose: To deploy the CloudFormation stacks in a modular and configurable way.

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
LOG_FILE="${LOG_DIR}/deploy_$(date +%Y-%m-%d_%H%M).log"

# --- Functions ---

# Function to log messages
function log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# Function to deploy a CloudFormation stack
function deploy_stack() {
  local stack_name="$1"
  local template_file="$2"
  local capabilities="$3"
  local parameters="$4"

  log_message "Deploying stack: ${stack_name} from template: ${template_file}"
  
  local cmd="aws cloudformation deploy \
    --profile \"${AWS_PROFILE}\" \
    --region \"${AWS_REGION}\" \
    --stack-name \"${stack_name}\" \
    --template-file \"${template_file}\" \
    --capabilities ${capabilities} \
    --no-fail-on-empty-changeset"

  if [ -n "${parameters}" ]; then
    cmd="${cmd} --parameter-overrides ${parameters}"
  fi

  eval "${cmd}" &>> "${LOG_FILE}"

  if [ $? -eq 0 ]; then
    log_message "Stack deployment initiated successfully for ${stack_name}."
  else
    log_message "ERROR: Stack deployment failed to initiate for ${stack_name}."
    exit 1
  fi
}

# Function to wait for stack completion
function wait_for_stack() {
    local stack_name="$1"
    log_message "Waiting for stack ${stack_name} to complete..."
    aws cloudformation wait stack-create-complete --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --stack-name "${stack_name}"
    if [ $? -eq 0 ]; then
        log_message "Stack ${stack_name} created successfully."
    else
        log_message "ERROR: Stack ${stack_name} creation failed."
        aws cloudformation describe-stack-events --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --stack-name "${stack_name}" --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[ResourceStatus, ResourceType, LogicalResourceId, ResourceStatusReason]" --output table &>> "${LOG_FILE}"
        exit 1
    fi
}

# Function to get a stack's output value
function get_stack_output() {
  local stack_name="$1"
  local output_key="$2"

  log_message "Retrieving output '${output_key}' from stack: ${stack_name}..." >&2
  local output_value
  output_value=$(aws cloudformation describe-stacks \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}" \
    --stack-name "${stack_name}" \
    --query "Stacks[0].Outputs[?OutputKey=='${output_key}'].OutputValue" \
    --output text)

  if [ -z "${output_value}" ]; then
    log_message "ERROR: Could not retrieve output '${output_key}' from stack ${stack_name}." >&2
    exit 1
  fi
  echo "${output_value}"
}

# --- Main Execution ---
function main() {
  mkdir -p "${LOG_DIR}"
  log_message "--- Starting CloudFormation Deployment ---"

  # Deploy IAM Policy Stack
  local policy_params="PolicyName=${IAM_POLICY_NAME}"
  deploy_stack "${POLICY_STACK_NAME}" "${TEMPLATE_DIR}/iam_policy.yaml" "CAPABILITY_NAMED_IAM" "${policy_params}"
  wait_for_stack "${POLICY_STACK_NAME}"
  
  # Get Policy ARN from output
  local policy_arn
  policy_arn=$(get_stack_output "${POLICY_STACK_NAME}" "PolicyArn")
  log_message "Retrieved Policy ARN: ${policy_arn}"

  # Deploy IAM Role and User Stack
  local role_user_params="RoleName=${IAM_ROLE_NAME} UserName=${IAM_USER_NAME} ManagedPolicyArn=${policy_arn}"
  deploy_stack "${ROLE_USER_STACK_NAME}" "${TEMPLATE_DIR}/iam_role_user.yaml" "CAPABILITY_NAMED_IAM" "${role_user_params}"
  wait_for_stack "${ROLE_USER_STACK_NAME}"

  log_message "--- CloudFormation Deployment Complete ---"
}

main