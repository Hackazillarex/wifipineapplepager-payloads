function createModal(id, title, contentHTML, showRefresh = false) {
    if (document.getElementById(id)) return;
    const style = document.createElement("style");
    style.textContent = `
        .modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 9999; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(2px); }
        .modal { background: #1e1e1e; color: #fff; border-radius: 10px; width: 480px; max-width: 95%; padding: 20px; box-shadow: 0 10px 40px rgba(0,0,0,.6); font-family: sans-serif; position: relative; z-index: 10000; display: flex; flex-direction: column; max-height: 90vh; }
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .modal h2 { margin: 0; font-size: 20px; color: #fff; font-weight: 600; }
        .modal-hr { border: 0; height: 1px; background: #333; margin: 0 0 18px 0; }
        .modal-content { overflow-y: auto; flex: 1; padding-right: 5px; }
        .modal-content::-webkit-scrollbar { width: 6px; }
        .modal-content::-webkit-scrollbar-thumb { background: #444; border-radius: 10px; }
        .modal .modal-close, .modal .modal-reset, .btn-apply, .btn-unapply, .btn-color-reset { 
            margin-top: 8px; width: 100%; padding: 10px; border-radius: 6px; border: none; cursor: pointer; 
            font-weight: 600; font-size: 14px; transition: transform 0.1s, background 0.2s, filter 0.2s; 
        }
        .modal .modal-close { background: #ff5252; color: #fff; flex-shrink: 0; }
        .btn-update-info { 
            background: #007acc; color: #fff; border: none; padding: 8px 16px; border-radius: 4px; 
            cursor: pointer; font-size: 13px; font-weight: 600; transition: transform 0.1s, filter 0.2s; 
        }
        .btn-update-info:active, .btn-apply:active, .btn-unapply:active { transform: scale(0.92); filter: brightness(1.2); }
        .sys-info-box { background: #2b2b2b; padding: 15px; border-radius: 6px; margin-bottom: 12px; border-left: 4px solid #444; }
        .sys-info-label { color: #aaa; font-size: 12px; text-transform: uppercase; font-weight: bold; margin-bottom: 6px; letter-spacing: 0.5px; }
        .sys-info-value { color: #00ffaa; font-family: monospace; font-size: 15px; font-weight: 500; }
        .sys-table { width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 8px; }
        .sys-table th { text-align: left; color: #888; padding-bottom: 8px; text-transform: uppercase; font-size: 10px; letter-spacing: 1px; }
        .sys-table td { padding: 10px 4px; border-bottom: 1px solid #333; white-space: nowrap; }
        .sys-dev { font-weight: bold; color: #eee; }
        .sys-total { color: #00ffaa; text-align: center; }
        .sys-used { color: #ffae42; text-align: center; }
        .sys-avail { color: #00ffaa; text-align: right; }
        .modal-links { display: flex; flex-direction: column; gap: 8px; }
        .modal-links .lib-item { display: flex; align-items: center; padding: 12px; border-radius: 6px; background: #2b2b2b; color: #fff; gap: 10px; cursor: pointer; transition: background 0.2s; }
        .modal-links .lib-item:hover { background: #383838; }
        .btn-apply { background: #007acc; color: #fff; width: auto; padding: 6px 14px; font-size: 13px; min-width: 80px; margin-top: 0 !important; }
        .btn-unapply { background: #ff5252; color: #fff; width: auto; padding: 6px 14px; font-size: 13px; min-width: 80px; margin-top: 0 !important; }
        .btn-color-reset { background: #555; color: #fff; width: auto; padding: 6px 12px; font-size: 12px; margin-top: 0; }
        .modal-reset { background: #444; color: white; width: 100%; }
        input[type="color"] { -webkit-appearance: none; width: 60px; height: 38px; border: none; padding: 0; background: none; cursor: pointer; }
        input[type="color"]::-webkit-color-swatch { border: 1px solid #333; border-radius: 6px; }
    `;
    document.head.appendChild(style);
    const overlay = document.createElement("div");
    overlay.className = "modal-overlay";
    overlay.id = id;
    overlay.style.display = "none";
    overlay.innerHTML = `
        <div class="modal" onclick="event.stopPropagation()">
            <div class="modal-header">
                <h2>${title}</h2>
                ${showRefresh ? `<button class="btn-update-info" id="${id}Update">Update</button>` : ''}
            </div>
            <hr class="modal-hr">
            <div class="modal-content">${contentHTML}</div>
            <button class="modal-close">Close</button>
        </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector(".modal-close").onclick = () => overlay.style.display = "none";
    overlay.onclick = (e) => { if (e.target === overlay) overlay.style.display = "none"; };
}

function showModal(id) {
    const overlay = document.getElementById(id);
    if (overlay) overlay.style.display = "flex";
}

async function sendServerRequest(action, data, returnJson = false, authenticated = true) {
    const url = new URL(`http://${window.location.hostname}:4040/cgi-bin/api.sh`);
    url.searchParams.set("action", action);
    if (authenticated) {
        const serverid = localStorage.getItem("serverid");
        if (!serverid) return;
        const cookieName = `AUTH_${serverid}`;
        const cookieValue = document.cookie.split("; ").find(c => c.startsWith(cookieName + "="));
        if (!cookieValue) return;
        url.searchParams.set("token", cookieValue.substring(cookieName.length + 1));
        url.searchParams.set("serverid", serverid);
    }
    const options = { method: action === "setconfig" ? "POST" : "GET" };
    if (action === "setconfig") options.body = data;
    else if (data) url.searchParams.set("data", data);
    try {
        const r = await fetch(url.toString(), options);
        return returnJson ? await r.json() : r;
    } catch(e) { console.error(e); }
}

