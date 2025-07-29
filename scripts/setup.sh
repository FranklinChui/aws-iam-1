#!/bin/bash
# setup.sh
# Purpose: To prepare the local environment for development and deployment.

# --- Configuration ---
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/setup_$(date +%Y-%m-%d_%H%M).log"
VENV_DIR=".venv"

# --- Functions ---

# Function to log messages to both stdout and a log file
function log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "${LOG_FILE}"
}

# Function to create necessary directories
function create_directories() {
  log_message "Creating required directories..."
  mkdir -p "${LOG_DIR}"
  mkdir -p "docs"
  mkdir -p "input"
  mkdir -p "output"
  mkdir -p "tests/unit"
  log_message "Directory creation complete."
}

# Function to check for a command and install the package if it's missing
function check_and_install_dep() {
  local cmd_name="$1"
  local pkg_name="$2"

  log_message "Checking for dependency: ${cmd_name}"
  if command -v "${cmd_name}" &> /dev/null; then
    log_message "${cmd_name} is already installed."
  else
    log_message "${cmd_name} not found. Attempting to install ${pkg_name}..."
    # OS detection
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        sudo apt-get update && sudo apt-get install -y "${pkg_name}"
      elif [[ "$ID" == "rhel" || "$ID" == "rocky" || "$ID" == "centos" || "$ID" == "fedora" ]]; then
        sudo dnf install -y "${pkg_name}"
      else
        log_message "Unsupported OS: ${ID}. Please install ${pkg_name} manually."
        exit 1
      fi
    else
      log_message "Cannot determine OS. Please install ${pkg_name} manually."
      exit 1
    fi

    if command -v "${cmd_name}" &> /dev/null; then
      log_message "Successfully installed ${pkg_name}."
    else
      log_message "Failed to install ${pkg_name}. Please install it manually."
      exit 1
    fi
  fi
}

# Function to create a Python virtual environment
function create_venv() {
  log_message "Checking for Python 3..."
  if ! command -v python3 &> /dev/null; then
    log_message "Python 3 is not installed. Please install it first."
    exit 1
  fi

  if [ -d "${VENV_DIR}" ]; then
    log_message "Virtual environment already exists at ${VENV_DIR}."
  else
    log_message "Creating Python virtual environment at ${VENV_DIR}..."
    python3 -m venv "${VENV_DIR}"
    log_message "Virtual environment created."
  fi
}

# Function to install python packages using pip from the venv
function install_pip_packages() {
    log_message "Activating virtual environment..."
    source "${VENV_DIR}/bin/activate"

    log_message "Installing/Verifying python packages..."
    pip install --upgrade pip &>> "${LOG_FILE}"
    pip install cfn-lint &>> "${LOG_FILE}"

    log_message "Verifying cfn-lint installation..."
    if ! command -v cfn-lint &> /dev/null; then
        log_message "ERROR: Failed to install cfn-lint."
        exit 1
    fi
    log_message "cfn-lint is available in the virtual environment."

    log_message "Deactivating virtual environment."
    deactivate
}


# --- Main Execution ---
function main() {
  create_directories
  log_message "--- Starting Environment Setup ---"

  check_and_install_dep "aws" "awscli"
  check_and_install_dep "jq" "jq"

  create_venv
  install_pip_packages

  log_message "--- Environment Setup Complete ---"
}

main
