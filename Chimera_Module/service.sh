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

# 2. BERECHTIGUNG ENTFERNT!
# (Der chmod-Befehl war hier und hat den "read-only filesystem" Crash verursacht)

# 3. Controller starten (im Hintergrund mit nohup)
# Wir rufen explizit "sh" auf. Damit umgehen wir alle potenziellen Rechte-Probleme!
nohup sh /system/bin/chimera_controller.sh > /dev/null 2>&1 &

echo "[$(date)] Chimera Service: Controller command issued." >> /cache/chimera_boot.log
