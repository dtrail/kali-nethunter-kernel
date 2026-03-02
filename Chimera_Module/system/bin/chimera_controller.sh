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
INTERVAL_NORMAL=3600
INTERVAL_SAVER=7200
SYNC_DURATION=60
CONF_GRACE_MS=2000
CONF_PANIC_MS=10000

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
    local WEB_STATS="/data/adb/modules/chimera/webroot/stats.data"
    
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
        # Saubere Version für die WebUI
        cat "$SYSFS_STATS" > "$WEB_STATS"
        chmod 644 "$WEB_STATS"

        # Version für das menschliche Log-File
        echo "# Chimera Wakelock Statistics (Live Snapshot)" > "$LOG_FILE"
        echo "Last Sync: $(date)" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "| Wakelock Name | Blocked (Total) | Allowed (Total) |" >> "$LOG_FILE"
        echo "| :--- | :---: | :---: |" >> "$LOG_FILE"
        
        tail -n +2 "$SYSFS_STATS" | while IFS='|' read -r name blocked allowed; do
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
    echo "# mRoutingWakeLock" >> $CONF_FILE
    echo "" >> $CONF_FILE

    echo "# --- TELEMETRY & DIAGNOSTICS (Uncommented = BLOCKED) ---" >> $CONF_FILE
    echo "# Safe to block. Stops Qualcomm/System data collection." >> $CONF_FILE
    echo "# DIAG_WS" >> $CONF_FILE
    echo "telemetry" >> $CONF_FILE
    echo "# mdm_stats" >> $CONF_FILE
    echo "# logd" >> $CONF_FILE
    echo "# pdp_watchdog" >> $CONF_FILE
    echo "" >> $CONF_FILE
    
    echo "# --- GOOGLE SERVICES (Uncommented = BLOCKED) ---" >> $CONF_FILE
    echo "gms_scheduler" >> $CONF_FILE
    echo "GcmSchedulerWakeupService" >> $CONF_FILE
    echo "QosUploaderService" >> $CONF_FILE
    echo "PayGcmTaskService" >> $CONF_FILE
    echo "Google_C2DM" >> $CONF_FILE
    echo "ChromeSync" >> $CONF_FILE
    echo "SendReportAction" >> $CONF_FILE
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
    
    # Parse Config
    PARSED_BL=$(grep -v "^[[:space:]]*#" $CONF_FILE | grep -v "^[[:space:]]*$" | tr '\n' ',' | sed 's/,,*/,/g' | sed 's/^,//' | sed 's/,$//')
    
    # Send to Kernel
    if [ ! -z "$PARSED_BL" ]; then
        write_sysfs $SYSFS_BLOCKLIST "$PARSED_BL"
    else
        write_sysfs $SYSFS_BLOCKLIST ""
    fi
    
    # Apply Kernel Parameters
    write_sysfs $SYSFS_GRACE $CONF_GRACE_MS
    write_sysfs $SYSFS_PANIC $CONF_PANIC_MS
    
    LAST_CONF_SUM=$CURRENT_SUM
}

auto_heal() {
    EMERGENCIES=$(dmesg | grep "CHIMERA-EMERGENCY:" | awk -F'CHIMERA-EMERGENCY: ' '{print $2}' | tr -d '\r' | sort -u)
    
    if [ ! -z "$EMERGENCIES" ]; then
        dmesg -c > /dev/null 
        HEALED=0
        
        if ! grep -q "EMERGENCY ENTRIES" "$CONF_FILE"; then
            echo "" >> "$CONF_FILE"
            echo "# --- EMERGENCY ENTRIES (Auto-disabled for causing bursts/instability) ---" >> "$CONF_FILE"
        fi
        
        for lock in $EMERGENCIES; do
            if grep -q "^${lock}$" "$CONF_FILE"; then
                sed -i "/^${lock}$/d" "$CONF_FILE"
                echo "# $lock" >> "$CONF_FILE"
                echo "⚠️ **AUTO-HEAL:** Automatically disabled \`$lock\` to prevent system instability." >> "$LOG_FILE"
                HEALED=1
            fi
        done
        
        if [ "$HEALED" == "1" ]; then
            LAST_CONF_SUM=""
            apply_config
        fi
    fi
}

