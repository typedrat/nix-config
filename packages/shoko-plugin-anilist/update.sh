#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
exec "$script_dir/../shoko/update-plugin.sh" "$script_dir/source.json"
