##########################################################################################
#
# Chimera Doom Sleep Module
# by Godis
# 
#
##########################################################################################

##########################################################################################
# Defines
##########################################################################################

# Deine ID (Muss zur module.prop passen!)
MODID=chimera_manager

# Magic Mount (Lassen wir an, damit /system/bin gemountet wird)
AUTOMOUNT=true

# Brauchen wir system.prop? JA! (Für persist.chimera.enable=1)
PROPFILE=true

# Brauchen wir post-fs-data? NEIN.
POSTFSDATA=false

# Brauchen wir service.sh? JA! (Um den Controller zu starten)
LATESTARTSERVICE=true

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod
print_modname() {
  ui_print "*******************************"
  ui_print "   Chimera Doom Sleep Module   "
  ui_print "*******************************"
}

##########################################################################################
# Replace list
##########################################################################################
# List all directories you want to directly replace in the system
# Leave it empty if you don't need to replace anything

REPLACE="
"

##########################################################################################
# Permissions
##########################################################################################

set_permissions() {
  # Standard-Rechte für alles (Ordner 755, Dateien 644)
  set_perm_recursive  $MODPATH  0  0  0755  0644

  # --- HIER DEINE ÄNDERUNGEN ---
  
  # Das CLI Tool muss ausführbar sein:
  set_perm  $MODPATH/system/bin/chimera                0  0  0755
  
  # Das Controller Script muss ausführbar sein:
  set_perm  $MODPATH/system/bin/chimera_controller.sh  0  0  0755
}
