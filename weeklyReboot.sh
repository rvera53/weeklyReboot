#!/bin/bash
#####################################################################################################
declare -x appName="WeeklyRebootNotifier"
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
#   WeeklyRebootNotifier
#
# SYNOPSIS
#   Runs once at user login, checks uptime, and notifies the user if a reboot is needed.
#
# DESCRIPTION
#   This script is triggered by a LaunchAgent at user login. It waits 5 minutes,
#   then checks if the system uptime exceeds a defined limit. If it does, it
#   displays a user dialog with deferral options. Based on the user's choice,
#   it creates an action or deferral file for the companion daemon to read.
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
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec:/usr/local/bin"
####################################################################################################
#
# SCRIPT CONTENTS
#
####################################################################################################

# --- GLOBAL VARIABLES AND CONSTANTS ---
readonly UPTIME_LIMIT_DAYS=7 # Set to 0 for testing
readonly currentUser="$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )"
readonly logFile="/var/log/com.carrier.WeeklyRebootNotifier.log"

# --- Communication files for the Daemon ---
readonly ACTION_FILE="/private/var/tmp/com.carrier.reboot.action"
readonly DEFER_FILE="/private/var/tmp/com.carrier.reboot.deferral"

# --- Session control file ---
readonly CHECK_FILE="/Users/$currentUser/Library/Caches/com.carrier.weeklyreboot.ran"


####################################################################################################
#
# FUNCTIONS
#
####################################################################################################

# --- Logging Function ---
sendToLog() {
    echo "$(date +"%a %b %d %T") $(hostname -s): [AGENT] $*" | tee -a "$logFile"
}

# --- Uptime Calculation Function ---
# Calculates and echoes the number of days the system has been up.
get_uptime_days() {
    local boot_time
    local current_time
    local uptime_seconds
    local uptime_days

    boot_time=$(sysctl -n kern.boottime | awk -F'sec = |, ' '{print $2}')
    current_time=$(date +%s)
    uptime_seconds=$((current_time - boot_time))
    uptime_days=$((uptime_seconds / 86400))
    
    echo "$uptime_days"
}

# --- User Notification Function ---
# Displays the osascript dialog and echoes the user's choice.
# This version uses a temporary file and includes a company icon.
show_notification() {
    local uptime_days="$1"
    local defer_options
    local applescript_list
    local user_choice
    local tmp_script_path="/private/var/tmp/reboot_notification.applescript"

    # --- CUSTOMIZATION: Set the POSIX path to your company logo here ---
    local icon_path_posix="/usr/local/JCLNotify/logo_72-165-66.png" # Example path

    defer_options=("5 minutes" "1 hour" "2 hours" "4 hours" "12 hours" "24 hours")

    applescript_list="{"
    for option in "${defer_options[@]}"; do
        applescript_list+="\"$option\","
    done
    applescript_list="${applescript_list%,}}"

    # Step 1: Write the AppleScript code to the temporary file.
    /bin/cat <<EOF > "$tmp_script_path"
on run argv
    set dialogText to "Your Mac has not been restarted in " & item 1 of argv & " days. A reboot is required for performance and security."
    set deferList to ${applescript_list}
    set iconAlias to POSIX file "${icon_path_posix}" as alias
    try
        set dialogResult to display dialog dialogText with title "Reboot Required" buttons {"Defer", "Reboot Now"} default button "Defer" with icon iconAlias giving up after 3600
        if gave up of dialogResult then
            return "timed out:" & item 1 of deferList
        end if
        if button returned of dialogResult is "Reboot Now" then
            return "button:Reboot Now"
        else
            set chosenDeferral to choose from list deferList with prompt "Please select a time to defer the reboot:" default items {item 1 of deferList}
            if chosenDeferral is false then
                return "cancelled:" & item 1 of deferList
            else
                return "button:Defer,selection:" & item 1 of chosenDeferral
            end if
        end if
    on error
        return "cancelled:error"
    end try
end run
EOF

    # Step 2: Execute the script from the file, running it as the logged-in user.
    sendToLog "Executing temporary AppleScript file: $tmp_script_path as user '$currentUser'..."
    user_choice=$(sudo -u "$currentUser" /usr/bin/osascript "$tmp_script_path" "$uptime_days")

    # Step 3: Clean up by removing the temporary file.
    /bin/rm "$tmp_script_path"
    
    echo "$user_choice"
}

