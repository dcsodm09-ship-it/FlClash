import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import '../hgfast_shared/hgfast_visual_kit.dart';

// 文档中心 (docs center) screen.
//
// There is no docs/CMS backend anywhere in this codebase (confirmed:
// HgfastRepository has no docs()/faq() method, and grepping the live
// backend's client_api handlers for anything doc-related turns up nothing)
// — the design-kit mockup's FAQ list is static reference copy, not live
// data. This screen keeps that honest: `_docSections` below is real,
// genuinely useful static content (not fabricated business data — a docs
// page's own copy IS the content), and search/category filtering over it
// is real, working, local logic — not a decorative search box wired to
// nothing.
class _DocEntry {
  const _DocEntry({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

const List<String> _docCategories = ['新手入门', '连接问题', '账号与套餐', '节点与线路'];

const List<_DocEntry> _docEntries = [
  _DocEntry(
    category: '新手入门',
    question: '如何开始使用 HGFAST',
    answer: '登录账号后，在"连接"页选择一个节点并点击中间的电源按钮即可开始连接。系统会自动选择延迟最低的节点，也可以手动切换。',
  ),
  _DocEntry(
    category: '新手入门',
    question: '首次连接指南（三端通用）',
    answer:
        'Windows / macOS / Android 使用同一套账号体系：登录后套餐与节点会自动同步，无需在多端分别购买或配置。',
  ),
  _DocEntry(
    category: '连接问题',
    question: '连接失败怎么办',
    answer: '① 尝试切换到延迟更低的其他节点；② 检查本地网络是否正常；③ 若持续失败，可在"客服"页联系人工客服协助排查。',
  ),
  _DocEntry(
    category: '连接问题',
    question: '为什么速度突然变慢',
    answer: '常见原因是目标网站本身限速，或本地网络波动。可先尝试切换节点，或点击节点旁的延迟数值重新测速。',
  ),
  _DocEntry(
    category: '账号与套餐',
    question: '如何购买 / 续费套餐',
    answer: '在"我的"页点击"续费 / 升级套餐"，或从"发现"页的推荐入口进入"购买套餐"页选择周期与套餐即可。',
  ),
  _DocEntry(
    category: '账号与套餐',
    question: '设备数超限怎么办',
    answer: '每个套餐都有设备数上限，超出后需要先在其他设备上退出登录，或升级到设备数更高的套餐。',
  ),
  _DocEntry(
    category: '节点与线路',
    question: 'VIP 专区 / 独享 IP / 住宅 IP 是什么',
    answer:
        'VIP 专区是通过订阅导入的专属定制线路；独享 IP 出口不与其他用户共享；住宅 IP 使用真实住宅网络出口，风控识别率更低。三类线路均可在"VIP 专区"页查看。',
  ),
  _DocEntry(
    category: '节点与线路',
    question: '如何选择最优节点',
    answer: '"连接"页的节点列表会显示每个节点的实时延迟，延迟越低通常体验越好；也可以直接使用"自动选择最优节点"。',
  ),
];

class DocsView extends StatefulWidget {
  const DocsView({super.key});

  @override
  State<DocsView> createState() => _DocsViewState();
}

class _DocsViewState extends State<DocsView> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = _docCategories.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_DocEntry> get _filtered {
    final query = _query.trim();
    if (query.isNotEmpty) {
      // A real search overrides the category filter, matching how a search
      // box conventionally behaves — searching shouldn't feel scoped to
      // whatever category chip happened to be selected before.
      return _docEntries
          .where(
            (entry) =>
                entry.question.contains(query) || entry.answer.contains(query),
          )
          .toList(growable: false);
    }
    return _docEntries
        .where((entry) => entry.category == _selectedCategory)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return HgfastAuthScope(
      child: CommonScaffold(
        title: '文档中心',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: '搜索问题或关键词',
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
            if (_query.isEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _docCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _docCategories[index];
                    final selected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    );
                  },
                ),
              ),
            const SizedBox(height: HgfastSpacing.sm),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        '没有找到相关内容',
                        style: TextStyle(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: HgfastSpacing.sm),
                      itemBuilder: (context, index) => _DocCard(
                        // Regression: without a key, ListView.separated
                        // matches children by slot/index, so _DocCard's
                        // own _expanded state stayed pinned to the slot
                        // across category switches and search refinements
                        // instead of following the entry — switching
                        // category could show a FAQ item pre-expanded
                        // that the user never tapped. Caught by review
                        // with a live probe, not by inspection.
                        key: ValueKey(entries[index].question),
                        entry: entries[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatefulWidget {
  const _DocCard({super.key, required this.entry});

  final _DocEntry entry;

  @override
  State<_DocCard> createState() => _DocCardState();
}

class _DocCardState extends State<_DocCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return HgSurfaceCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry.question,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Text(
              widget.entry.answer,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
