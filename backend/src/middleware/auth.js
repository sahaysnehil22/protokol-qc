const jwt = require('jsonwebtoken');
const { db } = require('../db');

// In production, JWT_SECRET must be set via environment variable.
// Real secrets must never be committed to source control. (render.yaml generates JWT_SECRET via generateValue).
const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-insecure-secret';

function authenticate(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            error: 'No autorizado. Se requiere un token Bearer válido.',
            code: 'AUTH_REQUIRED'
        });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        
        const user = db.prepare(`
            SELECT u.id, u.company_id, u.email, u.full_name, u.role, u.trade_specialty, u.is_active,
                   c.name as company_name, c.status as company_status, c.brand_color, c.logo_url
            FROM users u
            JOIN companies c ON u.company_id = c.id
            WHERE u.id = ?
        `).get(decoded.userId);

        if (!user) {
            return res.status(401).json({
                error: 'Usuario no encontrado.',
                code: 'USER_NOT_FOUND'
            });
        }

        if (!user.is_active) {
            return res.status(403).json({
                error: 'Esta cuenta de usuario ha sido desactivada.',
                code: 'USER_INACTIVE'
            });
        }

        if (user.company_status === 'suspended') {
            return res.status(403).json({
                error: 'La suscripción de la empresa se encuentra suspendida.',
                code: 'COMPANY_SUSPENDED'
            });
        }

        req.user = user;
        req.companyId = user.company_id;
        next();
    } catch (err) {
        return res.status(401).json({
            error: 'Sesión expirada o token inválido. Inicie sesión nuevamente.',
            code: 'INVALID_TOKEN'
        });
    }
}

function requireRole(...allowedRoles) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'No autenticado.' });
        }
        if (!allowedRoles.includes(req.user.role)) {
            return res.status(403).json({
                error: `Acceso restringido. Su rol '${req.user.role}' no tiene permisos para esta acción.`,
                code: 'FORBIDDEN_ROLE',
                requiredRoles: allowedRoles
            });
        }
        next();
    };
}

function logAudit(companyId, userId, action, entityType, entityId, payloadBefore = null, payloadAfter = null, ip = null) {
    try {
        const { v4: uuidv4 } = require('uuid');
        db.prepare(`
            INSERT INTO audit_logs (id, company_id, user_id, action, entity_type, entity_id, payload_before_json, payload_after_json, ip_address, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        `).run(
            uuidv4(),
            companyId,
            userId,
            action,
            entityType,
            entityId,
            payloadBefore ? JSON.stringify(payloadBefore) : null,
            payloadAfter ? JSON.stringify(payloadAfter) : null,
            ip
        );
    } catch (err) {
        console.error('Error logging audit trail:', err);
    }
}

module.exports = {
    authenticate,
    requireRole,
    logAudit,
    JWT_SECRET
};
