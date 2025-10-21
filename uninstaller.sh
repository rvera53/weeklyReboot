#!/bin/bash
#####################################################################################################
declare -x appName="WeeklyRebootUninstaller"
declare -x appVer="1.1" # Added sendToLog and atos namespace
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
#   WeeklyRebootUninstaller
#
# SYNOPSIS
#   Safely removes all components of the Weekly Reboot Notifier solution.
#
####################################################################################################
#
# CHANGE LOG
#
#     Date                     Version          Description
#--------------------------------------------------------------------------------------------------
#     20/Oct/2025              1.1              Added sendToLog and atos namespace.
#
####################################################################################################
#Path export.
####################################################################################################
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec:/usr/local/bin"
####################################################################################################
#Script logging
####################################################################################################
declare -x logFile="/var/log/com.atos.$appName.log"
#Function to send the output of a command to the log
sendToLog() {
    echo "$(date +"%a %b %d %T") $(hostname -s): [UNINSTALLER] $*" | tee -a "$logFile"
}
####################################################################################################
# 
# SCRIPT CONTENTS
#
####################################################################################################

# --- Check for Root ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Exiting."
    exit 1
fi

sendToLog "-------------------------------------------"
sendToLog "Starting Weekly Reboot Notifier Uninstallation"
sendToLog "-------------------------------------------"

# --- Component Paths ---
readonly AGENT_PLIST="/Library/LaunchAgents/com.carrier.weeklyreboot.agent.plist"
readonly DAEMON_PLIST="/Library/LaunchDaemons/com.carrier.reboot.daemon.plist"
readonly AGENT_SCRIPT="/Library/Scripts/weeklyReboot.sh"
readonly DAEMON_SCRIPT="/Library/Scripts/ForceRebootDaemon.sh"
readonly SCRIPT_DIR="/Library/Scripts"
readonly currentUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
readonly CHECK_FILE="/Users/$currentUser/Library/Caches/com.carrier.weeklyreboot.ran"

# 1. Unload the LaunchDaemon
if [[ -f "$DAEMON_PLIST" ]]; then
    sendToLog "LaunchDaemon found. Unloading..."
    launchctl unload "$DAEMON_PLIST"
    sendToLog "Removing LaunchDaemon plist: $DAEMON_PLIST"
    rm -f "$DAEMON_PLIST"
else
    sendToLog "LaunchDaemon plist not found. Skipping."
fi

# 2. Unload the LaunchAgent
if [[ -f "$AGENT_PLIST" ]]; then
    if [[ -n "$currentUser" && "$currentUser" != "loginwindow" ]]; then
        local loggedInUID=$(id -u "$currentUser")
        sendToLog "Active user '$currentUser' (UID: $loggedInUID) found. Unloading LaunchAgent..."
        launchctl asuser "$loggedInUID" launchctl unload "$AGENT_PLIST"
    else
        sendToLog "No active user session found. Agent will be removed for next login."
    fi
    sendToLog "Removing LaunchAgent plist: $AGENT_PLIST"
    rm -f "$AGENT_PLIST"
else
    sendToLog "LaunchAgent plist not found. Skipping."
fi

# 3. Remove the scripts
sendToLog "Removing scripts..."
rm -f "$AGENT_SCRIPT"
rm -f "$DAEMON_SCRIPT"

# 4. Remove temporary and cache files
sendToLog "Cleaning up temporary and cache files..."
rm -f "$CHECK_FILE"
rm -f "/private/var/tmp/com.carrier.reboot.action"
rm -f "/private/var/tmp/com.carrier.reboot.deferral"
rm -f "/private/var/tmp/reboot_notification.applescript"

sendToLog "-------------------------------------------"
sendToLog "Uninstallation complete."
sendToLog "-------------------------------------------"

exit 0