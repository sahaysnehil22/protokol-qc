import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('protokol_qc_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Projects Cache
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        district TEXT,
        resident_name TEXT,
        ito_name TEXT,
        status TEXT
      )
    ''');

    // Locations Cache
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        parent_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        code TEXT,
        sort_order INTEGER
      )
    ''');

    // Templates Cache
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        family TEXT NOT NULL,
        code TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        version INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE template_items (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        section TEXT NOT NULL,
        order_index INTEGER,
        code TEXT NOT NULL,
        question_text TEXT NOT NULL,
        item_type TEXT NOT NULL,
        tolerance_min REAL,
        tolerance_max REAL,
        unit TEXT,
        is_critical INTEGER
      )
    ''');

    // Inspections Cache
    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        location_id TEXT NOT NULL,
        template_id TEXT NOT NULL,
        code TEXT NOT NULL,
        status TEXT NOT NULL,
        pour_date TEXT,
        batch_number TEXT,
        weather TEXT,
        general_notes TEXT,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE inspection_answers (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        status TEXT NOT NULL,
        numeric_value REAL,
        observation_text TEXT,
        photo_urls_json TEXT
      )
    ''');

    // Findings Cache
    await db.execute('''
      CREATE TABLE findings (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        inspection_id TEXT,
        answer_id TEXT,
        location_id TEXT NOT NULL,
        code TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        assigned_contractor_id TEXT,
        assigned_trade TEXT NOT NULL,
        due_date TEXT NOT NULL,
        initial_photo_url TEXT,
        resolution_photo_url TEXT,
        resolution_notes TEXT,
        resolved_at TEXT,
        verified_at TEXT
      )
    ''');

    // Signatures Cache
    await db.execute('''
      CREATE TABLE signatures (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        signer_id TEXT NOT NULL,
        signer_name TEXT NOT NULL,
        signer_role TEXT NOT NULL,
        signature_data TEXT NOT NULL,
        signed_at TEXT NOT NULL
      )
    ''');

    // Sync Queue (Offline Operation Outbox)
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        client_op_id TEXT UNIQUE NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        client_timestamp TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  // Projects CRUD
  Future<void> saveProjects(List<Project> projects) async {
    final db = await database;
    final batch = db.batch();
    for (final p in projects) {
      batch.insert('projects', p.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Project>> getProjects() async {
    final db = await database;
    final maps = await db.query('projects');
    return maps.map((m) => Project.fromJson(m)).toList();
  }

  // Locations CRUD
  Future<void> saveLocations(List<LocationNode> locations) async {
    final db = await database;
    final batch = db.batch();
    for (final loc in locations) {
      batch.insert('locations', loc.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<LocationNode>> getLocations(String projectId) async {
    final db = await database;
    final maps = await db.query(
      'locations',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'type ASC, name ASC',
    );
    return maps.map((m) => LocationNode.fromJson(m)).toList();
  }

  // Templates CRUD
  Future<void> saveTemplates(List<InspectionTemplate> templates) async {
    final db = await database;
    final batch = db.batch();
    for (final t in templates) {
      batch.insert('templates', t.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in t.items) {
        batch.insert('template_items', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<InspectionTemplate>> getTemplates() async {
    final db = await database;
    final tmpls = await db.query('templates');
    final List<InspectionTemplate> result = [];
    for (final t in tmpls) {
      final items = await db.query(
        'template_items',
        where: 'template_id = ?',
        whereArgs: [t['id']],
        orderBy: 'order_index ASC',
      );
      result.add(InspectionTemplate(
        id: t['id'] as String,
        family: t['family'] as String,
        code: t['code'] as String,
        title: t['title'] as String,
        description: t['description'] as String?,
        version: (t['version'] as num?)?.toInt() ?? 1,
        items: items.map((i) => TemplateItem.fromJson(i)).toList(),
      ));
    }
    return result;
  }

  // Inspections CRUD
  Future<void> saveInspection(Inspection inspection) async {
    final db = await database;
    await db.insert('inspections', inspection.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final ans in inspection.answers) {
      batch.insert('inspection_answers', {
        'id': ans.id,
        'inspection_id': ans.inspectionId,
        'item_id': ans.itemId,
        'status': ans.status,
        'numeric_value': ans.numericValue,
        'observation_text': ans.observationText,
        'photo_urls_json': jsonEncode(ans.photoUrls),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Inspection>> getInspections(String projectId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.*, p.name as project_name, l.name as location_name, t.title as template_title
      FROM inspections i
      LEFT JOIN projects p ON i.project_id = p.id
      LEFT JOIN locations l ON i.location_id = l.id
      LEFT JOIN templates t ON i.template_id = t.id
      WHERE i.project_id = ?
      ORDER BY i.code DESC
    ''', [projectId]);

    final List<Inspection> inspections = [];
    for (final m in maps) {
      final answers = await db.query('inspection_answers', where: 'inspection_id = ?', whereArgs: [m['id']]);
      inspections.add(Inspection(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        locationId: m['location_id'] as String,
        templateId: m['template_id'] as String,
        code: m['code'] as String,
        status: m['status'] as String,
        pourDate: m['pour_date'] as String?,
        batchNumber: m['batch_number'] as String?,
        weather: m['weather'] as String?,
        generalNotes: m['general_notes'] as String?,
        projectName: m['project_name'] as String?,
        locationName: m['location_name'] as String?,
        templateTitle: m['template_title'] as String?,
        answers: answers.map((a) => InspectionAnswer.fromJson({
          ...a,
          'photo_urls_json': a['photo_urls_json'] != null ? jsonDecode(a['photo_urls_json'] as String) : [],
        })).toList(),
      ));
    }
    return inspections;
  }

  // Findings CRUD
  Future<void> saveFindings(List<Finding> findings) async {
    final db = await database;
    final batch = db.batch();
    for (final f in findings) {
      batch.insert('findings', f.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Finding>> getFindings({String? projectId, String? contractorId}) async {
    final db = await database;
    String query = '''
      SELECT f.*, p.name as project_name, l.name as location_name
      FROM findings f
      LEFT JOIN projects p ON f.project_id = p.id
      LEFT JOIN locations l ON f.location_id = l.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    if (projectId != null) {
      query += ' AND f.project_id = ?';
      args.add(projectId);
    }
    if (contractorId != null) {
      query += ' AND f.assigned_contractor_id = ?';
      args.add(contractorId);
    }
    query += ' ORDER BY f.due_date ASC, f.code DESC';
    final maps = await db.rawQuery(query, args);
    return maps.map((m) => Finding.fromJson(m)).toList();
  }

  Future<void> updateFinding(Finding finding) async {
    final db = await database;
    await db.update('findings', finding.toJson(), where: 'id = ?', whereArgs: [finding.id]);
  }

  // Offline Operation Outbox
  Future<void> queueOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final opId = const Uuid().v4();
    await db.insert('sync_queue', {
      'id': opId,
      'client_op_id': 'op-$opId',
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'client_timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'client_timestamp ASC',
    );
  }

  Future<void> markOperationsSynced(List<String> clientOpIds) async {
    final db = await database;
    for (final id in clientOpIds) {
      await db.delete('sync_queue', where: 'client_op_id = ?', whereArgs: [id]);
    }
  }

  Future<int> getPendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue WHERE status = ?', ['pending']);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
