#!/system/bin/sh
# Warten bis Boot abgeschlossen (Sicherheitspuffer)
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 1
done

sleep 5

# Startet den Controller im Hintergrund
# Da Magisk /system/bin bind-mounted, rufen wir es direkt von dort auf
nohup /system/bin/chimera_controller.sh > /dev/null 2>&1 &
