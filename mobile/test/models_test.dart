import 'package:flutter_test/flutter_test.dart';
import 'package:protokol_qc/models/models.dart';

void main() {
  group('Protokol QC Models & Logic Tests', () {
    test('Inspection serialization and round-trip conversion', () {
      final inspection = Inspection(
        id: 'insp-001',
        projectId: 'proj-001',
        locationId: 'loc-001',
        templateId: 'tmpl-001',
        code: 'PROT-2026-1001',
        status: 'conforme',
        pourDate: '15/10/2026',
        batchNumber: 'MIX-UNICON-9421',
        weather: 'Soleado 21°C',
        generalNotes: 'Vaciado ejecutado de acuerdo a planos E-04',
        answers: [
          InspectionAnswer(
            id: 'ans-001',
            inspectionId: 'insp-001',
            itemId: 'item-001',
            status: 'conforme',
            numericValue: 4.0,
            observationText: 'Slump conforme 4 pulgadas',
          ),
        ],
      );

      final json = inspection.toJson();
      expect(json['code'], 'PROT-2026-1001');
      expect(json['status'], 'conforme');
      expect(json['pour_date'], '15/10/2026');

      final deserialized = Inspection.fromJson({
        ...json,
        'answers': inspection.answers.map((a) => a.toJson()).toList(),
      });

      expect(deserialized.id, 'insp-001');
      expect(deserialized.answers.length, 1);
      expect(deserialized.answers.first.numericValue, 4.0);
    });

    test('Finding (Hallazgo) status flow and contractor isolation properties', () {
      final finding = Finding(
        id: 'hal-001',
        projectId: 'proj-001',
        locationId: 'loc-piso-2',
        code: 'HAL-2026-0042',
        title: 'Recubrimiento insuficiente en acero de placa',
        description: 'Separadores plásticos ausentes en cara exterior',
        severity: 'critico',
        status: 'abierto',
        assignedContractorId: 'usr-contratista-estructuras',
        assignedTrade: 'Fierrería',
        dueDate: '16/10/2026',
        projectName: 'Edificio Residencial Las Palmeras',
        locationName: 'Piso 2 - Placa PL-01',
      );

      expect(finding.status, 'abierto');
      expect(finding.severity, 'critico');
      expect(finding.assignedContractorId, 'usr-contratista-estructuras');

      // Transition to cerrado_con_evidencia
      finding.status = 'cerrado_con_evidencia';
      finding.resolutionPhotoUrl = 'https://storage.protokol.pe/res-001.jpg';
      finding.resolutionNotes = 'Se colocaron dados de concreto de 2.5cm según NTE E.060';

      expect(finding.status, 'cerrado_con_evidencia');
      expect(finding.resolutionNotes, isNotNull);
      expect(finding.resolutionPhotoUrl, contains('.jpg'));
    });

    test('TemplateItem numeric tolerance validation logic', () {
      final slumpItem = TemplateItem(
        id: 'item-slump',
        templateId: 'tmpl-conc',
        section: 'Concreto Fresco',
        orderIndex: 1,
        code: 'CONC-02',
        questionText: 'Asentamiento (Slump) ASTM C143',
        itemType: 'numeric_tolerance',
        toleranceMin: 3.0,
        toleranceMax: 5.0,
        unit: 'pulgadas',
        isCritical: true,
      );

      expect(slumpItem.isCritical, true);
      expect(slumpItem.toleranceMin, 3.0);
      expect(slumpItem.toleranceMax, 5.0);

      // Value in range
      double testVal1 = 4.0;
      bool isConforme1 = testVal1 >= slumpItem.toleranceMin! && testVal1 <= slumpItem.toleranceMax!;
      expect(isConforme1, true);

      // Value out of range
      double testVal2 = 6.5;
      bool isConforme2 = testVal2 >= slumpItem.toleranceMin! && testVal2 <= slumpItem.toleranceMax!;
      expect(isConforme2, false);
    });
  });
}
