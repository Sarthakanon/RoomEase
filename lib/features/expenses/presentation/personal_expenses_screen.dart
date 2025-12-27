import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/features/home/widgets/personal_expense_dialog.dart';
import 'package:room_ease/features/expenses/presentation/personal_expense_details_screen.dart';

class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  State<PersonalExpensesScreen> createState() => _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<PersonalExpenseData> _expenses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // Theme Color for Personal Expenses
  final Color _themeColor = Colors.orange;
  
  // Filter and search
  String _searchQuery = '';
  String? _selectedCategory;
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExpenses(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreExpenses();
      }
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
      final response = await _apiService.getPersonalExpenses(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      
      final data = response['data'];
      List<PersonalExpenseData> expenses = [];
      
      if (data != null && data is List) {
        expenses = data
            .map((json) => PersonalExpenseData.fromJson(json))
            .toList();
      }

      // Client-side filtering (if API doesn't support it directly)
      if (_searchQuery.isNotEmpty) {
        expenses = expenses.where((e) => 
          e.title.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
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
        _hasMoreData = expenses.length >= _pageSize; // Logic fixed to use >=
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

  Future<void> _refreshExpenses() async {
    await _loadExpenses(reset: true);
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }

  void _showAddPersonalExpenseDialog() {
    PersonalExpenseDialog.show(
      context,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _apiService.createPersonalExpense(request.toJson());

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Added: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.green,
              ),
            );
            _refreshExpenses();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add expense: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 1. Custom Header
          _buildHeader(),

          // 2. List Content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonalExpenseDialog,
        backgroundColor: _themeColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 60,
        bottom: 25,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_themeColor, _themeColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nav Row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.only(left: 6),
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  'Personal Expenses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _refreshExpenses,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                icon: const Icon(Icons.search, color: Colors.white70),
                hintText: 'Search personal expenses...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Optional: Trigger reload here or just filter locally
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _themeColor),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshExpenses,
              style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No personal expenses',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your spending separate from roommates',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshExpenses,
      color: _themeColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        itemCount: _expenses.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _expenses.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _themeColor),
              ),
            );
          }

          final expense = _expenses[index];
          return _buildExpenseCard(expense);
        },
      ),
    );
  }

  Widget _buildExpenseCard(PersonalExpenseData expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalExpenseDetailsScreen(expense: expense),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: _themeColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          expense.category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Amount & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${expense.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (expense.createdAt != null)
                      Text(
                        _formatDate(expense.createdAt!),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Expenses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _dateRange = null;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        Navigator.pop(context);
                        _refreshExpenses();
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Food',
                    'Shopping',
                    'Transport',
                    'Entertainment',
                    'Health',
                    'Education',
                    'Other'
                  ].map((category) {
                    final isSelected = _selectedCategory == category;
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: _themeColor.withValues(alpha: 0.2),
                      checkmarkColor: _themeColor,
                      labelStyle: TextStyle(
                        color: isSelected ? _themeColor : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _refreshExpenses();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries': return Icons.shopping_basket_rounded;
      case 'utilities': return Icons.bolt_rounded;
      case 'rent': return Icons.home_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'transport':
      case 'transportation': return Icons.directions_car_rounded;
      case 'entertainment': return Icons.movie_creation_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'health': return Icons.health_and_safety_rounded;
      case 'education': return Icons.school_rounded;
      default: return Icons.account_balance_wallet_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}