import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/expense_models.dart';
import '../../../models/balance_models.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/balance_service.dart';
import 'report_preview_screen.dart';

class ReportOptionsScreen extends StatefulWidget {
  const ReportOptionsScreen({super.key});

  @override
  State<ReportOptionsScreen> createState() => _ReportOptionsScreenState();
}

class _ReportOptionsScreenState extends State<ReportOptionsScreen> {
  final ApiService _apiService = ApiService();
  final BalanceService _balanceService = BalanceService();
  bool _isLoading = false;
  Map<DateTime, double> _monthlyTotals = {};
  double _fiveMonthTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() => _isLoading = true);
    try {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;

      double aggregateTotal = 0;
      Map<DateTime, double> totals = {};

      // Generate last 5 months
      for (int i = 0; i < 5; i++) {
        final monthDate = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
        double monthSum = 0;

        // Fetch shared
        if (!isPersonalSpace && activeRoomspace != null) {
          final sharedRes = await _apiService.getRoomspaceExpenses(activeRoomspace.id, month: monthDate);
          if (sharedRes['success'] == true) {
            final List data = sharedRes['data'] ?? [];
            for (var e in data) {
              monthSum += (e['amount'] as num).toDouble();
            }
          }
        }

        // Fetch personal
        final personalRes = await _apiService.getPersonalExpenses(month: monthDate);
        if (personalRes['success'] == true) {
          final List data = personalRes['data'] ?? [];
          for (var e in data) {
            monthSum += (e['amount'] as num).toDouble();
          }
        }

        totals[monthDate] = monthSum;
        aggregateTotal += monthSum;
      }

      setState(() {
        _monthlyTotals = totals;
        _fiveMonthTotal = aggregateTotal;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report summary: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateForRange(DateTimeRange range, String reportTitle) async {
    setState(() => _isLoading = true);

    try {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;

      List<ExpenseData> sharedExpenses = [];
      List<PersonalExpenseData> personalExpenses = [];
      BalanceSummary? balanceSummary;
      List<SettlementSuggestion> settlements = [];

      // Fetch balance data if in shared space
      if (!isPersonalSpace && activeRoomspace != null) {
        balanceSummary = await _balanceService.getRoomspaceBalances(activeRoomspace.id);
        settlements = await _balanceService.getSettlementSuggestions(activeRoomspace.id);
      }

      // Fetch broad data and filter (simulating range fetch since backend is month-based)
      DateTime current = DateTime(range.start.year, range.start.month, 1);
      while (current.isBefore(range.end) || (current.month == range.end.month && current.year == range.end.year)) {
        if (!isPersonalSpace && activeRoomspace != null) {
          final sharedRes = await _apiService.getRoomspaceExpenses(activeRoomspace.id, month: current);
          if (sharedRes['success'] == true) {
            final List data = sharedRes['data'] ?? [];
            sharedExpenses.addAll(data.map((e) => ExpenseData.fromJson(e)));
          }
        }

        final personalRes = await _apiService.getPersonalExpenses(month: current);
        if (personalRes['success'] == true) {
          final List data = personalRes['data'] ?? [];
          personalExpenses.addAll(data.map((e) => PersonalExpenseData.fromJson(e)));
        }
        
        current = DateTime(current.year, current.month + 1, 1);
      }

      // Exact filtering
      sharedExpenses = sharedExpenses.where((e) => 
        e.createdAt != null && 
        e.createdAt!.isAfter(range.start.subtract(const Duration(seconds: 1))) && 
        e.createdAt!.isBefore(range.end.add(const Duration(days: 1)))
      ).toList();

      personalExpenses = personalExpenses.where((e) => 
        e.createdAt != null && 
        e.createdAt!.isAfter(range.start.subtract(const Duration(seconds: 1))) && 
        e.createdAt!.isBefore(range.end.add(const Duration(days: 1)))
      ).toList();

      setState(() => _isLoading = false);

      if (sharedExpenses.isEmpty && personalExpenses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No expenses found for this period')),
          );
        }
        return;
      }

      String userName = 'User';
      try {
        final profileRes = await _apiService.getUserProfile();
        if (profileRes['success'] == true) {
          userName = profileRes['data']['name'] ?? 'User';
        }
      } catch (_) {}

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportPreviewScreen(
              sharedExpenses: sharedExpenses,
              personalExpenses: personalExpenses,
              dateRange: range,
              roomspaceName: isPersonalSpace ? 'Personal Space' : (activeRoomspace?.name ?? 'Shared Space'),
              userName: userName,
              balanceSummary: balanceSummary,
              settlements: settlements,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = _monthlyTotals.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Expense Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAggregateCard(),
                const SizedBox(height: 32),
                const Text(
                  "Monthly Reports",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 16),
                ...months.map((m) => _buildMonthTile(m)),
                const SizedBox(height: 32),
                _buildCustomRangeButton(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildAggregateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF2A2A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Past 5 Months Data",
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Rs. ${_fiveMonthTotal.toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final end = DateTime.now();
              final start = DateTime(end.year, end.month - 4, 1);
              _generateForRange(DateTimeRange(start: start, end: end), "5 Month Report");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A2E),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_rounded, size: 18),
                SizedBox(width: 8),
                Text("Generate 5-Month Report", style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTile(DateTime month) {
    final total = _monthlyTotals[month] ?? 0;
    final hasData = total > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: hasData ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  hasData ? "Rs. ${total.toStringAsFixed(0)}" : "No expenses",
                  style: TextStyle(
                    fontSize: 12,
                    color: hasData ? Colors.indigo.shade600 : Colors.grey.shade500,
                    fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('generate_report_${month.month}_${month.year}'),
            onPressed: hasData ? () {
              final lastDay = DateTime(month.year, month.month + 1, 0);
              _generateForRange(
                DateTimeRange(start: month, end: lastDay),
                DateFormat('MMMM yyyy').format(month),
              );
            } : null,
            icon: Icon(
              Icons.download_rounded,
              color: hasData ? const Color(0xFF1A1A2E) : Colors.grey.shade300,
            ),
            tooltip: 'Generate Report',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRangeButton() {
    return InkWell(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1A1A2E),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF1A1A2E),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          _generateForRange(picked, "Custom Range Report");
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1A1A2E), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "Custom Date Range Report",
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
          ),
        ),
      ),
    );
  }
}
