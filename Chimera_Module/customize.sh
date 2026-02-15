#!/system/bin/sh

SKIPUNZIP=1

# 1. Pfade vorbereiten
ui_print "- Extracting module files..."
unzip -o "$ZIPFILE" 'system/*' -d $MODPATH
unzip -o "$ZIPFILE" 'service.sh' -d $MODPATH
unzip -o "$ZIPFILE" 'module.prop' -d $MODPATH

# 2. Berechtigungen setzen (Das Wichtigste!)
ui_print "- Setting permissions..."

# CLI Tool ausführbar machen
set_perm $MODPATH/system/bin/chimera 0 0 0755

# Controller ausführbar machen
set_perm $MODPATH/system/bin/chimera_controller.sh 0 0 0755

# Service ausführbar machen
set_perm $MODPATH/service.sh 0 0 0755

# 3. Aufräumen (Optional: Config-Ordner erstellen, falls nicht da)
# Wir erstellen den Ordner, aber KEINE Datei, damit wir User-Configs nicht überschreiben!
if [ ! -d "/data/adb/chimera" ]; then
  ui_print "- Creating config directory..."
  mkdir -p /data/adb/chimera
fi

ui_print "- Installation complete!"
