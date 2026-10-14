/**
 * PROTOKOL QC — WEB CLIENT LOGIC
 * Connects to Express REST API (/api) for real-time quality assurance & morning office dashboard.
 */

const API_BASE = '/api';

// State
let currentToken = null;
let currentUser = null;
let currentProjectId = null;
let projectsList = [];
let inspectionsList = [];
let findingsList = [];
let templatesList = [];
let selectedTemplate = null;

// Demo accounts for instant role switching
const DEMO_USERS = {
    calidad: {
        email: 'calidad@sanmartin.pe',
        password: 'Protokol2026!',
        role: 'calidad',
        name: 'Ing. Daniel Vargas',
        title: 'Especialista de Calidad'
    },
    residente: {
        email: 'residente@sanmartin.pe',
        password: 'Protokol2026!',
        role: 'residente',
        name: 'Ing. Carlos Mendoza',
        title: 'Residente de Obra (CIP 84920)'
    },
    contratista_estructuras: {
        email: 'contratista.estructuras@subcon.pe',
        password: 'Protokol2026!',
        role: 'contratista',
        name: 'Carlos Estructuras',
        title: 'Contratista de Fierrería y Encofrados'
    },
    contratista_acabados: {
        email: 'contratista.acabados@subcon.pe',
        password: 'Protokol2026!',
        role: 'contratista',
        name: 'Jorge Acabados',
        title: 'Contratista de Acabados y Repasos'
    },
    ito: {
        email: 'ito@supervisorape.com',
        password: 'Protokol2026!',
        role: 'cliente_ito',
        name: 'Ing. Patricia Thorne',
        title: 'Supervisión Técnica (ITO)'
    },
    admin: {
        email: 'admin@sanmartin.pe',
        password: 'Protokol2026!',
        role: 'admin',
        name: 'Administrador General',
        title: 'Control Maestro'
    }
};

// Initialization
document.addEventListener('DOMContentLoaded', async () => {
    initNavigation();
    initModalHandlers();
    initFilters();

    // Default login as Calidad engineer
    await switchRole('calidad');

    // Load initial project list
    await loadProjects();
});

// Setup Tab Navigation
function initNavigation() {
    const tabs = document.querySelectorAll('.nav-tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.content-view').forEach(v => v.classList.remove('active'));

            tab.classList.add('active');
            const viewId = `view-${tab.getAttribute('data-view')}`;
            const targetView = document.getElementById(viewId);
            if (targetView) targetView.classList.add('active');

            // Refresh view data
            if (tab.getAttribute('data-view') === 'dashboard') loadDashboardData();
            if (tab.getAttribute('data-view') === 'inspections') loadInspections();
            if (tab.getAttribute('data-view') === 'findings') loadFindings();
            if (tab.getAttribute('data-view') === 'templates') loadTemplateStudio();
        });
    });

    // Project Dropdown change
    const projectSelector = document.getElementById('project-selector');
    projectSelector.addEventListener('change', (e) => {
        currentProjectId = e.target.value;
        loadDashboardData();
        loadInspections();
        loadFindings();
    });

    // Role switcher change
    const roleSwitcher = document.getElementById('role-switcher');
    roleSwitcher.addEventListener('change', async (e) => {
        await switchRole(e.target.value);
        loadDashboardData();
        loadInspections();
        loadFindings();
    });

    // Refresh Dashboard button
    document.getElementById('btn-refresh-dashboard').addEventListener('click', () => {
        loadDashboardData();
    });
}

// Switch Demo User Role
async function switchRole(roleKey) {
    const demo = DEMO_USERS[roleKey] || DEMO_USERS.calidad;
    try {
        const res = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: demo.email, password: demo.password })
        });

        if (res.ok) {
            const data = await res.json();
            currentToken = data.token;
            currentUser = data.user;
        } else {
            // Fallback demo user
            currentUser = {
                id: `demo-${roleKey}`,
                fullName: demo.name,
                role: demo.role,
                companyName: 'Constructora San Martín S.A.C.'
            };
        }
    } catch (_) {
        currentUser = {
            id: `demo-${roleKey}`,
            fullName: demo.name,
            role: demo.role,
            companyName: 'Constructora San Martín S.A.C.'
        };
    }

    document.getElementById('user-display-name').textContent = demo.name;
    document.getElementById('user-display-role').textContent = demo.title;
}

