#!/bin/zsh
# Start MATLAB's desktop through its supported command-line launcher.
# No credentials or network policy changes are made by this script.
set -eu
matlab_app='/Applications/MATLAB_R2025b.app'
if [[ ! -x "$matlab_app/bin/matlab" ]]; then
  print -u2 "MATLAB not found at $matlab_app; update matlab_app in this file."
  exit 1
fi
repo_dir="${0:A:h:h}"
cd "$repo_dir/exp2_chirp/host"
exec "$matlab_app/bin/matlab" -desktop
