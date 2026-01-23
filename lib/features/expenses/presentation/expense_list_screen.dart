import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/providers/roomspace_provider.dart';
import 'package:room_ease/core/widgets/skeleton_loader.dart';
import 'package:room_ease/features/expenses/presentation/expense_details_screen.dart';
import 'package:room_ease/features/home/widgets/add_expense_dialog.dart';
import 'package:room_ease/features/home/widgets/personal_expense_dialog.dart';

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
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<ExpenseData> _expenses = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // Filter and search
  String _searchQuery = '';
  String? _selectedCategory;
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Delay loading to ensure provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses(reset: true);
    });
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
      List<ExpenseData> expenses;
      
      // Get active roomspace from provider if not specified
      String? effectiveRoomspaceId = widget.roomspaceId;
      if (!widget.isPersonalExpenses && effectiveRoomspaceId == null) {
        final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
        effectiveRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
      }
      
      if (widget.isPersonalExpenses) {
         // Using the generic fetch for now, ensuring logic handles personal flag
         // Assuming ExpenseService has a method for personal expenses or handles it internally
         // If specific personal expense endpoint exists:
         // expenses = await _expenseService.getPersonalExpenses(...);
         
         // Fallback to user expenses for this example if specific method missing
         expenses = await _expenseService.getUserExpenses(
          limit: _pageSize,
          offset: _currentPage * _pageSize,
        );
      } else if (effectiveRoomspaceId != null) {
        final response = await _expenseService.getRoomspaceExpenses(
          effectiveRoomspaceId,
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

      // Manual Filtering if API doesn't support it directly
      if (_searchQuery.isNotEmpty) {
        expenses = expenses.where((e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      }
      if (_selectedCategory != null) {
        expenses = expenses.where((e) => e.category == _selectedCategory).toList();
      }

      // Check for more data based on page size
      final hasMore = expenses.length >= _pageSize;

      setState(() {
        if (reset) {
          _expenses = expenses;
        } else {
          _expenses.addAll(expenses);
        }
        _hasMoreData = hasMore;
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

  @override
  Widget build(BuildContext context) {
    // Determine Theme Color based on context (Shared vs Personal)
    final primaryColor = Theme.of(context).colorScheme.primary;
    final themeColor = widget.isPersonalExpenses ? Colors.orange : primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for the body
      body: Column(
        children: [
          // 1. Custom Header
          _buildHeader(themeColor),

          // 2. List Content
          Expanded(
            child: _buildBody(themeColor),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: themeColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(Color themeColor) {
    // Get roomspace name from provider
    String roomspaceName = '';
    if (!widget.isPersonalExpenses) {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      if (activeRoomspace != null) {
        roomspaceName = activeRoomspace.name;
      }
    }
    
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
          colors: [themeColor, themeColor.withValues(alpha: 0.8)],
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
          // Top Row: Back Button + Title + Actions
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isPersonalExpenses ? 'Personal Expenses' : 'Shared Expenses',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (roomspaceName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        roomspaceName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
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
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Search Bar embedded in Header
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
                hintText: 'Search expenses...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                // Debounce could be added here
                setState(() {
                  _searchQuery = value;
                });
                // In a real app, you might trigger a new API call here
                // For now, we filter locally or reload
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color themeColor) {
    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 80),
        child: ExpenseListSkeleton(itemCount: 8),
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
              'Failed to load expenses',
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
              style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
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
              widget.isPersonalExpenses ? Icons.account_balance_wallet_outlined : Icons.people_outline,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a new expense',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshExpenses,
      color: themeColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Extra bottom padding for FAB
        itemCount: _expenses.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _expenses.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(color: themeColor),
              ),
            );
          }

          final expense = _expenses[index];
          return _buildExpenseCard(expense, themeColor);
        },
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseData expense, Color themeColor) {
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
                builder: (context) => ExpenseDetailsScreen(expense: expense),
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
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: themeColor,
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
                      Row(
                        children: [
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
                          if (!widget.isPersonalExpenses && expense.payerName != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• by ${expense.payerName}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]
                        ],
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
                        color: themeColor,
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
          // Handle bar
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
                
                // Category filter
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
                    'Groceries',
                    'Utilities',
                    'Rent',
                    'Entertainment',
                    'Transport',
                    'Other'
                  ].map((category) {
                    final isSelected = _selectedCategory == category;
                    final themeColor = widget.isPersonalExpenses ? Colors.orange : Theme.of(context).primaryColor;
                    
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: themeColor.withValues(alpha: 0.2),
                      checkmarkColor: themeColor,
                      labelStyle: TextStyle(
                        color: isSelected ? themeColor : Colors.grey[700],
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
                      backgroundColor: widget.isPersonalExpenses ? Colors.orange : Theme.of(context).primaryColor,
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
      default: return Icons.receipt_long_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddExpenseDialog() {
    final themeColor = widget.isPersonalExpenses ? Colors.orange : Theme.of(context).colorScheme.primary;
    _showExpenseOptions(context, themeColor);
  }

  void _showExpenseOptions(BuildContext context, Color themeColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add Expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.people, color: themeColor),
              title: const Text('Add Shared Expense'),
              subtitle: const Text('Split with roommates'),
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: themeColor),
              title: const Text('Add Personal Expense'),
              subtitle: const Text('Track personal spending'),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showSharedExpenseDialog() async {
     try {
      // Get active roomspace from provider
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      
      if (activeRoomspace == null) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active roomspace. Please select a roomspace first.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final roomspaceId = activeRoomspace.id;
      
      // Fetch members for the active roomspace
      final roomspacesResponse = await _apiService.getRoomspaces();
      final roomspaces = roomspacesResponse['data'] as List<dynamic>? ?? [];
      
      // Find the active roomspace in the response
      final roomspaceData = roomspaces.firstWhere(
        (r) => r['id']?.toString() == roomspaceId,
        orElse: () => null,
      );
      
      if (roomspaceData == null) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Roomspace not found'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      
      final members = roomspaceData['members'] as List<dynamic>? ?? [];
      
      final roommates = members.map((m) {
        final user = m['user'];
        return RoommateItem(
          id: m['user_id'] ?? '',
          name: user?['name'] ?? user?['email'] ?? 'Unknown',
          email: user?['email'],
        );
      }).toList();

      if (mounted) {
        AddExpenseDialog.show(
          context,
          roommates: roommates,
          roomspaceId: roomspaceId,
          onSubmit: (expense) async {
            try {
              final request = ExpenseCreateRequest.fromExpenseData(expense, roomspaceId);
              await _apiService.createExpense(request.toJson());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added: ${expense.title}'), backgroundColor: Colors.green),
                );
                _refreshExpenses();
              }
            } catch (e) {
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
               }
            }
          },
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPersonalExpenseDialog() {
    PersonalExpenseDialog.show(
      context,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _apiService.createPersonalExpense(request.toJson());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added: ${expense.title}'), backgroundColor: Colors.green),
            );
            _refreshExpenses();
          }
        } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }
}