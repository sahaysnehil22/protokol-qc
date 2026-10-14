const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticate, requireRole, logAudit } = require('../middleware/auth');

// GET /api/inspections - List inspections with query filters
router.get('/', authenticate, (req, res) => {
    const { project_id, status, template_family } = req.query;
    let query = `
        SELECT i.*, 
               p.name as project_name, p.code as project_code,
               l.name as location_name, l.type as location_type,
               t.title as template_title, t.family as template_family,
               u.full_name as inspector_name,
               (SELECT COUNT(*) FROM inspection_answers WHERE inspection_id = i.id) as total_answers,
               (SELECT COUNT(*) FROM inspection_answers WHERE inspection_id = i.id AND status = 'no_conforme') as failed_answers,
               (SELECT COUNT(*) FROM findings WHERE inspection_id = i.id) as total_findings
        FROM inspections i
        JOIN projects p ON i.project_id = p.id
        JOIN locations l ON i.location_id = l.id
        JOIN templates t ON i.template_id = t.id
        JOIN users u ON i.inspector_id = u.id
        WHERE i.company_id = ?
    `;
    const params = [req.companyId];

    if (project_id) {
        query += ' AND i.project_id = ?';
        params.push(project_id);
    }
    if (status) {
        query += ' AND i.status = ?';
        params.push(status);
    }
    if (template_family) {
        query += ' AND t.family = ?';
        params.push(template_family);
    }

    query += ' ORDER BY i.created_at DESC';

    const inspections = db.prepare(query).all(...params);
    res.json({ inspections });
});

// GET /api/inspections/:id - Full inspection detail
router.get('/:id', authenticate, (req, res) => {
    const inspection = db.prepare(`
        SELECT i.*, 
               p.name as project_name, p.code as project_code, p.address as project_address, p.district as project_district,
               l.name as location_name, l.type as location_type,
               t.title as template_title, t.family as template_family, t.code as template_code,
               u.full_name as inspector_name, u.role as inspector_role
        FROM inspections i
        JOIN projects p ON i.project_id = p.id
        JOIN locations l ON i.location_id = l.id
        JOIN templates t ON i.template_id = t.id
        JOIN users u ON i.inspector_id = u.id
        WHERE i.id = ? AND i.company_id = ?
    `).get(req.params.id, req.companyId);

    if (!inspection) {
        return res.status(404).json({ error: 'Protocolo de inspección no encontrado.' });
    }

    const answers = db.prepare(`
        SELECT a.*, ti.section, ti.order_index, ti.code as item_code, ti.question_text, ti.item_type,
               ti.tolerance_min, ti.tolerance_max, ti.unit, ti.is_critical
        FROM inspection_answers a
        JOIN template_items ti ON a.item_id = ti.id
        WHERE a.inspection_id = ?
        ORDER BY ti.order_index ASC
    `).all(inspection.id);

    const findings = db.prepare(`
        SELECT f.*, u.full_name as contractor_name
        FROM findings f
        LEFT JOIN users u ON f.assigned_contractor_id = u.id
        WHERE f.inspection_id = ?
    `).all(inspection.id);

    const signatures = db.prepare(`
        SELECT * FROM signatures WHERE inspection_id = ? ORDER BY signed_at ASC
    `).all(inspection.id);

    res.json({
        inspection: {
            ...inspection,
            answers,
            findings,
            signatures
        }
    });
});

