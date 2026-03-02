// --- ON-SCREEN DEBUGGER ---
function debugLog(msg) {
    const list = document.getElementById('wakelock-list');
    if (list) {
        list.innerHTML += `<p style="color: yellow; font-size: 11px; text-align: left; font-family: monospace; margin: 2px 0;">> ${msg}</p>`;
    }
}

async function run(cmd) {
    if (typeof window.ksu !== 'undefined') {
        try {
            const res = await window.ksu.exec(cmd);
            if (res.errno !== 0) debugLog(`KSU Err ${res.errno}: ${res.stderr}`);
            return res.stdout || res.stderr || "";
        } catch (e) {
            debugLog(`Exception: ${e.toString()}`);
            return e.toString();
        }
    }
    debugLog("FEHLER: window.ksu ist nicht definiert! Hat die UI Root-Rechte?");
    return ""; 
}

async function loadAll() {
    document.getElementById('wakelock-list').innerHTML = ''; 
    debugLog("Starte Kernel-Abfrage...");
    
    try {
        const statsPath = "/data/adb/chimera/logs/chimera_stats.md";
        const confPath = "/data/adb/chimera/blocklist.conf";

        const rawStats = await run(`cat ${statsPath}`);
        const rawConf = await run(`cat ${confPath}`);
        
        debugLog(`Dateien gelesen. Config: ${rawConf.length > 0 ? 'OK' : 'LEER'}`);

        updateProfileView(rawConf);
        updateStatsView(rawStats, rawConf);
    } catch (e) {
        debugLog(`CRASH: ${e.message}`);
    }
}

function updateProfileView(data) {
    const container = document.getElementById('blocklist-content');
    if (!data || data.includes("No such file")) {
        container.innerHTML = '<p style="color: var(--red);">Config not found yet.</p>';
        document.getElementById('stat-active-profile').innerText = "0";
        return;
    }
    
    container.innerHTML = '';
    let activeCount = 0;
    const lines = data.split('\n').map(l => l.trim()).filter(l => l.length > 2 && !l.startsWith('# ---'));
    
    lines.forEach(line => {
        const isOff = line.startsWith('#');
        const name = line.replace('#', '').trim();
        const span = document.createElement('span');
        
        if (!isOff) activeCount++;

        span.className = `tag ${isOff ? 'tag-off' : 'tag-active'}`;
        span.innerText = name;
        container.appendChild(span);
    });

    document.getElementById('stat-active-profile').innerText = activeCount;
}

function updateStatsView(stats, conf) {
    const container = document.getElementById('wakelock-list');
    if (!stats || stats.includes("No such file")) {
        debugLog("Keine Stats gefunden. Der Bildschirm muss erst ausgehen!");
        return;
    }

    const activeList = conf ? conf.split('\n').filter(l => l.trim() && !l.startsWith('#')).map(l => l.trim().toLowerCase()) : [];

    let wakelocks = [];
    let totalBlocked = 0;
    const lines = stats.split('\n');

    lines.forEach(line => {
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
    
    // Debugging ausblenden, wenn echte Daten kommen
    container.innerHTML = '';

    if (wakelocks.length === 0) {
        container.innerHTML = '<p style="text-align:center; color:#555;">Warte auf Wakelock-Aktivität...</p>';
        return;
    }

    wakelocks.forEach(wl => {
        const isBlocked = activeList.includes(wl.name.toLowerCase());
        const item = document.createElement('div');
        item.className = 'wl-item';
        const blockedClass = wl.blocked > 0 ? 'blocked-count' : '';

        item.innerHTML = `
            <div class="wl-info">
                <span class="status-badge ${isBlocked ? 'badge-blocked' : 'badge-allowed'}">${isBlocked ? 'BLOCKED' : 'ALLOWED'}</span><br>
                <span class="wl-name">${wl.name}</span>
                <div class="wl-sub">
                    Fires: <b>${wl.total}</b> | <span class="${blockedClass}">Blocked: ${wl.blocked}</span> | Allowed: ${wl.allowed}
                </div>
            </div>
            <div class="wl-actions"></div>
        `;

        const actionsDiv = item.querySelector('.wl-actions');

        const btnSearch = document.createElement('button');
        btnSearch.className = 'btn-small btn-search';
        btnSearch.innerText = '🔍';
        btnSearch.addEventListener('click', () => window.open(`https://www.google.com/search?q=android+wakelock+"${encodeURIComponent(wl.name)}"`, '_blank'));
        actionsDiv.appendChild(btnSearch);

        const btnToggle = document.createElement('button');
        btnToggle.className = `btn-small ${isBlocked ? 'btn-allow' : 'btn-block'}`;
        btnToggle.innerText = isBlocked ? 'Allow' : 'Block';
        btnToggle.addEventListener('click', () => toggleWL(wl.name, !isBlocked));
        actionsDiv.appendChild(btnToggle);

        container.appendChild(item);
    });
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

// Sichere Zuweisung, sobald alles geladen ist
document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('btn-enable').addEventListener('click', () => toggleChimera(1));
    document.getElementById('btn-disable').addEventListener('click', () => toggleChimera(0));
    document.getElementById('btn-refresh').addEventListener('click', () => loadAll());
    document.getElementById('btn-add-custom').addEventListener('click', () => addCustom());
    
    loadAll();
});
