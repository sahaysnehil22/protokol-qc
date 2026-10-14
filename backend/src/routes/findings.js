const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticate, logAudit } = require('../middleware/auth');

// GET /api/findings - List findings with contractor isolation
router.get('/', authenticate, (req, res) => {
    const { project_id, status, severity, contractor_id } = req.query;
    
    let query = `
        SELECT f.*,
               p.name as project_name, p.code as project_code,
               l.name as location_name, l.type as location_type,
               u_contr.full_name as contractor_name, u_contr.phone as contractor_phone,
               u_verif.full_name as verified_by_name,
               CASE 
                   WHEN f.status != 'verificado' AND date(f.due_date) < date('now') THEN 1 
                   ELSE 0 
               END as is_overdue,
               CAST((julianday(date('now')) - julianday(date(f.due_date))) AS INTEGER) as days_overdue
        FROM findings f
        JOIN projects p ON f.project_id = p.id
        JOIN locations l ON f.location_id = l.id
        LEFT JOIN users u_contr ON f.assigned_contractor_id = u_contr.id
        LEFT JOIN users u_verif ON f.verified_by_id = u_verif.id
        WHERE f.company_id = ?
    `;
    const params = [req.companyId];

    // CRITICAL RBAC ISOLATION: Contratistas only ever see their own assigned findings!
    if (req.user.role === 'contratista') {
        query += ' AND f.assigned_contractor_id = ?';
        params.push(req.user.id);
    } else if (contractor_id) {
        query += ' AND f.assigned_contractor_id = ?';
        params.push(contractor_id);
    }

    if (project_id) {
        query += ' AND f.project_id = ?';
        params.push(project_id);
    }
    if (status) {
        query += ' AND f.status = ?';
        params.push(status);
    }
    if (severity) {
        query += ' AND f.severity = ?';
        params.push(severity);
    }

    query += ' ORDER BY is_overdue DESC, f.due_date ASC, f.created_at DESC';

    const findings = db.prepare(query).all(...params);
    res.json({ findings });
});

// GET /api/findings/:id - Single finding details
router.get('/:id', authenticate, (req, res) => {
    let query = `
        SELECT f.*,
               p.name as project_name, p.code as project_code,
               l.name as location_name, l.type as location_type,
               u_contr.full_name as contractor_name,
               u_verif.full_name as verified_by_name
        FROM findings f
        JOIN projects p ON f.project_id = p.id
        JOIN locations l ON f.location_id = l.id
        LEFT JOIN users u_contr ON f.assigned_contractor_id = u_contr.id
        LEFT JOIN users u_verif ON f.verified_by_id = u_verif.id
        WHERE f.id = ? AND f.company_id = ?
    `;
    const params = [req.params.id, req.companyId];

    if (req.user.role === 'contratista') {
        query += ' AND f.assigned_contractor_id = ?';
        params.push(req.user.id);
    }

    const finding = db.prepare(query).get(...params);
    if (!finding) {
        return res.status(404).json({ error: 'Hallazgo no encontrado o sin permisos para visualizarlo.' });
    }

    res.json({ finding });
});

// POST /api/findings - Manual finding creation from site
router.post('/', authenticate, (req, res) => {
    if (req.user.role === 'contratista' || req.user.role === 'cliente_ito') {
        return res.status(403).json({ error: 'Solo supervisores, residentes o especialistas de calidad pueden levantar hallazgos.' });
    }

    const { project_id, location_id, title, description, severity, assigned_contractor_id, assigned_trade, due_date, initial_photo_url } = req.body;
    if (!project_id || !location_id || !title || !description || !due_date || !assigned_trade) {
        return res.status(400).json({ error: 'Faltan campos obligatorios para registrar la observación o hallazgo.' });
    }

    const findingId = uuidv4();
    const count = db.prepare('SELECT COUNT(*) as count FROM findings WHERE company_id = ?').get(req.companyId).count;
    const code = `HAL-${new Date().getFullYear()}-${String(count + 1).padStart(3, '0')}`;

    db.prepare(`
        INSERT INTO findings (
            id, company_id, project_id, location_id, code, title, description,
            severity, status, assigned_contractor_id, assigned_trade, due_date, initial_photo_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'abierto', ?, ?, ?, ?)
    `).run(
        findingId,
        req.companyId,
        project_id,
        location_id,
        code,
        title.trim(),
        description.trim(),
        severity || 'moderado',
        assigned_contractor_id || null,
        assigned_trade,
        due_date,
        initial_photo_url || null
    );

    logAudit(req.companyId, req.user.id, 'FINDING_CREATED', 'findings', findingId, null, { code, title }, req.ip);

    const created = db.prepare('SELECT * FROM findings WHERE id = ?').get(findingId);
    res.status(201).json({ finding: created });
});

// PUT /api/findings/:id/status - Status transitions & evidence closure
router.put('/:id/status', authenticate, (req, res) => {
    const { status, resolution_photo_url, resolution_notes } = req.body;
    const finding = db.prepare('SELECT * FROM findings WHERE id = ? AND company_id = ?').get(req.params.id, req.companyId);

    if (!finding) {
        return res.status(404).json({ error: 'Hallazgo no encontrado.' });
    }

    // Role-based state transition verification
    if (status === 'cerrado_con_evidencia') {
        // Contractor or QA is claiming closure -> MUST provide photo evidence and notes
        if (!resolution_photo_url || !resolution_notes) {
            return res.status(400).json({
                error: 'Para cerrar una observación se requiere evidencia fotográfica obligatoria y nota explicativa de subsanación.',
                code: 'EVIDENCE_REQUIRED'
            });
        }

        db.prepare(`
            UPDATE findings
            SET status = 'cerrado_con_evidencia', resolution_photo_url = ?, resolution_notes = ?,
                resolved_at = datetime('now'), updated_at = datetime('now')
            WHERE id = ?
        `).run(resolution_photo_url, resolution_notes, finding.id);

    } else if (status === 'verificado') {
        // Formal verification -> Only Calidad or Residente can certify closure!
        if (req.user.role === 'contratista') {
            return res.status(403).json({
                error: 'Un contratista no puede auto-verificar un hallazgo. Solo el Especialista de Calidad o Residente de Obra puede otorgar la conformidad final.',
                code: 'CANNOT_SELF_VERIFY'
            });
        }

        db.prepare(`
            UPDATE findings
            SET status = 'verificado', verified_by_id = ?, verified_at = datetime('now'), updated_at = datetime('now')
            WHERE id = ?
        `).run(req.user.id, finding.id);

    } else if (status === 'en_proceso' || status === 'abierto') {
        db.prepare(`
            UPDATE findings
            SET status = ?, updated_at = datetime('now')
            WHERE id = ?
        `).run(status, finding.id);

    } else {
        return res.status(400).json({ error: 'Estado de transición no válido.' });
    }

    logAudit(req.companyId, req.user.id, 'FINDING_STATUS_CHANGED', 'findings', finding.id, { from: finding.status }, { to: status }, req.ip);

    const updated = db.prepare('SELECT * FROM findings WHERE id = ?').get(finding.id);
    res.json({ finding: updated });
});

module.exports = router;