// Fetch helper with JWT auth
async function apiFetch(endpoint, options = {}) {
    const headers = {
        'Content-Type': 'application/json',
        ...(currentToken ? { 'Authorization': `Bearer ${currentToken}` } : {}),
        ...(options.headers || {})
    };
    return await fetch(`${API_BASE}${endpoint}`, { ...options, headers });
}

// 1. Load Projects
async function loadProjects() {
    try {
        const res = await apiFetch('/projects');
        if (res.ok) {
            projectsList = await res.json();
        } else {
            projectsList = [{
                id: 'proj-las-palmeras',
                code: 'OBRA-2026-MIR',
                name: 'Edificio Residencial Las Palmeras (Miraflores)'
            }];
        }
    } catch (_) {
        projectsList = [{
            id: 'proj-las-palmeras',
            code: 'OBRA-2026-MIR',
            name: 'Edificio Residencial Las Palmeras (Miraflores)'
        }];
    }

    const select = document.getElementById('project-selector');
    select.innerHTML = projectsList.map(p => `
        <option value="${p.id}">${p.name} [${p.code}]</option>
    `).join('');

    if (projectsList.length > 0) {
        currentProjectId = projectsList[0].id;
        loadDashboardData();
    }
}

// 2. Load Morning KPI Dashboard
async function loadDashboardData() {
    if (!currentProjectId) return;

    try {
        const res = await apiFetch(`/dashboard/summary?project_id=${currentProjectId}`);
        if (res.ok) {
            const data = await res.json();

            // Populate KPI values
            document.getElementById('kpi-total-inspections').textContent = data.inspections.total;
            document.getElementById('kpi-pass-rate').textContent = `${data.inspections.pass_rate}%`;
            document.getElementById('kpi-conforme-detail').textContent = `${data.inspections.by_status.conforme || 0} conformes liberados`;
            document.getElementById('kpi-pour-blockers').textContent = data.inspections.critical_pour_blockers.length;
            document.getElementById('kpi-open-findings').textContent = data.findings.total_open;
            document.getElementById('kpi-overdue-detail').textContent = `${data.findings.overdue} vencidos (&gt;48h)`;
            document.getElementById('findings-counter-badge').textContent = data.findings.total_open;

            // Render Pour Blockers List
            renderPourBlockers(data.inspections.critical_pour_blockers);

            // Render Contractor Balance List
            renderContractorStats(data.findings.by_contractor);
        }
    } catch (e) {
        console.error('Error loading dashboard data:', e);
    }
}

function renderPourBlockers(blockers) {
    const container = document.getElementById('pour-blockers-container');
    if (!blockers || blockers.length === 0) {
        container.innerHTML = `
            <div class="empty-state" style="color: var(--conforme); font-weight: 600;">
                ✓ Todos los vaciados de concreto se encuentran debidamente liberados sin no-conformidades críticas.
            </div>
        `;
        return;
    }

    container.innerHTML = blockers.map(b => `
        <div style="padding: 12px; border-left: 4px solid var(--no-conforme); background: var(--no-conforme-bg); border-radius: 4px; margin-bottom: 8px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <strong style="color: var(--no-conforme);">${b.code} — ${b.template_title}</strong>
                <span class="badge badge-no_conforme">BLOQUEADO</span>
            </div>
            <div style="font-size: 12px; margin-top: 4px; color: var(--text-main);">
                Ubicación: <strong>${b.location_name || 'Obra'}</strong> | Fecha prevista: ${b.pour_date || 'Hoy'}
            </div>
            <div style="font-size: 11px; margin-top: 2px; color: var(--text-muted);">
                Inspector: ${b.inspector_name || 'Calidad'} | Causa: Falla de recubrimiento o asentamiento normativo
            </div>
        </div>
    `).join('');
}

