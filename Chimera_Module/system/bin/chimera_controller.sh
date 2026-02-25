#!/system/bin/sh
# ==============================================================================
# CHIMERA FAMILIA CONTROLLER v6.0 (Profiles & Stats Edition)
# ==============================================================================

# --- KERNEL PATHS ---
KPATH="/sys/kernel/chimera_doom"
SYSFS_ACTIVE="$KPATH/active"
SYSFS_STATS="$KPATH/stats"
SYSFS_BLOCKLIST="$KPATH/blocklist"
SYSFS_GRACE="$KPATH/grace_ms"
SYSFS_PANIC="$KPATH/panic_ms"

# --- USER CONFIG ---
CONF_DIR="/data/adb/chimera"
CONF_FILE="$CONF_DIR/blocklist.conf"

# --- LOGGING CONFIG (Fix: Sicheres Magisk-Verzeichnis) ---
LOG_DIR="/data/adb/chimera/logs"
LOG_FILE="$LOG_DIR/chimera_stats.md"
MAX_LOG_SIZE_KB=500
RETENTION_DAYS=7

# --- ANDROID SERVICES ---
GMS_PKG="com.google.android.gms"
SYNC_SVC="com.google.android.gms/.chimera.GmsIntentOperationService"

# --- DEFAULTS ---
INTERVAL_NORMAL=3600   # 1 Hour
INTERVAL_SAVER=7200    # 2 Hours
SYNC_DURATION=60       # Time to allow sync (Maintenance Window)
CONF_GRACE_MS=2000     # Kernel Grace Period
CONF_PANIC_MS=10000    # Burst Protection Duration

# --- STATE VARIABLES ---
LAST_SYNC=$(date +%s)
LAST_CONF_SUM="" 

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

write_sysfs() {
    if [ -f "$1" ]; then 
        echo "$2" > "$1"
    fi
}

update_log_file() {
    mkdir -p "$LOG_DIR"
    
    # 1. Check Rotation
    if [ -f "$LOG_FILE" ]; then
        SIZE=$(du -k "$LOG_FILE" | awk '{print $1}')
        if [ "$SIZE" -ge "$MAX_LOG_SIZE_KB" ]; then
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            mv "$LOG_FILE" "$LOG_DIR/archive_$TIMESTAMP.md"
            find "$LOG_DIR" -name "archive_*.md" -mtime +$RETENTION_DAYS -delete
        fi
    fi

    # 2. Write Stats from Kernel
    if [ -f "$SYSFS_STATS" ]; then
        echo "# Chimera Wakelock Statistics (Live Snapshot)" > "$LOG_FILE"
        echo "Last Sync: $(date)" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "| Wakelock Name | Blocked (Total) | Allowed (Total) |" >> "$LOG_FILE"
        echo "| :--- | :---: | :---: |" >> "$LOG_FILE"
        
        cat "$SYSFS_STATS" | tail -n +2 | while IFS='|' read -r name blocked allowed; do
             if [ ! -z "$name" ]; then
                 echo "| $name | **$blocked** | $allowed |" >> "$LOG_FILE"
             fi
        done
    fi
}

create_default_config() {
    if [ ! -d "$CONF_DIR" ]; then mkdir -p "$CONF_DIR"; fi
    
    echo "# =========================================================" > $CONF_FILE
    echo "# CHIMERA FAMILIA - DOOM BLOCKLIST (v6.0)" >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "# Remove the '#' to BLOCK a wakelock." >> $CONF_FILE
    echo "# Add a '#' to ALLOW a wakelock." >> $CONF_FILE
    echo "# Changes are applied automatically within 10-30 seconds." >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "" >> $CONF_FILE
    
    echo "# --- CRITICAL SYSTEM (Commented = ALLOWED) ---" >> $CONF_FILE
    echo "# NEVER block these! Blocking will cause kernel panics/freezes." >> $CONF_FILE
    echo "# eventpoll" >> $CONF_FILE
    echo "# alarmtimer" >> $CONF_FILE
    echo "# [timerfd]" >> $CONF_FILE
    echo "" >> $CONF_FILE

    echo "# --- HARDWARE & AUDIO (Commented = ALLOWED) ---" >> $CONF_FILE
    echo "# Do NOT uncomment these unless you want broken audio!" >> $CONF_FILE
    echo "# sensor_ind" >> $CONF_FILE
    echo "# *mRoutingWakeLock*" >> $CONF_FILE
    echo "" >> $CONF_FILE

    echo "# --- TELEMETRY & DIAGNOSTICS (Uncommented = BLOCKED) ---" >> $CONF_FILE
    echo "# Safe to block. Stops Qualcomm/System data collection." >> $CONF_FILE
    echo "DIAG_WS" >> $CONF_FILE
    echo "*telemetry*" >> $CONF_FILE
    echo "*mdm_stats*" >> $CONF_FILE
    echo "# *logd*" >> $CONF_FILE
    echo "# pdp_watchdog" >> $CONF_FILE
    echo "" >> $CONF_FILE
    
    echo "# --- GOOGLE SERVICES (Uncommented = BLOCKED) ---" >> $CONF_FILE
    echo "*gms_scheduler*" >> $CONF_FILE
    echo "GcmSchedulerWakeupService" >> $CONF_FILE
    echo "QosUploaderService" >> $CONF_FILE
    echo "PayGcmTaskService" >> $CONF_FILE
    echo "Google_C2DM" >> $CONF_FILE
    echo "ChromeSync" >> $CONF_FILE
    echo "*SendReportAction*" >> $CONF_FILE
    echo "" >> $CONF_FILE

    echo "# --- EXPERIMENTAL NETWORK (Commented = ALLOWED) ---" >> $CONF_FILE
    echo "# Uncomment for extreme battery, but might delay Push-Notifications!" >> $CONF_FILE
    echo "# qcom_rx_wakelock" >> $CONF_FILE
    echo "# wlan_pno_wl" >> $CONF_FILE
    echo "# wlan_rx_wake" >> $CONF_FILE
    echo "# IPA_WS" >> $CONF_FILE
    
    chmod 644 $CONF_FILE
    echo "Chimera: Default blocklist created at $CONF_FILE"
}

