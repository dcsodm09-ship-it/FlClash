import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NodeItem extends StatelessWidget {
  final NodeSpec node;

  const NodeItem({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final subtitle = node.rate == '1'
        ? node.routeLabel
        : '${node.routeLabel} · ${node.rate}x';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        type: CommonCardType.filled,
        onPressed: null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.public,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (node.category != NodeCategory.standard) ...[
              const SizedBox(width: 8),
              Chip(
                labelPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 4,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                clipBehavior: Clip.antiAlias,
                label: Text(Intl.message(node.category.name)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
