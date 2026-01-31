import 'package:flutter/material.dart';



class UserAvatar extends StatelessWidget {
  final String userName;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

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
    // If imageUrl is present, show the image
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: Colors.grey[200],
      );
    }

    // Extract Initials
    String initials = "";
    if (userName.isNotEmpty) {
      List<String> parts = userName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
        if (parts.length > 1) {
          initials += parts[1][0].toUpperCase();
        }
      }
    } else {
      initials = "?";
    }

    // Colors
    final Color bgColor = backgroundColor ?? Colors.purple[100]!;
    final Color txtColor = textColor ?? Colors.purple[800]!;

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