apply_config() {
    if [ ! -f "$CONF_FILE" ]; then create_default_config; fi
    
    CURRENT_SUM=$(md5sum $CONF_FILE | awk '{print $1}')
    if [ "$CURRENT_SUM" == "$LAST_CONF_SUM" ]; then
        return
    fi
    
    # Parse Config (Ignoriert auskommentierte Zeilen und leere Zeilen)
    PARSED_BL=$(grep -v "^[[:space:]]*#" $CONF_FILE | grep -v "^[[:space:]]*$" | tr '\n' ',' | sed 's/,,*/,/g' | sed 's/^,//' | sed 's/,$//')
    
    # Send to Kernel
    if [ ! -z "$PARSED_BL" ]; then
        write_sysfs $SYSFS_BLOCKLIST "$PARSED_BL"
    else
        write_sysfs $SYSFS_BLOCKLIST ""
    fi
    
    # Apply Kernel Parameters (Grace & Panic)
    write_sysfs $SYSFS_GRACE $CONF_GRACE_MS
    write_sysfs $SYSFS_PANIC $CONF_PANIC_MS
    
    LAST_CONF_SUM=$CURRENT_SUM
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

if [ "$(getprop persist.chimera.enable)" == "" ]; then
    setprop persist.chimera.enable 1
fi

LOOP_COUNT=0

while true; do
    
    # 1. Apply Config (Live Reload)
    apply_config

    # 2. Update Stats Log (Every 60 seconds)
    LOOP_COUNT=$((LOOP_COUNT + 1))
    if [ $LOOP_COUNT -ge 6 ]; then
        update_log_file
        LOOP_COUNT=0
    fi

    # 3. Master Switch Check
    ENABLED=$(getprop persist.chimera.enable)
    if [ "$ENABLED" == "0" ]; then
        CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
        if [ "$CURRENT_VAL" != "0" ]; then
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
        fi
        sleep 10
        continue
    fi

    # 4. Get Screen State
    SCREEN_STATE=$(dumpsys power | grep "mWakefulness=" | cut -d= -f2 | tr -d '\r')
    NOW=$(date +%s)

    if [ "$SCREEN_STATE" != "Awake" ]; then
        # >>> SCREEN OFF >>>
        LOW_POWER=$(settings get global low_power)
        if [ "$LOW_POWER" == "1" ]; then
            CURRENT_INTERVAL=$INTERVAL_SAVER
        else
            CURRENT_INTERVAL=$INTERVAL_NORMAL
        fi
        
        TIME_DIFF=$((NOW - LAST_SYNC))

        if [ $TIME_DIFF -ge $CURRENT_INTERVAL ]; then
            # >>> MAINTENANCE WINDOW <<<
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
            am start-service $SYNC_SVC > /dev/null 2>&1
            sleep $SYNC_DURATION
            LAST_SYNC=$(date +%s)
        else
            # >>> DOOM BLOCK <<<
            CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
            if [ "$CURRENT_VAL" != "1" ]; then
                write_sysfs $SYSFS_ACTIVE 1
                am set-standby-bucket $GMS_PKG restricted > /dev/null 2>&1
            fi
        fi

    else
        # >>> SCREEN ON >>>
        write_sysfs $SYSFS_ACTIVE 0
        am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
        LAST_SYNC=$(date +%s)
    fi

    sleep 10
done
