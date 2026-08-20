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
        // Desktop-only. Was reachable on mobile via the "更多" drawer too,
        // but got swapped out for vip (see home.dart's _moreDrawerLabels) —
        // dashboard mostly duplicates stats already on the connect screen.
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
        // Reached on mobile via the "更多" drawer — see home.dart's
        // _moreDrawerLabels for the full current set.
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
        // Reached on mobile via the "更多" drawer — see home.dart's
        // _moreDrawerLabels for the full current set.
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
        // already kept out (see its own comment below). Desktop-only here;
        // dashboard/profiles/tools/support originally all moved into the
        // "更多" drawer together, but support was later swapped out for
        // vip/invite (revenue/growth entries, see home.dart's
        // _moreDrawerLabels) — support keeps a narrower path back via
        // Connect's access-gate CTAs (onContactSupport in connect.dart's
        // _ConnectAccessGate) instead of a drawer entry.
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.card_giftcard),
        label: PageLabel.invite,
        builder: (_) =>
            const InviteView(key: GlobalObjectKey(PageLabel.invite)),
        path: '/invite',
        // Not a bottom-nav destination on either platform (kept out of
        // `modes` entirely) — it's a one-off promo action, not a destination
        // someone returns to repeatedly like the 4 primary bottom-bar items.
        // It IS one of the mobile "更多" drawer's 4 entries though (see
        // home.dart's _moreDrawerLabels), and stays reachable via
        // BaseNavigator.push(...) from wherever else links out to it (e.g. a
        // "我的"/account hub).
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
        // Desktop rail only (unchanged), but also one of the mobile "更多"
        // drawer's 4 entries — see home.dart's _moreDrawerLabels.
        modes: enableHgfast ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.payments),
        label: PageLabel.plans,
        builder: (_) => const PlansView(key: GlobalObjectKey(PageLabel.plans)),
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

// Keyless counterparts of the pages `Navigation.getItems()` builds with a
// `GlobalObjectKey(label)` baked in. Anything pushed outside the PageView
// (the "更多" drawer, CurrentPageLabel.toPage's reachability fallback) must
// use these instead of `NavigationItem.builder` — reusing the keyed builder
// risks a duplicate-GlobalKey collision if the same label re-enters the
// PageView later (e.g. resizing across the mobile/desktop breakpoint while
// the pushed route is still open). Mirrors the keyless-push pattern
// account_view.dart's _ListRow already uses for the same reason.
Widget? pushablePage(PageLabel label) {
  return switch (label) {
    PageLabel.dashboard => const DashboardView(),
    PageLabel.profiles => const ProfilesView(),
    PageLabel.tools => const ToolsView(),
    PageLabel.support => const SupportView(),
    PageLabel.vip => const VipView(),
    PageLabel.invite => const InviteView(),
    _ => null,
  };
}
