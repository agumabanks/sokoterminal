import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import 'ad_templates.dart';
import 'campaign_manager.dart';
import 'campaign_models.dart';
import 'studio_theme.dart';

// ---------------------------------------------------------------------------
// Marketing Dashboard — 360° Marketing Shell
// ---------------------------------------------------------------------------

class MarketingDashboardScreen extends ConsumerWidget {
  const MarketingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsProvider);
    final analytics = ref.watch(marketingAnalyticsProvider);
    final theme = ref.watch(studioThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffold,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.surface,
            foregroundColor: theme.textPrimary,
            elevation: 0,
            title: Text(
              'Marketing Dashboard',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showCreateCampaignSheet(context, ref),
                icon: Icon(Icons.add_rounded, color: theme.accent),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Health Score Card ─────────────────────────────────────
                _HealthScoreCard(analytics: analytics, theme: theme),
                const SizedBox(height: 16),

                // ── Quick Stats Row ───────────────────────────────────────
                _StatsRow(analytics: analytics, theme: theme),
                const SizedBox(height: 24),

                // ── Next Best Action ──────────────────────────────────────
                _NextActionCard(analytics: analytics, theme: theme),
                const SizedBox(height: 24),

                // ── Active Campaigns ──────────────────────────────────────
                _SectionHeader(title: 'Campaigns', count: campaigns.length, theme: theme),
                const SizedBox(height: 10),
                if (campaigns.isEmpty)
                  _EmptyCampaigns(theme: theme)
                else
                  ...campaigns.take(5).map((c) => _CampaignCard(
                    campaign: c,
                    theme: theme,
                    onTap: () => _showCampaignDetail(context, ref, c),
                  )),
                const SizedBox(height: 24),

                // ── Upcoming Posts ────────────────────────────────────────
                _SectionHeader(title: 'This Week', theme: theme),
                const SizedBox(height: 10),
                _WeeklyCalendar(theme: theme),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCampaignSheet(BuildContext context, WidgetRef ref) {
    Haptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCampaignSheet(),
    );
  }

  void _showCampaignDetail(BuildContext context, WidgetRef ref, Campaign campaign) {
    Haptics.selection();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CampaignDetailScreen(campaign: campaign),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health Score Card
// ---------------------------------------------------------------------------

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.analytics, required this.theme});

  final MarketingAnalytics analytics;
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    final score = analytics.campaignHealthScore;
    final color = score >= 75
        ? const Color(0xFF22c55e)
        : score >= 50
            ? const Color(0xFFf59e0b)
            : const Color(0xFFef4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: theme.border,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaign Health',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 75
                      ? 'Your marketing is performing great!'
                      : score >= 50
                          ? 'Good progress. A few tweaks needed.'
                          : 'Let\'s get your marketing started.',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.analytics, required this.theme});

  final MarketingAnalytics analytics;
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Ads', analytics.designsCreatedThisMonth.toString(), Icons.auto_awesome_rounded),
      ('Active', analytics.activeCampaigns.toString(), Icons.campaign_rounded),
      ('Done', analytics.completedCampaigns.toString(), Icons.check_circle_rounded),
      ('Shares', analytics.totalShares.toString(), Icons.share_rounded),
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              children: [
                Icon(s.$3, color: theme.accent, size: 22),
                const SizedBox(height: 8),
                Text(
                  s.$2,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.$1,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Next Action Card
// ---------------------------------------------------------------------------

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.analytics, required this.theme});

  final MarketingAnalytics analytics;
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.accent, theme.accent.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Best Action',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  analytics.nextBestAction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, required this.theme});

  final String title;
  final int? count;
  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: theme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty Campaigns
// ---------------------------------------------------------------------------

class _EmptyCampaigns extends StatelessWidget {
  const _EmptyCampaigns({required this.theme});

  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, color: theme.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            'No campaigns yet',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first marketing campaign to track progress.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campaign Card
// ---------------------------------------------------------------------------

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.theme,
    required this.onTap,
  });

  final Campaign campaign;
  final StudioThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = parseHexColor(campaign.status.colorHex);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  campaign.goal.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campaign.name,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${campaign.goal.label} · ${campaign.status.label}',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                campaign.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Calendar
// ---------------------------------------------------------------------------

class _WeeklyCalendar extends StatelessWidget {
  const _WeeklyCalendar({required this.theme});

  final StudioThemeData theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: days.asMap().entries.map((entry) {
        final i = entry.key;
        final d = entry.value;
        final isToday = d.day == now.day && d.month == now.month;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? theme.accent.withValues(alpha: 0.15) : theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday ? theme.accent : theme.border,
              ),
            ),
            child: Column(
              children: [
                Text(
                  dayLabels[i],
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${d.day}',
                  style: TextStyle(
                    color: isToday ? theme.accent : theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Campaign Sheet
// ---------------------------------------------------------------------------

class _CreateCampaignSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateCampaignSheet> createState() => _CreateCampaignSheetState();
}

class _CreateCampaignSheetState extends ConsumerState<_CreateCampaignSheet> {
  final _nameCtrl = TextEditingController();
  CampaignGoal _goal = CampaignGoal.awareness;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(studioThemeProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffold,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'New Campaign',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Plan and track your marketing efforts.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Campaign Name',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Christmas Sale 2025',
                  hintStyle: TextStyle(color: theme.textMuted),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Campaign Goal',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CampaignGoal.values.map((g) {
                  final selected = g == _goal;
                  return ChoiceChip(
                    label: Text('${g.emoji} ${g.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _goal = g),
                    selectedColor: theme.accent,
                    backgroundColor: theme.surface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : theme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: theme.border),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _createCampaign(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Create Campaign',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createCampaign(BuildContext context) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final campaign = Campaign(
      id: 'camp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      goal: _goal,
      startDate: DateTime.now(),
      status: CampaignStatus.active,
      createdAt: DateTime.now(),
    );

    ref.read(campaignsProvider.notifier).add(campaign);
    Navigator.pop(context);
  }
}

// ---------------------------------------------------------------------------
// Campaign Detail Screen
// ---------------------------------------------------------------------------

class _CampaignDetailScreen extends ConsumerWidget {
  const _CampaignDetailScreen({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(studioThemeProvider);
    final statusColor = parseHexColor(campaign.status.colorHex);

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        backgroundColor: theme.surface,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        title: Text(
          campaign.name,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.textMuted),
            onSelected: (value) {
              if (value == 'delete') {
                ref.read(campaignsProvider.notifier).delete(campaign.id);
                Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    campaign.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    campaign.goal.label,
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Started: ${_fmtDate(campaign.startDate)}',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
            if (campaign.endDate != null)
              Text(
                'Ends: ${_fmtDate(campaign.endDate!)}',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${campaign.durationDays} days',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Text(
              'Ads in this campaign',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (campaign.templateIds.isEmpty)
              Text(
                'No ads added yet. Create ads in the Studio and add them here.',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              )
            else
              ...campaign.templateIds.map((id) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Text(
                  'Ad: $id',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}
