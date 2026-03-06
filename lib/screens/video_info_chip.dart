import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VideoInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const VideoInfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.textColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textColor.withOpacity(0.9))),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
