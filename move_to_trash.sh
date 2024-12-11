#!/bin/bash
# Location: ~/move_to_trash.sh
# Prevent sleep while the script is running
/usr/bin/caffeinate -i -w $$ &

LOGFILE="/Users/gregorylarsen/move_to_trash.log"
STDERR_LOGFILE="/Users/gregorylarsen/move_to_trash.stderr"
TRASH_DIR="/Users/gregorylarsen/.Trash"
SOURCE_DIR="/Users/gregorylarsen/Downloads" # Intentionally make erroneous for testing

# Truncate log files to start fresh with each run
> "$LOGFILE"
> "$STDERR_LOGFILE"

# Function to show error dialog
show_error_dialog() {
    response=$(osascript -e "display dialog \"Error occurred while moving files! Open ${SOURCE_DIR} to check.\n\nTo stop these, comment out osascripts in ~/move_to_trash.sh\" with title \"Move to Trash\" buttons {\"No, thanks\", \"Open Source Directory\"} default button \"Open Source Directory\"" \
        2> >(grep -v 'IMKClient subclass' | grep -v 'IMKInputSession subclass' >> "$STDERR_LOGFILE"))

    # Check the user's response
    if [[ "$response" == "button returned:Open Source Directory" ]]; then
        # Try to open the directory and capture any error
        error_message=$(open "$SOURCE_DIR" 2>&1)
        if [[ $? -ne 0 ]]; then
            # Show a dialog with the captured error message
            osascript -e "display dialog \"Failed to open ${SOURCE_DIR}.\n\n$error_message\n\nTo stop these, comment out osascripts in ~/move_to_trash.sh\" with title \"Move to Trash\" buttons {\"OK\"} default button \"OK\"" \
                2> >(grep -v 'IMKClient subclass' | grep -v 'IMKInputSession subclass' >> "$STDERR_LOGFILE")
        fi
    fi
}

# Main Script Logic
{
    echo "Script started at $(date)"
    # Move files from SOURCE_DIR to TRASH_DIR
    echo "Moving files from $SOURCE_DIR to $TRASH_DIR..."
    find "$SOURCE_DIR" -mindepth 1 -type f -exec mv -n {} "$TRASH_DIR" \; 2> >(tee -a "$STDERR_LOGFILE" >>"$LOGFILE")

    # Move directories from SOURCE_DIR to TRASH_DIR
    echo "Moving directories from $SOURCE_DIR to $TRASH_DIR..."
    find "$SOURCE_DIR" -mindepth 1 -type d -depth -exec mv -n {} "$TRASH_DIR" \; 2> >(tee -a "$STDERR_LOGFILE" >>"$LOGFILE")

    # Check for errors
    if [[ $? -ne 0 ]]; then
        echo "Error: Could not move files or directories from $SOURCE_DIR - Check directory and permissions."
        show_error_dialog
        exit 1
    fi

    # Ensure all files and directories have been moved
    remaining_files=$(find "$SOURCE_DIR" -mindepth 1 2>/dev/null)
    if [[ -n "$remaining_files" ]]; then
        echo "Warning: Some files or directories could not be moved from $SOURCE_DIR. Check manually." >> "$LOGFILE"
        echo "$remaining_files" >> "$LOGFILE"
    fi

    echo "Files moved successfully."

    # Try cleaning up Trash and handle errors
    echo "Cleaning up Trash..."
    find "$TRASH_DIR" -mindepth 1 -exec rm -rf {} + 2> >(tee -a "$STDERR_LOGFILE" >>"$LOGFILE")
    find_exit_code=$? # Capture the exit code of find
    if [[ $find_exit_code -ne 0 ]]; then
        echo "Error: Could not clean up Trash." >>"$LOGFILE"
        show_error_dialog
        exit 1
    fi

    echo "Trash cleaned successfully."

    # Show success notification
    osascript -e 'display dialog "Download files moved to Trash and Trash emptied!\n\nTo stop these, comment out osascripts in ~/move_to_trash.sh" with title "Move to Trash" buttons {"OK"} default button "OK"' \
        2> >(grep -v 'IMKClient subclass' | grep -v 'IMKInputSession subclass' >> "$STDERR_LOGFILE")

} >>"$LOGFILE" 2>>"$STDERR_LOGFILE"
