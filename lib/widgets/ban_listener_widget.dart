import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ban_monitoring_service.dart';
import 'ban_countdown_dialog.dart';

class BanListenerWidget extends StatefulWidget {
  final Widget child;

  const BanListenerWidget({
    super.key,
    required this.child,
  });

  @override
  State<BanListenerWidget> createState() => _BanListenerWidgetState();
}

class _BanListenerWidgetState extends State<BanListenerWidget> {
  late StreamSubscription<String>? _banSubscription;

  @override
  void initState() {
    super.initState();
    _setupBanListener();
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    super.dispose();
  }

  void _setupBanListener() {
    _banSubscription = BanMonitoringService().banNotificationStream.listen((reason) {
      if (mounted) {
        _showBanDialog(reason);
      }
    });
  }

  void _showBanDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BanCountdownDialog(reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}