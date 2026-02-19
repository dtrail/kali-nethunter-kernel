#!/system/bin/sh
# Chimera Service Launcher

# 1. Warten auf Boot_Completed (Wichtig!)
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 1
done

# Kleiner Sicherheitspuffer
sleep 5

# Debug-Log schreiben (damit wir wissen, dass der Service lebt)
echo "[$(date)] Chimera Service: Starting Controller..." > /cache/chimera_boot.log

# 2. Berechtigungen zur Sicherheit nochmal setzen (falls beim Install was schief ging)
chmod 0755 /system/bin/chimera_controller.sh

# 3. Controller starten (im Hintergrund mit nohup)
# Wir leiten Output nach /dev/null um, damit der Puffer nicht volläuft
nohup /system/bin/chimera_controller.sh > /dev/null 2>&1 &

echo "[$(date)] Chimera Service: Controller command issued." >> /cache/chimera_boot.log
