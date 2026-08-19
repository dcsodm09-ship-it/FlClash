import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/account/account_view.dart';
import 'package:fl_clash/pages/discover/discover_view.dart';
import 'package:fl_clash/pages/docs/docs_view.dart';
import 'package:fl_clash/pages/invite/invite_view.dart';
import 'package:fl_clash/pages/plans/plans_view.dart';
import 'package:fl_clash/pages/support/support_view.dart';
import 'package:fl_clash/pages/vip/vip_view.dart';
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
        // Reached on mobile via the "更多" drawer (see home.dart _MoreDrawer)
        // instead of a bottom-nav tab — see the `support` comment below for
        // why the mobile bar needs to stay short.
        modes: const [NavigationItemMode.desktop],
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
        // Reached on mobile via the "更多" drawer — see the `dashboard`/
        // `support` comments above and below.
        modes: const [NavigationItemMode.desktop],
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
        // Reached on mobile via the "更多" drawer — see the `dashboard`/
        // `support` comments above/below.
        modes: const [NavigationItemMode.desktop],
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
        // Mobile's NavigationBar was carrying 8 destinations (dashboard,
        // proxies, profiles, tools, connect, discover, support, account) —
        // well past Material 3's 3-5 guidance even after `invite` was
        // already kept out (see its own comment below). dashboard/profiles/
        // tools/support move to desktop-only here and become reachable on
        // mobile through the new "更多" drawer item in home.dart's
        // _MoreDrawer instead, leaving connect/proxies/discover/account as
        // the 4 primary bottom-bar destinations.
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.card_giftcard),
        label: PageLabel.invite,
        builder: (_) =>
            const InviteView(key: GlobalObjectKey(PageLabel.invite)),
        path: '/invite',
        // Deliberately not a bottom-nav destination. The mobile bar is now
        // just connect/proxies/discover/account (dashboard/profiles/tools/
        // support moved to the "更多" drawer, see the `support` comment
        // above) — but invite still doesn't get a 5th slot: it's a one-off
        // promo action, not a destination someone returns to repeatedly like
        // the other four, so it stays reachable via BaseNavigator.push(...)
        // from wherever a "我的"/account hub links out to it instead.
        modes: const [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.person),
        label: PageLabel.account,
        builder: (_) =>
            const AccountView(key: GlobalObjectKey(PageLabel.account)),
        path: '/account',
        modes: enableHgfast
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.workspace_premium),
        label: PageLabel.vip,
        builder: (_) => const VipView(key: GlobalObjectKey(PageLabel.vip)),
        path: '/vip',
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.payments),
        label: PageLabel.plans,
        builder: (_) =>
            const PlansView(key: GlobalObjectKey(PageLabel.plans)),
        path: '/plans',
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.menu_book),
        label: PageLabel.docs,
        builder: (_) => const DocsView(key: GlobalObjectKey(PageLabel.docs)),
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
