// --- ON-SCREEN DEBUGGER & MAGISK/MMRL ROOT BRIDGE ---
function debugLog(msg) {
    const list = document.getElementById('wakelock-list');
    if (list) {
        list.innerHTML += `<p style="color: yellow; font-size: 11px; text-align: left; font-family: monospace; margin: 2px 0;">> ${msg}</p>`;
    }
}

async function run(cmd) {
    try {
        // 1. Die offizielle MMRL WebUI+ Bridge
        if (typeof window.os !== 'undefined' && typeof window.os.exec !== 'undefined') {
            const res = await window.os.exec(cmd);
            return res.stdout || res.stderr || "";
        }
        
        // 2. Alternative MMRL Bridge (falls os.exec gekapselt ist)
        if (typeof window.mmrl !== 'undefined' && typeof window.mmrl.exec !== 'undefined') {
            const res = await window.mmrl.exec(cmd);
            return res.stdout || res.stderr || "";
        }

        throw new Error("Keine MMRL Root-Bridge gefunden!");
    } catch (e) {
        debugLog(`Shell Error: ${e.message}`);
        
        // Letzter Rettungsanker: Zeige uns, was MMRL wirklich geladen hat
        const available = Object.keys(window).filter(k => k === 'os' || k === 'mmrl' || k === 'su');
        debugLog("Gefundene APIs im Fenster: " + (available.length > 0 ? available.join(', ') : "KEINE"));
        return "";
    }
}

async function loadAll() {
    document.getElementById('wakelock-list').innerHTML = ''; 
    debugLog("Starte Magisk-Kernel-Abfrage via MMRL...");
    
    try {
        const statsPath = "/data/adb/chimera/logs/chimera_stats.md";
        const confPath = "/data/adb/chimera/blocklist.conf";

        // Befehle einzeln ausführen für sauberes Fehler-Tracking
        const rawStats = await run(`cat ${statsPath}`);
        const rawConf = await run(`cat ${confPath}`);
        
        // Wenn der cat-Befehl fehlschlägt und nichts zurückgibt, abbrechen
        if (!rawStats && !rawConf) return; 

        updateProfileView(rawConf);
        updateStatsView(rawStats, rawConf);
    } catch (e) {
        debugLog(`CRASH: ${e.message}`);
    }
}

function updateProfileView(data) {
    let activeCount = 0;
    if (data && !data.includes("No such file")) {
        const lines = data.split('\n').map(l => l.trim()).filter(l => l.length > 2 && !l.startsWith('# ---'));
        lines.forEach(line => {
            if (!line.startsWith('#')) activeCount++;
        });
    }
    document.getElementById('stat-active-profile').innerText = activeCount;
    // Alte Profile-Liste ausblenden (wird jetzt in den Cards angezeigt)
    document.getElementById('blocklist-content').innerHTML = '<p style="color: #555;">(Liste wird unten im Dashboard verwaltet)</p>';
}

