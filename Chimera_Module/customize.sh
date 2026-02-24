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

# 3. Berechtigungen setzen (Das Wichtigste!)
# Da Magisk schon entpackt hat, sind die Dateien jetzt in $MODPATH.
ui_print "- Setting permissions..."

# Alle Ordner auf 755, Dateien auf 644 (Basis-Rechte)
# set_perm_recursive $MODPATH 0 0 0755 0644

# Die Skripte ausführbar machen (755)
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/system/bin/chimera 0 0 0755
set_perm $MODPATH/system/bin/chimera_controller.sh 0 0 0755

# 4. Aufräumen (Wie in deinem Beispiel)
# customize.sh wird im installierten Modul nicht mehr gebraucht
rm -f $MODPATH/customize.sh

ui_print "- Installation successful! Please Reboot."
