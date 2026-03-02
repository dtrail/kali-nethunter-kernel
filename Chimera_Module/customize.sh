#!/system/bin/sh

# HINWEIS: Wir nutzen KEIN "SKIPUNZIP=1".
# Magisk entpackt die ZIP automatisch nach $MODPATH, bevor dieses Skript startet.

ui_print "- Installing Chimera Familia..."

# 1. Alte Instanzen töten (Wie in deinem Beispiel)
# Das verhindert "Text file busy" Fehler beim Überschreiben
killall -9 chimera_controller.sh 2>/dev/null
killall -9 chimera 2>/dev/null

# 2. Config Ordner erstellen
ui_print "- Creating config directory..."
mkdir -p /data/adb/chimera
mkdir -p /data/adb/chimera/logs

# 3. Berechtigungen setzen (Das Wichtigste!)
# Da Magisk schon entpackt hat, sind die Dateien jetzt in $MODPATH.
ui_print "- Setting permissions..."

# Alle Ordner auf 755, Dateien auf 644 (Basis-Rechte)
# set_perm_recursive $MODPATH 0 0 0755 0644

# Die Skripte ausführbar machen (755)
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/system/bin/chimera 0 0 0755
set_perm $MODPATH/system/bin/chimera_controller.sh 0 0 0755

# ==============================================================================
# CHIMERA FAMILIA - UPDATE & MIGRATION LOGIC
# ==============================================================================

CONF_DIR="/data/adb/chimera"
CONF_FILE="$CONF_DIR/blocklist.conf"
BACKUP_FILE="$CONF_DIR/blocklist_backup_v6.1.conf"

ui_print "- Checking for existing configuration..."

if [ -f "$CONF_FILE" ]; then
    ui_print "  *************************************************"
    ui_print "  ! EXISTING BLOCKLIST DETECTED !"
    ui_print "  *************************************************"
    ui_print "  Because v6.1 contains critical safety updates,"
    ui_print "  your old blocklist has been backed up to:"
    ui_print "  -> blocklist_backup_v6.1.conf"
    ui_print " "
    ui_print "  A fresh, safe default list will be generated."
    ui_print "  Please use the WebUI or text editor to port"
    ui_print "  your custom wakelocks over manually."
    ui_print "  *************************************************"
    
    # Datei umbenennen (sichern)
    mv "$CONF_FILE" "$BACKUP_FILE"
else
    ui_print "- No previous configuration found. Clean install."
fi

# Setze korrekte Berechtigungen für den Ordner, falls er schon existiert
if [ -d "$CONF_DIR" ]; then
    set_perm_recursive "$CONF_DIR" 0 0 0755 0644
fi

# 4. Aufräumen (Wie in deinem Beispiel)
# customize.sh wird im installierten Modul nicht mehr gebraucht
rm -f $MODPATH/customize.sh

ui_print "- Installation successful! Please Reboot."
