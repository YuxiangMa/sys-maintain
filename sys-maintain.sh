#!/bin/bash
#----------------------------------#
#  Enhanced System Maintenance     #
#  Safe, modular, extensible       #
#----------------------------------#

set -euo pipefail

LOG_TAG="system_maintenance"
REPORT_FILE="/tmp/system_maintenance_report_$(date +%Y%m%d).log"
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

declare -a SUMMARY

log() {
  local level=$1
  local msg=$2
  local timestamp
  timestamp=$(date -Iseconds)
  echo "${timestamp} [${LOG_TAG}] [${level}] PID $$ ${msg}" | tee -a "$REPORT_FILE"
}

report() {
  echo "$(date -Iseconds) $1" | tee -a "$REPORT_FILE"
}

report_summary() {
  local msg="$1"
  SUMMARY+=("$msg")
  report "$msg"
}

ensure_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
  else
    OS_NAME=$(uname -s | tr 'A-Z' 'a-z')
    OS_VERSION=$(uname -r)
  fi
  log "INFO" "Detected OS: ${OS_NAME} ${OS_VERSION}"
  report_summary "Operating System: ${OS_NAME} ${OS_VERSION}"
}

update_cache() {
  log "INFO" "Updating package cache..."
  if [[ "$OS_NAME" =~ ^(ubuntu|debian)$ ]]; then
    if apt-get update &>/dev/null; then
      report_summary "Package cache updated successfully."
    else
      report_summary "Failed to update package cache."
    fi
  else
    report_summary "OS not supported for package cache update."
  fi
}

upgrade_system() {
  log "INFO" "Upgrading packages (dist-upgrade)..."
  if [[ "$OS_NAME" =~ ^(ubuntu|debian)$ ]]; then
    if apt-get dist-upgrade -y &>/dev/null; then
      report_summary "System upgraded successfully."
    else
      report_summary "System upgrade encountered errors."
    fi
  else
    report_summary "OS not supported for upgrade."
  fi
}

install_linux_generic() {
  if [[ "$OS_NAME" == "ubuntu" ]]; then
    log "INFO" "Installing linux-generic..."
    if apt-get install -y linux-generic &>/dev/null; then
      report_summary "linux-generic installed."
    else
      report_summary "Failed to install linux-generic."
    fi
  fi
}

remove_old_kernels() {
  log "INFO" "Removing old kernels..."
  local current_kernel_pkg="linux-image-$(uname -r)"
  local old_kernels
  old_kernels=$(dpkg --list | awk '/^ii/ && /^linux-image-[0-9]/ {print $2}' | grep -v "^${current_kernel_pkg}$" || true)
  if [[ -z "$old_kernels" ]]; then
    report_summary "No old kernels to remove."
  else
    if apt-get purge -y $old_kernels &>/dev/null; then
      report_summary "Removed old kernels: $old_kernels"
    else
      report_summary "Failed to remove some old kernels: $old_kernels"
    fi
  fi
}

autoremove_clean() {
  log "INFO" "Running apt-get autoremove..."
  if apt-get autoremove -y &>/dev/null; then
    report_summary "Autoremove completed successfully."
  else
    report_summary "Autoremove encountered errors."
  fi
}

autoclean_cache() {
  log "INFO" "Running apt-get autoclean..."
  if apt-get autoclean -y &>/dev/null; then
    report_summary "Autoclean completed successfully."
  else
    report_summary "Autoclean encountered errors."
  fi
}

remove_residual_configs() {
  log "INFO" "Removing residual config files..."
  local residuals
  residuals=$(dpkg -l | awk '/^rc/ {print $2}')
  if [[ -z "$residuals" ]]; then
    report_summary "No residual config files to remove."
  else
    if apt-get purge -y $residuals &>/dev/null; then
      report_summary "Removed residual config files: $residuals"
    else
      report_summary "Failed to remove some residual config files: $residuals"
    fi
  fi
}

remove_orphaned_packages() {
  log "INFO" "Removing orphaned packages..."

  if command -v deborphan &>/dev/null; then
    local orphans
    orphans=$(deborphan)
    if [[ -z "$orphans" ]]; then
      report_summary "No orphaned packages found."
    else
      if apt-get purge -y $orphans &>/dev/null; then
        report_summary "Removed orphaned packages: $orphans"
      else
        report_summary "Failed to remove some orphaned packages: $orphans"
      fi
    fi
  else
    report_summary "deborphan not installed; skipping orphan removal."
  fi
}


