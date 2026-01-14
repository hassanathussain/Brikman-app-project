#!/usr/bin/env bash
set -e

find . -type f -name "*.tf" -print0 \
  | xargs -0 -n1 dirname \
  | sort -u \
  | while read dir; do
      echo "🔍 Validating $dir"
      terraform -chdir="$dir" init -backend=false -input=false >/dev/null
      terraform -chdir="$dir" validate
    done

