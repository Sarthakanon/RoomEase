import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/roomspace_provider.dart';
import '../../models/roomspace_data.dart';

/// Global roomspace selector widget for app bar.
/// Uses a premium, minimalist design with neutral colors and subtle borders.
class GlobalRoomspaceSelector extends StatefulWidget {
  final VoidCallback? onRoomspaceChanged;
  const GlobalRoomspaceSelector({super.key, this.onRoomspaceChanged});

  @override
  State<GlobalRoomspaceSelector> createState() => _GlobalRoomspaceSelectorState();
}

class _GlobalRoomspaceSelectorState extends State<GlobalRoomspaceSelector> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomspaceProvider>(builder: (context, provider, child) {
      final active = provider.activeRoomspace;
      final primary = Theme.of(context).colorScheme.primary;

      return GestureDetector(
        onTap: () => _showMenu(context, provider, primary),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Icon(active?.visualIcon ?? Icons.person_rounded, size: 14, color: primary)),
            const SizedBox(width: 10),
            Flexible(child: Text(active?.name ?? 'Personal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey.shade400),
          ]),
        ),
      );
    });
  }

  void _showMenu(BuildContext context, RoomspaceProvider provider, Color primary) {
    final active = provider.activeRoomspace;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(value: 'personal', child: _buildMenuItem('Personal', 'Private spending', Icons.person_rounded, active == null, primary)),
      if (provider.roomspaces.isNotEmpty) const PopupMenuDivider(height: 1),
      ...provider.roomspaces.map((r) => PopupMenuItem<String>(value: r.id, child: _buildMenuItem(r.name, '${r.memberCount} members', r.visualIcon, active?.id == r.id, r.visualColor))),
      const PopupMenuDivider(height: 1),
      PopupMenuItem<String>(value: 'add_new', child: _buildMenuItem('Add Roomspace', 'Create or join', Icons.add_rounded, false, primary, isAction: true)),
    ];

    showMenu(context: context, position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width - 200, kToolbarHeight + 10, 20, 0), items: items, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.white).then((v) {
      if (v == null) return;
      if (v == 'add_new') Navigator.pushNamed(context, '/settings');
      else if (v == 'personal') _switch(context, provider, null);
      else _switch(context, provider, v);
    });
  }

  Widget _buildMenuItem(String title, String sub, IconData icon, bool active, Color color, {bool isAction = false}) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isAction ? color.withValues(alpha: 0.1) : (active ? color.withValues(alpha: 0.1) : const Color(0xFFF7F7FB)), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: isAction ? color : (active ? color : Colors.grey.shade500))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: active || isAction ? FontWeight.w700 : FontWeight.w500, color: isAction ? color : const Color(0xFF1A1A2E))), Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade400))])),
      if (active) Icon(Icons.check_rounded, size: 16, color: color),
    ]);
  }

  Future<void> _switch(BuildContext context, RoomspaceProvider provider, String? id) async {
    try {
      if (id == null) await provider.switchToPersonalSpace();
      else await provider.setActiveRoomspace(id);
      if (mounted) widget.onRoomspaceChanged?.call();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to switch')));
    }
  }
}
