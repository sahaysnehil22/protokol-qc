class User {
  final String id;
  final String companyId;
  final String email;
  final String fullName;
  final String role; // admin, residente, calidad, contratista, cliente_ito
  final String? tradeSpecialty;
  final String? companyName;
  final String? brandColor;

  User({
    required this.id,
    required this.companyId,
    required this.email,
    required this.fullName,
    required this.role,
    this.tradeSpecialty,
    this.companyName,
    this.brandColor,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      companyId: json['company_id'] ?? json['company']?['id'] ?? '',
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      tradeSpecialty: json['trade_specialty'],
      companyName: json['company_name'] ?? json['company']?['name'],
      brandColor: json['brand_color'] ?? json['company']?['brand_color'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'email': email,
    'full_name': fullName,
    'role': role,
    'trade_specialty': tradeSpecialty,
    'company_name': companyName,
    'brand_color': brandColor,
  };
}

class Project {
  final String id;
  final String code;
  final String name;
  final String? address;
  final String? district;
  final String? residentName;
  final String? itoName;
  final String status;

  Project({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.district,
    this.residentName,
    this.itoName,
    this.status = 'activo',
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      address: json['address'],
      district: json['district'],
      residentName: json['resident_name'],
      itoName: json['ito_name'],
      status: json['status'] ?? 'activo',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'address': address,
    'district': district,
    'resident_name': residentName,
    'ito_name': itoName,
    'status': status,
  };
}

class LocationNode {
  final String id;
  final String projectId;
  final String? parentId;
  final String name;
  final String type; // torre, bloque, sotano, piso, departamento, area_comun
  final String? code;
  final List<LocationNode> children;

  LocationNode({
    required this.id,
    required this.projectId,
    this.parentId,
    required this.name,
    required this.type,
    this.code,
    this.children = const [],
  });

  factory LocationNode.fromJson(Map<String, dynamic> json) {
    return LocationNode(
      id: json['id'],
      projectId: json['project_id'],
      parentId: json['parent_id'],
      name: json['name'],
      type: json['type'],
      code: json['code'],
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => LocationNode.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'parent_id': parentId,
    'name': name,
    'type': type,
    'code': code,
  };
}

class TemplateItem {
  final String id;
  final String templateId;
  final String section;
  final int orderIndex;
  final String code;
  final String questionText;
  final String itemType; // conforme_no_conforme, numeric_tolerance, photo_required, text_observation
  final double? toleranceMin;
  final double? toleranceMax;
  final String? unit;
  final bool isCritical;

  TemplateItem({
    required this.id,
    required this.templateId,
    required this.section,
    required this.orderIndex,
    required this.code,
    required this.questionText,
    required this.itemType,
    this.toleranceMin,
    this.toleranceMax,
    this.unit,
    this.isCritical = false,
  });

  factory TemplateItem.fromJson(Map<String, dynamic> json) {
    return TemplateItem(
      id: json['id'],
      templateId: json['template_id'],
      section: json['section'] ?? 'General',
      orderIndex: json['order_index'] ?? 0,
      code: json['code'],
      questionText: json['question_text'],
      itemType: json['item_type'],
      toleranceMin: json['tolerance_min'] != null ? (json['tolerance_min'] as num).toDouble() : null,
      toleranceMax: json['tolerance_max'] != null ? (json['tolerance_max'] as num).toDouble() : null,
      unit: json['unit'],
      isCritical: json['is_critical'] == 1 || json['is_critical'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'template_id': templateId,
    'section': section,
    'order_index': orderIndex,
    'code': code,
    'question_text': questionText,
    'item_type': itemType,
    'tolerance_min': toleranceMin,
    'tolerance_max': toleranceMax,
    'unit': unit,
    'is_critical': isCritical ? 1 : 0,
  };
}

class InspectionTemplate {
  final String id;
  final String family; // concreto, acero, encofrado, topografia, acabados, recepcion
  final String code;
  final String title;
  final String? description;
  final int version;
  final List<TemplateItem> items;

  InspectionTemplate({
    required this.id,
    required this.family,
    required this.code,
    required this.title,
    this.description,
    this.version = 1,
    this.items = const [],
  });

  factory InspectionTemplate.fromJson(Map<String, dynamic> json) {
    return InspectionTemplate(
      id: json['id'],
      family: json['family'],
      code: json['code'],
      title: json['title'],
      description: json['description'],
      version: json['version'] ?? 1,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => TemplateItem.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'family': family,
    'code': code,
    'title': title,
    'description': description,
    'version': version,
  };
}

class InspectionAnswer {
  final String id;
  final String inspectionId;
  final String itemId;
  String status; // conforme, no_conforme, no_aplica, pendiente
  double? numericValue;
  String? observationText;
  List<String> photoUrls;

  InspectionAnswer({
    required this.id,
    required this.inspectionId,
    required this.itemId,
    this.status = 'pendiente',
    this.numericValue,
    this.observationText,
    this.photoUrls = const [],
  });

  factory InspectionAnswer.fromJson(Map<String, dynamic> json) {
    List<String> photos = [];
    if (json['photo_urls_json'] != null) {
      try {
        photos = List<String>.from(json['photo_urls_json']);
      } catch (_) {}
    }
    return InspectionAnswer(
      id: json['id'],
      inspectionId: json['inspection_id'],
      itemId: json['item_id'],
      status: json['status'] ?? 'pendiente',
      numericValue: json['numeric_value'] != null ? (json['numeric_value'] as num).toDouble() : null,
      observationText: json['observation_text'],
      photoUrls: photos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspection_id': inspectionId,
    'item_id': itemId,
    'status': status,
    'numeric_value': numericValue,
    'observation_text': observationText,
    'photo_urls_json': photoUrls,
  };
}

class Inspection {
  final String id;
  final String projectId;
  final String locationId;
  final String templateId;
  final String code;
  String status; // borrador, en_revision, conforme, observado, cerrado
  String? pourDate;
  String? batchNumber;
  String? weather;
  String? generalNotes;
  String? projectName;
  String? locationName;
  String? templateTitle;
  String? inspectorName;
  List<InspectionAnswer> answers;

  Inspection({
    required this.id,
    required this.projectId,
    required this.locationId,
    required this.templateId,
    required this.code,
    this.status = 'borrador',
    this.pourDate,
    this.batchNumber,
    this.weather,
    this.generalNotes,
    this.projectName,
    this.locationName,
    this.templateTitle,
    this.inspectorName,
    this.answers = const [],
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'],
      projectId: json['project_id'],
      locationId: json['location_id'],
      templateId: json['template_id'],
      code: json['code'],
      status: json['status'] ?? 'borrador',
      pourDate: json['pour_date'],
      batchNumber: json['batch_number'],
      weather: json['weather'],
      generalNotes: json['general_notes'],
      projectName: json['project_name'],
      locationName: json['location_name'],
      templateTitle: json['template_title'],
      inspectorName: json['inspector_name'],
      answers: (json['answers'] as List<dynamic>? ?? [])
          .map((a) => InspectionAnswer.fromJson(a))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'location_id': locationId,
    'template_id': templateId,
    'code': code,
    'status': status,
    'pour_date': pourDate,
    'batch_number': batchNumber,
    'weather': weather,
    'general_notes': generalNotes,
  };
}

class Finding {
  final String id;
  final String projectId;
  final String? inspectionId;
  final String locationId;
  final String code;
  final String title;
  final String description;
  final String severity; // leve, moderado, critico
  String status; // abierto, en_proceso, cerrado_con_evidencia, verificado
  final String? assignedContractorId;
  final String assignedTrade;
  final String dueDate;
  final String? initialPhotoUrl;
  String? resolutionPhotoUrl;
  String? resolutionNotes;
  String? resolvedAt;
  String? verifiedAt;
  final String? projectName;
  final String? locationName;
  final String? contractorName;
  final bool isOverdue;

  Finding({
    required this.id,
    required this.projectId,
    this.inspectionId,
    required this.locationId,
    required this.code,
    required this.title,
    required this.description,
    this.severity = 'moderado',
    this.status = 'abierto',
    this.assignedContractorId,
    required this.assignedTrade,
    required this.dueDate,
    this.initialPhotoUrl,
    this.resolutionPhotoUrl,
    this.resolutionNotes,
    this.resolvedAt,
    this.verifiedAt,
    this.projectName,
    this.locationName,
    this.contractorName,
    this.isOverdue = false,
  });

  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      id: json['id'],
      projectId: json['project_id'],
      inspectionId: json['inspection_id'],
      locationId: json['location_id'],
      code: json['code'],
      title: json['title'],
      description: json['description'],
      severity: json['severity'] ?? 'moderado',
      status: json['status'] ?? 'abierto',
      assignedContractorId: json['assigned_contractor_id'],
      assignedTrade: json['assigned_trade'] ?? 'General',
      dueDate: json['due_date'] ?? '',
      initialPhotoUrl: json['initial_photo_url'],
      resolutionPhotoUrl: json['resolution_photo_url'],
      resolutionNotes: json['resolution_notes'],
      resolvedAt: json['resolved_at'],
      verifiedAt: json['verified_at'],
      projectName: json['project_name'],
      locationName: json['location_name'],
      contractorName: json['contractor_name'],
      isOverdue: json['is_overdue'] == 1 || json['is_overdue'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'inspection_id': inspectionId,
    'location_id': locationId,
    'code': code,
    'title': title,
    'description': description,
    'severity': severity,
    'status': status,
    'assigned_contractor_id': assignedContractorId,
    'assigned_trade': assignedTrade,
    'due_date': dueDate,
    'initial_photo_url': initialPhotoUrl,
    'resolution_photo_url': resolutionPhotoUrl,
    'resolution_notes': resolutionNotes,
  };
}
