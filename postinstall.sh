#!/bin/bash
#####################################################################################################
declare -x appName="WeeklyRebootPostinstall"
declare -x appVer="1.2" # Added sendToLog and atos namespace
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
#   WeeklyRebootPostinstall
#
# SYNOPSIS
#   Loads the LaunchAgent and LaunchDaemon after package installation.
#
# DESCRIPTION
#   This postinstall script loads both the system-wide LaunchDaemon and the
#   GUI LaunchAgent for the currently logged-in user.
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
#     20/Oct/2025              1.2              Added sendToLog and atos namespace.
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
    echo "$(date +"%a %b %d %T") $(hostname -s): [POSTINSTALL] $*" | tee -a "$logFile"
}
####################################################################################################
# 
# SCRIPT CONTENTS
#
####################################################################################################

sendToLog "Running WeeklyRebootPostinstall script v1.2..."

# --- Component Paths ---
readonly AGENT_PLIST="/Library/LaunchAgents/com.carrier.weeklyreboot.agent.plist"
readonly DAEMON_PLIST="/Library/LaunchDaemons/com.carrier.reboot.daemon.plist"

# 1. LOAD THE SYSTEM DAEMON
sendToLog "Loading system LaunchDaemon: $DAEMON_PLIST"
# Unload first in case of re-installation (suppress errors)
launchctl bootout system "$DAEMON_PLIST" 2>/dev/null
# Load the daemon into the system domain
launchctl bootstrap system "$DAEMON_PLIST"
if [[ $? -eq 0 ]]; then
    sendToLog "Successfully bootstrapped system daemon."
else
    sendToLog "ERROR: Failed to bootstrap system daemon."
fi


# 2. LOAD THE USER AGENT
sendToLog "Loading user LaunchAgent: $AGENT_PLIST"
# Find the UID of the user currently logged into the GUI
loggedInUID=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/UID :/ { print $3 }' )

# Proceed only if a user is logged in
if [[ -n "$loggedInUID" ]]; then

    sendToLog "User with UID $loggedInUID found. Loading LaunchAgent..."
    
    # Unload the agent first (suppress errors)
    launchctl bootout gui/"$loggedInUID" "$AGENT_PLIST" 2>/dev/null

    # Load the agent for the current user
    launchctl bootstrap gui/"$loggedInUID" "$AGENT_PLIST"
    
    if [[ $? -eq 0 ]]; then
        sendToLog "Successfully bootstrapped LaunchAgent for UID $loggedInUID."
    else
        sendToLog "ERROR: Failed to bootstrap LaunchAgent for UID $loggedInUID."
    fi

else
    sendToLog "No user logged in at the GUI. Agent will be loaded automatically at the next login."
fi

sendToLog "Postinstall script finished."
exit 0