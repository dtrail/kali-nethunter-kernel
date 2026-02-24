#!/system/bin/sh
ui_print "- Installing Chimera Familia (v6.0 Profiles Edition)..."

# 1. Alte Instanzen stoppen
killall -9 chimera_controller.sh 2>/dev/null
killall -9 chimera 2>/dev/null

# 2. Config Ordner erstellen
if [ ! -d "/data/adb/chimera" ]; then
  ui_print "- Creating config directory..."
  mkdir -p /data/adb/chimera
fi

# 3. Berechtigungen setzen
ui_print "- Setting executable permissions..."
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/system/bin/chimera 0 0 0755
set_perm $MODPATH/system/bin/chimera_controller.sh 0 0 0755

# 4. Aufräumen
rm -f $MODPATH/customize.sh

ui_print "- Installation successful! Please Reboot."
