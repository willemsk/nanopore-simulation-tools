#! /bin/bash
################################################################################
# run.sh — launcher for calculation.sh
################################################################################

if [ ! -f "./vars.conf" ]; then
  echo "Error: vars.conf not found in scripts/!"
  exit 1
fi
if [ ! -f "./calculation.sh" ]; then
  echo "Error: calculation.sh not found in scripts/!"
  exit 1
fi

echo "Using configuration from vars.conf:"
grep -v '^#' ./vars.conf | grep -v '^$'
echo

bash ./calculation.sh

