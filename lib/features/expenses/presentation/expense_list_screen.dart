import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/services/cached_api_service.dart';
import 'package:room_ease/services/real_time_data_service.dart';
import 'package:room_ease/providers/roomspace_provider.dart';
import 'package:room_ease/core/widgets/skeleton_loader.dart';
import 'package:room_ease/features/home/widgets/add_expense_dialog.dart';
import 'package:room_ease/features/home/widgets/personal_expense_dialog.dart';
import 'package:room_ease/widgets/enhanced_expense_tile.dart';
import 'dart:async';

/// Screen displaying a paginated list of expenses (shared or personal).
class ExpenseListScreen extends StatefulWidget {
  final String? roomspaceId;
  final bool isPersonalExpenses;

  const ExpenseListScreen({
    super.key,
    this.roomspaceId,
    this.isPersonalExpenses = false,
  });

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CachedApiService _cachedApiService = CachedApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  final ScrollController _scrollController = ScrollController();
  
  List<ExpenseData> _expenses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  // Stream subscriptions for real-time updates
  StreamSubscription<ExpenseUpdateEvent>? _expenseUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses(reset: true);
      _setupRealTimeListeners();
    });
  }

  void _setupRealTimeListeners() {
    _expenseUpdateSubscription = _realTimeService.expenseUpdates.listen((event) {
      debugPrint('🔄 ExpenseList: Update received: ${event.type}');
      
      // Check if this update affects current screen
      final currentRoomspaceId = widget.roomspaceId ?? 
          Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
      
      bool shouldRefresh = false;
      
      if (event.type == ExpenseUpdateType.clearCache) {
        shouldRefresh = true;
      } else if (widget.isPersonalExpenses && event.type == ExpenseUpdateType.personalCreated) {
        shouldRefresh = true;
      } else if (!widget.isPersonalExpenses && event.roomspaceId == currentRoomspaceId) {
        shouldRefresh = true;
      }
      
      if (shouldRefresh && mounted) {
        debugPrint('🔄 ExpenseList: Refreshing data');
        _loadExpenses(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _expenseUpdateSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) _loadMoreExpenses();
    }
  }

  Future<void> _loadExpenses({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 0;
        _hasMoreData = true;
      });
    }

    try {
      List<ExpenseData> expenses;
      String? effectiveId = widget.roomspaceId;
      if (!widget.isPersonalExpenses && effectiveId == null) {
        effectiveId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
      }
      
      if (widget.isPersonalExpenses) {
         expenses = await _expenseService.getUserExpenses(
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        );
      } else if (effectiveId != null) {
        final response = await _expenseService.getRoomspaceExpenses(
          effectiveId,
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        );
        expenses = response.expenses;
      } else {
        expenses = await _expenseService.getUserExpenses(
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        );
      }

      if (_searchQuery.isNotEmpty) {
        expenses = expenses.where((e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      }
      if (_selectedCategory != null) {
        expenses = expenses.where((e) => e.category == _selectedCategory).toList();
      }

      setState(() {
        if (reset) {
          _expenses = expenses;
        } else {
          _expenses.addAll(expenses);
        }
        _hasMoreData = expenses.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreExpenses() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _loadExpenses();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final horizontalPadding = isTablet ? width * 0.15 : 16.0;
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    final themeColor = widget.isPersonalExpenses ? Colors.orange.shade700 : primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isPersonalExpenses ? 'Personal Expenses' : 'Shared Expenses',
          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.grey.shade600, size: 20),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                child: _buildSearchBar(),
              ),
              Container(color: const Color(0xFFF0F0F0), height: 1),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(20), child: ExpenseListSkeleton(itemCount: 8))
          : _hasError
              ? _buildErrorState(themeColor)
              : _buildList(themeColor, horizontalPadding),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add_expense_fab'),
        onPressed: _showAddExpenseDialog,
        backgroundColor: themeColor,
        elevation: 2,
        tooltip: 'Add Expense',
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search expenses...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildList(Color themeColor, double horizontalPadding) {
    if (_expenses.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () => _loadExpenses(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 80),
        itemCount: _expenses.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _expenses.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final expense = _expenses[index];
          return EnhancedExpenseTile(
            expense: expense,
            themeColor: themeColor,
            isPersonal: widget.isPersonalExpenses,
            onUpdated: () => _loadExpenses(reset: true),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('No expenses found', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color themeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Couldn\'t load items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => _loadExpenses(reset: true), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSheet() {
    final themeColor = widget.isPersonalExpenses ? Colors.orange.shade700 : Theme.of(context).primaryColor;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter By Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedCategory = null);
                        Navigator.pop(context);
                        _loadExpenses(reset: true);
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Food', 'Groceries', 'Utilities', 'Rent', 'Entertainment', 'Transport', 'Other'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey.shade700)),
                      selected: isSelected,
                        selectedColor: themeColor,
                        backgroundColor: const Color(0xFFF7F7FB),
                        onSelected: (val) => setState(() => _selectedCategory = val ? cat : null),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadExpenses(reset: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final themeColor = widget.isPersonalExpenses ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.all(16), child: Text('Add New Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            ListTile(
              leading: Icon(Icons.people_outlined, color: themeColor),
              title: const Text('Shared Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(context); _showSharedExpenseDialog(); },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined, color: themeColor),
              title: const Text('Personal Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(context); _showPersonalExpenseDialog(); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- (Helper methods for Shared/Personal Dialogs remain similar to original but with cleaned error handling) ---
  Future<void> _showSharedExpenseDialog() async {
    final provider = Provider.of<RoomspaceProvider>(context, listen: false);
    final active = provider.activeRoomspace;
    if (active == null) return;
    
    try {
      final res = await _cachedApiService.getRoomspaces();
      final data = (res['data'] as List).firstWhere((r) => r['id'].toString() == active.id);
      final roommates = (data['members'] as List).map((m) => RoommateItem(
        id: m['user_id'] ?? '',
        name: m['user']?['name'] ?? m['user']?['email'] ?? 'Unknown',
        email: m['user']?['email'],
      )).toList();
      
      if (!mounted) return;
      AddExpenseDialog.show(context, roommates: roommates, roomspaceId: active.id, onSubmit: (ex) async {
        await _cachedApiService.createExpense(ExpenseCreateRequest.fromExpenseData(ex, active.id).toJson());
        // Real-time service will automatically notify listeners
        // No need to manually refresh here
      });
    } catch (_) {}
  }

  void _showPersonalExpenseDialog() {
    PersonalExpenseDialog.show(context, onSubmit: (ex) async {
      await _cachedApiService.createPersonalExpense(PersonalExpenseCreateRequest.fromExpenseData(ex).toJson());
      // Real-time service will automatically notify listeners
      // No need to manually refresh here
    });
  }
}
