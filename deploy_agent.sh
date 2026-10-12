#!/bin/bash

cleanup_and_exit() {
    echo -e "\n[!] Deployment interrupted by user!"
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        echo "[*] Archiving incomplete setup to ${PROJECT_DIR}_archive.zip..."
        zip -r "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR" > /dev/null 2>&1
        rm -rf "$PROJECT_DIR"
        echo "[*] Incomplete project folder cleaned up."
    fi
    exit 1
}

deploy_app() {
    trap cleanup_and_exit SIGINT SIGTSTP

    echo "--- FEATURE 1: DEPLOY APPLICATION ---"

    echo "[*] Performing pre-flight checks..."
    if ! command -v python3 &> /dev/null; then
        echo "[ERROR] python3 is not installed."
        exit 1
    fi
    if ! command -v zip &> /dev/null; then
        echo "[ERROR] zip is not installed."
        exit 1
    fi
    echo "[+] Pre-flight checks passed."

    read -p "Enter project folder suffix name: " SUFFIX
    if [ -z "$SUFFIX" ]; then
        echo "[ERROR] Project suffix cannot be empty."
        exit 1
    fi

    PROJECT_DIR="attendance_tracker_${SUFFIX}"

    if [ -d "$PROJECT_DIR" ]; then
        read -p "Directory '$PROJECT_DIR' already exists. Overwrite? (y/n): " OVERWRITE
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            echo "[*] Aborting deployment."
            return
        fi
        rm -rf "$PROJECT_DIR"
    fi

    mkdir -p "$PROJECT_DIR/Helpers"
    mkdir -p "$PROJECT_DIR/reports"

    cp templates/attendance_checker.py "$PROJECT_DIR/"

    echo "Select Roster Configuration Option:"
    echo "1) Option A - Copy template roster (10 sample students)"
    echo "2) Option B - Generate fresh roster"
    read -p "Choice (1 or 2): " ROSTER_CHOICE

    if [ "$ROSTER_CHOICE" -eq 1 ]; then
        read -p "How many students to copy from template (max 10)? " STU_COUNT
        head -n 1 templates/assets.csv > "$PROJECT_DIR/Helpers/assets.csv"
        tail -n +2 templates/assets.csv | head -n "$STU_COUNT" >> "$PROJECT_DIR/Helpers/assets.csv"
        
        cp templates/config.json "$PROJECT_DIR/Helpers/config.json"
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 5/' "$PROJECT_DIR/Helpers/config.json"
    else
        read -p "How many students to add to fresh roster? " STU_COUNT
        echo "Email,Names,Attendance Count,Absence Count" > "$PROJECT_DIR/Helpers/assets.csv"
        for (( i=1; i<=STU_COUNT; i++ )); do
            echo "student${i}@example.com,Student ${i},0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        done

        cp templates/config.json "$PROJECT_DIR/Helpers/config.json"
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json"
    fi

    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"
    echo "[+] Permissions set: attendance_checker.py (+x), config.json (600)."

    read -p "Do you want to update warning/failure thresholds? (y/n): " UPDATE_THRESH
    if [[ "$UPDATE_THRESH" == "y" || "$UPDATE_THRESH" == "Y" ]]; then
        read -p "Enter warning threshold percentage (numeric): " WARN_VAL
        read -p "Enter failure threshold percentage (numeric): " FAIL_VAL

        if [[ "$WARN_VAL" =~ ^[0-9]+$ ]] && [[ "$FAIL_VAL" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"warning\": [0-9]*/\"warning\": $WARN_VAL/" "$PROJECT_DIR/Helpers/config.json"
            sed -i "s/\"failure\": [0-9]*/\"failure\": $FAIL_VAL/" "$PROJECT_DIR/Helpers/config.json"
            echo "[+] Thresholds updated successfully."
        else
            echo "[!] Invalid input. Keeping default thresholds."
        fi
    fi

    trap - SIGINT SIGSTP
    echo "[+] Deployment completed successfully in '$PROJECT_DIR'."
}

run_app() {
    echo "--- FEATURE 2: RUN APPLICATION ---"
    read -p "Enter project folder suffix name to run: " SUFFIX
    PROJECT_DIR="attendance_tracker_${SUFFIX}"

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "[ERROR] Directory '$PROJECT_DIR' does not exist."
        return
    fi

    cd "$PROJECT_DIR" || return
    python3 attendance_checker.py
    cd ..
}

archive_logs() {
    echo "--- FEATURE 3: ARCHIVE LOG FILES ---"
    read -p "Enter project folder suffix name to archive logs: " SUFFIX
    PROJECT_DIR="attendance_tracker_${SUFFIX}"

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "[ERROR] Directory '$PROJECT_DIR' does not exist."
        return
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$PROJECT_DIR/archives/attendance"
    mkdir -p "$PROJECT_DIR/archives/absent"

    if [ -f "$PROJECT_DIR/reports/attendance.log" ]; then
        mv "$PROJECT_DIR/reports/attendance.log" "$PROJECT_DIR/archives/attendance/attendance_${TIMESTAMP}.log"
        echo "[+] Archived attendance.log to archives/attendance/attendance_${TIMESTAMP}.log"
    else
        echo "[*] No attendance.log found to archive."
    fi

    if [ -f "$PROJECT_DIR/reports/absent.log" ]; then
        mv "$PROJECT_DIR/reports/absent.log" "$PROJECT_DIR/archives/absent/absent_${TIMESTAMP}.log"
        echo "[+] Archived absent.log to archives/absent/absent_${TIMESTAMP}.log"
    else
        echo "[*] No absent.log found to archive."
    fi
}

while true; do
    echo "=========================================="
    echo " Automated Project Bootstrapping Agent    "
    echo "=========================================="
    echo "1. Deploy Application"
    echo "2. Run Application"
    echo "3. Archive Log Files"
    echo "4. Exit"
    read -p "Select option (1-4): " MAIN_CHOICE

    case $MAIN_CHOICE in
        1) deploy_app ;;
        2) run_app ;;
        3) archive_logs ;;
        4) echo "Exiting agent."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
