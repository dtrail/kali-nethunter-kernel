#!/system/bin/sh
# ==============================================================================
# CHIMERA FAMILIA CONTROLLER v4.0
# Target: SM8250 / Android 14
#
# Features:
# - Auto-generates user config at /data/adb/chimera/whitelist.conf
# - Live-Reloads config changes without reboot
# - Handles Smart Kernel v3.1 Logic
# ==============================================================================

# --- PATHS ---
KPATH="/sys/kernel/chimera_doom"
SYSFS_ACTIVE="$KPATH/active"
SYSFS_GRACE="$KPATH/grace_ms"
SYSFS_PANIC="$KPATH/panic_ms"
SYSFS_WHITELIST="$KPATH/whitelist"

# Config Path (User editable)
CONF_DIR="/data/adb/chimera"
CONF_FILE="$CONF_DIR/whitelist.conf"

# Android Services
GMS_PKG="com.google.android.gms"
SYNC_SVC="com.google.android.gms/.chimera.GmsIntentOperationService"

# --- DEFAULTS ---
INTERVAL_NORMAL=3600   # 1 Hour
INTERVAL_SAVER=7200    # 2 Hours
SYNC_DURATION=60       
CONF_GRACE_MS=2000     
CONF_PANIC_MS=10000    

# State vars
LAST_SYNC=$(date +%s)
LAST_CONF_SUM="" # To detect file changes

# --- HELPER: WRITE SYSFS ---
write_sysfs() {
    if [ -f "$1" ]; then echo "$2" > "$1"; fi
}

# --- HELPER: GENERATE DEFAULT CONFIG ---
create_default_config() {
    if [ ! -d "$CONF_DIR" ]; then mkdir -p "$CONF_DIR"; fi
    
    echo "# =========================================================" > $CONF_FILE
    echo "# CHIMERA FAMILIA - USER WHITELIST" >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "# Remove the '#' to ALLOW a wakelock (stop blocking it)." >> $CONF_FILE
    echo "# Changes are applied automatically within 10-30 seconds." >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "" >> $CONF_FILE
    echo "# --- Google Services ---" >> $CONF_FILE
    echo "# *gms_scheduler*" >> $CONF_FILE
    echo "# GcmSchedulerWakeupService" >> $CONF_FILE
    echo "# QosUploaderService" >> $CONF_FILE
    echo "# PayGcmTaskService" >> $CONF_FILE
    echo "# Google_C2DM" >> $CONF_FILE
    echo "# ChromeSync" >> $CONF_FILE
    echo "# *SendReportAction*" >> $CONF_FILE
    echo "" >> $CONF_FILE
    echo "# --- System Core ---" >> $CONF_FILE
    echo "# *SyncLoopWakeLock*" >> $CONF_FILE
    echo "# *job_scheduler*" >> $CONF_FILE
    echo "# *NetworkStats*" >> $CONF_FILE
    echo "# *LocationManagerService*" >> $CONF_FILE
    echo "" >> $CONF_FILE
    echo "# --- Hardware / Drivers ---" >> $CONF_FILE
    echo "# wlan_pno_wl" >> $CONF_FILE
    echo "# sensor_ind" >> $CONF_FILE
    echo "# *mRoutingWakeLock*" >> $CONF_FILE
    echo "# *hal_bluetooth_lock*" >> $CONF_FILE
    echo "# qcom_rx_wakelock" >> $CONF_FILE
    echo "# *Rcu*" >> $CONF_FILE
    echo "" >> $CONF_FILE
    
    # Set permissions so user can edit it easily
    chmod 644 $CONF_FILE
    echo "Chimera: Default config created at $CONF_FILE"
}

# --- HELPER: APPLY CONFIG ---
apply_config() {
    # 1. Create if missing
    if [ ! -f "$CONF_FILE" ]; then create_default_config; fi
    
    # 2. Check for changes (md5sum) to avoid spamming the kernel
    CURRENT_SUM=$(md5sum $CONF_FILE | awk '{print $1}')
    if [ "$CURRENT_SUM" == "$LAST_CONF_SUM" ]; then
        return # No changes, do nothing
    fi
    
    # 3. Parse Config
    # Remove comments, empty lines, replace newlines with comma
    PARSED_WL=$(grep -v "^\s*#" $CONF_FILE | grep -v "^\s*$" | tr '\n' ',' | sed 's/,,*/,/g' | sed 's/^,//' | sed 's/,$//')
    
    # 4. Send to Kernel
    if [ ! -z "$PARSED_WL" ]; then
        echo "Chimera: Loading Whitelist -> [$PARSED_WL]"
        write_sysfs $SYSFS_WHITELIST "$PARSED_WL"
    else
        write_sysfs $SYSFS_WHITELIST ""
    fi
    
    # 5. Apply Kernel Basics (just in case)
    write_sysfs $SYSFS_GRACE $CONF_GRACE_MS
    write_sysfs $SYSFS_PANIC $CONF_PANIC_MS
    
    LAST_CONF_SUM=$CURRENT_SUM
}

# --- STARTUP ---
if [ "$(getprop persist.chimera.enable)" == "" ]; then
    setprop persist.chimera.enable 1
fi

echo "Chimera Controller: Loop Started."

# --- MAIN LOOP ---
while true; do
    
    # 0. CHECK CONFIG UPDATES (Live Reload)
    apply_config

    # 1. MASTER SWITCH CHECK
    ENABLED=$(getprop persist.chimera.enable)
    if [ "$ENABLED" == "0" ]; then
        CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
        if [ "$CURRENT_VAL" != "0" ]; then
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active
        fi
        sleep 30
        continue
    fi

    # 2. SCREEN STATE
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
            # MAINTENANCE
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active
            am start-service $SYNC_SVC > /dev/null 2>&1
            sleep $SYNC_DURATION
            LAST_SYNC=$(date +%s)
        else
            # DOOM BLOCK
            CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
            if [ "$CURRENT_VAL" != "1" ]; then
                write_sysfs $SYSFS_ACTIVE 1
                am set-standby-bucket $GMS_PKG restricted
            fi
        fi

    else
        # >>> SCREEN ON >>>
        write_sysfs $SYSFS_ACTIVE 0
        am set-standby-bucket $GMS_PKG active
        LAST_SYNC=$(date +%s)
    fi

    sleep 10
done