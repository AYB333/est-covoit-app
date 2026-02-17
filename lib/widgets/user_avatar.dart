// Import dyal Flutter UI
import 'package:flutter/material.dart';

// Widget dyal avatar: ila كاين photo URL كنوري الصورة،
// ila ما كايناش كنخرج initials من الاسم
class UserAvatar extends StatelessWidget {
  // Props li kayjiw men parent
  final String userName;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  // Constructor
  const UserAvatar({
    super.key,
    required this.userName,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    // Kan7awlo nkhrjo initials men userName
    String initials = "";
    if (userName.isNotEmpty) {
      // N9ssmo l-ism l parts (b space)
      List<String> parts = userName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        // Awl 7arf men l-ism
        initials = parts[0][0].toUpperCase();
        if (parts.length > 1) {
          // 7arf tani men l-ism tani ila kayn
          initials += parts[1][0].toUpperCase();
        }
      }
    } else {
      // Ila l-ism khawi
      initials = "?";
    }

    // Colors default ila ma t3tawsh
    final Color bgColor = backgroundColor ?? Colors.purple[100]!;
    final Color txtColor = textColor ?? Colors.purple[800]!;

    // Ila kayna imageUrl nreja3 CircleAvatar b image
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: Colors.grey[200],
      );
    }

    // Ila ma kaynach imageUrl, nreja3 CircleAvatar b initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.8),
        ),
      ),
    );
  }
}