# --- Choice Processing Function ---
# Parses the user's choice and creates the appropriate communication file for the daemon.
# Takes the raw choice string as an argument ($1).
process_user_choice() {
    local user_choice="$1"
    local action
    local selection
    local deferral_seconds
    local expiry_timestamp

    sendToLog "osascript result: $user_choice"

    # Clean up old files before creating a new one
    rm -f "$ACTION_FILE" "$DEFER_FILE"

    action=$(echo "$user_choice" | awk -F '[,:]' '{print $2}')
    selection=$(echo "$user_choice" | awk -F '[,:]' '{print $4}')

    case "$selection" in
        "5 minutes") deferral_seconds=300 ;;
        "1 hour") deferral_seconds=3600 ;;
        "2 hours") deferral_seconds=7200 ;;
        "4 hours") deferral_seconds=14400 ;;
        "12 hours") deferral_seconds=43200 ;;
        "24 hours") deferral_seconds=86400 ;;
        *) deferral_seconds=3600 ;; # Default to 1 hour
    esac

    if [[ "$action" == "Reboot Now" ]]; then
        sendToLog "User chose 'Reboot Now'. Creating action file for daemon."
        echo "now" > "$ACTION_FILE"
    else
        # This covers Defer, timed out, and cancelled actions.
        expiry_timestamp=$(( $(date +%s) + deferral_seconds ))
        sendToLog "Action was '$action'. Deferring for $deferral_seconds seconds. Expiry: $(date -r $expiry_timestamp)."
        echo "$expiry_timestamp" > "$DEFER_FILE"
    fi
}


####################################################################################################
#
# MAIN SCRIPT LOGIC
#
####################################################################################################

main() {
    sendToLog "-------------------------------------------"
    sendToLog "Start: $(date)" 
    sendToLog "Program name: $appName" 
    sendToLog "ProgramVersion: $appVer" 
    sendToLog "Author: $appAuthor"
    sendToLog "Development Department: $appDepartment"
    sendToLog "Program Creation Date: $appDate"
    sendToLog "Program Modification date: $appUpDate"
    sendToLog "Client serial number: $(ioreg -d 2 -c IOPlatformExpertDevice | grep "IOPlatformSerialNumber" | sed 's/        "IOPlatformSerialNumber" = //' | sed 's/"//g')"
    sendToLog "Client name: $(hostname)"
    sendToLog "-------------------------------------------"
    sendToLog "Current logged-in user: $currentUser"

    # Wait 5 minutes after login before starting the checks.
    sendToLog "Waiting 5 minutes after login before proceeding..."
    sleep 300

    local uptime_days
    uptime_days=$(get_uptime_days)
    sendToLog "System has been up for $uptime_days days."

    # If uptime is low, it means a reboot happened. Clean up all old files and exit.
    if [[ "$uptime_days" -lt "$UPTIME_LIMIT_DAYS" ]]; then
        sendToLog "Uptime is within the limit. Entering cleanup mode."
        rm -f "$ACTION_FILE" "$DEFER_FILE" "$CHECK_FILE"
        sendToLog "All residual files have been cleaned up. Exiting."
        exit 0
    fi

    # If uptime is high, check if we've already run in this session.
    if [[ -f "$CHECK_FILE" ]]; then
        sendToLog "Uptime is high, but the script has already run in this session. Exiting to avoid duplicate notifications."
        exit 0
    fi

    # If uptime is high and we haven't run yet, proceed with the notification.
    sendToLog "Uptime exceeds limit and this is the first run this session. Proceeding with notification."
    touch "$CHECK_FILE"

    local user_choice
    user_choice=$(show_notification "$uptime_days")
    
    process_user_choice "$user_choice"

    sendToLog "End: $(date)"
    sendToLog "-------------------------------------------"
}

# --- Run the main function ---
main