import 'package:flutter/material.dart';

class HomeRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HomeRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: textTheme.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
