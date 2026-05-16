#!/usr/bin/env bash
set -eu

temp_path="${1:?temp path required}"
final_path="${2:?final path required}"

if [ -s "$temp_path" ]; then
  mv "$temp_path" "$final_path"
else
  rm -f "$temp_path"
fi
