import 'package:flutter/material.dart';

class LibraryEntry extends StatelessWidget {
  const LibraryEntry({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 16,
          children: [
            leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const ExcludeSemantics(child: Icon(Icons.chevron_right)),
          ],
        ),
      ),
    ),
  );
}
