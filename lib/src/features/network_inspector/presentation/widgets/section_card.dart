import 'package:material_ui/material_ui.dart';

import '../../../../core/core.dart';

/// A rounded card used as a section container throughout the inspector.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: AppSizes.gap8),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingLg,
                AppSizes.paddingMd,
                AppSizes.paddingLg,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.title(
                      title!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          if (title != null)
            const Divider(
              height: AppSizes.gap12,
              indent: AppSizes.paddingLg,
              endIndent: AppSizes.paddingLg,
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