cleanup_snap() {
  log "INFO" "Cleaning up old snap revisions..."
  if ! command -v snap &>/dev/null; then
    report_summary "Snap not installed; skipping."
    return
  fi

  snap set system refresh.retain=2 &>/dev/null || true
  mapfile -t disabled < <(snap list --all 2>/dev/null | awk '/disabled/ {print $1, $3}')
  if [[ ${#disabled[@]} -eq 0 ]]; then
    report_summary "No disabled snap revisions to remove."
    return
  fi

  local success=true
  for entry in "${disabled[@]}"; do
    read -r name rev <<< "$entry"
    if ! snap remove "$name" --revision="$rev" --purge &>/dev/null; then
      success=false
      log "WARN" "Failed to remove snap $name revision $rev"
    fi
  done

  if $success; then
    report_summary "Removed old snap revisions."
  else
    report_summary "Failed to remove some snap revisions."
  fi
}

cleanup_temp_dirs() {
  log "INFO" "Cleaning /tmp and /var/tmp directories..."
  find /tmp /var/tmp -mindepth 1 ! -name '.X11-unix' ! -name '.ICE-unix' -exec rm -rf {} + 2>/dev/null || true
  report_summary "/tmp and /var/tmp cleaned (safe)."
}

cleanup_user_caches() {
  log "INFO" "Cleaning user caches..."
  local cleaned=0
  while IFS= read -r user_home; do
    if [[ -d "$user_home/.cache" ]]; then
      rm -rf "$user_home/.cache/"* 2>/dev/null || true
      ((cleaned++))
    fi
  done < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $6}')

  if (( cleaned > 0 )); then
    report_summary "Cleared cache for $cleaned user(s)."
  else
    report_summary "No user caches found to clean."
  fi
}

cleanup_user_trash() {
  log "INFO" "Emptying user trash..."
  local cleaned=0
  while IFS= read -r user_home; do
    local trash="$user_home/.local/share/Trash/files"
    if [[ -d "$trash" ]]; then
      rm -rf "$trash"/* 2>/dev/null || true
      ((cleaned++))
    fi
  done < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $6}')

  if (( cleaned > 0 )); then
    report_summary "Emptied trash for $cleaned user(s)."
  else
    report_summary "No user trash found to empty."
  fi
}

vacuum_journal() {
  log "INFO" "Vacuuming journal logs older than 7 days..."
  if command -v journalctl &>/dev/null; then
    if journalctl --vacuum-time=7d &>/dev/null; then
      report_summary "Journal logs older than 7 days vacuumed."
    else
      report_summary "Failed to vacuum journal logs."
    fi
  else
    report_summary "journalctl not available."
  fi
}

fix_package_db() {
  log "INFO" "Repairing package database..."
  if dpkg --configure -a &>/dev/null && apt-get install -f -y &>/dev/null; then
    report_summary "Package database repaired."
  else
    report_summary "Failed to repair package database."
  fi
}

clean_old_logs() {
  log "INFO" "Cleaning old logs..."
  find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
  find /var/log -type f -name "*.gz" -mtime +90 -delete 2>/dev/null || true
  report_summary "Old logs removed (>30d .log, >90d .gz)."
}

free_memory() {
  log "INFO" "Dropping memory caches..."
  sync
  if [[ -w /proc/sys/vm/drop_caches ]]; then
    echo 3 > /proc/sys/vm/drop_caches
    report_summary "Dropped memory caches."
  else
    report_summary "No permission to drop memory caches."
  fi
}

firmware_update() {
  log "INFO" "Checking firmware updates..."
  if ! command -v fwupdmgr &>/dev/null; then
    report_summary "fwupd not installed."
    return
  fi

  if fwupdmgr refresh &>/dev/null && fwupdmgr get-updates &>/dev/null; then
    local updates_count
    updates_count=$(fwupdmgr get-updates | wc -l)
    if (( updates_count > 0 )); then
      fwupdmgr update -y &>/dev/null
      report_summary "Firmware updated ($updates_count updates applied)."
    else
      report_summary "No firmware updates available."
    fi
  else
    report_summary "Failed to check firmware updates."
  fi
}

main() {
  ensure_root
  detect_os
  update_cache
  upgrade_system
  install_linux_generic
  remove_old_kernels
  autoremove_clean
  autoclean_cache
  remove_residual_configs
  remove_orphaned_packages
  cleanup_snap
  cleanup_temp_dirs
  cleanup_user_caches
  cleanup_user_trash
  vacuum_journal
  fix_package_db
  clean_old_logs
  free_memory
  firmware_update

  log "INFO" "System maintenance completed. Report saved to: $REPORT_FILE"
  echo -e "\n===== Maintenance Summary ====="
  for entry in "${SUMMARY[@]}"; do
    echo "- $entry"
  done
}

main "$@"
