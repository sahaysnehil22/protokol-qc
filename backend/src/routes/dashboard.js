const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { authenticate } = require('../middleware/auth');

// GET /api/dashboard/stats & /api/dashboard/summary - Resident and QA manager morning analytics
const handleDashboardStats = (req, res) => {
    const { project_id } = req.query;
    const companyId = req.companyId;

    let inspFilter = '';
    let findFilter = '';
    const params = [companyId];
    if (project_id) {
        inspFilter = ' AND i.project_id = ?';
        findFilter = ' AND f.project_id = ?';
        params.push(project_id);
    }

    // 1. Inspections by status
    const inspectionsByStatus = db.prepare(`
        SELECT i.status, COUNT(*) as count
        FROM inspections i
        WHERE i.company_id = ? ${inspFilter}
        GROUP BY i.status
    `).all(...params);

    // 2. Findings summary
    const findingsSummary = db.prepare(`
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN f.status = 'abierto' THEN 1 ELSE 0 END) as abierto,
            SUM(CASE WHEN f.status = 'en_proceso' THEN 1 ELSE 0 END) as en_proceso,
            SUM(CASE WHEN f.status = 'cerrado_con_evidencia' THEN 1 ELSE 0 END) as cerrado_con_evidencia,
            SUM(CASE WHEN f.status = 'verificado' THEN 1 ELSE 0 END) as verificado,
            SUM(CASE WHEN f.status != 'verificado' AND date(f.due_date) < date('now') THEN 1 ELSE 0 END) as overdue,
            SUM(CASE WHEN f.severity = 'critico' AND f.status != 'verificado' THEN 1 ELSE 0 END) as critical_open
        FROM findings f
        WHERE f.company_id = ? ${findFilter}
    `).get(...params);

    // 3. Findings by Contractor
    const findingsByContractor = db.prepare(`
        SELECT 
            coalesce(u.full_name, f.assigned_trade) as contractor_name,
            f.assigned_trade,
            COUNT(*) as total_assigned,
            SUM(CASE WHEN f.status != 'verificado' THEN 1 ELSE 0 END) as pending,
            SUM(CASE WHEN f.status != 'verificado' AND date(f.due_date) < date('now') THEN 1 ELSE 0 END) as overdue
        FROM findings f
        LEFT JOIN users u ON f.assigned_contractor_id = u.id
        WHERE f.company_id = ? ${findFilter}
        GROUP BY f.assigned_contractor_id, f.assigned_trade
        ORDER BY pending DESC
    `).all(...params);

    // 4. Critical pour release blockers
    const blockers = db.prepare(`
        SELECT f.*, p.name as project_name, l.name as location_name
        FROM findings f
        JOIN projects p ON f.project_id = p.id
        JOIN locations l ON f.location_id = l.id
        WHERE f.company_id = ? ${findFilter} AND f.severity = 'critico' AND f.status != 'verificado'
        ORDER BY f.due_date ASC
        LIMIT 5
    `).all(...params);

    // 5. Recent inspections
    const recentInspections = db.prepare(`
        SELECT i.id, i.code, i.status, i.pour_date, i.created_at,
               p.name as project_name, l.name as location_name, t.title as template_title,
               u.full_name as inspector_name
        FROM inspections i
        JOIN projects p ON i.project_id = p.id
        JOIN locations l ON i.location_id = l.id
        JOIN templates t ON i.template_id = t.id
        JOIN users u ON i.inspector_id = u.id
        WHERE i.company_id = ? ${inspFilter}
        ORDER BY i.created_at DESC
        LIMIT 6
    `).all(...params);

    // Calculate aggregated metrics
    const totalInspections = inspectionsByStatus.reduce((acc, row) => acc + (row.count || 0), 0);
    const byStatusMap = {};
    inspectionsByStatus.forEach(r => { byStatusMap[r.status] = r.count; });
    const conformeCount = byStatusMap['conforme'] || 0;
    const passRate = totalInspections > 0 ? Math.round((conformeCount / totalInspections) * 100) : 100;

    const fSummary = findingsSummary || { total: 0, abierto: 0, en_proceso: 0, cerrado_con_evidencia: 0, verificado: 0, overdue: 0, critical_open: 0 };
    const totalOpenFindings = (fSummary.abierto || 0) + (fSummary.en_proceso || 0) + (fSummary.cerrado_con_evidencia || 0);

    const formattedContractors = findingsByContractor.map(c => ({
        contractor_name: c.contractor_name,
        assigned_trade: c.assigned_trade,
        open_findings: c.pending || 0,
        overdue_findings: c.overdue || 0
    }));

    res.json({
        stats: {
            inspectionsByStatus,
            findingsSummary: fSummary,
            findingsByContractor,
            blockers,
            recentInspections
        },
        inspections: {
            total: totalInspections,
            pass_rate: passRate,
            by_status: byStatusMap,
            critical_pour_blockers: blockers
        },
        findings: {
            total_open: totalOpenFindings,
            overdue: fSummary.overdue || 0,
            by_contractor: formattedContractors
        }
    });
};

router.get('/stats', authenticate, handleDashboardStats);
router.get('/summary', authenticate, handleDashboardStats);

module.exports = router;
