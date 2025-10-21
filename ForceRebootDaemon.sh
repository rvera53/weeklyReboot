#!/bin/bash
#####################################################################################################
declare -x appName="RebootDaemon"
declare -x appVer="2.1" # Switched to atos namespace
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
# DESCRIPTION
#   Periodically checks for reboot instructions and executes them.
#
####################################################################################################
#
# CHANGE LOG
#
#     Date                     Version          Description
#--------------------------------------------------------------------------------------------------
#     20/Oct/2025              2.1              Switched to atos namespace and shared log.
#
####################################################################################################
#Path export.
####################################################################################################
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
####################################################################################################
#Script logging
####################################################################################################
# Log to the *main* notifier log for unified debugging
declare -x logFile="/var/log/com.atos.WeeklyRebootNotifier.log"
#Function to send the output of a command to the log
sendToLog() {
    echo "$(date +"%a %b %d %T") $(hostname -s): [DAEMON] $*" | tee -a "$logFile"
}
####################################################################################################
# 
# SCRIPT CONTENTS
#
####################################################################################################

# --- GLOBAL VARIABLES ---
readonly UPTIME_LIMIT_DAYS=7

# --- Communication files from the Agent ---
readonly ACTION_FILE="/private/var/tmp/com.atos.reboot.action"
readonly DEFER_FILE="/private/var/tmp/com.atos.reboot.deferral"

# --- Reboot Function ---
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

if [[ "$uptime_days" -lt "$UPTIME_LIMIT_DAYS" ]]; then
    sendToLog "Uptime ($uptime_days days) is within limits. No action needed."
    exit 0
fi

# 3. PRIORITY 3: Uptime is HIGH. Check for an active deferral.
sendToLog "Uptime ($uptime_days days) exceeds limit. Checking for deferral file."
if [[ -f "$DEFER_FILE" ]]; then
    defer_expiry_time=$(cat "$DEFER_FILE")
    
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