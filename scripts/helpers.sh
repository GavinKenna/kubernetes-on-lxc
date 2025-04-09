#!/bin/bash

# ========== Helpers ==========
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR: $*" | tee -a "$LOG_FILE"
}