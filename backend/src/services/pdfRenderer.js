const PDFDocument = require('pdfkit');

function generateInspectionPdf(data, stream) {
    const { inspection, company, blocks } = data;
    const primaryColor = company.brand_color || '#D9531E';

    const doc = new PDFDocument({
        size: 'A4',
        margin: 36,
        info: {
            Title: `Protocolo ${inspection.code} - ${inspection.project_name}`,
            Author: company.name,
            Subject: 'Control de Calidad Técnico de Obra',
            Keywords: 'Perú, Construcción, Protocolo, Calidad, ITO'
        }
    });

    doc.pipe(stream);

    const activeBlocks = Array.isArray(blocks) && blocks.length > 0 ? blocks : [
        { type: 'header', showLogo: true, title: 'PROTOCOLO DE CONTROL DE CALIDAD' },
        { type: 'project_meta' },
        { type: 'protocol_checks', showTolerances: true },
        { type: 'findings_summary' },
        { type: 'signatures' },
        { type: 'footer', legalText: 'Documento técnico oficial generado por Protokol QC. Validez técnica según R.N.E. y normas peruanas vigentes.' }
    ];

    for (const block of activeBlocks) {
        if (block.type === 'header') {
            // Render Header Block with Brand Accent Bar
            doc.rect(36, 36, 523, 5).fill(primaryColor);
            doc.moveDown(0.8);

            doc.fontSize(16).fillColor('#1A202C').font('Helvetica-Bold')
               .text(company.name.toUpperCase(), 36, 48, { width: 523, align: 'left' });

            if (company.ruc) {
                doc.fontSize(8).fillColor('#718096').font('Helvetica')
                   .text(`RUC: ${company.ruc}`, 36, 68);
            }

            doc.fontSize(13).fillColor(primaryColor).font('Helvetica-Bold')
               .text(block.title || 'PROTOCOLO DE CONTROL DE CALIDAD', 36, 82, { align: 'left' });

            doc.fontSize(10).fillColor('#2D3748').font('Helvetica-Bold')
               .text(`CÓDIGO: ${inspection.code}`, 36, 82, { align: 'right' });

            doc.moveTo(36, 102).lineTo(559, 102).strokeColor('#E2E8F0').lineWidth(1).stroke();
            doc.y = 110;

        } else if (block.type === 'project_meta') {
            // Project Meta Grid Table
            const startY = doc.y;
            doc.rect(36, startY, 523, 62).fillAndStroke('#F7FAFC', '#CBD5E0');
            
            doc.fillColor('#2D3748').fontSize(8.5).font('Helvetica-Bold');
            doc.text('OBRA / PROYECTO:', 44, startY + 8);
            doc.font('Helvetica').text(`${inspection.project_name} (${inspection.project_code})`, 140, startY + 8);

            doc.font('Helvetica-Bold').text('UBICACIÓN / ELEMENTO:', 44, startY + 22);
            doc.font('Helvetica').text(`${inspection.location_type?.toUpperCase() || 'NIVEL'}: ${inspection.location_name}`, 160, startY + 22);

            doc.font('Helvetica-Bold').text('FECHA DE INSPECCIÓN:', 44, startY + 36);
            doc.font('Helvetica').text(inspection.pour_date || inspection.created_at.split(' ')[0], 160, startY + 36);

            doc.font('Helvetica-Bold').text('RESPONSABLE CALIDAD:', 320, startY + 8);
            doc.font('Helvetica').text(inspection.inspector_name || 'Ing. Residente', 430, startY + 8);

            doc.font('Helvetica-Bold').text('ESTADO DEL PROTOCOLO:', 320, startY + 22);
            const statusColor = inspection.status === 'conforme' ? '#22543D' : (inspection.status === 'observado' ? '#9C4221' : '#2B6CB0');
            doc.fillColor(statusColor).font('Helvetica-Bold').text(inspection.status.toUpperCase(), 440, startY + 22);

            if (inspection.weather) {
                doc.fillColor('#2D3748').font('Helvetica-Bold').text('CLIMA / CONDICIONES:', 320, startY + 36);
                doc.font('Helvetica').text(inspection.weather, 435, startY + 36);
            }

            doc.y = startY + 74;

        } else if (block.type === 'protocol_checks') {
            // Protocol Checks Table Header
            doc.rect(36, doc.y, 523, 20).fill(primaryColor);
            doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
            doc.text('ITEM', 42, doc.y + 6);
            doc.text('VERIFICACIÓN TÉCNICA (NTE / PLANOS)', 90, doc.y + 6);
            doc.text('MEDICIÓN / TOLERANCIA', 360, doc.y + 6);
            doc.text('RESULTADO', 485, doc.y + 6);

            doc.y += 24;

            // Render answers
            let currentSection = '';
            for (const ans of (inspection.answers || [])) {
                if (ans.section && ans.section !== currentSection) {
                    currentSection = ans.section;
                    doc.rect(36, doc.y, 523, 16).fill('#EDF2F7');
                    doc.fillColor('#2D3748').fontSize(8).font('Helvetica-Bold')
                       .text(`SECCIÓN: ${currentSection.toUpperCase()}`, 42, doc.y + 4);
                    doc.y += 18;
                }

                const rowY = doc.y;
                doc.rect(36, rowY, 523, 22).fillAndStroke(rowY % 2 === 0 ? '#FFFFFF' : '#FAFAFA', '#E2E8F0');

                doc.fillColor('#4A5568').fontSize(7.5).font('Helvetica-Bold').text(ans.item_code || '', 42, rowY + 6);
                
                doc.font('Helvetica').fillColor('#1A202C')
                   .text(ans.question_text || '', 90, rowY + 5, { width: 260, height: 16, ellipsis: true });

                let measurementText = '-';
                if (ans.item_type === 'numeric_tolerance') {
                    measurementText = `${ans.numeric_value !== null ? ans.numeric_value : '-'} ${ans.unit || ''} (Tol: ${ans.tolerance_min}-${ans.tolerance_max})`;
                }
                doc.fillColor('#4A5568').text(measurementText, 360, rowY + 6, { width: 115, height: 16 });

                // Status tag
                let tagColor = '#718096';
                let tagBg = '#EDF2F7';
                let statusLabel = ans.status.toUpperCase();
                if (ans.status === 'conforme') {
                    tagColor = '#22543D';
                    tagBg = '#C6F6D5';
                    statusLabel = 'CONFORME';
                } else if (ans.status === 'no_conforme') {
                    tagColor = '#742A2A';
                    tagBg = '#FED7D7';
                    statusLabel = 'NO CONFORME';
                } else if (ans.status === 'no_aplica') {
                    statusLabel = 'N/A';
                }

                doc.rect(480, rowY + 4, 70, 14).fill(tagBg);
                doc.fillColor(tagColor).fontSize(7).font('Helvetica-Bold')
                   .text(statusLabel, 480, rowY + 7, { width: 70, align: 'center' });

                doc.y = rowY + 24;

                // Check page overflow
                if (doc.y > 700) {
                    doc.addPage();
                }
            }
            doc.moveDown(0.8);

        } else if (block.type === 'findings_summary' && inspection.findings && inspection.findings.length > 0) {
            if (doc.y > 650) doc.addPage();

            doc.rect(36, doc.y, 523, 18).fill('#C53030');
            doc.fillColor('#FFFFFF').fontSize(8.5).font('Helvetica-Bold')
               .text('HALLAZGOS Y NO CONFORMIDADES DETECTADAS (ACCIONES CORRECTIVAS)', 42, doc.y + 5);
            doc.y += 22;

            for (const f of inspection.findings) {
                const fY = doc.y;
                doc.rect(36, fY, 523, 34).strokeColor('#E2E8F0').lineWidth(1).stroke();
                
                doc.fillColor('#C53030').fontSize(8).font('Helvetica-Bold').text(`[${f.code}] ${f.title}`, 42, fY + 5);
                doc.fillColor('#4A5568').fontSize(7.5).font('Helvetica')
                   .text(`Plazo Subsanación: ${f.due_date} | Contratista: ${f.contractor_name || f.assigned_trade} | Severidad: ${f.severity.toUpperCase()} | Estado: ${f.status.toUpperCase()}`, 42, fY + 18);

                doc.y = fY + 38;
                if (doc.y > 720) doc.addPage();
            }
            doc.moveDown(0.8);

        } else if (block.type === 'signatures') {
            if (doc.y > 660) doc.addPage();

            doc.fontSize(9).font('Helvetica-Bold').fillColor('#2D3748').text('CONFORMIDAD TÉCNICA Y FIRMAS:', 36, doc.y);
            doc.moveDown(0.4);

            const sigY = doc.y;
            const colWidth = 160;

            // Box 1: Residente
            doc.rect(36, sigY, colWidth, 60).strokeColor('#CBD5E0').stroke();
            doc.fontSize(7).font('Helvetica').fillColor('#718096').text('RESIDENCIA DE OBRA', 36, sigY + 46, { width: colWidth, align: 'center' });
            doc.font('Helvetica-Bold').fillColor('#2D3748').text(inspection.resident_name || 'Ing. Residente Colegiado', 36, sigY + 34, { width: colWidth, align: 'center' });

            // Box 2: Calidad
            doc.rect(36 + colWidth + 21, sigY, colWidth, 60).strokeColor('#CBD5E0').stroke();
            doc.fontSize(7).font('Helvetica').fillColor('#718096').text('ESPECIALISTA DE CALIDAD', 36 + colWidth + 21, sigY + 46, { width: colWidth, align: 'center' });
            doc.font('Helvetica-Bold').fillColor('#2D3748').text(inspection.inspector_name || 'Especialista QC', 36 + colWidth + 21, sigY + 34, { width: colWidth, align: 'center' });

            // Box 3: ITO
            doc.rect(36 + (colWidth + 21) * 2, sigY, colWidth, 60).strokeColor('#CBD5E0').stroke();
            doc.fontSize(7).font('Helvetica').fillColor('#718096').text('INSPECCIÓN TÉCNICA (ITO)', 36 + (colWidth + 21) * 2, sigY + 46, { width: colWidth, align: 'center' });
            doc.font('Helvetica-Bold').fillColor('#2D3748').text(inspection.ito_name || 'Supervisión Externa', 36 + (colWidth + 21) * 2, sigY + 34, { width: colWidth, align: 'center' });

            doc.y = sigY + 70;

        } else if (block.type === 'footer') {
            const footerY = 790;
            doc.moveTo(36, footerY).lineTo(559, footerY).strokeColor('#E2E8F0').lineWidth(0.5).stroke();
            doc.fontSize(6.5).font('Helvetica').fillColor('#A0AEC0')
               .text(block.legalText || 'Documento técnico oficial generado por Protokol QC.', 36, footerY + 6, { width: 523, align: 'center' });
        }
    }

    doc.end();
}

module.exports = {
    generateInspectionPdf
};