async function getFullConfig() {
    const res = await sendServerRequest("listconfig", undefined, true, false);
    return res?.config || {};
}

async function saveFullConfig(newData) {
    const current = await getFullConfig();
    const merged = { ...current, ...newData };
    return await sendServerRequest("setconfig", JSON.stringify(merged), false, true);
}

function applyTheme(value, isColorOnly = false) {
    if (!value) return;
    let styleTag = document.getElementById("dynamic-skinner-css");
    if (!styleTag) {
        styleTag = document.createElement("style");
        styleTag.id = "dynamic-skinner-css";
        document.head.appendChild(styleTag);
    }
    const isImage = !isColorOnly && (value.startsWith("data:") || value.startsWith("http"));
    const cssRule = isImage 
        ? `background-image: url("${value}") !important; background-size: cover !important; background-position: center !important; background-repeat: no-repeat !important; background-attachment: fixed !important;` 
        : `background-color: ${value} !important; background-image: none !important;`;
    styleTag.textContent = `body, #sidebarnav, #sidebarbutton, #sidebarbutton.toggle { ${cssRule} }`;
}

async function updateSystemData() {
    const container = document.getElementById("systemInfoContent");
    const res = await sendServerRequest("systeminfo", undefined, true, true);
    if (res?.status === "ok") {
        const diskLines = res.data.disk.split(',').map(d => {
            const parts = d.trim().split(/\s+/);
            if (parts.length < 4) return "";
            return `<tr><td class="sys-dev">${parts[0]}</td><td class="sys-total">${parts[1]}</td><td class="sys-used">${parts[2]}</td><td class="sys-avail">${parts[3]}</td></tr>`;
        }).join('');
        container.innerHTML = `
            <div class="sys-info-box"><div class="sys-info-label">CPU Load</div><div class="sys-info-value">${res.data.cpu_load}</div></div>
            <div class="sys-info-box"><div class="sys-info-label">Memory</div><div class="sys-info-value">${res.data.memory}</div></div>
            <div class="sys-info-box"><div class="sys-info-label">Disk Usage</div>
            <table class="sys-table"><thead><tr><th>Mount</th><th style="text-align:center">Size</th><th style="text-align:center">Used</th><th style="text-align:right">Available</th></tr></thead>
            <tbody>${diskLines}</tbody></table></div>`;
    }
}

