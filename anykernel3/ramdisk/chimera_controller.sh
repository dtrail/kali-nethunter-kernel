#!/system/bin/sh
# ==============================================================================
# CHIMERA FAMILIA CONTROLLER - SM8250 / Android 14
#
# Logic:
# 1. Screen OFF -> Block Wakelocks via Kernel Module & Restrict GMS
# 2. Screen ON  -> Allow everything
# 3. Maintenance Window -> Allow Sync every X minutes (depending on Battery Saver)
# ==============================================================================

# --- CONFIGURATION ---
SYSFS_NODE="/sys/kernel/chimera_doom/active"
GMS_PKG="com.google.android.gms"

# Chimera-Service
SYNC_SVC="com.google.android.gms/.chimera.GmsIntentOperationService"

# interval in seconds
INTERVAL_NORMAL=3600
INTERVAL_SAVER=7200
SYNC_DURATION=60

# Init
LAST_SYNC=$(date +%s)

# Standardwert setzen, falls nicht vorhanden (Standard = AN)
if [ "$(getprop persist.chimera.enable)" == "" ]; then
    setprop persist.chimera.enable 1
fi

echo "Chimera Controller: Started."

# --- Master Toggle ---
while true; do
    # --- 0. MASTER TOGGLE CHECK ---
    # Wir lesen die Property. Wenn 0, dann alles deaktivieren.
    ENABLED=$(getprop persist.chimera.enable)
    
    if [ "$ENABLED" == "0" ]; then
        # Master Switch ist AUS -> Alles erlauben
        
        # Only write, if neccessary (avoid spam)
        CURRENT_VAL=$(cat $SYSFS_NODE 2>/dev/null)
        if [ "$CURRENT_VAL" != "0" ]; then
            echo 0 > $SYSFS_NODE
            am set-standby-bucket $GMS_PKG active
            echo "Chimera: Master Switch OFF -> Disabled Doom Mode."
        fi
        
        # Langsam pollen (30s), um CPU zu sparen, während wir deaktiviert sind
        sleep 30
        continue
    fi

    # --- main loop ---
    
    # 1. get screen state (reliable via dumpsys)
    # Output should be either "OFF" or "ON" (mostly, sometimes DOZE, will be handled like ON)
    SCREEN_STATE=$(dumpsys display | grep "mScreenState" | cut -d= -f2)
    NOW=$(date +%s)

    if [ "$SCREEN_STATE" == "OFF" ]; then
        
        # check doze (1 = On, 0 = Off)
        LOW_POWER=$(settings get global low_power)
        
        # append dynamic interval
        if [ "$LOW_POWER" == "1" ]; then
            CURRENT_INTERVAL=$INTERVAL_SAVER
        else
            CURRENT_INTERVAL=$INTERVAL_NORMAL
        fi
        
        # calculate time since last sync
        TIME_DIFF=$((NOW - LAST_SYNC))

	# 3. decision: Doom Mode or Maintenance Window?
        if [ $TIME_DIFF -ge $CURRENT_INTERVAL ]; then
            
            # ==============================
            # MAINTENANCE WINDOW (SYNC TIME)
            # ==============================
            # run blocker
            echo 0 > $SYSFS_NODE
            
            # Raise GMS priority (to allow network access)
            am set-standby-bucket $GMS_PKG active
            
            # trigger manual sync
            am start-service $SYNC_SVC
            
            # wait (blocks the script, but that's fine right here
            sleep $SYNC_DURATION
            
            # Timer reset
            LAST_SYNC=$(date +%s)
        else
            # ==============================
            # DOOM MODE (DEEP SLEEP)
            # ==============================
            # IO-Check: Nur schreiben, wenn nötig (vermeidet Overhead)
            CURRENT_VAL=$(cat $SYSFS_NODE 2>/dev/null)
            if [ "$CURRENT_VAL" != "1" ]; then
                echo 1 > $SYSFS_NODE
                am set-standby-bucket $GMS_PKG restricted
            fi
        fi

    else
    
        # ==============================
        # SCREEN ON (INTERACTIVE)
        # ==============================
        # deactivate Kernel Blocker
        echo 0 > $SYSFS_NODE
        
        # normalize GMS 
        am set-standby-bucket $GMS_PKG active
        
        # reset time, so we won't sync immediately on Screen-Off,
        # but after completing the full interval
        LAST_SYNC=$(date +%s)
    fi

    # spare processing power, 10 mins is okay
    sleep 10
done