// POST /api/inspections - Create new inspection record
router.post('/', authenticate, requireRole('admin', 'residente', 'calidad'), (req, res) => {
    const { project_id, location_id, template_id, pour_date, batch_number, weather, general_notes } = req.body;
    if (!project_id || !location_id || !template_id) {
        return res.status(400).json({ error: 'La obra, ubicación y plantilla son requeridos para iniciar la inspección.' });
    }

    const template = db.prepare('SELECT * FROM templates WHERE id = ?').get(template_id);
    if (!template) {
        return res.status(404).json({ error: 'Plantilla de protocolo no válida.' });
    }

    const inspectionId = uuidv4();
    const countToday = db.prepare("SELECT COUNT(*) as count FROM inspections WHERE company_id = ? AND date(created_at) = date('now')").get(req.companyId).count;
    const code = `PROT-${template.family.toUpperCase().slice(0, 4)}-${new Date().getFullYear()}-${String(countToday + 1).padStart(3, '0')}`;

    const tx = db.transaction(() => {
        db.prepare(`
            INSERT INTO inspections (id, company_id, project_id, location_id, template_id, template_version, inspector_id, code, status, pour_date, batch_number, weather, general_notes, synced_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'borrador', ?, ?, ?, ?, datetime('now'))
        `).run(
            inspectionId,
            req.companyId,
            project_id,
            location_id,
            template_id,
            template.version,
            req.user.id,
            code,
            pour_date || null,
            batch_number || null,
            weather || null,
            general_notes || null
        );

        // Pre-populate answers from template items
        const items = db.prepare('SELECT id FROM template_items WHERE template_id = ? ORDER BY order_index ASC').all(template_id);
        const insertAnswer = db.prepare(`
            INSERT INTO inspection_answers (id, inspection_id, item_id, status)
            VALUES (?, ?, ?, 'pendiente')
        `);

        items.forEach(item => {
            insertAnswer.run(uuidv4(), inspectionId, item.id);
        });
    });

    tx();
    logAudit(req.companyId, req.user.id, 'INSPECTION_CREATED', 'inspections', inspectionId, null, { code, template_id }, req.ip);

    const created = db.prepare('SELECT * FROM inspections WHERE id = ?').get(inspectionId);
    res.status(201).json({ inspection: created });
});

