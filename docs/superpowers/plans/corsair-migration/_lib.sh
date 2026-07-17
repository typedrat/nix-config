#!/usr/bin/env bash
# Shared identifiers and safety guards for the Corsair NVMe migration.
# Source it:  . ./_lib.sh
#
# Device names (nvme0n1 / nvme1n1) are NOT stable across reboots -- on this
# machine they have already inverted. Only ever reference drives by stable
# by-id path, and guard every destructive op on the model string.

set -euo pipefail

CORSAIR=/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO
SAMSUNG=/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D
CORSAIR_MODEL="Corsair MP700 PRO XT"
SAMSUNG_MODEL="Samsung SSD 990 EVO Plus 4TB"

assert_is_corsair() {
  local m; m=$(lsblk -dno MODEL "$CORSAIR")
  [ "$m" = "$CORSAIR_MODEL" ] || { echo "ABORT: \$CORSAIR model is '$m', not '$CORSAIR_MODEL'"; return 1; }
  echo "OK: Corsair = $(readlink -f "$CORSAIR"), model matches"
}

# Fail loudly if any zpool-new dataset is mounted (they must never mount over
# the live system). Call before/after receives.
assert_zpoolnew_unmounted() {
  if mount | grep -q ' zpool-new'; then
    echo "DANGER: something from zpool-new is mounted:"; mount | grep ' zpool-new'
    return 1
  fi
  echo "OK: nothing from zpool-new is mounted"
}

confirm() {
  local prompt="$1"
  if [ -t 0 ]; then
    local ans; read -rp "$prompt Type YES to proceed: " ans
    [ "$ans" = "YES" ] || { echo "aborted"; exit 1; }
  else
    echo "(non-interactive: relying on guards) $prompt"
  fi
}
