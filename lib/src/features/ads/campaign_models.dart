

// ---------------------------------------------------------------------------
// Campaign Models — 360° Marketing Shell
// ---------------------------------------------------------------------------

enum CampaignStatus { draft, active, paused, completed }

enum CampaignGoal { awareness, conversion, engagement, loyalty, launch }

extension CampaignStatusX on CampaignStatus {
  String get label => switch (this) {
    CampaignStatus.draft => 'Draft',
    CampaignStatus.active => 'Active',
    CampaignStatus.paused => 'Paused',
    CampaignStatus.completed => 'Completed',
  };

  String get colorHex => switch (this) {
    CampaignStatus.draft => '#64748b',
    CampaignStatus.active => '#22c55e',
    CampaignStatus.paused => '#f59e0b',
    CampaignStatus.completed => '#3b82f6',
  };
}

extension CampaignGoalX on CampaignGoal {
  String get label => switch (this) {
    CampaignGoal.awareness => 'Brand Awareness',
    CampaignGoal.conversion => 'Drive Sales',
    CampaignGoal.engagement => 'Engagement',
    CampaignGoal.loyalty => 'Customer Loyalty',
    CampaignGoal.launch => 'Product Launch',
  };

  String get emoji => switch (this) {
    CampaignGoal.awareness => '📢',
    CampaignGoal.conversion => '💰',
    CampaignGoal.engagement => '💬',
    CampaignGoal.loyalty => '❤️',
    CampaignGoal.launch => '🚀',
  };
}

class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.goal,
    required this.startDate,
    this.endDate,
    this.status = CampaignStatus.draft,
    this.templateIds = const [],
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final CampaignGoal goal;
  final DateTime startDate;
  final DateTime? endDate;
  final CampaignStatus status;
  final List<String> templateIds;
  final String notes;
  final DateTime? createdAt;

  bool get isActive => status == CampaignStatus.active;
  bool get isCompleted => status == CampaignStatus.completed;

  int get durationDays {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate).inDays;
  }

  Campaign copyWith({
    String? name,
    CampaignGoal? goal,
    DateTime? startDate,
    DateTime? endDate,
    CampaignStatus? status,
    List<String>? templateIds,
    String? notes,
  }) => Campaign(
    id: id,
    name: name ?? this.name,
    goal: goal ?? this.goal,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
    templateIds: templateIds ?? this.templateIds,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'goal': goal.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status.name,
    'templateIds': templateIds,
    'notes': notes,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? 'Untitled',
    goal: CampaignGoal.values.firstWhere(
      (g) => g.name == j['goal'],
      orElse: () => CampaignGoal.awareness,
    ),
    startDate: DateTime.tryParse(j['startDate']?.toString() ?? '') ?? DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.tryParse(j['endDate'].toString()) : null,
    status: CampaignStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => CampaignStatus.draft,
    ),
    templateIds: (j['templateIds'] as List? ?? []).map((e) => e.toString()).toList(),
    notes: j['notes']?.toString() ?? '',
    createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
  );
}

// ---------------------------------------------------------------------------
// Scheduled Post / Content Calendar Entry
// ---------------------------------------------------------------------------

class ScheduledPost {
  const ScheduledPost({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.scheduledDate,
    this.platform = 'whatsapp',
    this.templateId,
    this.caption,
    this.isCompleted = false,
  });

  final String id;
  final String campaignId;
  final String title;
  final DateTime scheduledDate;
  final String platform;
  final String? templateId;
  final String? caption;
  final bool isCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'title': title,
    'scheduledDate': scheduledDate.toIso8601String(),
    'platform': platform,
    'templateId': templateId,
    'caption': caption,
    'isCompleted': isCompleted,
  };

  factory ScheduledPost.fromJson(Map<String, dynamic> j) => ScheduledPost(
    id: j['id']?.toString() ?? '',
    campaignId: j['campaignId']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    scheduledDate: DateTime.tryParse(j['scheduledDate']?.toString() ?? '') ?? DateTime.now(),
    platform: j['platform']?.toString() ?? 'whatsapp',
    templateId: j['templateId']?.toString(),
    caption: j['caption']?.toString(),
    isCompleted: j['isCompleted'] as bool? ?? false,
  );
}

// ---------------------------------------------------------------------------
// Marketing Analytics Snapshot
// ---------------------------------------------------------------------------

class MarketingAnalytics {
  const MarketingAnalytics({
    this.designsCreatedThisWeek = 0,
    this.designsCreatedThisMonth = 0,
    this.totalShares = 0,
    this.totalDownloads = 0,
    this.activeCampaigns = 0,
    this.completedCampaigns = 0,
    this.topTemplateId,
    this.topTemplateUses = 0,
    this.brandKitScore = 0,
  });

  final int designsCreatedThisWeek;
  final int designsCreatedThisMonth;
  final int totalShares;
  final int totalDownloads;
  final int activeCampaigns;
  final int completedCampaigns;
  final String? topTemplateId;
  final int topTemplateUses;
  final int brandKitScore;

  int get campaignHealthScore {
    var score = 0;
    if (designsCreatedThisMonth >= 10) score += 25;
    if (totalShares >= 5) score += 25;
    if (activeCampaigns >= 1) score += 25;
    if (brandKitScore >= 60) score += 25;
    return score;
  }

  String get nextBestAction {
    if (brandKitScore < 40) return 'Complete your Brand Kit';
    if (designsCreatedThisMonth < 5) return 'Create your first campaign ad';
    if (activeCampaigns == 0) return 'Start a marketing campaign';
    if (totalShares < 3) return 'Share your designs on social media';
    return 'Great job! Keep creating content';
  }
}