// PUT /api/inspections/:id - Update answers and auto-generate findings for failures
router.put('/:id', authenticate, requireRole('admin', 'residente', 'calidad'), (req, res) => {
    const { answers, status, general_notes, pour_date, batch_number, weather } = req.body;
    const inspection = db.prepare('SELECT * FROM inspections WHERE id = ? AND company_id = ?').get(req.params.id, req.companyId);

    if (!inspection) {
        return res.status(404).json({ error: 'Inspección no encontrada.' });
    }

    let hasCriticalFailure = false;
    let anyFailure = false;

    const tx = db.transaction(() => {
        if (Array.isArray(answers)) {
            for (const ans of answers) {
                const item = db.prepare('SELECT * FROM template_items WHERE id = ?').get(ans.item_id);
                if (!item) continue;

                let answerStatus = ans.status;

                // Validate numeric tolerances if numeric type
                if (item.item_type === 'numeric_tolerance' && ans.numeric_value !== undefined && ans.numeric_value !== null) {
                    const val = Number(ans.numeric_value);
                    if ((item.tolerance_min !== null && val < item.tolerance_min) ||
                        (item.tolerance_max !== null && val > item.tolerance_max)) {
                        answerStatus = 'no_conforme';
                    } else if (ans.status !== 'no_aplica') {
                        answerStatus = 'conforme';
                    }
                }

                if (answerStatus === 'no_conforme') {
                    anyFailure = true;
                    if (item.is_critical) {
                        hasCriticalFailure = true;
                    }

                    // Check if a finding already exists for this answer
                    const existingFinding = db.prepare('SELECT id FROM findings WHERE inspection_id = ? AND answer_id = ?').get(inspection.id, ans.id || ans.answer_id);

                    if (!existingFinding) {
                        // AUTO-GENERATE HALLAZGO (Finding)
                        const findingId = uuidv4();
                        const findingCount = db.prepare('SELECT COUNT(*) as count FROM findings WHERE company_id = ?').get(req.companyId).count;
                        const findingCode = `HAL-${new Date().getFullYear()}-${String(findingCount + 1).padStart(3, '0')}`;

                        // Default due date: 48h from now
                        const dueDate = new Date(Date.now() + 48 * 3600 * 1000).toISOString().split('T')[0];

                        // Find contractor for trade if available
                        const contractor = db.prepare("SELECT id FROM users WHERE company_id = ? AND role = 'contratista' LIMIT 1").get(req.companyId);

                        db.prepare(`
                            INSERT INTO findings (
                                id, company_id, project_id, inspection_id, answer_id, location_id,
                                code, title, description, severity, status, assigned_contractor_id,
                                assigned_trade, due_date, initial_photo_url
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'abierto', ?, ?, ?, ?)
                        `).run(
                            findingId,
                            req.companyId,
                            inspection.project_id,
                            inspection.id,
                            ans.id,
                            inspection.location_id,
                            findingCode,
                            `No Conformidad: ${item.code} - ${item.question_text.slice(0, 60)}...`,
                            ans.observation_text || `El ítem de control técnico ${item.code} no superó la verificación en obra.`,
                            item.is_critical ? 'critico' : 'moderado',
                            contractor ? contractor.id : null,
                            'Estructuras y Acabados',
                            dueDate,
                            ans.photo_urls_json && JSON.parse(ans.photo_urls_json).length > 0 ? JSON.parse(ans.photo_urls_json)[0] : null
                        );
                    }
                }

                // Update answer record
                db.prepare(`
                    UPDATE inspection_answers
                    SET status = ?, numeric_value = ?, observation_text = ?, photo_urls_json = ?, updated_at = datetime('now')
                    WHERE inspection_id = ? AND item_id = ?
                `).run(
                    answerStatus,
                    ans.numeric_value !== undefined ? ans.numeric_value : null,
                    ans.observation_text || null,
                    ans.photo_urls_json || '[]',
                    inspection.id,
                    item.id
                );
            }
        }

        // Determine inspection status: if any failed check, cannot be 'conforme'
        let finalStatus = status || inspection.status;
        if (anyFailure && finalStatus === 'conforme') {
            finalStatus = 'observado';
        }

        db.prepare(`
            UPDATE inspections
            SET status = ?, general_notes = coalesce(?, general_notes), pour_date = coalesce(?, pour_date),
                batch_number = coalesce(?, batch_number), weather = coalesce(?, weather), updated_at = datetime('now')
            WHERE id = ?
        `).run(finalStatus, general_notes, pour_date, batch_number, weather, inspection.id);
    });

    tx();
    logAudit(req.companyId, req.user.id, 'INSPECTION_UPDATED', 'inspections', inspection.id, null, { hasCriticalFailure, anyFailure }, req.ip);

    const updated = db.prepare('SELECT * FROM inspections WHERE id = ?').get(inspection.id);
    res.json({ inspection: updated });
});

// POST /api/inspections/:id/signatures - Capture on-device digital signature
router.post('/:id/signatures', authenticate, (req, res) => {
    const { signature_data, signer_role, signer_name } = req.body;
    if (!signature_data) {
        return res.status(400).json({ error: 'Los datos de la firma son requeridos.' });
    }

    const inspection = db.prepare('SELECT * FROM inspections WHERE id = ? AND company_id = ?').get(req.params.id, req.companyId);
    if (!inspection) {
        return res.status(404).json({ error: 'Inspección no encontrada.' });
    }

    const signatureId = uuidv4();
    db.prepare(`
        INSERT INTO signatures (id, inspection_id, signer_id, signer_name, signer_role, signature_data, signed_at)
        VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
    `).run(
        signatureId,
        inspection.id,
        req.user.id,
        signer_name || req.user.full_name,
        signer_role || req.user.role,
        signature_data
    );

    logAudit(req.companyId, req.user.id, 'SIGNATURE_CAPTURED', 'signatures', signatureId, null, { inspection_id: inspection.id }, req.ip);

    const sig = db.prepare('SELECT * FROM signatures WHERE id = ?').get(signatureId);
    res.status(201).json({ signature: sig });
});

module.exports = router;
