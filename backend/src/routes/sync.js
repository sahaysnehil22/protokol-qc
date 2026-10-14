const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticate, logAudit } = require('../middleware/auth');

// POST /api/sync/push - Process queued offline operations idempotently
router.post('/push', authenticate, (req, res) => {
    const { deviceId, operations } = req.body;

    if (!Array.isArray(operations)) {
        return res.status(400).json({ error: 'Formato de operaciones inválido. Se espera un array.' });
    }

    const processedOps = [];
    const errors = [];

    const tx = db.transaction(() => {
        for (const op of operations) {
            const { client_op_id, entity_type, entity_id, operation, payload, client_timestamp } = op;

            // 1. Idempotency Check: if this exact client operation was already applied, skip execution
            const existingOp = db.prepare('SELECT id FROM sync_operations WHERE client_op_id = ?').get(client_op_id);
            if (existingOp) {
                processedOps.push(client_op_id);
                continue;
            }

            try {
                const data = typeof payload === 'string' ? JSON.parse(payload) : payload;

                if (entity_type === 'inspections') {
                    if (operation === 'CREATE') {
                        db.prepare(`
                            INSERT OR REPLACE INTO inspections (
                                id, company_id, project_id, location_id, template_id, template_version,
                                inspector_id, code, status, pour_date, batch_number, weather, general_notes, synced_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                        `).run(
                            entity_id,
                            req.companyId,
                            data.project_id,
                            data.location_id,
                            data.template_id,
                            data.template_version || 1,
                            req.user.id,
                            data.code,
                            data.status || 'borrador',
                            data.pour_date || null,
                            data.batch_number || null,
                            data.weather || null,
                            data.general_notes || null
                        );
                    } else if (operation === 'UPDATE') {
                        db.prepare(`
                            UPDATE inspections
                            SET status = coalesce(?, status), general_notes = coalesce(?, general_notes),
                                pour_date = coalesce(?, pour_date), batch_number = coalesce(?, batch_number),
                                weather = coalesce(?, weather), updated_at = datetime('now'), synced_at = datetime('now')
                            WHERE id = ? AND company_id = ?
                        `).run(data.status, data.general_notes, data.pour_date, data.batch_number, data.weather, entity_id, req.companyId);
                    }
                } else if (entity_type === 'inspection_answers') {
                    db.prepare(`
                        INSERT OR REPLACE INTO inspection_answers (
                            id, inspection_id, item_id, status, numeric_value, observation_text, photo_urls_json, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
                    `).run(
                        entity_id,
                        data.inspection_id,
                        data.item_id,
                        data.status || 'pendiente',
                        data.numeric_value !== undefined ? data.numeric_value : null,
                        data.observation_text || null,
                        data.photo_urls_json || '[]'
                    );
                } else if (entity_type === 'findings') {
                    if (operation === 'CREATE') {
                        db.prepare(`
                            INSERT OR REPLACE INTO findings (
                                id, company_id, project_id, inspection_id, answer_id, location_id,
                                code, title, description, severity, status, assigned_contractor_id,
                                assigned_trade, due_date, initial_photo_url, created_at, updated_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
                        `).run(
                            entity_id,
                            req.companyId,
                            data.project_id,
                            data.inspection_id || null,
                            data.answer_id || null,
                            data.location_id,
                            data.code,
                            data.title,
                            data.description,
                            data.severity || 'moderado',
                            data.status || 'abierto',
                            data.assigned_contractor_id || null,
                            data.assigned_trade || 'General',
                            data.due_date,
                            data.initial_photo_url || null
                        );
                    } else if (operation === 'UPDATE') {
                        db.prepare(`
                            UPDATE findings
                            SET status = coalesce(?, status),
                                resolution_photo_url = coalesce(?, resolution_photo_url),
                                resolution_notes = coalesce(?, resolution_notes),
                                resolved_at = case when ? = 'cerrado_con_evidencia' then datetime('now') else resolved_at end,
                                updated_at = datetime('now')
                            WHERE id = ? AND company_id = ?
                        `).run(data.status, data.resolution_photo_url, data.resolution_notes, data.status, entity_id, req.companyId);
                    }
                } else if (entity_type === 'signatures') {
                    db.prepare(`
                        INSERT OR REPLACE INTO signatures (id, inspection_id, signer_id, signer_name, signer_role, signature_data, signed_at)
                        VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
                    `).run(entity_id, data.inspection_id, req.user.id, data.signer_name || req.user.full_name, data.signer_role || req.user.role, data.signature_data);
                }

                // Record into sync operations ledger
                db.prepare(`
                    INSERT INTO sync_operations (
                        id, client_op_id, client_device_id, company_id, user_id,
                        entity_type, entity_id, operation, payload_json, client_timestamp, server_timestamp
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                `).run(
                    uuidv4(),
                    client_op_id,
                    deviceId || 'unknown',
                    req.companyId,
                    req.user.id,
                    entity_type,
                    entity_id,
                    operation,
                    typeof payload === 'string' ? payload : JSON.stringify(payload),
                    client_timestamp || new Date().toISOString()
                );

                processedOps.push(client_op_id);
            } catch (err) {
                errors.push({ client_op_id, error: err.message });
            }
        }
    });

    tx();
    logAudit(req.companyId, req.user.id, 'SYNC_PUSH_PROCESSED', 'sync', deviceId || 'unknown', null, { processed: processedOps.length, errors: errors.length }, req.ip);

    res.json({
        success: true,
        processed_op_ids: processedOps,
        errors,
        server_time: new Date().toISOString()
    });
});

