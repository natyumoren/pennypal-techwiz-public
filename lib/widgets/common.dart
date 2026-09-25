import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/category.dart';

/// Centers content and caps its width so tablet / web layouts stay readable.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 56, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Semantics(
      label: 'PennyPal logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.brand,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        alignment: Alignment.center,
        child: Text('P',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.6,
                fontWeight: FontWeight.w800)),
      ),
    );
    if (!showName) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      SizedBox(width: size * 0.25),
      Text('PennyPal',
          style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          if (action != null) action!,
        ]),
      );
}

/// Friendly placeholder used whenever a list or chart has no data yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: cs.primaryContainer,
          child: Icon(icon, size: 32, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ]),
    );
  }
}

/// Small metric tile (income, expenses, balance...).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Semantics(
        label: '$label: $value${caption != null ? ', $caption' : ''}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: TextStyle(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(caption!,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.radius = 20});
  final Category category;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: category.color.withValues(alpha: 0.15),
        child: Icon(category.iconData,
            color: category.color, size: radius, semanticLabel: category.name),
      );
}

/// Labelled progress bar that changes colour near / over the limit.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.ratio, this.threshold = 80, this.height = 10});
  final double ratio;
  final int threshold;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${(ratio * 100).round()} percent used',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1).toDouble(),
            minHeight: height,
            color: AppTheme.usageColor(ratio, thresholdPercent: threshold),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      );
}

/// Receipt thumbnail that works for file paths (mobile) and data URIs (web).
class ReceiptImage extends StatelessWidget {
  const ReceiptImage(this.source, {super.key, this.height = 180});
  final String source;
  final double height;

  ImageProvider get _provider {
    if (source.startsWith('data:')) {
      return MemoryImage(base64Decode(source.split(',').last));
    }
    if (source.startsWith('http') || kIsWeb) return NetworkImage(source);
    return FileImage(File(source));
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Receipt photo',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: _provider,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: height,
              alignment: Alignment.center,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Text('Receipt image unavailable'),
            ),
          ),
        ),
      );
}

void showSnack(BuildContext context, String message,
    {bool error = false, Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? (error ? AppTheme.expense : null),
    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String message,
    String confirmLabel = 'Delete',
    bool destructive = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppTheme.expense)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Standard padding for scrollable screens.
const screenPadding = EdgeInsets.fromLTRB(16, 8, 16, 96);
