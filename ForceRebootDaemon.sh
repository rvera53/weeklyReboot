#!/bin/bash
#####################################################################################################
declare -x appName="RebootDaemon"
declare -x appVer="2.0" # Final file-based architecture
declare -x appAuthor="Raul Vera"
declare -x appDepartment="Atos WPS"
declare -x appDate="20/Oct/2025"
declare -x appUpDate="20/Oct/2025"
declare -x templateLastModified="2/Apr/2024"
declare -x runtime=$( date '+%d%m%Y%H%M%S' )
####################################################################################################
#
# Copyright (c) 2022, AtoS IT Solutions and Services, Inc.
# All rights reserved.
#
# ABOUT THIS PROGRAM
#
# NAME
#   RebootDaemon
#
# SYNOPSIS
#   Periodically checks for reboot instructions and executes them.
#
# DESCRIPTION
#   This script is run by a LaunchDaemon on a regular interval. It checks for
#   action/deferral files created by the agent script. It also checks system uptime
#   as a failsafe. It performs the system reboot when conditions are met.
#
####################################################################################################
#
# HISTORY
#
#   - Copyright 2022 AtoS. All rights reserved.
#
#
# CHANGE LOG
#
#     Date                     Version          Description
#--------------------------------------------------------------------------------------------------
#     20/Oct/2025              2.0              Finalized robust file-based architecture.
#
####################################################################################################
#Path export.
####################################################################################################
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
####################################################################################################
#
# SCRIPT CONTENTS
#
####################################################################################################

# --- GLOBAL VARIABLES ---
readonly logFile="/var/log/com.carrier.WeeklyRebootNotifier.log"
readonly UPTIME_LIMIT_DAYS=7

# --- Communication files from the Agent ---
readonly ACTION_FILE="/private/var/tmp/com.carrier.reboot.action"
readonly DEFER_FILE="/private/var/tmp/com.carrier.reboot.deferral"

# --- Logging Function ---
sendToLog() {
    echo "$(date +"%a %b %d %T") $(hostname -s): [DAEMON] $*" | tee -a "$logFile"
}

# --- Reboot Function ---
# Logs the action, cleans up files, and performs the reboot.
perform_reboot() {
    sendToLog "REBOOT TRIGGERED. Cleaning up files and restarting now."
    rm -f "$ACTION_FILE" "$DEFER_FILE"
    /sbin/shutdown -r now
    exit 0
}


# --- MAIN DAEMON LOGIC ---
sendToLog "Daemon is running. Checking for tasks."

# 1. PRIORITY 1: Immediate reboot request.
if [[ -f "$ACTION_FILE" ]] && [[ "$(cat "$ACTION_FILE")" == "now" ]]; then
    sendToLog "Action file found. User requested an immediate reboot."
    perform_reboot
fi

# 2. PRIORITY 2: Check uptime.
boot_time=$(sysctl -n kern.boottime | awk -F'sec = |, ' '{print $2}')
current_time=$(date +%s)
uptime_days=$(( (current_time - boot_time) / 86400 ))

# If uptime is low, it means a reboot happened. We do nothing.
if [[ "$uptime_days" -lt "$UPTIME_LIMIT_DAYS" ]]; then
    sendToLog "Uptime ($uptime_days days) is within limits. No action needed."
    exit 0
fi

# 3. PRIORITY 3: Uptime is HIGH. Check for an active deferral.
sendToLog "Uptime ($uptime_days days) exceeds limit. Checking for deferral file."
if [[ -f "$DEFER_FILE" ]]; then
    defer_expiry_time=$(cat "$DEFER_FILE")
    
    # Check if the deferral time has passed.
    if [[ "$current_time" -gt "$defer_expiry_time" ]]; then
        sendToLog "Deferral has expired (Current: $current_time > Expiry: $defer_expiry_time)."
        perform_reboot
    else
        sendToLog "Deferral is still active. Reboot scheduled for after $(date -r "$defer_expiry_time"). No action now."
        exit 0
    fi
else
    # 4. FAILSAFE: Uptime is HIGH and NO deferral file exists.
    sendToLog "Uptime is high and no deferral file was found. This is a failsafe reboot."
    perform_reboot
fi

sendToLog "Daemon check complete. No reboot conditions met this time."
exit 0