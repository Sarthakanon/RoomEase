import 'package:flutter/material.dart';
import 'app_navbar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final String? title;
  final List<Widget>? actions;
  final bool showNavbar;

  const MainLayout({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.title,
    this.actions,
    this.showNavbar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: showNavbar
          ? AppNavbar(
              showBackButton: showBackButton,
              title: title,
              actions: actions,
            )
          : null,
      body: child,
    );
  }
}