function initSystemInfo() {
    createModal("systemInfoModal", "System Information", '<div id="systemInfoContent">Fetching data...</div>', true);
    document.getElementById("systemInfoModalUpdate").onclick = updateSystemData;
    const ul = document.querySelector("#sidebarnav ul");
    if (!ul || document.getElementById("systemInfoBtn")) return;
    const li = document.createElement("li");
    li.innerHTML = `<a href="#" id="systemInfoBtn"><i class="material-icons">info</i><div class="sidebarsub">System Info<div class="sidebarmini">View your systems information.</div></div></a>`;
    ul.appendChild(li);
    document.getElementById("systemInfoBtn").onclick = (e) => { e.preventDefault(); showModal("systemInfoModal"); updateSystemData(); };
}

function initLootUI() {
    createModal("lootModal", "Download Specific Loot", '<div class="modal-links"></div>');
    const ul = document.querySelector("#sidebarnav ul");
    if (!ul || document.getElementById("lootSidebarBtn")) return;
    const li = document.createElement("li");
    li.innerHTML = `<a href="#" id="lootSidebarBtn"><i class="material-icons">download</i><div class="sidebarsub">Download Specific Loot<div class="sidebarmini">Download a specific loot folder from /root/loot</div></div></a>`;
    ul.appendChild(li);
    document.getElementById("lootSidebarBtn").onclick = async e => {
        e.preventDefault();
        showModal("lootModal");
        const container = document.querySelector("#lootModal .modal-links");
        container.innerHTML = 'Fetching loot...';
        const res = await sendServerRequest("command", "ls /root/loot/ | tr '\\n' ','", true);
        if (res?.status === "done") {
            const list = res.output.trim().split(",").filter(Boolean);
            container.innerHTML = "";
            list.forEach(dir => {
                const a = document.createElement("div");
                a.className = "lib-item"; 
                a.innerHTML = `<i class="material-icons">folder</i> <span>${dir.trim()}</span>`;
                a.onclick = () => window.location.href = `/api/files/zip/root/loot/${dir.trim()}`;
                container.appendChild(a);
            });
        }
    };
}

