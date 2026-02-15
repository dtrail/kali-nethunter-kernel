#!/system/bin/sh
# ==============================================================================
# CHIMERA FAMILIA CONTROLLER v4.3 (Stable)
# Target: SM8250 / Android 14
#
# Logic:
# - Monitors Screen State & Battery Saver
# - Manages Kernel Blocking (Doom Mode)
# - Handles Maintenance Windows for Sync
# - Live-Reloads User Whitelist from /data/adb/chimera/whitelist.conf
# ==============================================================================

# --- KERNEL PATHS ---
KPATH="/sys/kernel/chimera_doom"
SYSFS_ACTIVE="$KPATH/active"
SYSFS_GRACE="$KPATH/grace_ms"
SYSFS_PANIC="$KPATH/panic_ms"
SYSFS_WHITELIST="$KPATH/whitelist"
# Debug node is NOT touched by controller (manual control only)

# --- USER CONFIG ---
CONF_DIR="/data/adb/chimera"
CONF_FILE="$CONF_DIR/whitelist.conf"

# --- ANDROID SERVICES ---
GMS_PKG="com.google.android.gms"
SYNC_SVC="com.google.android.gms/.chimera.GmsIntentOperationService"

# --- DEFAULTS ---
INTERVAL_NORMAL=3600   # 1 Hour
INTERVAL_SAVER=7200    # 2 Hours
SYNC_DURATION=60       # Time to allow sync
CONF_GRACE_MS=2000     # Kernel Grace Period
CONF_PANIC_MS=10000    # Burst Protection Duration

# --- STATE VARIABLES ---
LAST_SYNC=$(date +%s)
LAST_CONF_SUM="" 

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

write_sysfs() {
    # $1 = Path, $2 = Value
    if [ -f "$1" ]; then 
        echo "$2" > "$1"
    fi
}

create_default_config() {
    # Ensure directory exists
    if [ ! -d "$CONF_DIR" ]; then mkdir -p "$CONF_DIR"; fi
    
    # Create file content
    echo "# =========================================================" > $CONF_FILE
    echo "# CHIMERA FAMILIA - USER WHITELIST" >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "# Remove the '#' to ALLOW a wakelock." >> $CONF_FILE
    echo "# Changes are applied automatically within 10-30 seconds." >> $CONF_FILE
    echo "# =========================================================" >> $CONF_FILE
    echo "" >> $CONF_FILE
    
    # --- AUDIO & SENSORS (DEFAULT: ALLOWED / UNCOMMENTED) ---
    # Fixes Microphone deadlocks and Sensor Hub freezes
    echo "# --- Hardware: Audio & Sensors (Keep enabled!) ---" >> $CONF_FILE
    echo "sensor_ind" >> $CONF_FILE
    echo "*mRoutingWakeLock*" >> $CONF_FILE
    
    echo "" >> $CONF_FILE
    echo "# --- Google Services (Blocked by default) ---" >> $CONF_FILE
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
    echo "# --- Drivers ---" >> $CONF_FILE
    echo "# wlan_pno_wl" >> $CONF_FILE
    echo "# *hal_bluetooth_lock*" >> $CONF_FILE
    echo "# qcom_rx_wakelock" >> $CONF_FILE
    echo "# *Rcu*" >> $CONF_FILE
    
    # Make readable/writable for user
    chmod 644 $CONF_FILE
    echo "Chimera: Default config created at $CONF_FILE"
}

