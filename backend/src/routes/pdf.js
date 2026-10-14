const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { authenticate } = require('../middleware/auth');
const { generateInspectionPdf } = require('../services/pdfRenderer');

// GET /api/inspections/:id/pdf and /api/pdf/inspections/:id - Stream canonical PDF
const handlePdfStream = (req, res) => {
    const inspection = db.prepare(`
        SELECT i.*, 
               p.name as project_name, p.code as project_code, p.resident_name, p.ito_name,
               l.name as location_name, l.type as location_type,
               t.title as template_title, t.family as template_family,
               u.full_name as inspector_name
        FROM inspections i
        JOIN projects p ON i.project_id = p.id
        JOIN locations l ON i.location_id = l.id
        JOIN templates t ON i.template_id = t.id
        JOIN users u ON i.inspector_id = u.id
        WHERE i.id = ? AND i.company_id = ?
    `).get(req.params.id, req.companyId);

    if (!inspection) {
        return res.status(404).json({ error: 'Inspección no encontrada.' });
    }

    const company = db.prepare('SELECT * FROM companies WHERE id = ?').get(req.companyId);
    
    const answers = db.prepare(`
        SELECT a.*, ti.section, ti.order_index, ti.code as item_code, ti.question_text, ti.item_type,
               ti.tolerance_min, ti.tolerance_max, ti.unit
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

    const defaultPdfTemplate = db.prepare(`
        SELECT blocks_json FROM pdf_templates WHERE company_id = ? AND is_default = 1
    `).get(req.companyId);

    let blocks = [];
    if (defaultPdfTemplate && defaultPdfTemplate.blocks_json) {
        try {
            blocks = JSON.parse(defaultPdfTemplate.blocks_json);
        } catch (e) {}
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${inspection.code}.pdf"`);

    generateInspectionPdf({
        inspection: { ...inspection, answers, findings },
        company,
    }, res);
};

router.get('/:id/pdf', authenticate, handlePdfStream);
router.get('/inspections/:id', authenticate, handlePdfStream);
router.get('/:id', authenticate, handlePdfStream);

// GET /api/pdf-templates - List PDF layout configurations
router.get('/templates', authenticate, (req, res) => {
    const templates = db.prepare('SELECT * FROM pdf_templates WHERE company_id = ? OR company_id IS NULL').all(req.companyId);
    res.json({ templates });
});

// PUT /api/pdf-templates/:id - Update blocks configuration (Template Studio)
router.put('/templates/:id', authenticate, (req, res) => {
    const { blocks } = req.body;
    if (!Array.isArray(blocks)) {
        return res.status(400).json({ error: 'La configuración de bloques debe ser un array válido.' });
    }

    db.prepare(`
        UPDATE pdf_templates
        SET blocks_json = ?, updated_at = datetime('now')
        WHERE id = ? AND company_id = ?
    `).run(JSON.stringify(blocks), req.params.id, req.companyId);

    res.json({ success: true });
});

module.exports = router;
