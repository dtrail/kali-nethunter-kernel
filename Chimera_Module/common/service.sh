#!/system/bin/sh
# Bitte nicht hardcoden, MODDIR wird vom Template bereitgestellt
MODDIR=${0%/*}

# Warten bis Boot fertig
until [ $(getprop sys.boot_completed) -eq 1 ]; do
  sleep 1
done

sleep 10

# Controller starten
# Wir rufen ihn aus /system/bin auf, da das Template ihn dorthin installiert
nohup /system/bin/chimera_controller.sh > /dev/null 2>&1 &