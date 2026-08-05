import 'package:flutter/material.dart';

/// Small caption-style label used to break a single settings category
/// screen into a few sub-groups (e.g. "Appearance"/"Language"/"Startup"
/// within General) — the category itself is now the screen/AppBar title,
/// this is only for finer-grained grouping within it.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
