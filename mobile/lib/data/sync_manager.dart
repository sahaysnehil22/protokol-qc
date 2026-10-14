import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'local_db.dart';

class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager._init();
  SyncManager._init();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;
  String? _errorMessage;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    // Initial connectivity check
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      notifyListeners();
      
      // Auto-flush queue when coming back online
      if (!wasOnline && _isOnline) {
        syncNow();
      }
    });

    await refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await LocalDatabase.instance.getPendingOperationsCount();
    notifyListeners();
  }

  Future<bool> syncNow() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check connectivity
      final results = await _connectivity.checkConnectivity();
      _isOnline = !results.contains(ConnectivityResult.none);
      if (!_isOnline) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      // 2. Push pending operations in outbox
      final pendingOps = await LocalDatabase.instance.getPendingOperations();
      if (pendingOps.isNotEmpty) {
        final opsPayload = pendingOps.map((op) => {
          'client_op_id': op['client_op_id'],
          'entity_type': op['entity_type'],
          'entity_id': op['entity_id'],
          'operation': op['operation'],
          'payload': jsonDecode(op['payload_json'] as String),
          'client_timestamp': op['client_timestamp'],
        }).toList();

        final pushResponse = await ApiClient.instance.post('/sync/push', {
          'operations': opsPayload,
        });

        if (pushResponse.statusCode == 200) {
          final resData = jsonDecode(pushResponse.body);
          final appliedOps = (resData['applied'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          await LocalDatabase.instance.markOperationsSynced(appliedOps);
        } else {
          _errorMessage = 'Error en push sync: ${pushResponse.statusCode}';
        }
      }

      // 3. Delta pull from server
      final pullResponse = await ApiClient.instance.get('/sync/pull');
      if (pullResponse.statusCode == 200) {
        final data = jsonDecode(pullResponse.body);
        
        // Cache projects
        if (data['projects'] != null) {
          final projects = (data['projects'] as List<dynamic>).map((p) => Project.fromJson(p)).toList();
          await LocalDatabase.instance.saveProjects(projects);
        }

        // Cache templates
        if (data['templates'] != null) {
          final templates = (data['templates'] as List<dynamic>).map((t) => InspectionTemplate.fromJson(t)).toList();
          await LocalDatabase.instance.saveTemplates(templates);
        }

        // Cache findings
        if (data['findings'] != null) {
          final findings = (data['findings'] as List<dynamic>).map((f) => Finding.fromJson(f)).toList();
          await LocalDatabase.instance.saveFindings(findings);
        }
      }

      _lastSyncTime = DateTime.now();
      await refreshPendingCount();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
