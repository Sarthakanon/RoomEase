import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/services/api_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final ExpenseData expense;

  const EditExpenseScreen({
    super.key,
    required this.expense,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseService _expenseService = ExpenseService();
  final ApiService _apiService = ApiService();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  
  late String _selectedCategory;
  late SplitType _selectedSplitType;
  List<Map<String, dynamic>> _roommates = [];
  List<String> _selectedRoommateIds = [];
  Map<String, double> _customSplits = {};
  
  bool _isLoading = false;
  bool _isLoadingRoommates = true;

  final List<String> _categories = [
    'General',
    'Food',
    'Groceries',
    'Utilities',
    'Rent',
    'Entertainment',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRoommates();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.expense.title);
    _descriptionController = TextEditingController(text: widget.expense.description);
    _amountController = TextEditingController(text: widget.expense.amount.toString());
    _selectedCategory = widget.expense.category;
    _selectedSplitType = widget.expense.splitType;
    
    // Initialize selected roommates from splits
    if (widget.expense.splits != null) {
      _selectedRoommateIds = widget.expense.splits!
          .map((split) => split.userUid)
          .toList();
      
      // Initialize custom splits if needed
      if (_selectedSplitType != SplitType.equal) {
        for (final split in widget.expense.splits!) {
          if (_selectedSplitType == SplitType.percentage) {
            _customSplits[split.userUid] = split.percentage ?? 0.0;
          } else {
            _customSplits[split.userUid] = split.amount;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRoommates() async {
    if (widget.expense.roomspaceId == null) return;
    
    try {
      final response = await _apiService.getRoomspaceMembers(widget.expense.roomspaceId!);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _roommates = List<Map<String, dynamic>>.from(response['data']);
          _isLoadingRoommates = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingRoommates = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load roommates: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoommateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one roommate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate custom splits if needed
    if (_selectedSplitType != SplitType.equal) {
      if (!_validateCustomSplits()) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = ExpenseCreateRequest(
        roomspaceId: widget.expense.roomspaceId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        splitType: _selectedSplitType.apiValue,
        selectedRoommates: _selectedRoommateIds,
        customSplits: _selectedSplitType != SplitType.equal ? _customSplits : null,
      );

      final updatedExpense = await _expenseService.updateExpense(
        widget.expense.id!,
        request,
      );

      if (mounted) {
        Navigator.pop(context, updatedExpense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update expense: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateCustomSplits() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    
    if (_selectedSplitType == SplitType.percentage) {
      double totalPercentage = 0;
      for (final roommateId in _selectedRoommateIds) {
        final percentage = _customSplits[roommateId] ?? 0;
        if (percentage <= 0 || percentage > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Percentage values must be between 0 and 100'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        totalPercentage += percentage;
      }
      
      if ((totalPercentage - 100).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Percentage splits must total exactly 100%'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } else if (_selectedSplitType == SplitType.exact) {
      double totalAmount = 0;
      for (final roommateId in _selectedRoommateIds) {
        final splitAmount = _customSplits[roommateId] ?? 0;
        if (splitAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Split amounts must be greater than 0'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        totalAmount += splitAmount;
      }
      
      if ((totalAmount - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split amounts must total the expense amount'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }
    
    return true;
  }

  void _onSplitTypeChanged(SplitType? newType) {
    if (newType == null) return;
    
    setState(() {
      _selectedSplitType = newType;
      _customSplits.clear();
      
      if (newType == SplitType.percentage) {
        // Initialize with equal percentages
        final equalPercentage = 100.0 / _selectedRoommateIds.length;
        for (final roommateId in _selectedRoommateIds) {
          _customSplits[roommateId] = equalPercentage;
        }
      } else if (newType == SplitType.exact) {
        // Initialize with equal amounts
        final amount = double.tryParse(_amountController.text) ?? 0;
        final equalAmount = amount / _selectedRoommateIds.length;
        for (final roommateId in _selectedRoommateIds) {
          _customSplits[roommateId] = equalAmount;
        }
      }
    });
  }

  void _onRoommateSelectionChanged(String roommateId, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoommateIds.add(roommateId);
        
        // Add to custom splits if needed
        if (_selectedSplitType == SplitType.percentage) {
          final equalPercentage = 100.0 / _selectedRoommateIds.length;
          _customSplits[roommateId] = equalPercentage;
          // Redistribute existing percentages
          for (final id in _selectedRoommateIds) {
            _customSplits[id] = equalPercentage;
          }
        } else if (_selectedSplitType == SplitType.exact) {
          final amount = double.tryParse(_amountController.text) ?? 0;
          final equalAmount = amount / _selectedRoommateIds.length;
          _customSplits[roommateId] = equalAmount;
          // Redistribute existing amounts
          for (final id in _selectedRoommateIds) {
            _customSplits[id] = equalAmount;
          }
        }
      } else {
        _selectedRoommateIds.remove(roommateId);
        _customSplits.remove(roommateId);
        
        // Redistribute remaining splits
        if (_selectedRoommateIds.isNotEmpty) {
          if (_selectedSplitType == SplitType.percentage) {
            final equalPercentage = 100.0 / _selectedRoommateIds.length;
            for (final id in _selectedRoommateIds) {
              _customSplits[id] = equalPercentage;
            }
          } else if (_selectedSplitType == SplitType.exact) {
            final amount = double.tryParse(_amountController.text) ?? 0;
            final equalAmount = amount / _selectedRoommateIds.length;
            for (final id in _selectedRoommateIds) {
              _customSplits[id] = equalAmount;
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateExpense,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _isLoadingRoommates
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(),
                    const SizedBox(height: 24),
                    _buildSplitTypeSection(),
                    const SizedBox(height: 24),
                    _buildRoommateSelection(),
                    if (_selectedSplitType != SplitType.equal) ...[
                      const SizedBox(height: 24),
                      _buildCustomSplits(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Update custom splits when amount changes
                      if (_selectedSplitType == SplitType.exact) {
                        final amount = double.tryParse(value) ?? 0;
                        if (amount > 0 && _selectedRoommateIds.isNotEmpty) {
                          final equalAmount = amount / _selectedRoommateIds.length;
                          setState(() {
                            for (final id in _selectedRoommateIds) {
                              _customSplits[id] = equalAmount;
                            }
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...SplitType.values.map((type) {
              return RadioListTile<SplitType>(
                title: Row(
                  children: [
                    Icon(type.icon, size: 20),
                    const SizedBox(width: 8),
                    Text(type.label),
                  ],
                ),
                value: type,
                groupValue: _selectedSplitType,
                onChanged: _onSplitTypeChanged,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoommateSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Roommates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._roommates.map((roommate) {
              final roommateId = roommate['user_id'] ?? roommate['firebase_uid'] ?? '';
              final roommateName = roommate['name'] ?? 'Unknown';
              final isSelected = _selectedRoommateIds.contains(roommateId);
              
              return CheckboxListTile(
                title: Text(roommateName),
                value: isSelected,
                onChanged: (selected) {
                  _onRoommateSelectionChanged(roommateId, selected ?? false);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSplits() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedSplitType == SplitType.percentage
                  ? 'Percentage Splits'
                  : 'Exact Amount Splits',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._selectedRoommateIds.map((roommateId) {
              final roommate = _roommates.firstWhere(
                (r) => (r['user_id'] ?? r['firebase_uid']) == roommateId,
                orElse: () => {'name': 'Unknown'},
              );
              final roommateName = roommate['name'] ?? 'Unknown';
              final currentValue = _customSplits[roommateId] ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(roommateName),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: currentValue.toString(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          suffixText: _selectedSplitType == SplitType.percentage ? '%' : '\$',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final numValue = double.tryParse(value) ?? 0;
                          setState(() {
                            _customSplits[roommateId] = numValue;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_selectedSplitType == SplitType.percentage) ...[
              const SizedBox(height: 8),
              Text(
                'Total: ${_customSplits.values.fold(0.0, (sum, value) => sum + value).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: (_customSplits.values.fold(0.0, (sum, value) => sum + value) - 100).abs() < 0.01
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (_selectedSplitType == SplitType.exact) ...[
              const SizedBox(height: 8),
              Text(
                'Total: \$${_customSplits.values.fold(0.0, (sum, value) => sum + value).toStringAsFixed(2)}',
                style: TextStyle(
                  color: (_customSplits.values.fold(0.0, (sum, value) => sum + value) - (double.tryParse(_amountController.text) ?? 0)).abs() < 0.01
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}