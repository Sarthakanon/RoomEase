import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/features/home/widgets/personal_expense_dialog.dart';
import 'package:room_ease/features/expenses/presentation/personal_expense_details_screen.dart';

/// Professional, minimalist screen for tracking personal spending.
class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  State<PersonalExpensesScreen> createState() => _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<PersonalExpenseData> _expenses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  String _searchQuery = '';
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData) _loadMore();
      }
    });
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _isLoading = true; _currentPage = 0; _hasMoreData = true; });
    try {
      final res = await _apiService.getPersonalExpenses(limit: _pageSize, offset: _currentPage * _pageSize);
      final data = res['data'] as List?;
      final List<PersonalExpenseData> fetched = data?.map((json) => PersonalExpenseData.fromJson(json)).where((e) => _searchQuery.isEmpty || e.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList() ?? [];
      setState(() {
        if (reset) {
          _expenses = fetched;
        } else {
          _expenses.addAll(fetched);
        }
        _hasMoreData = fetched.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() { _isLoadingMore = true; _currentPage++; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Personal Expenses', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(onPressed: () => _load(reset: true), icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600, size: 20)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(60), child: _buildSearchArea()),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildList(width, primary),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add_personal_expense_fab'),
        onPressed: () => PersonalExpenseDialog.show(context, onSubmit: (e) async {
          await _apiService.createPersonalExpense(PersonalExpenseCreateRequest.fromExpenseData(e).toJson());
          _load(reset: true);
        }),
        backgroundColor: primary, 
        foregroundColor: Colors.white, 
        elevation: 2,
        tooltip: 'Add Personal Expense',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            hintText: 'Search expenses...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          ),
          onChanged: (v) { setState(() => _searchQuery = v); _load(reset: true); },
        ),
      ),
    );
  }

  Widget _buildList(double width, Color primary) {
    if (_expenses.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: () => _load(reset: true), color: primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: width > 600 ? width * 0.1 : 20, vertical: 16),
        itemCount: _expenses.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _expenses.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          final e = _expenses[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F3))),
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PersonalExpenseDetailsScreen(expense: e))),
              contentPadding: const EdgeInsets.all(12),
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12)), child: Icon(_getCatIcon(e.category), color: const Color(0xFF1A1A2E), size: 20)),
              title: Text(e.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Rs. ${e.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary)),
                const SizedBox(height: 2),
                Text(_fmtDate(e.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade200), const SizedBox(height: 16), Text('No personal expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade500)), Text('Separate your private spending', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))]));
  }

  IconData _getCatIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'groceries': return Icons.shopping_basket_rounded;
      case 'utilities': return Icons.bolt_rounded;
      case 'rent': return Icons.home_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'transport': return Icons.directions_car_rounded;
      case 'entertainment': return Icons.movie_creation_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    if (now.day == d.day && now.month == d.month && now.year == d.year) return 'Today';
    return '${d.day}/${d.month}';
  }

  @override
  void dispose() { _scrollController.dispose(); _searchController.dispose(); super.dispose(); }
}