function updateStatsView(stats, conf) {
    const container = document.getElementById('wakelock-list');
    if (!stats || stats.includes("No such file")) {
        debugLog("Keine Stats gefunden. Ist der Bildschirm mal aus gewesen?");
        return;
    }

    const activeList = conf ? conf.split('\n').filter(l => l.trim() && !l.startsWith('#')).map(l => l.trim().toLowerCase()) : [];

    let wakelocks = [];
    let totalBlocked = 0;
    const lines = stats.split('\n');

    lines.forEach(line => {
        // Filtere Markdown-Trenner und leere Zeilen
        if (line.includes('|') && !line.includes('Name') && !line.includes(':---')) {
            const p = line.split('|').map(x => x.trim());
            if (p.length >= 4 && p[1]) {
                const name = p[1];
                const blocked = parseInt(p[2].replace(/\*/g, '')) || 0;
                const allowed = parseInt(p[3]) || 0;
                totalBlocked += blocked;
                wakelocks.push({ name, blocked, allowed, total: blocked + allowed });
            }
        }
    });

    document.getElementById('stat-total-blocked').innerText = totalBlocked;
    wakelocks.sort((a,b) => b.total - a.total);
    
    container.innerHTML = '';

    if (wakelocks.length === 0) {
        container.innerHTML = '<p style="text-align:center; color:#555;">Warte auf Wakelock-Aktivität vom Kernel...</p>';
        return;
    }

    // --- MAGISK/MMRL CARD RENDERER ---
    wakelocks.forEach(wl => {
        const isBlocked = activeList.includes(wl.name.toLowerCase());
        const item = document.createElement('div');
        
        item.style.cssText = "background: #111; border: 1px solid #333; border-radius: 12px; padding: 14px; margin-bottom: 12px; display: flex; flex-direction: column; gap: 10px;";

        const blockedColor = wl.blocked > 0 ? 'var(--red)' : '#888';
        const statusColor = isBlocked ? 'var(--red)' : 'var(--green)';
        const statusText = isBlocked ? 'BLOCKED' : 'ALLOWED';

        item.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div style="font-family: monospace; font-size: 1.05rem; font-weight: bold; color: var(--text);">
                    ${wl.name}
                </div>
                <div style="font-size: 0.75rem; font-weight: bold; padding: 3px 8px; border-radius: 6px; background: #222; color: ${statusColor}; border: 1px solid ${statusColor};">
                    ${statusText}
                </div>
            </div>
            <div style="font-size: 0.8rem; color: #888; display: flex; gap: 15px;">
                <span>Fires: <b style="color:#ccc">${wl.total}</b></span>
                <span style="color: ${blockedColor}">Blocked: <b>${wl.blocked}</b></span>
                <span>Allowed: <b style="color:#ccc">${wl.allowed}</b></span>
            </div>
            <div class="wl-actions" style="display: flex; gap: 8px; margin-top: 5px;"></div>
        `;

        const actionsDiv = item.querySelector('.wl-actions');

        const btnSearch = document.createElement('button');
        btnSearch.style.cssText = "background: #222; color: white; border: 1px solid #444; flex: 1; padding: 8px; border-radius: 8px;";
        btnSearch.innerText = '🔍 Info';
        btnSearch.addEventListener('click', () => window.open(`https://www.google.com/search?q=android+wakelock+"${encodeURIComponent(wl.name)}"`, '_blank'));
        actionsDiv.appendChild(btnSearch);

        const btnToggle = document.createElement('button');
        btnToggle.style.cssText = `background: ${isBlocked ? 'var(--green)' : 'var(--red)'}; color: ${isBlocked ? '#000' : '#fff'}; border: none; flex: 1; padding: 8px; border-radius: 8px;`;
        btnToggle.innerText = isBlocked ? 'Allow' : 'Block';
        btnToggle.addEventListener('click', () => toggleWL(wl.name, !isBlocked));
        actionsDiv.appendChild(btnToggle);

        const btnDelete = document.createElement('button');
        btnDelete.style.cssText = "background: transparent; color: #888; border: 1px solid #444; width: 40px; padding: 8px; border-radius: 8px;";
        btnDelete.innerText = '✖';
        btnDelete.addEventListener('click', () => deleteWL(wl.name));
        actionsDiv.appendChild(btnDelete);

        container.appendChild(item);
    });
}

// Löscht einen Eintrag hart aus der Config
async function deleteWL(name) {
    const file = "/data/adb/chimera/blocklist.conf";
    const cmd = `grep -vi "^[[:space:]]*#*[[:space:]]*${name}$" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"\n pkill -HUP -f chimera_controller.sh`;
    await run(cmd);
    loadAll();
}

async function toggleWL(name, block) {
    const file = "/data/adb/chimera/blocklist.conf";
    let cmd = `grep -vi "^[[:space:]]*#*[[:space:]]*${name}$" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"\n`;
    if (block) cmd += `echo "${name}" >> "${file}"\n`;
    else cmd += `echo "# ${name}" >> "${file}"\n`;
    cmd += `pkill -HUP -f chimera_controller.sh`;
    
    await run(cmd);
    loadAll();
}

async function toggleChimera(on) {
    await run(`setprop persist.chimera.enable ${on}`);
    alert(on ? "Chimera ARMED! 🐉" : "Chimera DISARMED! 💤");
}

async function addCustom() {
    const input = document.getElementById('custom-wl-input');
    const name = input.value.trim();
    if (name.length > 2) {
        await toggleWL(name, true);
        input.value = '';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('btn-enable').addEventListener('click', () => toggleChimera(1));
    document.getElementById('btn-disable').addEventListener('click', () => toggleChimera(0));
    document.getElementById('btn-refresh').addEventListener('click', () => loadAll());
    document.getElementById('btn-add-custom').addEventListener('click', () => addCustom());
    
    loadAll();
});
