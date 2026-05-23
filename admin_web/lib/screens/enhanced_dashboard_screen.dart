import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/admin_api_service.dart';
import '../widgets/stat_card.dart';

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  State<EnhancedDashboardScreen> createState() => _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen> {
  int _selectedIndex = 0;
  final AdminApiService _apiService = AdminApiService();
  
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roomspaces = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _personalExpenses = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  final List<AdminPage> _pages = [
    AdminPage(title: 'Dashboard', icon: Icons.dashboard_rounded),
    AdminPage(title: 'Users', icon: Icons.people_rounded),
    AdminPage(title: 'Roomspaces', icon: Icons.home_work_rounded),
    AdminPage(title: 'Expenses', icon: Icons.receipt_long_rounded),
    AdminPage(title: 'Analytics', icon: Icons.analytics_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔄 Loading admin data...');
      
      final stats = await _apiService.getSystemStats();
      debugPrint('✅ Stats loaded: ${stats.keys}');
      
      final users = await _apiService.getAllUsers();
      debugPrint('✅ Users loaded: ${users['data']?.length ?? 0} users');
      
      final roomspaces = await _apiService.getAllRoomspaces();
      debugPrint('✅ Roomspaces loaded: ${roomspaces['data']?.length ?? 0} roomspaces');
      
      final expenses = await _apiService.getAllExpenses(limit: 100);
      debugPrint('✅ Expenses loaded: ${expenses['data']?.length ?? 0} expenses');
      
      final personalExpenses = await _apiService.getAllPersonalExpenses(limit: 100);
      debugPrint('✅ Personal expenses loaded: ${personalExpenses['data']?.length ?? 0} expenses');
      
      final analytics = await _apiService.getAnalyticsData();
      debugPrint('✅ Analytics loaded: ${analytics.keys}');
      
      
      if (mounted) {
        setState(() {
          _stats = stats['data'] ?? stats;
          _users = List<Map<String, dynamic>>.from(users['data'] ?? []);
          _roomspaces = List<Map<String, dynamic>>.from(roomspaces['data'] ?? []);
          _expenses = List<Map<String, dynamic>>.from(expenses['data'] ?? []);
          _personalExpenses = List<Map<String, dynamic>>.from(personalExpenses['data'] ?? []);
          _analytics = analytics['data'] ?? analytics;
          _isLoading = false;
        });
      }
      
      debugPrint('✅ All data loaded successfully!');
      debugPrint('   - Stats: $_stats');
      debugPrint('   - Users: ${_users.length}');
      debugPrint('   - Roomspaces: ${_roomspaces.length}');
      debugPrint('   - Expenses: ${_expenses.length}');
      debugPrint('   - Personal Expenses: ${_personalExpenses.length}');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('❌ Error loading admin data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'RoomEase Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                ...List.generate(_pages.length, (index) {
                  return _buildNavItem(
                    _pages[index].icon,
                    _pages[index].title,
                    index == _selectedIndex,
                    () => setState(() => _selectedIndex = index),
                  );
                }),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text('Logout', style: TextStyle(color: Colors.white)),
                  onTap: () async => await authService.signOut(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return UsersManagementPage(users: _users, onRefresh: _loadAllData);
      case 2:
        return RoomspacesPage(roomspaces: _roomspaces, onRefresh: _loadAllData, apiService: _apiService);
      case 3:
        return ExpensesPage(expenses: _expenses, personalExpenses: _personalExpenses, onRefresh: _loadAllData);
      case 4:
        return AnalyticsPage(stats: _stats, analytics: _analytics, users: _users);
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadAllData,
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Users',
                    value: _stats?['total_users']?.toString() ?? '0',
                    change: '+12.5%',
                    isPositive: true,
                    icon: Icons.people_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StatCard(
                    title: 'Active Roomspaces',
                    value: _stats?['total_roomspaces']?.toString() ?? '0',
                    change: '+8.2%',
                    isPositive: true,
                    icon: Icons.home_work_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StatCard(
                    title: 'Total Expenses',
                    value: 'Rs. ${(_stats?['total_expense_amount'] ?? 0).toStringAsFixed(0)}',
                    change: '+15.3%',
                    isPositive: true,
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StatCard(
                    title: 'Banned Users',
                    value: _stats?['banned_users']?.toString() ?? '0',
                    change: '-2.1%',
                    isPositive: true,
                    icon: Icons.block_rounded,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Recent Activity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildRecentUsers(),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildQuickStats(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentUsers() {
    final recentUsers = _users.take(5).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...recentUsers.map((user) => ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF6366F1),
                child: Text(
                  (user['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user['name'] ?? 'Unknown'),
              subtitle: Text(user['email'] ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user['is_banned'] == true 
                      ? Colors.red.shade100 
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user['is_banned'] == true ? 'Banned' : 'Active',
                  style: TextStyle(
                    color: user['is_banned'] == true 
                        ? Colors.red.shade800 
                        : Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatRow('Active Users', _users.where((u) => u['is_banned'] != true).length.toString(), Icons.check_circle, Colors.green),
            _buildStatRow('Banned Users', _users.where((u) => u['is_banned'] == true).length.toString(), Icons.block, Colors.red),
            _buildStatRow('Pro Users', '0', Icons.star, Colors.amber),
            _buildStatRow('Free Users', _users.length.toString(), Icons.person, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class AdminPage {
  final String title;
  final IconData icon;
  AdminPage({required this.title, required this.icon});
}

// Users Management Page
class UsersManagementPage extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback onRefresh;

  const UsersManagementPage({
    super.key,
    required this.users,
    required this.onRefresh,
  });

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final AdminApiService _apiService = AdminApiService();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, banned

  Future<void> _banUser(String userId, String reason) async {
    try {
      await _apiService.banUser(userId, reason);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User banned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await _apiService.unbanUser(userId);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow('Firebase UID', user['firebase_uid'] ?? 'N/A'),
              _buildDetailRow('Phone', user['phone'] ?? 'Not provided'),
              _buildDetailRow('Subscription', user['subscription_plan'] ?? 'free'),
              _buildDetailRow('Status', user['is_banned'] == true ? 'Banned' : 'Active'),
              if (user['is_banned'] == true)
                _buildDetailRow('Ban Reason', user['ban_reason'] ?? 'N/A'),
              _buildDetailRow('Created', user['created_at'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ban User: ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: ${user['email']}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for ban',
                hintText: 'e.g., Unusual activity, Policy violation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _banUser(user['firebase_uid'], reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredUsers = widget.users.where((user) {
      final matchesSearch = user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _filterStatus == 'all' ||
                           (_filterStatus == 'active' && user['is_banned'] != true) ||
                           (_filterStatus == 'banned' && user['is_banned'] == true);
      
      return matchesSearch && matchesFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(value: 'banned', label: Text('Banned')),
                ],
                selected: {_filterStatus},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _filterStatus = newSelection.first);
                },
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Showing ${filteredUsers.length} of ${widget.users.length} users',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Subscription', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final isBanned = user['is_banned'] == true;
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF6366F1),
                                      child: Text(
                                        (user['name'] ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(user['name'] ?? 'Unknown')),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(user['email'] ?? 'Unknown'),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: user['subscription_plan'] == 'pro' 
                                        ? Colors.amber.shade100 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (user['subscription_plan'] ?? 'free').toUpperCase(),
                                    style: TextStyle(
                                      color: user['subscription_plan'] == 'pro' 
                                          ? Colors.amber.shade800 
                                          : Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBanned ? Colors.red.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isBanned ? 'Banned' : 'Active',
                                    style: TextStyle(
                                      color: isBanned ? Colors.red.shade800 : Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, size: 20),
                                      onPressed: () => _showUserDetails(user),
                                      tooltip: 'View Details',
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isBanned)
                                      ElevatedButton(
                                        onPressed: () => _showBanDialog(user),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(60, 32),
                                        ),
                                        child: const Text('Ban', style: TextStyle(fontSize: 12)),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: () => _unbanUser(user['firebase_uid']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(60, 32),
                                        ),
                                        child: const Text('Unban', style: TextStyle(fontSize: 12)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Roomspaces Page - Complete Implementation
class RoomspacesPage extends StatelessWidget {
  final List<Map<String, dynamic>> roomspaces;
  final VoidCallback onRefresh;
  final AdminApiService apiService;

  const RoomspacesPage({
    super.key,
    required this.roomspaces,
    required this.onRefresh,
    required this.apiService,
  });

  void _showRoomspaceDetails(BuildContext context, Map<String, dynamic> roomspace) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(roomspace['name'] ?? 'Roomspace Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', roomspace['id']?.toString() ?? 'N/A'),
              _buildDetailRow('Code', roomspace['code'] ?? 'N/A'),
              _buildDetailRow('Description', roomspace['description'] ?? 'No description'),
              _buildDetailRow('Members', roomspace['member_count']?.toString() ?? '0'),
              _buildDetailRow('Created By', roomspace['creator']?['name'] ?? 'Unknown'),
              _buildDetailRow('Created', roomspace['created_at'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Roomspaces Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onRefresh,
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ${roomspaces.length} roomspaces',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Creator', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: roomspaces.length,
                      itemBuilder: (context, index) {
                        final roomspace = roomspaces[index];
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.home_work_rounded,
                                        color: Color(0xFF8B5CF6),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        roomspace['name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(roomspace['code'] ?? 'N/A'),
                              ),
                              Expanded(
                                child: Text('${roomspace['member_count'] ?? 0} members'),
                              ),
                              Expanded(
                                child: Text(roomspace['creator']?['name'] ?? 'Unknown'),
                              ),
                              Expanded(
                                child: IconButton(
                                  icon: const Icon(Icons.info_outline, size: 20),
                                  onPressed: () => _showRoomspaceDetails(context, roomspace),
                                  tooltip: 'View Details',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Expenses Page - Complete Implementation
class ExpensesPage extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> personalExpenses;
  final VoidCallback onRefresh;

  const ExpensesPage({
    super.key,
    required this.expenses,
    required this.personalExpenses,
    required this.onRefresh,
  });

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String _expenseType = 'shared'; // shared or personal

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense['title'] ?? 'Expense Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Amount', 'Rs. ${expense['amount']?.toString() ?? '0'}'),
              _buildDetailRow('Category', expense['category'] ?? 'N/A'),
              _buildDetailRow('Description', expense['description'] ?? 'No description'),
              if (_expenseType == 'shared') ...[
                _buildDetailRow('Roomspace', expense['roomspace']?['name'] ?? 'N/A'),
                _buildDetailRow('Paid By', expense['paid_by_user']?['name'] ?? 'Unknown'),
                _buildDetailRow('Split Type', expense['split_type'] ?? 'N/A'),
              ] else ...[
                _buildDetailRow('User', expense['user']?['name'] ?? 'Unknown'),
              ],
              _buildDetailRow('Date', expense['created_at'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayExpenses = _expenseType == 'shared' ? widget.expenses : widget.personalExpenses;
    
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Expenses Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'shared', label: Text('Shared')),
                  ButtonSegment(value: 'personal', label: Text('Personal')),
                ],
                selected: {_expenseType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _expenseType = newSelection.first);
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ${displayExpenses.length} expenses',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 2, child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        if (_expenseType == 'shared')
                          const Expanded(child: Text('Roomspace', style: TextStyle(fontWeight: FontWeight.bold)))
                        else
                          const Expanded(child: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = displayExpenses[index];
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  expense['title'] ?? 'Untitled',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Rs. ${expense['amount']?.toString() ?? '0'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    expense['category'] ?? 'Other',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _expenseType == 'shared'
                                      ? (expense['roomspace']?['name'] ?? 'N/A')
                                      : (expense['user']?['name'] ?? 'Unknown'),
                                ),
                              ),
                              Expanded(
                                child: IconButton(
                                  icon: const Icon(Icons.info_outline, size: 20),
                                  onPressed: () => _showExpenseDetails(expense),
                                  tooltip: 'View Details',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Analytics Page - Complete Implementation
class AnalyticsPage extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? analytics;
  final List<Map<String, dynamic>> users;

  const AnalyticsPage({
    super.key,
    this.stats,
    this.analytics,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final categoryBreakdown = analytics?['category_breakdown'] as List? ?? [];
    final subscriptionDist = analytics?['subscription_dist'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 32),
          
          // Category Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...categoryBreakdown.map((cat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(cat['category']?.toString() ?? 'Unknown'),
                        ),
                        Text(
                          '${cat['count']} expenses',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Rs. ${cat['total']?.toString() ?? '0'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Subscription Distribution
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...subscriptionDist.map((sub) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (sub['subscription_plan']?.toString() ?? 'free').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${sub['count']} users',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
