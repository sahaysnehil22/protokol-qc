const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { seed } = require('../src/seed');
const app = require('../src/server');

let server;
let baseUrl;
let adminToken;
let calidadToken;
let contratistaEstToken;
let contratistaAcabToken;
let itoToken;

function request(path, options = {}) {
    return new Promise((resolve, reject) => {
        const url = new URL(path, baseUrl);
        const req = http.request(url, {
            method: options.method || 'GET',
            headers: {
                'Content-Type': 'application/json',
                ...(options.headers || {})
            }
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                let parsed = data;
                try {
                    parsed = JSON.parse(data);
                } catch (e) {}
                resolve({ status: res.statusCode, headers: res.headers, body: parsed });
            });
        });

        req.on('error', reject);
        if (options.body) {
            req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
        }
        req.end();
    });
}

describe('Protokol QC Backend Test Suite', () => {
    before(async () => {
        // Run seed
        seed();

        // Start server on ephemeral port
        await new Promise(resolve => {
            server = app.listen(0, () => {
                const port = server.address().port;
                baseUrl = `http://localhost:${port}`;
                resolve();
            });
        });

        // Login Admin
        const resAdmin = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'admin@sanmartin.pe', password: 'Protokol2026!' }
        });
        adminToken = resAdmin.body.token;

        // Login Calidad
        const resCalidad = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'calidad@sanmartin.pe', password: 'Protokol2026!' }
        });
        calidadToken = resCalidad.body.token;

        // Login Contratista Estructuras
        const resContrEst = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'contratista.estructuras@subcon.pe', password: 'Protokol2026!' }
        });
        contratistaEstToken = resContrEst.body.token;

        // Login Contratista Acabados
        const resContrAcab = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'contratista.acabados@subcon.pe', password: 'Protokol2026!' }
        });
        contratistaAcabToken = resContrAcab.body.token;

        // Login ITO
        const resIto = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'ito@supervisorape.com', password: 'Protokol2026!' }
        });
        itoToken = resIto.body.token;
    });

    after(async () => {
        if (server) {
            await new Promise(resolve => server.close(resolve));
        }
    });

    test('1. Health Check returns 200 online', async () => {
        const res = await request('/api/health');
        assert.strictEqual(res.status, 200);
        assert.strictEqual(res.body.status, 'online');
    });

    test('2. Auth rejects invalid credentials', async () => {
        const res = await request('/api/auth/login', {
            method: 'POST',
            body: { email: 'admin@sanmartin.pe', password: 'WrongPassword123' }
        });
        assert.strictEqual(res.status, 401);
    });

    test('3. Contratista isolation: Contratista Estructuras only sees their own findings', async () => {
        const res = await request('/api/findings', {
            headers: { Authorization: `Bearer ${contratistaEstToken}` }
        });
        assert.strictEqual(res.status, 200);
        assert.ok(Array.isArray(res.body.findings));
        // All returned findings must be assigned to Estructuras
        for (const f of res.body.findings) {
            assert.strictEqual(f.assigned_trade, 'Estructuras y Encofrados');
        }
    });

    test('4. Contratista cannot self-verify finding to "verificado"', async () => {
        const listRes = await request('/api/findings', {
            headers: { Authorization: `Bearer ${contratistaEstToken}` }
        });
        const finding = listRes.body.findings[0];
        assert.ok(finding);

        // Contratista tries to verify
        const res = await request(`/api/findings/${finding.id}/status`, {
            method: 'PUT',
            headers: { Authorization: `Bearer ${contratistaEstToken}` },
            body: { status: 'verificado' }
        });

        assert.strictEqual(res.status, 403);
        assert.strictEqual(res.body.code, 'CANNOT_SELF_VERIFY');
    });

    test('5. Closing finding requires photo evidence and notes', async () => {
        const listRes = await request('/api/findings', {
            headers: { Authorization: `Bearer ${contratistaEstToken}` }
        });
        const finding = listRes.body.findings[0];

        // Try closing without photo
        const resNoPhoto = await request(`/api/findings/${finding.id}/status`, {
            method: 'PUT',
            headers: { Authorization: `Bearer ${contratistaEstToken}` },
            body: { status: 'cerrado_con_evidencia', resolution_notes: 'Listo jefe' }
        });
        assert.strictEqual(resNoPhoto.status, 400);
        assert.strictEqual(resNoPhoto.body.code, 'EVIDENCE_REQUIRED');

        // Close WITH photo evidence and notes
        const resWithPhoto = await request(`/api/findings/${finding.id}/status`, {
            method: 'PUT',
            headers: { Authorization: `Bearer ${contratistaEstToken}` },
            body: {
                status: 'cerrado_con_evidencia',
                resolution_photo_url: '/media/uploads/reparacion_columna_c4.jpg',
                resolution_notes: 'Se colocaron dados de concreto de 4.0 cm en toda la cara este.'
            }
        });
        assert.strictEqual(resWithPhoto.status, 200);
        assert.strictEqual(resWithPhoto.body.finding.status, 'cerrado_con_evidencia');

        // Now Calidad verifies on-site
        const resVerify = await request(`/api/findings/${finding.id}/status`, {
            method: 'PUT',
            headers: { Authorization: `Bearer ${calidadToken}` },
            body: { status: 'verificado' }
        });
        assert.strictEqual(resVerify.status, 200);
        assert.strictEqual(resVerify.body.finding.status, 'verificado');
    });

    test('6. Offline sync push is idempotent', async () => {
        const clientOpId = 'test-offline-op-' + Date.now();
        const testInspectionId = 'offline-insp-' + Date.now();

        // Get a valid seeded project, location, and template
        const projRes = await request('/api/projects', {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        const project = projRes.body.projects[0];
        
        const projDetail = await request(`/api/projects/${project.id}`, {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        const location = projDetail.body.project.flatLocations[0];

        const tmplRes = await request('/api/templates', {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        const template = tmplRes.body.templates[0];

        const payload = {
            deviceId: 'pixel-android-field-1',
            operations: [
                {
                    client_op_id: clientOpId,
                    entity_type: 'inspections',
                    entity_id: testInspectionId,
                    operation: 'CREATE',
                    client_timestamp: new Date().toISOString(),
                    payload: {
                        project_id: project.id,
                        location_id: location.id,
                        template_id: template.id,
                        code: 'OFFLINE-001',
                        status: 'borrador',
                        general_notes: 'Inspección realizada en sótano 2 sin señal'
                    }
                }
            ]
        };

        // First push
        const res1 = await request('/api/sync/push', {
            method: 'POST',
            headers: { Authorization: `Bearer ${calidadToken}` },
            body: payload
        });
        assert.strictEqual(res1.status, 200);
        assert.ok(res1.body.processed_op_ids.includes(clientOpId));

        // Second push of identical op (network retry / queue replay)
        const res2 = await request('/api/sync/push', {
            method: 'POST',
            headers: { Authorization: `Bearer ${calidadToken}` },
            body: payload
        });
        assert.strictEqual(res2.status, 200);
        assert.ok(res2.body.processed_op_ids.includes(clientOpId));
        assert.strictEqual(res2.body.errors.length, 0);
    });

    test('7. Server-side deterministic PDF stream works', async () => {
        const inspRes = await request('/api/inspections', {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        const inspection = inspRes.body.inspections[0];
        assert.ok(inspection);

        const pdfRes = await request(`/api/inspections/${inspection.id}/pdf`, {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        assert.strictEqual(pdfRes.status, 200);
        assert.strictEqual(pdfRes.headers['content-type'], 'application/pdf');
    });

    test('8. Dashboard analytics morning view returns populated metrics', async () => {
        const res = await request('/api/dashboard/stats', {
            headers: { Authorization: `Bearer ${calidadToken}` }
        });
        assert.strictEqual(res.status, 200);
        assert.ok(res.body.stats);
        assert.ok(Array.isArray(res.body.stats.inspectionsByStatus));
        assert.ok(Array.isArray(res.body.stats.findingsByContractor));
    });
});
