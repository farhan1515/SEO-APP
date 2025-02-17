import 'package:flutter/material.dart';

void showTopSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.blueAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      duration: const Duration(seconds: 2),
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10.0,
        right: 10.0,
      ),
      animation: CurvedAnimation(
        parent: const AlwaysStoppedAnimation(1),
        curve: Curves.easeOutCubic,
      ),
      dismissDirection: DismissDirection.horizontal,
    ),
  );
}