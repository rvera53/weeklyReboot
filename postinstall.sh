#!/bin/bash
#####################################################################################################
declare -x appName="WeeklyRebootPostinstall"
declare -x appVer="1.0"
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
#   Loads the LaunchAgent for the current user after package installation.
#
# DESCRIPTION
#   This postinstall script identifies the currently logged-in GUI user and loads the
#   LaunchAgent service for them. This ensures the agent is active immediately,
#   without requiring a logout/login event.
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
#     20/Oct/2025              1.0              Initial version.
#
####################################################################################################
#Path export.
####################################################################################################
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec:/usr/local/bin"
####################################################################################################
#Script logging
####################################################################################################
# This script will log to the main installer log at /var/log/install.log
echo "Running WeeklyRebootPostinstall script..."

# --- SCRIPT CONTENTS ---

# Path to the agent plist
agent_plist="/Library/LaunchAgents/com.carrier.weeklyreboot.agent.plist"

# Find the UID of the user currently logged into the GUI
loggedInUID=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/UID :/ { print $3 }' )

# Proceed only if a user is logged in
if [[ -n "$loggedInUID" ]]; then

    echo "User with UID $loggedInUID found. Loading LaunchAgent..."

    # Unload the agent first in case it's an upgrade/reinstall (suppress errors)
    launchctl bootout gui/"$loggedInUID" "$agent_plist" 2>/dev/null

    # Load the agent for the current user using the modern 'bootstrap' command
    launchctl bootstrap gui/"$loggedInUID" "$agent_plist"

    echo "LaunchAgent successfully loaded for UID $loggedInUID."

else
    echo "No user logged in at the GUI. Agent will be loaded automatically at the next login."
fi

exit 0