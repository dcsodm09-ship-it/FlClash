import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Reuse the auth flow's own fallback-contacts extraction instead of
// duplicating the `bootstrap().values['fallback_contacts']` parsing here.
import '../auth/auth_shell.dart' show extractFallbackContacts;
import '../hgfast_shared/hgfast_visual_kit.dart';

class _Announcement {
  const _Announcement({required this.title, this.body, this.url});

  final String title;
  final String? body;
  final String? url;
}

class _DiscoverData {
  const _DiscoverData({required this.announcements, required this.contacts});

  final List<_Announcement> announcements;
  final List<Map<String, Object?>> contacts;

  bool get isEmpty => announcements.isEmpty && contacts.isEmpty;
}

// Defensive parsing: the exact `/announcement` response shape has not been
// confirmed against the live backend from this client repo (only
// `fallback_contacts` on bootstrap() was verified for this task). We try the
// most likely container/field names below and simply skip any entry that
// doesn't at least carry a title, rather than inventing placeholder banner
// copy. An empty result renders the screen's real empty state — never a
// fabricated announcement.
// TODO: replace with a typed model once the announcement schema is
// confirmed against live backend source.
List<_Announcement> _parseAnnouncements(HgfastAnnouncementCatalog catalog) {
  final values = catalog.values;
  final raw =
      values['announcements'] ??
      values['items'] ??
      values['list'] ??
      values['data'];
  if (raw is! List) {
    return const [];
  }
  final result = <_Announcement>[];
  for (final entry in raw) {
    if (entry is! Map) {
      continue;
    }
    final map = entry.map((key, value) => MapEntry('$key', value));
    final title = (map['title'] ?? map['subject'] ?? map['headline'])
        ?.toString()
        .trim();
    if (title == null || title.isEmpty) {
      continue;
    }
    final body =
        (map['content'] ?? map['body'] ?? map['summary'] ?? map['description'])
            ?.toString();
    final url = (map['url'] ?? map['link'])?.toString();
    result.add(
      _Announcement(
        title: title,
        body: (body != null && body.trim().isNotEmpty) ? body.trim() : null,
        url: (url != null && url.trim().isNotEmpty) ? url.trim() : null,
      ),
    );
  }
  return result;
}

/// 发现 (Discover) screen: announcement carousel + common-links grid backed
/// by the real `announcements()` and `bootstrap().fallback_contacts` calls.
/// There is intentionally no "load/负载" indicator anywhere here — the
/// backend does not expose one on nodes.
class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  late Future<_DiscoverData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DiscoverData> _load() async {
    final repository = ref.read(hgfastRepositoryProvider);
    final announcementsResult = await repository.announcements();
    final bootstrapResult = await repository.bootstrap();
    final announcements = switch (announcementsResult) {
      HgfastResultSuccess<HgfastAnnouncementCatalog, HgfastError>(
        :final value,
      ) =>
        _parseAnnouncements(value),
      HgfastResultFailure<HgfastAnnouncementCatalog, HgfastError>() =>
        const <_Announcement>[],
    };
    final contacts = switch (bootstrapResult) {
      HgfastResultSuccess<HgfastBootstrap, HgfastError>(:final value) =>
        extractFallbackContacts(value),
      HgfastResultFailure<HgfastBootstrap, HgfastError>() =>
        const <Map<String, Object?>>[],
    };
    return _DiscoverData(announcements: announcements, contacts: contacts);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _dataFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return HgfastAuthScope(
      child: CommonScaffold(
        title: appLocalizations.discover,
        body: FutureBuilder<_DiscoverData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CommonCircleLoading());
            }
            final data =
                snapshot.data ??
                const _DiscoverData(announcements: [], contacts: []);
            if (data.isEmpty) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: NullStatus(
                        label: appLocalizations.nullTip(
                          appLocalizations.discover,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (data.announcements.isNotEmpty) ...[
                    Text('公告', style: context.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _AnnouncementCarousel(announcements: data.announcements),
                    const SizedBox(height: 24),
                  ],
                  if (data.contacts.isNotEmpty) ...[
                    Text('常用链接', style: context.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _ContactsGrid(contacts: data.contacts),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementCarousel extends StatefulWidget {
  const _AnnouncementCarousel({required this.announcements});

  final List<_Announcement> announcements;

  @override
  State<_AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<_AnnouncementCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: 0.92,
  );
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.announcements.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final announcement = widget.announcements[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: HgSurfaceCard(
                  onTap: announcement.url == null
                      ? null
                      : () => unawaited(globalState.openUrl(announcement.url!)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              gradient: HgfastGradients.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              announcement.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (announcement.body != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          announcement.body!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.announcements.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.announcements.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: i == _index ? HgfastGradients.brand : null,
                    color: i == _index
                        ? null
                        : context.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ContactsGrid extends StatelessWidget {
  const _ContactsGrid({required this.contacts});

  final List<Map<String, Object?>> contacts;

  IconData _iconFor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('mail')) return Icons.email_outlined;
    if (lower.contains('telegram')) return Icons.send_outlined;
    if (lower.contains('site') ||
        lower.contains('web') ||
        lower.contains('official')) {
      return Icons.language;
    }
    if (lower.contains('wechat')) return Icons.chat_bubble_outline;
    if (lower.contains('qq')) return Icons.forum_outlined;
    return Icons.link;
  }

  Uri? _resolveUri(Map<String, Object?> contact) {
    final type = (contact['type'] ?? '').toString();
    final value = (contact['value'] ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value);
    }
    final lowerType = type.toLowerCase();
    if (lowerType.contains('mail') ||
        (value.contains('@') && !value.contains('/'))) {
      return Uri(scheme: 'mailto', path: value);
    }
    if (lowerType.contains('telegram')) {
      final handle = value.startsWith('@') ? value.substring(1) : value;
      return Uri.tryParse('https://t.me/$handle');
    }
    return Uri.tryParse('https://$value');
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final type = (contact['type'] ?? '').toString();
        final label = (contact['label'] ?? contact['type'] ?? '').toString();
        final value = (contact['value'] ?? '').toString();
        final uri = _resolveUri(contact);
        return HgSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: uri == null
              ? null
              : () => unawaited(globalState.openUrl(uri.toString())),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: HgfastGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(type), size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.isEmpty ? value : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (label.isNotEmpty && value.isNotEmpty)
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
