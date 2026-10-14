const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const { initDb } = require('./db');
const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/projects');
const templateRoutes = require('./routes/templates');
const inspectionRoutes = require('./routes/inspections');
const findingRoutes = require('./routes/findings');
const syncRoutes = require('./routes/sync');
const pdfRoutes = require('./routes/pdf');
const dashboardRoutes = require('./routes/dashboard');

// Ensure DB is initialized
initDb();

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));

// Static media uploads folder
const mediaDir = path.join(__dirname, '../data/uploads');
if (!fs.existsSync(mediaDir)) {
    fs.mkdirSync(mediaDir, { recursive: true });
}
app.use('/media/uploads', express.static(mediaDir));

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'online',
        service: 'Protokol QC SaaS API',
        region: 'PE (Lima)',
        time: new Date().toISOString()
    });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/templates', templateRoutes);
app.use('/api/inspections', inspectionRoutes);
app.use('/api/findings', findingRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/inspections', pdfRoutes);
app.use('/api/pdf', pdfRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Serve Web Client Dashboard
const webDir = path.join(__dirname, '../../web');
if (fs.existsSync(webDir)) {
    app.use(express.static(webDir));
    app.get('*', (req, res, next) => {
        if (req.path.startsWith('/api') || req.path.startsWith('/media')) {
            return next();
        }
        res.sendFile(path.join(webDir, 'index.html'));
    });
}

// Global Error Handler
app.use((err, req, res, next) => {
    console.error('Unhandled server error:', err);
    res.status(500).json({
        error: 'Ocurrió un error interno en el servidor.',
        details: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`🚀 Protokol QC Backend API listening on port ${PORT}`);
        console.log(`📡 Health Check: http://localhost:${PORT}/api/health`);
    });
}

module.exports = app;
