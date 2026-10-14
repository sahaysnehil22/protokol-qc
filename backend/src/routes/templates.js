const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticate, requireRole, logAudit } = require('../middleware/auth');

// GET /api/templates - List templates for company (includes global & company custom)
router.get('/', authenticate, (req, res) => {
    const templates = db.prepare(`
        SELECT t.*,
               (SELECT COUNT(*) FROM template_items WHERE template_id = t.id) as total_items
        FROM templates t
        WHERE t.company_id = ? OR t.company_id IS NULL
        ORDER BY t.family ASC, t.code ASC
    `).all(req.companyId);

    res.json({ templates });
});

// GET /api/templates/:id - Get template with all checkpoints/items
router.get('/:id', authenticate, (req, res) => {
    const template = db.prepare(`
        SELECT * FROM templates WHERE id = ? AND (company_id = ? OR company_id IS NULL)
    `).get(req.params.id, req.companyId);

    if (!template) {
        return res.status(404).json({ error: 'Plantilla de protocolo no encontrada.' });
    }

    const items = db.prepare(`
        SELECT * FROM template_items WHERE template_id = ? ORDER BY order_index ASC
    `).all(template.id);

    res.json({
        template: {
            ...template,
            items
        }
    });
});

// POST /api/templates - Create custom template with checkpoints
router.post('/', authenticate, requireRole('admin', 'calidad'), (req, res) => {
    const { family, code, title, description, items } = req.body;
    if (!family || !code || !title || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'La familia, código, título y al menos un ítem de control son obligatorios.' });
    }

    const templateId = uuidv4();
    const tx = db.transaction(() => {
        db.prepare(`
            INSERT INTO templates (id, company_id, family, code, title, description, version, is_active, schema_json)
            VALUES (?, ?, ?, ?, ?, ?, 1, 1, '{}')
        `).run(templateId, req.companyId, family, code.toUpperCase().trim(), title.trim(), description || '');

        const insertItem = db.prepare(`
            INSERT INTO template_items (id, template_id, section, order_index, code, question_text, item_type, tolerance_min, tolerance_max, unit, is_critical)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        items.forEach((item, idx) => {
            insertItem.run(
                uuidv4(),
                templateId,
                item.section || 'General',
                idx + 1,
                item.code || `ITM-${idx + 1}`,
                item.question_text,
                item.item_type || 'conforme_no_conforme',
                item.tolerance_min !== undefined ? item.tolerance_min : null,
                item.tolerance_max !== undefined ? item.tolerance_max : null,
                item.unit || null,
                item.is_critical ? 1 : 0
            );
        });
    });

    try {
        tx();
        logAudit(req.companyId, req.user.id, 'TEMPLATE_CREATED', 'templates', templateId, null, req.body, req.ip);
        const created = db.prepare('SELECT * FROM templates WHERE id = ?').get(templateId);
        const createdItems = db.prepare('SELECT * FROM template_items WHERE template_id = ?').all(templateId);
        res.status(201).json({ template: { ...created, items: createdItems } });
    } catch (err) {
        res.status(500).json({ error: 'Error al registrar la plantilla de protocolo.', details: err.message });
    }
});

module.exports = router;
