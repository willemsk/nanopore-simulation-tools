#!/usr/bin/env bash
################################################################################
# workflow_helpers.sh — Helper functions for APBS electrostatics workflow
################################################################################
# Provides configuration parsing, validation, and template generation utilities.
# Designed to be sourced by justfile recipes and standalone scripts.
#
# Usage:
#   source workflow_helpers.sh
#   CONFIG_FILE="path/to/params.conf"
#   value=$(get_config_value "KEY")
#   create_apbs_input template.in output.in ionc
################################################################################

set -e

################################################################################
# Configuration parsing
################################################################################

# Get a configuration value from params.env
# Usage: get_config_value "KEY_NAME" [config_file]
# Returns: The value associated with the key, or empty string if not found
get_config_value() {
  local key=$1
  local config=${2:-${CONFIG_FILE:-params.env}}
  
  if [ ! -f "$config" ]; then
    echo "Error: Configuration file '$config' not found" >&2
    return 1
  fi
  
  # Match lines starting with KEY= (ignoring leading whitespace and comments)
  grep "^[[:space:]]*${key}=" "$config" | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Load all configuration values into shell variables
# Usage: load_config [config_file]
# Note: This exports variables for use in current shell and subprocesses
load_config() {
  local config=${1:-${CONFIG_FILE:-params.env}}
  
  if [ ! -f "$config" ]; then
    echo "Error: Configuration file '$config' not found" >&2
    return 1
  fi
  
  # Export all non-comment, non-empty lines as environment variables
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove leading/trailing whitespace from key and value
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Export the variable
    export "$key=$value"
  done < <(grep -v "^[[:space:]]*$" "$config")
}

################################################################################
# Template generation functions
################################################################################

# Create APBS input file from template by substituting placeholders
# Usage: create_apbs_input template_file output_file ionc
# Reads: GCENT, DIME_L, DIME_S, GRID_L, GRID_S, PDIE, SDIE, IONR from environment
create_apbs_input() {
  local template=$1
  local apbs_input=$2
  local ionc=$3
  
  if [ ! -f "$template" ]; then
    echo "Error: Template file '$template' not found" >&2
    return 1
  fi
  
  # Substitute placeholders with configuration values
  cat "$template" | \
    sed -e "s/GCENT/${GCENT}/g" \
        -e "s/DIME_L/${DIME_L}/g" \
        -e "s/DIME_S/${DIME_S}/g" \
        -e "s/GRID_L/${GRID_L}/g" \
        -e "s/GRID_S/${GRID_S}/g" \
        -e "s/PDIE/${PDIE}/g" \
        -e "s/SDIE/${SDIE}/g" \
        -e "s/IONC/${ionc}/g" \
        -e "s/IONR/${IONR}/g" \
    > "$apbs_input"
}

# Create draw_membrane input file
# Usage: create_draw_input output_file ionc
# Reads: ZMEM, LMEM, PDIE, MEMV, R_TOP, R_BOTTOM from environment
create_draw_input() {
  local draw_input=$1
  local ionc=$2
  
  echo "${ZMEM} ${LMEM} ${PDIE} ${MEMV} ${ionc} ${R_TOP} ${R_BOTTOM}" > "$draw_input"
}

################################################################################
# Validation functions
################################################################################

# Validate that template files exist and contain required placeholders
# Usage: validate_templates template_file [template_file2 ...]
# Returns: 0 if all valid, 1 if issues found (warnings emitted)
validate_templates() {
  local templates=("$@")
  local issues_found=0
  
  # Required placeholders
  local placeholders=("GCENT" "DIME_L" "DIME_S" "GRID_L" "GRID_S" "PDIE" "SDIE" "IONC" "IONR")
  
  for template in "${templates[@]}"; do
    # Check file existence
    if [ ! -f "$template" ]; then
      echo "Warning: Template file '$template' not found" >&2
      issues_found=1
      continue
    fi
    
    # Check for placeholders
    for placeholder in "${placeholders[@]}"; do
      if ! grep -q "$placeholder" "$template"; then
        echo "Warning: Template '$template' missing placeholder '$placeholder'" >&2
        issues_found=1
      fi
    done
  done
  
  return $issues_found
}

# Check if PQR files exist in the specified directory
# Usage: check_pqr_files pqr_directory
# Returns: 0 if files found, 1 if not
check_pqr_files() {
  local pqr_dir=$1
  
  if [ ! -d "$pqr_dir" ]; then
    echo "Warning: PQR directory '$pqr_dir' does not exist" >&2
    return 1
  fi
  
  local pqr_count=$(find "$pqr_dir" -type f -name "*.pqr" 2>/dev/null | wc -l)
  
  if [ "$pqr_count" -eq 0 ]; then
    echo "Warning: No PQR files found in '$pqr_dir'" >&2
    return 1
  fi
  
  return 0
}

# Check if APBS run directories exist
# Usage: check_apbs_dirs apbs_directory
# Returns: 0 if directories found, 1 if not
check_apbs_dirs() {
  local apbs_dir=$1
  
  if [ ! -d "$apbs_dir" ]; then
    echo "Warning: APBS directory '$apbs_dir' does not exist" >&2
    return 1
  fi
  
  local dir_count=$(find "$apbs_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  
  if [ "$dir_count" -eq 0 ]; then
    echo "Warning: No APBS run directories found in '$apbs_dir'" >&2
    return 1
  fi
  
  return 0
}

# Check if PDB/CIF files exist in the specified directory
# Usage: check_pdb_files pdb_directory
# Returns: 0 if files found, 1 if not
check_pdb_files() {
  local pdb_dir=$1
  
  if [ ! -d "$pdb_dir" ]; then
    echo "Warning: PDB directory '$pdb_dir' does not exist" >&2
    return 1
  fi
  
  local pdb_count=$(find "$pdb_dir" -maxdepth 1 -type f \( -name "*.pdb" -o -name "*.cif" \) 2>/dev/null | wc -l)
  
  if [ "$pdb_count" -eq 0 ]; then
    echo "Warning: No PDB/CIF files found in '$pdb_dir'" >&2
    return 1
  fi
  
  return 0
}

################################################################################
# Utility functions
################################################################################

# Print verbose message if VERBOSE is enabled
# Usage: verbose_echo "message"
verbose_echo() {
  if [ "${VERBOSE:-false}" = "true" ]; then
    echo "$@"
  fi
}