function initPagerSkinner() {
    const defaultHex = "#303030";
    const MAX_FILE_SIZE = 500 * 1024;
    const contentHTML = `
        <h3 style="margin: 0 0 8px 0; font-size:14px; color:#ddd;">Background Color</h3>
        <div style="display:flex; align-items:center; gap:10px; margin-bottom:10px;"><input type="color" id="backgroundColorPicker" value="${defaultHex}"><button id="btnResetDefault" class="btn-color-reset">Reset to Default</button></div>
        <hr class="modal-hr"><h3 style="margin: 0 0 8px 0; font-size:14px; color:#ddd;">Upload Image <span style="font-size:11px; color:#888;">(Max 500KB)</span></h3>
        <input type="text" id="imgName" placeholder="Name" style="width:100%; box-sizing:border-box; padding:8px; border-radius:4px; border:1px solid #333; background:#2b2b2b; color:#fff; margin-bottom:10px;">
        <input type="file" id="imgFile" accept="image/*" style="width:100%; color:#aaa; font-size:12px; margin-bottom:10px;">
        <button id="btnUpload" class="modal-reset">Add to Library</button>
        <h3 style="margin: 15px 0 8px 0; font-size:14px; color:#ddd;">Background Library</h3><div id="libraryList" class="modal-links"></div>`;

    const renderLibrary = (config, overlay) => {
        const listContainer = overlay.querySelector("#libraryList");
        const backgrounds = config.savedBackgrounds || [];
        const currentActiveName = config.appliedBackgroundName || "";
        listContainer.innerHTML = backgrounds.length ? "" : "No images saved.";
        backgrounds.forEach((bg, index) => {
            const isApplied = (currentActiveName === bg.name);
            const div = document.createElement("div");
            div.className = "lib-item";
            div.innerHTML = `<i class="material-icons">image</i><span style="flex:1;">${bg.name}</span><button class="${isApplied ? 'btn-unapply' : 'btn-apply'}">${isApplied ? 'Unapply' : 'Apply'}</button><i class="material-icons delete-btn" style="color:#ff5252;">delete</i>`;
            div.querySelector(isApplied ? ".btn-unapply" : ".btn-apply").onclick = async (e) => {
                e.stopPropagation();
                if (isApplied) { await saveFullConfig({ appliedBackgroundName: "" }); applyTheme(config.backgroundHex || defaultHex, true); }
                else { await saveFullConfig({ appliedBackgroundName: bg.name }); applyTheme(bg.url); }
                renderLibrary(await getFullConfig(), overlay);
            };
            div.querySelector(".delete-btn").onclick = async (e) => {
                e.stopPropagation();
                if(!confirm(`Delete "${bg.name}"?`)) return;
                backgrounds.splice(index, 1);
                const update = { savedBackgrounds: backgrounds };
                if (currentActiveName === bg.name) { update.appliedBackgroundName = ""; applyTheme(config.backgroundHex || defaultHex, true); }
                await saveFullConfig(update);
                renderLibrary(await getFullConfig(), overlay);
            };
            listContainer.appendChild(div);
        });
    };

    createModal("pagerSkinnerModal", "Pager Skinner Settings", contentHTML);
    const overlay = document.getElementById("pagerSkinnerModal");
    const picker = overlay.querySelector("#backgroundColorPicker");

    overlay.querySelector("#btnUpload").onclick = async () => {
        const n = overlay.querySelector("#imgName"), f = overlay.querySelector("#imgFile"), file = f.files[0];
        if (!n.value || !file) return alert("Missing name or file.");
        if (file.size > MAX_FILE_SIZE) { alert(`File too large (${(file.size / 1024).toFixed(1)}KB). Please keep images under 500KB.`); f.value = ""; return; }
        const r = new FileReader();
        r.onload = async (e) => {
            const config = await getFullConfig();
            const bgs = config.savedBackgrounds || [];
            bgs.push({ name: n.value, url: e.target.result });
            await saveFullConfig({ savedBackgrounds: bgs });
            n.value = ""; f.value = "";
            renderLibrary(await getFullConfig(), overlay);
        };
        r.readAsDataURL(file);
    };

    picker.oninput = (e) => applyTheme(e.target.value, true);
    picker.onchange = async (e) => { await saveFullConfig({ backgroundHex: e.target.value, appliedBackgroundName: "" }); renderLibrary(await getFullConfig(), overlay); };
    overlay.querySelector("#btnResetDefault").onclick = async () => { await saveFullConfig({ backgroundHex: defaultHex, appliedBackgroundName: "" }); applyTheme(defaultHex, true); picker.value = defaultHex; renderLibrary(await getFullConfig(), overlay); };

    const ul = document.querySelector("#sidebarnav ul");
    if (!ul || document.getElementById("pagerSkinnerBtn")) return;
    const li = document.createElement("li");
    li.innerHTML = `<a href="#" id="pagerSkinnerBtn"><i class="material-icons">color_lens</i><div class="sidebarsub">Pager Skinner<div class="sidebarmini">Skin your pager</div></div></a>`;
    ul.appendChild(li);
    document.getElementById("pagerSkinnerBtn").onclick = async (e) => { 
        e.preventDefault(); 
        showModal("pagerSkinnerModal"); 
        const config = await getFullConfig(); 
        if (config.backgroundHex) picker.value = config.backgroundHex;
        renderLibrary(config, overlay); 
    };
}

async function loadConfigAndApply() {
    const config = await getFullConfig();
    if (config.appliedBackgroundName) {
        const activeObj = (config.savedBackgrounds || []).find(b => b.name === config.appliedBackgroundName);
        if (activeObj) { applyTheme(activeObj.url); return; }
    }
    applyTheme(config.backgroundHex || "#303030", true);
}

function startInitialization() {
    const init = () => { initLootUI(); initPagerSkinner(); initSystemInfo(); fetch("/api/api_ping").then(res => res.json()).then(data => { if (data.serverid) localStorage.setItem("serverid", data.serverid); }).catch(()=>{}); };
    if (document.getElementById("sidebarnav")) init();
    else { const observer = new MutationObserver(() => { if (document.getElementById("sidebarnav")) { init(); observer.disconnect(); } }); observer.observe(document.documentElement, { childList: true, subtree: true }); }
}

loadConfigAndApply();
startInitialization();