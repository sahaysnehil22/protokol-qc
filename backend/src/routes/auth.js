const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { db } = require('../db');
const { JWT_SECRET, authenticate, logAudit } = require('../middleware/auth');

// POST /api/auth/login
router.post('/login', (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({ error: 'Debe ingresar su correo electrónico y contraseña.' });
    }

    const user = db.prepare(`
        SELECT u.id, u.company_id, u.email, u.password_hash, u.full_name, u.phone, u.role, u.trade_specialty, u.is_active,
               c.name as company_name, c.ruc as company_ruc, c.brand_color, c.logo_url, c.status as company_status,
               p.code as plan_code, p.name as plan_name, p.max_projects, p.max_users
        FROM users u
        JOIN companies c ON u.company_id = c.id
        LEFT JOIN plans p ON c.plan_id = p.id
        WHERE LOWER(u.email) = LOWER(?)
    `).get(email);

    if (!user) {
        return res.status(401).json({ error: 'Credenciales inválidas. Verifique su correo o contraseña.' });
    }

    if (!user.is_active) {
        return res.status(403).json({ error: 'Su usuario está inactivo. Contacte al administrador de su empresa.' });
    }

    const isValidPassword = bcrypt.compareSync(password, user.password_hash);
    if (!isValidPassword) {
        return res.status(401).json({ error: 'Credenciales inválidas. Verifique su correo o contraseña.' });
    }

    const token = jwt.sign(
        { userId: user.id, companyId: user.company_id, role: user.role },
        JWT_SECRET,
        { expiresIn: '30d' }
    );

    logAudit(user.company_id, user.id, 'USER_LOGIN', 'users', user.id, null, { email: user.email }, req.ip);

    res.json({
        token,
        user: {
            id: user.id,
            email: user.email,
            full_name: user.full_name,
            phone: user.phone,
            role: user.role,
            trade_specialty: user.trade_specialty,
            company: {
                id: user.company_id,
                name: user.company_name,
                ruc: user.company_ruc,
                brand_color: user.brand_color,
                logo_url: user.logo_url,
                plan: {
                    code: user.plan_code,
                    name: user.plan_name,
                    max_projects: user.max_projects,
                    max_users: user.max_users
                }
            }
        }
    });
});

// GET /api/auth/me
router.get('/me', authenticate, (req, res) => {
    res.json({ user: req.user });
});

module.exports = router;
