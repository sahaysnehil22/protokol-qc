const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db, initDb } = require('./db');
const { starterTemplates } = require('./templates/starterLibrary');

async function seed() {
    initDb();
    console.log('🌱 Starting database seeding with realistic Peruvian project data...');

    const tx = db.transaction(() => {
        // Clear existing tables
        db.exec(`
            DELETE FROM sync_operations;
            DELETE FROM audit_logs;
            DELETE FROM signatures;
            DELETE FROM findings;
            DELETE FROM inspection_answers;
            DELETE FROM inspections;
            DELETE FROM template_items;
            DELETE FROM templates;
            DELETE FROM locations;
            DELETE FROM projects;
            DELETE FROM users;
            DELETE FROM pdf_templates;
            DELETE FROM companies;
            DELETE FROM plans;
        `);

        // 1. Seed Plans
        const planProfId = uuidv4();
        db.prepare(`
            INSERT INTO plans (id, code, name, price_pen, max_projects, max_users, features_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(
            planProfId,
            'profesional',
            'Plan Profesional Obra',
            790.0,
            5,
            15,
            JSON.stringify({ offline_sync: true, unlimited_protocols: true, branded_pdf: true, whatsapp_share: true })
        );

        // 2. Seed Company
        const companyId = uuidv4();
        db.prepare(`
            INSERT INTO companies (id, name, ruc, logo_url, brand_color, plan_id, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(
            companyId,
            'Constructora & Inmobiliaria San Martín S.A.C.',
            '20608945123',
            'https://raw.githubusercontent.com/sahaysnehil22/rea/main/docs/assets/san-martin-logo.png',
            '#D9531E', // Terracotta safety orange
            planProfId,
            'active'
        );

        // 3. Seed Users (5 Peruvian site roles)
        const passwordHash = bcrypt.hashSync('Protokol2026!', 10);
        
        const adminId = uuidv4();
        const residenteId = uuidv4();
        const calidadId = uuidv4();
        const contratistaEstId = uuidv4();
        const contratistaAcabId = uuidv4();
        const itoId = uuidv4();

        const insertUser = db.prepare(`
            INSERT INTO users (id, company_id, email, password_hash, full_name, phone, role, trade_specialty)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `);

        insertUser.run(adminId, companyId, 'admin@sanmartin.pe', passwordHash, 'Ing. Carlos Mendoza R.', '+51 987 654 321', 'admin', 'Gerencia Técnica');
        insertUser.run(residenteId, companyId, 'residente@sanmartin.pe', passwordHash, 'Ing. Jorge Valdivia C.', '+51 976 543 210', 'residente', 'Residencia de Obra');
        insertUser.run(calidadId, companyId, 'calidad@sanmartin.pe', passwordHash, 'Ing. Lucía Huamán M.', '+51 965 432 109', 'calidad', 'Control de Calidad');
        insertUser.run(contratistaEstId, companyId, 'contratista.estructuras@subcon.pe', passwordHash, 'Manuel Quispe B.', '+51 954 321 098', 'contratista', 'Estructuras y Encofrados');
        insertUser.run(contratistaAcabId, companyId, 'contratista.acabados@subcon.pe', passwordHash, 'Raúl Gómez T.', '+51 943 210 987', 'contratista', 'Acabados y Pintura');
        insertUser.run(itoId, companyId, 'ito@supervisorape.com', passwordHash, 'Ing. Alberto Farfán S.', '+51 932 109 876', 'cliente_ito', 'Supervisión Externa ITO');

        // 4. Seed Project (Obra)
        const projectId = uuidv4();
        db.prepare(`
            INSERT INTO projects (id, company_id, code, name, address, district, city, resident_name, ito_name, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            projectId,
            companyId,
            'OBRA-LPM-01',
            'Edificio Residencial Las Palmeras de Miraflores',
            'Av. Angamos Oeste 1240',
            'Miraflores',
            'Lima',
            'Ing. Jorge Valdivia C.',
            'Ing. Alberto Farfán S.',
            'activo'
        );

        // 5. Seed Location Tree
        const insertLocation = db.prepare(`
            INSERT INTO locations (id, project_id, parent_id, name, type, code, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        const torreAId = uuidv4();
        insertLocation.run(torreAId, projectId, null, 'Torre A', 'torre', 'TORRE-A', 1);

        const sotano2Id = uuidv4();
        insertLocation.run(sotano2Id, projectId, torreAId, 'Sótano 2 (Cisterna y Cimentación)', 'sotano', 'SOT-2', 1);

        const sotano1Id = uuidv4();
        insertLocation.run(sotano1Id, projectId, torreAId, 'Sótano 1 (Estacionamientos)', 'sotano', 'SOT-1', 2);

        const piso1Id = uuidv4();
        insertLocation.run(piso1Id, projectId, torreAId, 'Piso 1 (Lobby)', 'piso', 'PISO-1', 3);

        const piso2Id = uuidv4();
        insertLocation.run(piso2Id, projectId, torreAId, 'Piso 2 (Viviendas)', 'piso', 'PISO-2', 4);

        const dpto201Id = uuidv4();
        insertLocation.run(dpto201Id, projectId, piso2Id, 'Departamento 201', 'departamento', 'DPTO-201', 1);

        const dpto202Id = uuidv4();
        insertLocation.run(dpto202Id, projectId, piso2Id, 'Departamento 202', 'departamento', 'DPTO-202', 2);

        const piso3Id = uuidv4();
        insertLocation.run(piso3Id, projectId, torreAId, 'Piso 3 (Estructura en Proceso)', 'piso', 'PISO-3', 5);

        // 6. Seed Templates & Template Items
        const insertTemplate = db.prepare(`
            INSERT INTO templates (id, company_id, family, code, title, description, version, is_active, schema_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        const insertItem = db.prepare(`
            INSERT INTO template_items (id, template_id, section, order_index, code, question_text, item_type, tolerance_min, tolerance_max, unit, is_critical)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        let concretoTemplateId = null;
        let aceroTemplateId = null;
        let acabadosTemplateId = null;

        for (const tmpl of starterTemplates) {
            const templateId = uuidv4();
            if (tmpl.family === 'concreto') concretoTemplateId = templateId;
            if (tmpl.family === 'acero') aceroTemplateId = templateId;
            if (tmpl.family === 'acabados') acabadosTemplateId = templateId;

            insertTemplate.run(
                templateId,
                companyId,
                tmpl.family,
                tmpl.code,
                tmpl.title,
                tmpl.description,
                1,
                1,
                JSON.stringify({ created_by: 'system' })
            );

            tmpl.items.forEach((item, index) => {
                insertItem.run(
                    uuidv4(),
                    templateId,
                    item.section,
                    index + 1,
                    item.code,
                    item.question_text,
                    item.item_type,
                    item.tolerance_min !== undefined ? item.tolerance_min : null,
                    item.tolerance_max !== undefined ? item.tolerance_max : null,
                    item.unit || null,
                    item.is_critical || 0
                );
            });
        }

        // 7. Seed Sample Inspections with Answers
        const inspection1Id = uuidv4(); // Vaciado de Losas Piso 2
        db.prepare(`
            INSERT INTO inspections (id, company_id, project_id, location_id, template_id, template_version, inspector_id, code, status, pour_date, batch_number, weather, general_notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            inspection1Id,
            companyId,
            projectId,
            piso2Id,
            concretoTemplateId,
            1,
            calidadId,
            'PROT-CONC-2026-001',
            'conforme',
            '2026-10-12',
            'UNICON-GUIA-89212',
            'Soleado 21°C',
            'Vaciado de losa aligerada y vigas Piso 2. Se tomaron 4 probetas de control f\'c=280 kg/cm².'
        );

        // Fetch template items for concreto
        const concItems = db.prepare('SELECT id, code, item_type FROM template_items WHERE template_id = ?').all(concretoTemplateId);
        const insertAnswer = db.prepare(`
            INSERT INTO inspection_answers (id, inspection_id, item_id, status, numeric_value, observation_text, photo_urls_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        concItems.forEach(item => {
            if (item.code === 'CONC-03') {
                insertAnswer.run(uuidv4(), inspection1Id, item.id, 'conforme', 4.0, 'Slump medido: 4.0 pulgadas. Conforme dentro del rango especificado.', '[]');
            } else if (item.code === 'CONC-04') {
                insertAnswer.run(uuidv4(), inspection1Id, item.id, 'conforme', 23.5, 'Temperatura 23.5°C al momento de descarga.', '[]');
            } else {
                insertAnswer.run(uuidv4(), inspection1Id, item.id, 'conforme', null, 'Verificado satisfactoriamente.', '[]');
            }
        });

        // 8. Seed Inspection 2 (Acero Piso 3) with a Non-Conformity that becomes a Finding
        const inspection2Id = uuidv4();
        db.prepare(`
            INSERT INTO inspections (id, company_id, project_id, location_id, template_id, template_version, inspector_id, code, status, general_notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            inspection2Id,
            companyId,
            projectId,
            piso3Id,
            aceroTemplateId,
            1,
            calidadId,
            'PROT-ACER-2026-002',
            'observado',
            'Inspección previa a vaciado de columnas C-4 y C-5 Piso 3. Se detectó falta de recubrimiento en cara este.'
        );

        const aceroItems = db.prepare('SELECT id, code FROM template_items WHERE template_id = ?').all(aceroTemplateId);
        let failAnswerId = null;

        aceroItems.forEach(item => {
            if (item.code === 'ACER-04') {
                failAnswerId = uuidv4();
                insertAnswer.run(
                    failAnswerId,
                    inspection2Id,
                    item.id,
                    'no_conforme',
                    1.8,
                    'Recubrimiento libre insuficiente (1.8 cm medido vs 4.0 cm especificado en plano E-03). Varillas pegadas al encofrado.',
                    '["/media/uploads/evidencia_acero_c4.jpg"]'
                );
            } else {
                insertAnswer.run(uuidv4(), inspection2Id, item.id, 'conforme', null, 'Conforme con planos.', '[]');
            }
        });

        // 9. Seed Findings (Hallazgos)
        // Finding 1: Created from failed inspection checkpoint
        const finding1Id = uuidv4();
        db.prepare(`
            INSERT INTO findings (
                id, company_id, project_id, inspection_id, answer_id, location_id,
                code, title, description, severity, status, assigned_contractor_id,
                assigned_trade, due_date, initial_photo_url
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            finding1Id,
            companyId,
            projectId,
            inspection2Id,
            failAnswerId,
            piso3Id,
            'HAL-2026-001',
            'Falta de recubrimiento en armadura de Columnas C-4 y C-5',
            'Se detectó que los dados separadores de concreto se quebraron, dejando el estribo a solo 1.8 cm del encofrado. Requiere colocación inmediata de dados de 4.0 cm antes de autorizar vaciado.',
            'critico',
            'en_proceso',
            contratistaEstId,
            'Estructuras y Encofrados',
            '2026-10-16', // Due tomorrow
            '/media/uploads/evidencia_acero_c4.jpg'
        );

        // Finding 2: Repaso de acabados in Dpto 201 (Resolved with evidence, awaiting QA verification)
        const finding2Id = uuidv4();
        db.prepare(`
            INSERT INTO findings (
                id, company_id, project_id, location_id,
                code, title, description, severity, status, assigned_contractor_id,
                assigned_trade, due_date, initial_photo_url, resolution_photo_url, resolution_notes, resolved_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        `).run(
            finding2Id,
            companyId,
            projectId,
            dpto201Id,
            'HAL-2026-002',
            'Fisura capilar y pintura soplada en muro cabecero Dormitorio Principal',
            'Muro presenta fisura de contracción de 1.2 m de longitud en pintura látex blanca.',
            'moderado',
            'cerrado_con_evidencia',
            contratistaAcabId,
            'Acabados y Pintura',
            '2026-10-14',
            '/media/uploads/dpto201_fisura_antes.jpg',
            '/media/uploads/dpto201_reparado_despues.jpg',
            'Se aplicó cinta de malla de fibra de vidrio con pasta elastomérica, lijado fino y dos manos de pintura látex satinada tono blanco humo.',
        );

        // 10. Seed Default Block-Based PDF Template
        const pdfTemplateId = uuidv4();
        const defaultBlocks = [
            { type: 'header', showLogo: true, title: 'PROTOCOLO DE CONTROL DE CALIDAD' },
            { type: 'project_meta', fields: ['projectName', 'projectCode', 'locationPath', 'date', 'weather', 'inspector'] },
            { type: 'protocol_checks', showTolerances: true },
            { type: 'findings_summary', showResolvedOnly: false },
            { type: 'photo_gallery', columns: 2, showTimestamps: true },
            { type: 'signatures', roles: ['calidad', 'residente', 'cliente_ito'] },
            { type: 'footer', legalText: 'Documento técnico oficial generado por Protokol QC. Validez según R.N.E. y normas técnicas peruanas vigentes.' }
        ];

        db.prepare(`
            INSERT INTO pdf_templates (id, company_id, name, blocks_json, is_default)
            VALUES (?, ?, ?, ?, 1)
        `).run(pdfTemplateId, companyId, 'Formato Oficial Edificaciones San Martín', JSON.stringify(defaultBlocks));

        console.log('✅ Seeding completed successfully!');
    });

    tx();
}

if (require.main === module) {
    seed();
}

module.exports = { seed };