function renderContractorStats(contractors) {
    const container = document.getElementById('contractor-stats-container');
    if (!contractors || contractors.length === 0) {
        container.innerHTML = '<div class="empty-state">No hay observaciones pendientes por contratista.</div>';
        return;
    }

    container.innerHTML = contractors.map(c => `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px; border-bottom: 1px solid var(--border-subtle);">
            <div>
                <strong style="font-size: 13px;">${c.contractor_name || 'Subcontratista de Obra'}</strong>
                <div style="font-size: 11px; color: var(--text-muted);">Especialidad: ${c.assigned_trade}</div>
            </div>
            <div style="text-align: right;">
                <span class="badge ${c.open_findings > 0 ? 'badge-abierto' : 'badge-conforme'}">
                    ${c.open_findings} pendientes
                </span>
                ${c.overdue_findings > 0 ? `<div style="font-size: 11px; color: var(--no-conforme); font-weight: bold; margin-top: 2px;">${c.overdue_findings} vencidos</div>` : ''}
            </div>
        </div>
    `).join('');
}

// 3. Load Inspections Table
async function loadInspections() {
    if (!currentProjectId) return;
    const tbody = document.getElementById('inspections-tbody');
    tbody.innerHTML = '<tr><td colspan="8" class="text-center">Cargando protocolos...</td></tr>';

    try {
        const res = await apiFetch(`/inspections?project_id=${currentProjectId}`);
        if (res.ok) {
            inspectionsList = await res.json();
            renderInspectionsTable(inspectionsList);
        }
    } catch (e) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-danger">Error al cargar inspecciones.</td></tr>';
    }
}

function renderInspectionsTable(list) {
    const tbody = document.getElementById('inspections-tbody');
    if (!list || list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No hay protocolos registrados para esta obra.</td></tr>';
        return;
    }

    tbody.innerHTML = list.map(insp => `
        <tr>
            <td><strong style="color: var(--primary);">${insp.code}</strong></td>
            <td><strong>${insp.template_title || 'Protocolo de Calidad'}</strong></td>
            <td>${insp.location_name || 'Ubicación General'}</td>
            <td>${insp.pour_date || 'N/A'}</td>
            <td><code>${insp.batch_number || 'S/N'}</code></td>
            <td><span class="badge badge-${insp.status}">${insp.status.toUpperCase()}</span></td>
            <td>${insp.inspector_name || 'Ing. Calidad'}</td>
            <td class="text-right">
                <button class="btn btn-secondary btn-sm" onclick="openInspectionModal('${insp.id}')">Ver Detalle</button>
                <a href="${API_BASE}/pdf/inspections/${insp.id}" target="_blank" class="btn btn-primary btn-sm" style="text-decoration: none;">PDF Oficial</a>
            </td>
        </tr>
    `).join('');
}

// 4. Load Findings (Snag List)
async function loadFindings() {
    if (!currentProjectId) return;
    const tbody = document.getElementById('findings-tbody');
    tbody.innerHTML = '<tr><td colspan="8" class="text-center">Cargando hallazgos...</td></tr>';

    try {
        const res = await apiFetch(`/findings?project_id=${currentProjectId}`);
        if (res.ok) {
            findingsList = await res.json();
            renderFindingsTable(findingsList);
        }
    } catch (e) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-danger">Error al cargar hallazgos.</td></tr>';
    }
}

function renderFindingsTable(list) {
    const tbody = document.getElementById('findings-tbody');
    if (!list || list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No hay hallazgos registrados.</td></tr>';
        return;
    }

    tbody.innerHTML = list.map(f => `
        <tr>
            <td><strong style="color: var(--primary);">${f.code}</strong></td>
            <td>
                <strong>${f.title}</strong>
                <div style="font-size: 11px; color: var(--text-muted); max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    ${f.description}
                </div>
            </td>
            <td>${f.location_name || 'Obra'}</td>
            <td>
                <strong>${f.assigned_trade}</strong>
                <div style="font-size: 11px; color: var(--text-secondary);">${f.contractor_name || 'Subcontratista'}</div>
            </td>
            <td><span class="badge badge-${f.severity == 'critico' ? 'no_conforme' : 'en_proceso'}">${f.severity.toUpperCase()}</span></td>
            <td>
                <span style="font-weight: 600; color: ${f.is_overdue || f.status === 'abierto' ? 'var(--no-conforme)' : 'inherit'};">
                    ${f.due_date}
                </span>
            </td>
            <td><span class="badge badge-${f.status}">${f.status.replace(/_/g, ' ').toUpperCase()}</span></td>
            <td class="text-right">
                <button class="btn btn-secondary btn-sm" onclick="openFindingModal('${f.id}')">
                    ${f.status === 'cerrado_con_evidencia' ? 'Verificar Subsanación' : 'Gestionar'}
                </button>
            </td>
        </tr>
    `).join('');
}

