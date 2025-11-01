#!/usr/bin/env bash

################################################################################
# workflow_helpers.sh — Shared helper functions for APBS electrostatics workflow
################################################################################
# This script provides template generation, validation, and file-checking utilities.
# It is sourced by all workflow scripts and justfile recipes in this toolkit.
#
# Usage:
#   source workflow_helpers.sh
#   create_apbs_input template.in output.in ionc
#   ...
#
# All functions are intended for use in the main workflow and expect environment
# variables to be set by params.env or the justfile.
################################################################################

set -e

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
    echo "Error: Template file '$template' not found (check APBS_DUMMY_TEMPLATE/APBS_SOLV_TEMPLATE in params.env)" >&2
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

# Validate APBS grid dimensions follow multigrid formula
# Usage: validate_grid_dimensions dime_x dime_y dime_z
# Formula: dime = c * 2^(nlev+1) + 1 where c and nlev are positive integers
# Returns: 0 if all dimensions valid, 1 if any invalid
validate_grid_dimensions() {
  local dx=$1
  local dy=$2
  local dz=$3
  local valid=0
  
  # Check each dimension
  for dim in $dx $dy $dz; do
    local is_valid=0
    
    # Try common nlev values (typically nlev=4, but check 1-6)
    for nlev in {1..6}; do
      # For each nlev, try c values from 1 to 20
      for c in {1..20}; do
        local expected=$(( c * 2**(nlev + 1) + 1 ))
        if [ "$dim" -eq "$expected" ]; then
          is_valid=1
          break 2
        fi
        # Stop if we've exceeded the dimension
        [ "$expected" -gt "$dim" ] && break
      done
    done
    
    if [ "$is_valid" -eq 0 ]; then
      echo "Warning: Grid dimension $dim does not satisfy formula dime = c*2^(nlev+1) + 1" >&2
      echo "  Valid dimensions include: 33, 65, 97, 129, 161, 193, 225, 257, 289, 321, 353, 385, 417, 449, 481, 513..." >&2
      valid=1
    fi
  done
  
  return $valid
}

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
      echo "Warning: Template file '$template' not found (check template paths in params.env)" >&2
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
    echo "Warning: PQR directory '$pqr_dir' does not exist (check OUTPUT_DIR and run pqrs)" >&2
    return 1
  fi
  
  local pqr_count=$(find "$pqr_dir" -type f -name "*.pqr" 2>/dev/null | wc -l)
  
  if [ "$pqr_count" -eq 0 ]; then
    echo "Warning: No PQR files found in '$pqr_dir' (check PDB2PQR output and input PDB files)" >&2
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
    echo "Warning: APBS directory '$apbs_dir' does not exist (check OUTPUT_DIR and run inputs)" >&2
    return 1
  fi
  
  local dir_count=$(find "$apbs_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  
  if [ "$dir_count" -eq 0 ]; then
    echo "Warning: No APBS run directories found in '$apbs_dir' (run inputs to prepare)" >&2
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
    echo "Warning: PDB directory '$pdb_dir' does not exist (check PDB_INPUT_DIR)" >&2
    return 1
  fi
  
  local pdb_count=$(find "$pdb_dir" -maxdepth 1 -type f \( -name "*.pdb" -o -name "*.cif" \) 2>/dev/null | wc -l)
  
  if [ "$pdb_count" -eq 0 ]; then
    echo "Warning: No PDB/CIF files found in '$pdb_dir' (add .pdb or .cif files to input directory)" >&2
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