# ==============================================================================
# MAIN LOGIC (v6.1 - Smart Engine)
# ==============================================================================

trap 'LAST_CONF_SUM=""; apply_config; update_log_file' HUP

# --- 1. SOFORTIGE INITIALISIERUNG ---
if [ ! -f "$CONF_FILE" ]; then 
    create_default_config
fi

mkdir -p "$LOG_DIR"

if [ "$(getprop persist.chimera.enable)" == "" ]; then
    setprop persist.chimera.enable 1
fi

SETTINGS_FILE="/data/adb/chimera/settings.conf"
LOOP_COUNT=0

apply_config

while true; do
    
    auto_heal
    apply_config

    LOOP_COUNT=$((LOOP_COUNT + 1))
    if [ $LOOP_COUNT -ge 6 ]; then
        update_log_file
        LOOP_COUNT=0
    fi

    ENABLED=$(getprop persist.chimera.enable)
    if [ "$ENABLED" == "0" ]; then
        CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
        if [ "$CURRENT_VAL" != "0" ]; then
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
        fi
        sleep 10 & wait $!
        continue
    fi

    if [ -f "$SETTINGS_FILE" ]; then source "$SETTINGS_FILE"; fi

    SCREEN_STATE=$(dumpsys power | grep "mWakefulness=" | cut -d= -f2 | tr -d '\r')
    NOW=$(date +%s)

    if [ "$SCREEN_STATE" != "Awake" ]; then
        CURRENT_INTERVAL=$INTERVAL_NORMAL
        LOW_POWER=$(settings get global low_power)
        
        if [ "$LOW_POWER" == "1" ]; then
            CURRENT_INTERVAL=$INTERVAL_SAVER
        fi
        
        if [ "$NIGHT_MODE" == "1" ]; then
            CURRENT_HOUR=$(date +%H)
            if [ "$CURRENT_HOUR" -ge "${NIGHT_START:-01}" ] && [ "$CURRENT_HOUR" -lt "${NIGHT_END:-06}" ]; then
                CURRENT_INTERVAL=14400
            fi
        fi
        
        TIME_DIFF=$((NOW - LAST_SYNC))

        if [ $TIME_DIFF -ge $CURRENT_INTERVAL ]; then
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
            am start-service $SYNC_SVC > /dev/null 2>&1
            sleep $SYNC_DURATION & wait $!
            LAST_SYNC=$(date +%s)
        else
            BLOCK_ALLOWED=1
            
            if [ "$SMART_CALL_DETECT" == "1" ]; then
                CALL_STATE=$(dumpsys telecom | grep "mCallState=" | tail -n 1)
                if echo "$CALL_STATE" | grep -q -E "RINGING|ACTIVE|DIALING"; then
                    BLOCK_ALLOWED=0
                fi
            fi
            
            if [ "$BLOCK_ALLOWED" == "1" ] && [ "$SMART_MEDIA_DETECT" == "1" ]; then
                if dumpsys audio | grep -q "player piid:.*state:started"; then
                    BLOCK_ALLOWED=0
                fi
            fi

            if [ "$BLOCK_ALLOWED" == "1" ]; then
                CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
                if [ "$CURRENT_VAL" != "1" ]; then
                    write_sysfs $SYSFS_ACTIVE 1
                    am set-standby-bucket $GMS_PKG restricted > /dev/null 2>&1
                fi
            else
                write_sysfs $SYSFS_ACTIVE 0
            fi
        fi

    else
        write_sysfs $SYSFS_ACTIVE 0
        am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
        LAST_SYNC=$(date +%s)
    fi

    sleep 10 & wait $!
done