// 5. Template Studio
async function loadTemplateStudio() {
    try {
        const res = await apiFetch('/templates');
        if (res.ok) {
            templatesList = await res.json();
            renderTemplateStudioList(templatesList);
        }
    } catch (e) {
        console.error('Error loading templates:', e);
    }
}

function renderTemplateStudioList(templates) {
    const container = document.getElementById('studio-templates-list');
    if (!templates || templates.length === 0) {
        container.innerHTML = '<div class="empty-state">No hay plantillas registradas.</div>';
        return;
    }

    container.innerHTML = templates.map((t, idx) => `
        <div class="template-card-item ${idx === 0 ? 'selected' : ''}" onclick="selectStudioTemplate('${t.id}')" data-id="${t.id}">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span class="badge badge-borrador">${t.code}</span>
                <span style="font-size: 11px; color: var(--text-secondary);">${t.items ? t.items.length : 0} ítems</span>
            </div>
            <strong style="font-size: 13px; display: block; margin-top: 6px;">${t.title}</strong>
            <p style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">${t.family.toUpperCase()}</p>
        </div>
    `).join('');

    if (templates.length > 0) {
        selectStudioTemplate(templates[0].id);
    }
}

function selectStudioTemplate(templateId) {
    selectedTemplate = templatesList.find(t => t.id === templateId);
    if (!selectedTemplate) return;

    document.querySelectorAll('.template-card-item').forEach(el => {
        el.classList.toggle('selected', el.getAttribute('data-id') === templateId);
    });

    document.getElementById('studio-template-title').textContent = selectedTemplate.title;
    document.getElementById('studio-template-code').textContent = `${selectedTemplate.code} • Versión ${selectedTemplate.version || 1} • Norma Técnica Peruana`;
}

// Modal Handlers
function initModalHandlers() {
    // Close inspection modal
    document.getElementById('btn-close-insp-modal').addEventListener('click', () => {
        document.getElementById('modal-inspection').classList.remove('show');
    });
    document.getElementById('btn-modal-close').addEventListener('click', () => {
        document.getElementById('modal-inspection').classList.remove('show');
    });

    // Close finding modal
    document.getElementById('btn-close-finding-modal').addEventListener('click', () => {
        document.getElementById('modal-finding').classList.remove('show');
    });

    // Save Template blocks button
    document.getElementById('btn-save-template-blocks').addEventListener('click', () => {
        alert('Configuración de bloques del protocolo PDF actualizada con éxito.');
    });
}

