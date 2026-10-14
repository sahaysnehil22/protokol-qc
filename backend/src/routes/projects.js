const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticate, requireRole, logAudit } = require('../middleware/auth');

// Helper to construct recursive location tree
function buildLocationTree(locations, parentId = null) {
    return locations
        .filter(loc => loc.parent_id === parentId)
        .sort((a, b) => a.sort_order - b.sort_order)
        .map(loc => ({
            ...loc,
            children: buildLocationTree(locations, loc.id)
        }));
}

// GET /api/projects - List company projects
router.get('/', authenticate, (req, res) => {
    const projects = db.prepare(`
        SELECT p.*,
               (SELECT COUNT(*) FROM inspections WHERE project_id = p.id) as total_inspections,
               (SELECT COUNT(*) FROM findings WHERE project_id = p.id AND status != 'verificado') as open_findings
        FROM projects p
        WHERE p.company_id = ?
        ORDER BY p.created_at DESC
    `).all(req.companyId);

    res.json({ projects });
});

// GET /api/projects/:id - Get project with nested location tree
router.get('/:id', authenticate, (req, res) => {
    const project = db.prepare(`
        SELECT * FROM projects WHERE id = ? AND company_id = ?
    `).get(req.params.id, req.companyId);

    if (!project) {
        return res.status(404).json({ error: 'Proyecto u obra no encontrada.' });
    }

    const flatLocations = db.prepare(`
        SELECT * FROM locations WHERE project_id = ? ORDER BY sort_order ASC
    `).all(project.id);

    const locationTree = buildLocationTree(flatLocations);

    res.json({
        project: {
            ...project,
            locations: locationTree,
            flatLocations
        }
    });
});

// POST /api/projects - Create project with quota check
router.post('/', authenticate, requireRole('admin'), (req, res) => {
    const { code, name, address, district, city, resident_name, ito_name } = req.body;
    if (!code || !name) {
        return res.status(400).json({ error: 'El código y nombre de la obra son obligatorios.' });
    }

    // Check SaaS plan project limits
    const quota = db.prepare(`
        SELECT p.max_projects,
               (SELECT COUNT(*) FROM projects WHERE company_id = c.id) as current_count
        FROM companies c
        LEFT JOIN plans p ON c.plan_id = p.id
        WHERE c.id = ?
    `).get(req.companyId);

    if (quota && quota.max_projects && quota.current_count >= quota.max_projects) {
        return res.status(403).json({
            error: `Ha alcanzado el límite máximo de ${quota.max_projects} obras de su plan actual. Actualice a un plan superior para registrar más proyectos.`,
            code: 'PROJECT_LIMIT_REACHED'
        });
    }

    const projectId = uuidv4();
    try {
        db.prepare(`
            INSERT INTO projects (id, company_id, code, name, address, district, city, resident_name, ito_name, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'activo')
        `).run(projectId, req.companyId, code.toUpperCase().trim(), name.trim(), address || '', district || '', city || 'Lima', resident_name || '', ito_name || '');

        logAudit(req.companyId, req.user.id, 'PROJECT_CREATED', 'projects', projectId, null, req.body, req.ip);

        const newProject = db.prepare('SELECT * FROM projects WHERE id = ?').get(projectId);
        res.status(201).json({ project: newProject });
    } catch (err) {
        if (err.message && err.message.includes('UNIQUE')) {
            return res.status(409).json({ error: `Ya existe una obra con el código '${code}'.` });
        }
        res.status(500).json({ error: 'Error interno al registrar la obra.' });
    }
});

// POST /api/projects/:id/locations - Add location node to hierarchy
router.post('/:id/locations', authenticate, requireRole('admin', 'residente'), (req, res) => {
    const { parent_id, name, type, code, sort_order } = req.body;
    if (!name || !type) {
        return res.status(400).json({ error: 'El nombre y tipo de ubicación son obligatorios.' });
    }

    const locationId = uuidv4();
    db.prepare(`
        INSERT INTO locations (id, project_id, parent_id, name, type, code, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(locationId, req.params.id, parent_id || null, name.trim(), type, code || '', sort_order || 0);

    const newLocation = db.prepare('SELECT * FROM locations WHERE id = ?').get(locationId);
    res.status(201).json({ location: newLocation });
});

module.exports = router;