// GET /api/sync/pull - Return all changes since timestamp
router.get('/pull', authenticate, (req, res) => {
    const { since } = req.query;
    const sinceTimestamp = since || '1970-01-01T00:00:00Z';

    const projects = db.prepare('SELECT * FROM projects WHERE company_id = ? AND updated_at > ?').all(req.companyId, sinceTimestamp);
    const locations = db.prepare(`
        SELECT l.* FROM locations l
        JOIN projects p ON l.project_id = p.id
        WHERE p.company_id = ? AND l.updated_at > ?
    `).all(req.companyId, sinceTimestamp);

    const templates = db.prepare('SELECT * FROM templates WHERE (company_id = ? OR company_id IS NULL) AND updated_at > ?').all(req.companyId, sinceTimestamp);
    const templateIds = templates.map(t => t.id);
    const templateItems = templateIds.length > 0 
        ? db.prepare(`SELECT * FROM template_items WHERE template_id IN (${templateIds.map(() => '?').join(',')})`).all(...templateIds)
        : [];

    const inspections = db.prepare('SELECT * FROM inspections WHERE company_id = ? AND updated_at > ?').all(req.companyId, sinceTimestamp);
    const inspectionIds = inspections.map(i => i.id);
    const answers = inspectionIds.length > 0
        ? db.prepare(`SELECT * FROM inspection_answers WHERE inspection_id IN (${inspectionIds.map(() => '?').join(',')})`).all(...inspectionIds)
        : [];

    let findingsQuery = 'SELECT * FROM findings WHERE company_id = ? AND updated_at > ?';
    const findingsParams = [req.companyId, sinceTimestamp];
    if (req.user.role === 'contratista') {
        findingsQuery += ' AND assigned_contractor_id = ?';
        findingsParams.push(req.user.id);
    }
    const findings = db.prepare(findingsQuery).all(...findingsParams);

    const signatures = inspectionIds.length > 0
        ? db.prepare(`SELECT * FROM signatures WHERE inspection_id IN (${inspectionIds.map(() => '?').join(',')})`).all(...inspectionIds)
        : [];

    const pdfTemplates = db.prepare('SELECT * FROM pdf_templates WHERE (company_id = ? OR company_id IS NULL) AND updated_at > ?').all(req.companyId, sinceTimestamp);

    res.json({
        changes: {
            projects,
            locations,
            templates,
            templateItems,
            inspections,
            answers,
            findings,
            signatures,
            pdfTemplates
        },
        server_time: new Date().toISOString()
    });
});

module.exports = router;