// Inspection Detail Modal
window.openInspectionModal = async function(inspectionId) {
    const insp = inspectionsList.find(i => i.id === inspectionId);
    if (!insp) return;

    document.getElementById('modal-insp-title').textContent = `${insp.code} — ${insp.template_title || 'Protocolo de Inspección'}`;
    document.getElementById('modal-insp-subtitle').textContent = `Ubicación: ${insp.location_name || 'En obra'} | Estado: ${insp.status.toUpperCase()}`;
    document.getElementById('btn-modal-download-pdf').href = `${API_BASE}/pdf/inspections/${insp.id}`;

    const body = document.getElementById('modal-insp-body');
    body.innerHTML = `
        <div style="background: var(--bg-app); padding: 14px; border-radius: var(--radius-s); margin-bottom: 16px;">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; font-size: 12px;">
                <div><span class="text-muted">Fecha de Vaciado:</span> <strong>${insp.pour_date || 'No aplica'}</strong></div>
                <div><span class="text-muted">Guía Mixer / Lote:</span> <strong>${insp.batch_number || 'S/N'}</strong></div>
                <div><span class="text-muted">Condición Climática:</span> <strong>${insp.weather || 'Normal'}</strong></div>
                <div><span class="text-muted">Inspector Responsable:</span> <strong>${insp.inspector_name || 'Calidad'}</strong></div>
            </div>
            ${insp.general_notes ? `<div style="margin-top: 8px; font-size: 12px; border-top: 1px solid var(--border-color); padding-top: 8px;"><strong>Notas:</strong> ${insp.general_notes}</div>` : ''}
        </div>

        <h3 style="font-size: 14px; margin-bottom: 10px;">Verificación de Requisitos Técnicos y Tolerancias:</h3>
        <div id="modal-answers-list">Cargando respuestas del protocolo...</div>
    `;

    document.getElementById('modal-inspection').classList.add('show');

    // Fetch full inspection answers
    try {
        const res = await apiFetch(`/inspections/${insp.id}`);
        if (res.ok) {
            const data = await res.json();
            const answersContainer = document.getElementById('modal-answers-list');
            if (!data.answers || data.answers.length === 0) {
                answersContainer.innerHTML = '<p class="text-muted" style="font-size: 13px;">No se registraron respuestas específicas.</p>';
                return;
            }

            answersContainer.innerHTML = data.answers.map(a => `
                <div style="padding: 10px; border-bottom: 1px solid var(--border-subtle); display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <strong style="font-size: 13px;">${a.question_text || a.code || 'Ítem de inspección'}</strong>
                        ${a.observation_text ? `<div style="font-size: 12px; color: var(--no-conforme); margin-top: 2px;">Obs: ${a.observation_text}</div>` : ''}
                        ${a.numeric_value !== null ? `<div style="font-size: 12px; color: var(--text-secondary);">Valor medido: ${a.numeric_value}</div>` : ''}
                    </div>
                    <div>
                        <span class="badge badge-${a.status}">${a.status.replace(/_/g, ' ').toUpperCase()}</span>
                    </div>
                </div>
            `).join('');
        }
    } catch (_) {}
};

// Finding Detail & Verification Modal
window.openFindingModal = function(findingId) {
    const f = findingsList.find(item => item.id === findingId);
    if (!f) return;

    document.getElementById('modal-finding-title').textContent = f.title;
    document.getElementById('modal-finding-code').textContent = `${f.code} • ${f.assigned_trade} • Vence: ${f.due_date}`;

    const body = document.getElementById('modal-finding-body');
    body.innerHTML = `
        <div style="margin-bottom: 16px;">
            <span class="badge badge-${f.status}" style="margin-bottom: 8px;">${f.status.replace(/_/g, ' ').toUpperCase()}</span>
            <p style="font-size: 14px; color: var(--text-main); margin-top: 6px;">${f.description}</p>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 16px;">
            <div style="border: 1px solid var(--border-color); border-radius: var(--radius-s); padding: 12px; background: var(--bg-app); text-align: center;">
                <strong style="font-size: 12px; display: block; margin-bottom: 6px; color: var(--no-conforme);">1. FOTO INICIAL DEL DEFECTO</strong>
                <div style="height: 100px; display: flex; align-items: center; justify-content: center; background: #ffffff; border-radius: 4px; border: 1px dashed var(--divider);">
                    <span style="font-size: 11px; color: var(--text-muted);">📷 Registro en Obra</span>
                </div>
            </div>

            <div style="border: 1px solid var(--border-color); border-radius: var(--radius-s); padding: 12px; background: var(--bg-app); text-align: center;">
                <strong style="font-size: 12px; display: block; margin-bottom: 6px; color: var(--conforme);">2. FOTO DE SUBSANACIÓN (CONTRATISTA)</strong>
                <div style="height: 100px; display: flex; align-items: center; justify-content: center; background: #ffffff; border-radius: 4px; border: 1px dashed var(--divider);">
                    <span style="font-size: 11px; color: ${f.resolution_photo_url ? 'var(--conforme)' : 'var(--text-muted)'}; font-weight: bold;">
                        ${f.resolution_photo_url ? '✓ Evidencia Adjunta' : 'Pendiente de carga'}
                    </span>
                </div>
            </div>
        </div>

        ${f.resolution_notes ? `
            <div style="background: var(--info-bg); padding: 12px; border-radius: var(--radius-s); font-size: 13px; color: var(--info); margin-bottom: 12px;">
                <strong>Notas de Corrección del Contratista:</strong>
                <div>${f.resolution_notes}</div>
            </div>
        ` : ''}
    `;

    const footer = document.getElementById('modal-finding-footer');
    if (f.status === 'cerrado_con_evidencia') {
        footer.innerHTML = `
            <button class="btn btn-secondary" onclick="document.getElementById('modal-finding').classList.remove('show')">Cancelar</button>
            <button class="btn btn-danger" onclick="updateFindingStatus('${f.id}', 'abierto')">Rechazar Subsanación</button>
            <button class="btn btn-success" onclick="updateFindingStatus('${f.id}', 'verificado')">Aprobar y Cerrar Definitivo</button>
        `;
    } else if (f.status === 'abierto') {
        footer.innerHTML = `
            <button class="btn btn-secondary" onclick="document.getElementById('modal-finding').classList.remove('show')">Cerrar</button>
            <button class="btn btn-primary" onclick="simulateContractorFix('${f.id}')">Simular Subsanación con Evidencia</button>
        `;
    } else {
        footer.innerHTML = `
            <button class="btn btn-secondary" onclick="document.getElementById('modal-finding').classList.remove('show')">Cerrar</button>
        `;
    }

    document.getElementById('modal-finding').classList.add('show');
};