apply_config() {
    # 1. Create config if missing
    if [ ! -f "$CONF_FILE" ]; then create_default_config; fi
    
    # 2. Check for changes (MD5 Checksum)
    # Using awk to get just the hash
    if [ -f "$CONF_FILE" ]; then
        CURRENT_SUM=$(md5sum $CONF_FILE | awk '{print $1}')
    else
        CURRENT_SUM="error"
    fi

    if [ "$CURRENT_SUM" == "$LAST_CONF_SUM" ]; then
        return # Nothing changed, exit function
    fi
    
    # 3. Parse Config (Robust Regex Fix included!)
    # grep -v "^[[:space:]]*#" : Ignores lines starting with # (even with spaces)
    # grep -v "^[[:space:]]*$" : Ignores empty lines
    # tr '\n' ','              : Replaces newlines with commas
    PARSED_WL=$(grep -v "^[[:space:]]*#" $CONF_FILE | grep -v "^[[:space:]]*$" | tr '\n' ',' | sed 's/,,*/,/g' | sed 's/^,//' | sed 's/,$//')
    
    # 4. Send to Kernel
    if [ ! -z "$PARSED_WL" ]; then
        echo "Chimera: Loading Whitelist -> [$PARSED_WL]"
        write_sysfs $SYSFS_WHITELIST "$PARSED_WL"
    else
        # Clear whitelist if file is empty/all comments
        write_sysfs $SYSFS_WHITELIST ""
    fi
    
    # 5. Apply Kernel Parameters (Grace & Panic)
    write_sysfs $SYSFS_GRACE $CONF_GRACE_MS
    write_sysfs $SYSFS_PANIC $CONF_PANIC_MS
    
    # Update checksum
    LAST_CONF_SUM=$CURRENT_SUM
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Ensure Property is set
if [ "$(getprop persist.chimera.enable)" == "" ]; then
    setprop persist.chimera.enable 1
fi

echo "Chimera Controller: Loop Started."

while true; do
    
    # 1. Apply Config (Live Reload)
    apply_config

    # 2. Master Switch Check
    ENABLED=$(getprop persist.chimera.enable)
    if [ "$ENABLED" == "0" ]; then
        # Check current state to avoid spamming IO
        CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
        if [ "$CURRENT_VAL" != "0" ]; then
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
            echo "Chimera: Master Switch OFF -> Paused."
        fi
        sleep 30
        continue
    fi

    # 3. Get Screen State (Efficient Method)
    # Returns "Awake", "Asleep", or "Dozing"
    SCREEN_STATE=$(dumpsys power | grep "mWakefulness=" | cut -d= -f2 | tr -d '\r')
    NOW=$(date +%s)

    if [ "$SCREEN_STATE" != "Awake" ]; then
        # >>> SCREEN OFF >>>
        
        # Check Low Power Mode
        LOW_POWER=$(settings get global low_power)
        if [ "$LOW_POWER" == "1" ]; then
            CURRENT_INTERVAL=$INTERVAL_SAVER
        else
            CURRENT_INTERVAL=$INTERVAL_NORMAL
        fi
        
        TIME_DIFF=$((NOW - LAST_SYNC))

        if [ $TIME_DIFF -ge $CURRENT_INTERVAL ]; then
            # >>> MAINTENANCE WINDOW <<<
            # 1. Open Gates
            write_sysfs $SYSFS_ACTIVE 0
            am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
            
            # 2. Trigger Sync
            am start-service $SYNC_SVC > /dev/null 2>&1
            
            # 3. Wait
            sleep $SYNC_DURATION
            
            # 4. Reset Timer
            LAST_SYNC=$(date +%s)
        else
            # >>> DOOM BLOCK <<<
            # Only write if not already 1
            CURRENT_VAL=$(cat $SYSFS_ACTIVE 2>/dev/null)
            if [ "$CURRENT_VAL" != "1" ]; then
                write_sysfs $SYSFS_ACTIVE 1
                am set-standby-bucket $GMS_PKG restricted > /dev/null 2>&1
            fi
        fi

    else
        # >>> SCREEN ON >>>
        # 1. Open Gates
        write_sysfs $SYSFS_ACTIVE 0
        
        # 2. Normalize GMS
        am set-standby-bucket $GMS_PKG active > /dev/null 2>&1
        
        # 3. Reset Timer
        LAST_SYNC=$(date +%s)
    fi

    # Loop Tick
    sleep 10
done
