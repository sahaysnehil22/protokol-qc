-- Protokol QC: Production Database Schema
-- Multi-company B2B SaaS for Peruvian Real-Estate & Construction

PRAGMA foreign_keys = ON;

-- 1. SaaS Plans & Quotas
CREATE TABLE IF NOT EXISTS plans (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    price_pen REAL NOT NULL,
    max_projects INTEGER NOT NULL,
    max_users INTEGER NOT NULL,
    features_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 2. Companies (Tenants)
CREATE TABLE IF NOT EXISTS companies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    ruc TEXT UNIQUE,
    logo_url TEXT,
    brand_color TEXT NOT NULL DEFAULT '#E65100',
    plan_id TEXT REFERENCES plans(id),
    status TEXT NOT NULL DEFAULT 'active', -- active, trial, suspended
    trial_ends_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 3. Users & RBAC
-- Roles: admin, residente, calidad, contratista, cliente_ito
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL CHECK(role IN ('admin', 'residente', 'calidad', 'contratista', 'cliente_ito')),
    trade_specialty TEXT, -- e.g., 'Estructuras', 'Albañilería', 'Instalaciones Sanitarias'
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 4. Projects (Obras)
CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    district TEXT,
    city TEXT DEFAULT 'Lima',
    resident_name TEXT,
    ito_name TEXT,
    status TEXT NOT NULL DEFAULT 'activo', -- activo, pausado, entregado
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(company_id, code)
);

-- 5. Location Tree Hierarchy (Torre -> Piso -> Unidad/Ambiente)
CREATE TABLE IF NOT EXISTS locations (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_id TEXT REFERENCES locations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('torre', 'bloque', 'sotano', 'piso', 'departamento', 'area_comun', 'elemento')),
    code TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 6. Protocol Templates & Quality Checkpoints
CREATE TABLE IF NOT EXISTS templates (
    id TEXT PRIMARY KEY,
    company_id TEXT REFERENCES companies(id) ON DELETE CASCADE, -- NULL means global standard template
    family TEXT NOT NULL CHECK(family IN ('concreto', 'acero', 'encofrado', 'topografia', 'acabados', 'recepcion', 'seguridad_itse')),
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    version INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    schema_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(company_id, code, version)
);

CREATE TABLE IF NOT EXISTS template_items (
    id TEXT PRIMARY KEY,
    template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    section TEXT NOT NULL,
    order_index INTEGER NOT NULL DEFAULT 0,
    code TEXT NOT NULL,
    question_text TEXT NOT NULL,
    item_type TEXT NOT NULL CHECK(item_type IN ('conforme_no_conforme', 'numeric_tolerance', 'photo_required', 'text_observation')),
    tolerance_min REAL,
    tolerance_max REAL,
    unit TEXT,
    is_critical INTEGER NOT NULL DEFAULT 0, -- If fails, blocks pour/liberación
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 7. Inspections (Protocolos en Obra)
CREATE TABLE IF NOT EXISTS inspections (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    location_id TEXT NOT NULL REFERENCES locations(id),
    template_id TEXT NOT NULL REFERENCES templates(id),
    template_version INTEGER NOT NULL DEFAULT 1,
    inspector_id TEXT NOT NULL REFERENCES users(id),
    code TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('borrador', 'en_revision', 'conforme', 'observado', 'cerrado')) DEFAULT 'borrador',
    pour_date TEXT,
    batch_number TEXT,
    weather TEXT,
    general_notes TEXT,
    pdf_url TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    synced_at TEXT
);

CREATE TABLE IF NOT EXISTS inspection_answers (
    id TEXT PRIMARY KEY,
    inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES template_items(id),
    status TEXT NOT NULL CHECK(status IN ('conforme', 'no_conforme', 'no_aplica', 'pendiente')) DEFAULT 'pendiente',
    numeric_value REAL,
    observation_text TEXT,
    photo_urls_json TEXT DEFAULT '[]',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(inspection_id, item_id)
);

-- 8. Hallazgos (Defects / Non-Conformities Workflow)
CREATE TABLE IF NOT EXISTS findings (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    inspection_id TEXT REFERENCES inspections(id) ON DELETE SET NULL,
    answer_id TEXT REFERENCES inspection_answers(id) ON DELETE SET NULL,
    location_id TEXT NOT NULL REFERENCES locations(id),
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    severity TEXT NOT NULL CHECK(severity IN ('leve', 'moderado', 'critico')) DEFAULT 'moderado',
    status TEXT NOT NULL CHECK(status IN ('abierto', 'en_proceso', 'cerrado_con_evidencia', 'verificado')) DEFAULT 'abierto',
    assigned_contractor_id TEXT REFERENCES users(id),
    assigned_trade TEXT NOT NULL,
    due_date TEXT NOT NULL,
    initial_photo_url TEXT,
    resolution_photo_url TEXT,
    resolution_notes TEXT,
    resolved_at TEXT,
    verified_by_id TEXT REFERENCES users(id),
    verified_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 9. Digital Signatures (Actas de Recepción / Liberaciones)
CREATE TABLE IF NOT EXISTS signatures (
    id TEXT PRIMARY KEY,
    inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
    signer_id TEXT NOT NULL REFERENCES users(id),
    signer_name TEXT NOT NULL,
    signer_role TEXT NOT NULL,
    signature_data TEXT NOT NULL, -- SVG path or base64 representation
    signed_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 10. Modular Block-Based PDF Templates
CREATE TABLE IF NOT EXISTS pdf_templates (
    id TEXT PRIMARY KEY,
    company_id TEXT REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    blocks_json TEXT NOT NULL DEFAULT '[]',
    is_default INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 11. Tamper-Evident Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id TEXT REFERENCES users(id),
    action TEXT NOT NULL, -- e.g., 'INSPECTION_CREATED', 'FINDING_RESOLVED', 'SIGNATURE_CAPTURED'
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    payload_before_json TEXT,
    payload_after_json TEXT,
    ip_address TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 12. Client Offline Sync Operation Queue Ledger
CREATE TABLE IF NOT EXISTS sync_operations (
    id TEXT PRIMARY KEY,
    client_op_id TEXT UNIQUE NOT NULL,
    client_device_id TEXT NOT NULL,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id),
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL CHECK(operation IN ('CREATE', 'UPDATE', 'DELETE')),
    payload_json TEXT NOT NULL,
    client_timestamp TEXT NOT NULL,
    server_timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    status TEXT NOT NULL DEFAULT 'applied'
);

-- Create Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_company ON users(company_id);
CREATE INDEX IF NOT EXISTS idx_projects_company ON projects(company_id);
CREATE INDEX IF NOT EXISTS idx_locations_project ON locations(project_id);
CREATE INDEX IF NOT EXISTS idx_locations_parent ON locations(parent_id);
CREATE INDEX IF NOT EXISTS idx_inspections_project ON inspections(project_id);
CREATE INDEX IF NOT EXISTS idx_inspections_status ON inspections(status);
CREATE INDEX IF NOT EXISTS idx_findings_project ON findings(project_id);
CREATE INDEX IF NOT EXISTS idx_findings_contractor ON findings(assigned_contractor_id);
CREATE INDEX IF NOT EXISTS idx_findings_status ON findings(status);
CREATE INDEX IF NOT EXISTS idx_audit_company ON audit_logs(company_id);
CREATE INDEX IF NOT EXISTS idx_sync_company ON sync_operations(company_id);
