import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/discover/discover_view.dart';
import 'package:fl_clash/pages/invite/invite_view.dart';
import 'package:fl_clash/pages/support/support_view.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool enableHgfast = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
      ),
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
      ),
      NavigationItem(
        icon: const Icon(Icons.view_timeline),
        label: PageLabel.requests,
        builder: (_) =>
            const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
        description: 'requestsDesc',
        modes: [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.ballot),
        label: PageLabel.connections,
        builder: (_) =>
            const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
        description: 'connectionsDesc',
        modes: [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.storage),
        label: PageLabel.resources,
        description: 'resourcesDesc',
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.adb),
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        description: 'logsDesc',
        modes: openLogs
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.power_settings_new),
        label: PageLabel.connect,
        builder: (_) =>
            const ConnectView(key: GlobalObjectKey(PageLabel.connect)),
        path: '/connect',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.explore),
        label: PageLabel.discover,
        builder: (_) =>
            const DiscoverView(key: GlobalObjectKey(PageLabel.discover)),
        path: '/discover',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.support_agent),
        label: PageLabel.support,
        builder: (_) =>
            const SupportView(key: GlobalObjectKey(PageLabel.support)),
        path: '/support',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.card_giftcard),
        label: PageLabel.invite,
        builder: (_) =>
            const InviteView(key: GlobalObjectKey(PageLabel.invite)),
        path: '/invite',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.person),
        label: PageLabel.account,
        builder: (_) =>
            const SizedBox.shrink(key: GlobalObjectKey(PageLabel.account)),
        path: '/account',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.workspace_premium),
        label: PageLabel.vip,
        builder: (_) =>
            const SizedBox.shrink(key: GlobalObjectKey(PageLabel.vip)),
        path: '/vip',
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.payments),
        label: PageLabel.plans,
        builder: (_) =>
            const SizedBox.shrink(key: GlobalObjectKey(PageLabel.plans)),
        path: '/plans',
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.menu_book),
        label: PageLabel.docs,
        builder: (_) =>
            const SizedBox.shrink(key: GlobalObjectKey(PageLabel.docs)),
        path: '/docs',
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