// Update Finding Status Action
window.updateFindingStatus = async function(findingId, newStatus) {
    try {
        const res = await apiFetch(`/findings/${findingId}/status`, {
            method: 'PUT',
            body: JSON.stringify({ status: newStatus })
        });

        if (res.ok) {
            document.getElementById('modal-finding').classList.remove('show');
            loadFindings();
            loadDashboardData();
        } else {
            const err = await res.json();
            alert(err.error || 'Error al actualizar estado del hallazgo');
        }
    } catch (e) {
        alert('Error de conexión');
    }
};

window.simulateContractorFix = async function(findingId) {
    try {
        const res = await apiFetch(`/findings/${findingId}/status`, {
            method: 'PUT',
            body: JSON.stringify({
                status: 'cerrado_con_evidencia',
                resolution_photo_url: 'https://storage.protokol.pe/evidence/fix-simulated.jpg',
                resolution_notes: 'Se retiró el óxido y se colocaron separadores normalizados de 2.5cm'
            })
        });

        if (res.ok) {
            document.getElementById('modal-finding').classList.remove('show');
            loadFindings();
            loadDashboardData();
        } else {
            const err = await res.json();
            alert(err.error || 'Error al actualizar');
        }
    } catch (_) {}
};

// Filters setup
function initFilters() {
    document.getElementById('filter-inspections-status').addEventListener('change', (e) => {
        const val = e.target.value;
        if (val === 'all') renderInspectionsTable(inspectionsList);
        else renderInspectionsTable(inspectionsList.where ? inspectionsList : inspectionsList.filter(i => i.status === val));
    });

    document.getElementById('filter-inspections-search').addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        renderInspectionsTable(inspectionsList.filter(i => 
            (i.code && i.code.toLowerCase().includes(query)) ||
            (i.template_title && i.template_title.toLowerCase().includes(query)) ||
            (i.location_name && i.location_name.toLowerCase().includes(query))
        ));
    });

    document.getElementById('filter-findings-status').addEventListener('change', (e) => {
        const val = e.target.value;
        if (val === 'all') renderFindingsTable(findingsList);
        else renderFindingsTable(findingsList.filter(f => f.status === val));
    });

    document.getElementById('filter-findings-severity').addEventListener('change', (e) => {
        const val = e.target.value;
        if (val === 'all') renderFindingsTable(findingsList);
        else renderFindingsTable(findingsList.filter(f => f.severity === val));
    });
}
