#!/system/bin/sh

# Standard-Variable: Sagt Magisk, dass wir selber entpacken wollen (oft sicherer)
SKIPUNZIP=1

ui_print "- Installiere Chimera Familia Manager..."

# 1. Entpacken
# Wir entpacken alles aus der Zip in den Modul-Pfad ($MODPATH)
unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'service.sh' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'system.prop' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'module.prop' -d $MODPATH >&2

# 2. Berechtigungen setzen (CRITICAL!)
ui_print "- Setze Ausführungsrechte..."

# Das CLI Tool
set_perm $MODPATH/system/bin/chimera 0 0 0755
# Der Controller
set_perm $MODPATH/system/bin/chimera_controller.sh 0 0 0755
# Der Autostart-Service
set_perm $MODPATH/service.sh 0 0 0755

ui_print "- Fertig! Rebooten."