import 'package:flutter/material.dart';
import '../../../models/payment_confirmation_models.dart';

/// Premium, minimalist card for displaying payment confirmations.
class PaymentConfirmationCard extends StatelessWidget {
  final PaymentConfirmation payment;
  final String currentUserId;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onTap;

  const PaymentConfirmationCard({
    super.key,
    required this.payment,
    required this.currentUserId,
    this.onConfirm,
    this.onReject,
    this.onTap,
  });

  bool get isRecipient => payment.toUserId == currentUserId;
  bool get isPayer => payment.fromUserId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final typeColor = isPayer ? Colors.redAccent : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F3))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getStatusIcon(), color: statusColor, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isPayer ? 'Sent to ${payment.toUserName}' : 'From ${payment.fromUserName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(_getSubtitle(), style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                  ])),
                  _buildStatusBadge(statusColor),
                ],
              ),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(payment.paymentTypeText, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('Rs. ${payment.amount.toStringAsFixed(0)}', style: TextStyle(color: typeColor, fontWeight: FontWeight.w900, fontSize: 16)),
              ])),
              if (payment.paymentProofUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _openProofFullScreen(context, payment.paymentProofUrl!),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      payment.paymentProofUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              if (payment.notes?.isNotEmpty == true) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFAFBFD), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.notes_rounded, size: 14, color: Colors.grey.shade400), const SizedBox(width: 8), Expanded(child: Text(payment.notes!, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.4)))]))],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_formatDate(payment.paymentDate), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500)),
                if (payment.isPending && isRecipient) ...[
                  Row(children: [
                    _ActionLink(label: 'Reject', color: Colors.redAccent, onTap: onReject),
                    const SizedBox(width: 16),
                    _ActionLink(label: 'Confirm', color: const Color(0xFF10B981), onTap: onConfirm),
                  ]),
                ],
              ]),
              if (payment.isRejected && payment.rejectionReason != null) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.1))), child: Text('Reason: ${payment.rejectionReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(payment.statusText.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.5)));
  }

  Color _getStatusColor() {
    if (payment.isPending) return Colors.orange;
    if (payment.isConfirmed) return const Color(0xFF10B981);
    return Colors.redAccent;
  }

  IconData _getStatusIcon() {
    if (payment.isPending) return Icons.schedule_rounded;
    if (payment.isConfirmed) return Icons.check_circle_rounded;
    return Icons.cancel_rounded;
  }

  String _getSubtitle() {
    if (payment.isPending) return isRecipient ? 'Please verify receipt' : 'Waiting for verification';
    if (payment.isConfirmed) return 'Verified on ${_formatDate(payment.confirmedAt!)}';
    return 'Verification rejected';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) return 'Today';
    return '${date.day} ${_getMonth(date.month)}';
  }

  String _getMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  void _openProofFullScreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionLink({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2)));
  }
}
