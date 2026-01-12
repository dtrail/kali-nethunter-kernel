**Chimera Familia: Doom Sleep Module**
## Operational Guide & Troubleshooting

This kernel features the **Doom Sleep Module**, a hybrid solution for **SM8250** on **Android 14+**. It combines a hard kernel-level wakelock filter with an intelligent user-space controller to silence aggressive GMS (Google Mobile Services) background activity.

---

### 1. The Core Components
* **Kernel Hook:** Intercepts specific wakelocks (e.g., `*gms_scheduler*`) at the source.
* **Chimera Controller:** A background daemon that monitors screen state and battery saver mode to toggle the kernel blocker and adjust Android Standby Buckets.
* **Master Switch:** A persistent toggle to enable or disable the entire system on the fly.

---

### 2. CLI Tool: `chimera`
The easiest way to interact with the system is via the built-in terminal tool. Open any terminal emulator (as **root**) and use the following commands:



Check Status: Displays the Master Toggle state and the real-time kernel blocker status:
```bash
chimera status
```

Disable System: (Master Kill-Switch) If you need to debug or ensure 100% sync (e.g., for banking or urgent notifications), use this to stop all restrictions:
```bash
chimera off
```

Enable System: Reactivates the intelligent monitoring and the Doom Sleep logic:
```Bash
chimera on
```

3. Manual Verification (Deep Dive)If you want to verify that the "Chimera Familia" logic is actually working, you can check the nodes directly:

Verify Kernel Blocker: Check if the kernel is currently ignoring the blacklisted wakelocks (1 = Blocking, 0 = Allowed):
```Bash
cat /sys/kernel/chimera_doom/active
```

Verify GMS Standby State: Check which "Bucket" Android has assigned to Google Play Services:
```Bash
dumpsys usagestats | grep -A 1 "com.google.android.gms"
```
- RESTRICTED: Doom Sleep is active. GMS is heavily throttled.
- ACTIVE: Screen is on or Maintenance Window is open. GMS has full access.


4. Logic Table

Screen State | Battery Saver | Action | GMS Bucket
------------ | ------------- | ------ | ----------
ON           | Any           | Blocker OFF | ACTIVE
OFF          | OFF           | Blocker ON (Sync every 60m) | RESTRICTED
OFF          | ON            | Blocker ON (Sync every 120m)| RESTRICTED



5. Troubleshooting

Enable Debug:

```Bash
echo 1 > /sys/kernel/chimera_doom/debug
```

Check logs:
```Bash
dmesg -w | grep "Chimera"
```

Notifications are delayed: This is expected during Deep Sleep. If it's too aggressive, use: 
```bash
chimera off
```

'Command not found': Ensure that /sbin is in your environment's $PATH. Must be ROOT to check.

