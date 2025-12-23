import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

import 'package:ailaundry_web/login_page.dart';
import 'package:ailaundry_web/models/clothes_item.dart';
import 'package:ailaundry_web/models/dispute.dart';
import 'package:ailaundry_web/models/washer.dart';
import 'package:ailaundry_web/services/clothes_services.dart';
import 'package:ailaundry_web/services/customer_service.dart';
import 'package:ailaundry_web/services/dispute_service.dart';
import 'package:ailaundry_web/services/report_service.dart';
import 'package:ailaundry_web/services/system_settings_service.dart';
import 'package:ailaundry_web/services/washer_service.dart';
import 'package:ailaundry_web/services/login_history_service.dart';
import 'package:ailaundry_web/models/login_history.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  int _selectedIndex = 0;
  Map<String, dynamic>? _metrics;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    try {
      final reportService = ReportService(supabase);
      final metrics = await reportService.getTodayMetrics();
      setState(() {
        _metrics = metrics;
        _isLoadingMetrics = false;
      });
    } catch (e) {
      setState(() => _isLoadingMetrics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading metrics: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Log logout activity - find most recent login without logout
        try {
          final loginHistoryService = LoginHistoryService(supabase);
          final recentLogins = await loginHistoryService.fetchAllLoginHistory(
            userId: currentUser.id,
            limit: 1,
          );
          if (recentLogins.isNotEmpty && recentLogins.first.logoutAt == null) {
            // Find the login record ID from the database
            // Get all logins and filter for null logout_at in code
            final allLogins = await supabase
                .from('login_history')
                .select('id, logout_at')
                .eq('user_id', currentUser.id)
                .order('login_at', ascending: false)
                .limit(10);
            
            final activeLogin = List<Map<String, dynamic>>.from(allLogins)
                .firstWhere(
                  (login) => login['logout_at'] == null,
                  orElse: () => <String, dynamic>{},
                );
            
            if (activeLogin.isNotEmpty && activeLogin['id'] != null) {
              await loginHistoryService.logLogout(activeLogin['id'] as String);
            }
          }
        } catch (e) {
          // Silently fail - logout logging shouldn't block logout
          print('Failed to log logout activity: $e');
        }
      }
      
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Manager Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 2,
        shadowColor: colorScheme.primary.withOpacity(0.3),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMetrics,
              tooltip: 'Refresh Metrics',
              color: Colors.white,
              iconSize: 22,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, left: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
              tooltip: 'Logout',
              color: Colors.white,
              iconSize: 22,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              tabs: const [
                Tab(
                  height: 56,
                  icon: Icon(Icons.dashboard_rounded, size: 22),
                  text: 'Overview',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.gavel_rounded, size: 22),
                  text: 'Disputes',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.inventory_2_rounded, size: 22),
                  text: 'Data Management',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.people_rounded, size: 22),
                  text: 'Users',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.analytics_rounded, size: 22),
                  text: 'Reports',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.settings_rounded, size: 22),
                  text: 'Settings',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme, colorScheme),
          _buildDisputesTab(theme, colorScheme),
          _buildDataManagementTab(theme, colorScheme),
          _buildUsersTab(theme, colorScheme),
          _buildReportsTab(theme, colorScheme),
          _buildSettingsTab(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-Time Metrics',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingMetrics)
            const Center(child: CircularProgressIndicator())
          else if (_metrics != null)
            _buildMetricsGrid(theme, colorScheme, _metrics!)
          else
            const Center(child: Text('No metrics available')),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActions(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, ColorScheme colorScheme, Map<String, dynamic> metrics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildMetricCard(
          theme,
          colorScheme,
          'Items Scanned Today',
          metrics['itemsScannedToday'].toString(),
          Icons.scanner,
          Colors.blue,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Approval Rate',
          '${metrics['approvalRate']}%',
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Open Disputes',
          metrics['disputesOpen'].toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildMetricCard(
          theme,
          colorScheme,
          'Resolved Disputes',
          metrics['disputesResolved'].toString(),
          Icons.verified,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildMetricCard(ThemeData theme, ColorScheme colorScheme, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, ColorScheme colorScheme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(theme, colorScheme, 'View Disputes', Icons.gavel, () {
          _tabController.animateTo(1);
        }),
        _buildActionCard(theme, colorScheme, 'Manage Items', Icons.inventory, () {
          _tabController.animateTo(2); // Data Management is now index 2
        }),
        _buildActionCard(theme, colorScheme, 'View Reports', Icons.analytics, () {
          _tabController.animateTo(4); // Reports is now index 4
        }),
      ],
    );
  }

  Widget _buildActionCard(ThemeData theme, ColorScheme colorScheme, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisputesTab(ThemeData theme, ColorScheme colorScheme) {
    return const DisputeResolutionCenter();
  }

  Widget _buildDataManagementTab(ThemeData theme, ColorScheme colorScheme) {
    return const DataManagementSection();
  }

  Widget _buildUsersTab(ThemeData theme, ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'User Management', icon: Icon(Icons.people)),
              Tab(text: 'Login History', icon: Icon(Icons.history)),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                UserManagementSection(),
                LoginHistorySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(ThemeData theme, ColorScheme colorScheme) {
    return const ReportsSection();
  }

  Widget _buildSettingsTab(ThemeData theme, ColorScheme colorScheme) {
    return const SystemSettingsSection();
  }
}

// Dispute Resolution Center
class DisputeResolutionCenter extends StatefulWidget {
  const DisputeResolutionCenter({super.key});

  @override
  State<DisputeResolutionCenter> createState() => _DisputeResolutionCenterState();
}

class _DisputeResolutionCenterState extends State<DisputeResolutionCenter> {
  final supabase = Supabase.instance.client;
  final DisputeService _disputeService = DisputeService(Supabase.instance.client);
  
  List<Dispute> _disputes = [];
  List<Dispute> _filteredDisputes = [];
  bool _isLoading = true;
  String _sortBy = 'age'; // age or urgency
  String _statusFilter = 'all'; // all, pending, resolved, rejected
  Dispute? _selectedDispute;
  List<Map<String, dynamic>> _similarItems = [];

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final disputes = await _disputeService.fetchDisputes();
      setState(() {
        _disputes = disputes;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading disputes: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _disputes;

    if (_statusFilter != 'all') {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    if (_sortBy == 'age') {
      filtered.sort((a, b) {
        final aDate = a.createdAt ?? '';
        final bDate = b.createdAt ?? '';
        return bDate.compareTo(aDate); // Newest first
      });
    }

    setState(() => _filteredDisputes = filtered);
  }

  Future<void> _selectDispute(Dispute dispute) async {
    setState(() {
      _selectedDispute = dispute;
    });

    if (dispute.itemId != null && dispute.id != null) {
      try {
        final similar = await _disputeService.getSimilarItems(dispute.id!);
        setState(() => _similarItems = similar);
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _resolveDispute(String id, String status, String? notes) async {
    try {
      // Get the dispute before updating to get customer_id
      final dispute = _disputes.firstWhere((d) => d.id == id);
      
      await _disputeService.updateDisputeStatus(id, status, resolutionNotes: notes);
      
      // Automatically create notification for the customer
      if (dispute.customerId != null) {
        try {
          String disputeTypeLabel;
          switch (dispute.type) {
            case 'missing':
              disputeTypeLabel = 'Missing Item';
              break;
            case 'duplicate':
              disputeTypeLabel = 'Duplicate Item';
              break;
            case 'wrong_clothes':
              disputeTypeLabel = 'Wrong Clothes';
              break;
            default:
              disputeTypeLabel = dispute.type;
          }

          String statusLabel;
          switch (status) {
            case 'pending':
              statusLabel = 'Pending Review';
              break;
            case 'reviewing':
              statusLabel = 'Under Review';
              break;
            case 'resolved':
              statusLabel = 'Resolved';
              break;
            case 'rejected':
              statusLabel = 'Rejected';
              break;
            default:
              statusLabel = status;
          }

          String notificationMessage;
          if (notes != null && notes.isNotEmpty) {
            notificationMessage = 'Your dispute "${disputeTypeLabel}" has been updated to ${statusLabel}. $notes';
          } else {
            notificationMessage = 'Your dispute "${disputeTypeLabel}" status has been updated to ${statusLabel}.';
          }

          await supabase.from('notifications').insert({
            'user_id': dispute.customerId!,
            'title': 'Dispute Update',
            'message': notificationMessage,
            'type': 'dispute',
            'related_id': id,
            'related_type': 'dispute',
            'is_read': false,
          });
        } catch (e) {
          // Log error but don't fail the dispute resolution
          print('Error creating notification: $e');
        }
      }
      
      await _loadDisputes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispute $status successfully. Customer has been notified.')),
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

  Future<void> _notifyCustomer(Dispute dispute) async {
    if (dispute.customerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This dispute is from an unauthenticated user. Please contact them via alaundryai@gmail.com'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      // Fetch customer information
      final customerResponse = await supabase
          .from('laundry_users')
          .select('id, name, email')
          .eq('id', dispute.customerId!)
          .maybeSingle();

      if (customerResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer not found')),
          );
        }
        return;
      }

      final customerName = customerResponse['name'] as String? ?? 'Customer';
      final customerEmail = customerResponse['email'] as String? ?? '';

      // Show notification dialog with customer info
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notify Customer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: $customerName'),
                const SizedBox(height: 16),
                const Text(
                  'An in-app notification will be sent to the customer about this dispute update.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The customer will see this notification when they open the mobile app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _sendCustomerNotification(dispute, customerEmail, customerName);
                },
                child: const Text('Send Notification'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching customer info: $e')),
        );
      }
    }
  }

  Future<void> _sendCustomerNotification(
    Dispute dispute,
    String customerEmail,
    String customerName,
  ) async {
    if (dispute.customerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot send notification: Customer ID not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Get dispute type label
      String disputeTypeLabel;
      switch (dispute.type) {
        case 'missing':
          disputeTypeLabel = 'Missing Item';
          break;
        case 'duplicate':
          disputeTypeLabel = 'Duplicate Item';
          break;
        case 'wrong_clothes':
          disputeTypeLabel = 'Wrong Clothes';
          break;
        default:
          disputeTypeLabel = dispute.type;
      }

      // Get status label
      String statusLabel;
      switch (dispute.status) {
        case 'pending':
          statusLabel = 'Pending Review';
          break;
        case 'reviewing':
          statusLabel = 'Under Review';
          break;
        case 'resolved':
          statusLabel = 'Resolved';
          break;
        case 'rejected':
          statusLabel = 'Rejected';
          break;
        default:
          statusLabel = dispute.status;
      }

      // Create notification message
      String notificationMessage;
      if (dispute.resolutionNotes != null && dispute.resolutionNotes!.isNotEmpty) {
        notificationMessage = 'Your dispute "${disputeTypeLabel}" has been updated to ${statusLabel}. ${dispute.resolutionNotes}';
      } else {
        notificationMessage = 'Your dispute "${disputeTypeLabel}" status has been updated to ${statusLabel}.';
      }

      // Create in-app notification record
      await supabase.from('notifications').insert({
        'user_id': dispute.customerId!,
        'title': 'Dispute Update',
        'message': notificationMessage,
        'type': 'dispute',
        'related_id': dispute.id,
        'related_type': 'dispute',
        'is_read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to $customerName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResolutionDialog(Dispute dispute) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolve Dispute: ${dispute.type}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Resolution Status'),
              items: const [
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Info')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null && dispute.id != null) {
                  _resolveDispute(dispute.id!, value, notesController.text);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Resolution Notes'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Disputes List
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Status',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _statusFilter = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sort by',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'age', child: Text('Age')),
                            DropdownMenuItem(value: 'urgency', child: Text('Urgency')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortBy = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredDisputes.isEmpty
                          ? const Center(child: Text('No disputes found'))
                          : ListView.builder(
                              itemCount: _filteredDisputes.length,
                              itemBuilder: (context, index) {
                                final dispute = _filteredDisputes[index];
                                final isUnauthenticated = dispute.customerId == null;
                                return ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(dispute.type.toUpperCase()),
                                      ),
                                      if (isUnauthenticated)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_off,
                                                size: 14,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Guest',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dispute.notes),
                                      if (isUnauthenticated)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'No account - Contact via email',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Chip(
                                    label: Text(dispute.status),
                                    backgroundColor: dispute.status == 'pending'
                                        ? Colors.orange
                                        : dispute.status == 'resolved'
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                  onTap: () => _selectDispute(dispute),
                                  selected: _selectedDispute?.id == dispute.id,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        // Dispute Details & Matching Tool
        Expanded(
          flex: 2,
          child: _selectedDispute == null
              ? const Center(child: Text('Select a dispute to view details'))
              : _buildDisputeDetails(theme, colorScheme, _selectedDispute!),
        ),
      ],
    );
  }

  Widget _buildDisputeDetails(ThemeData theme, ColorScheme colorScheme, Dispute dispute) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dispute Details',
                style: theme.textTheme.headlineSmall,
              ),
              Chip(
                label: Text(dispute.status.toUpperCase()),
                backgroundColor: dispute.status == 'pending'
                    ? Colors.orange
                    : dispute.status == 'resolved'
                        ? Colors.green
                        : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                children: [
                  Text('Type: ${dispute.type}'),
                      if (dispute.customerId == null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Guest User',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Notes: ${dispute.notes}'),
                  if (dispute.customerId != null)
                    Text('Customer ID: ${dispute.customerId}')
                  else
                    Text(
                      'Customer: Not authenticated - Contact via alaundryai@gmail.com',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (dispute.itemId != null)
                    Text('Item ID: ${dispute.itemId}'),
                  if (dispute.resolutionNotes != null) ...[
                    const SizedBox(height: 8),
                    Text('Resolution Notes: ${dispute.resolutionNotes}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (dispute.itemId != null) ...[
            Text(
              'Similar Items',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _similarItems.isEmpty
                ? const Text('No similar items found')
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _similarItems.length,
                    itemBuilder: (context, index) {
                      final item = _similarItems[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(item['type'] ?? ''),
                              Text(item['brand'] ?? ''),
                              Text(item['color'] ?? ''),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _showResolutionDialog(dispute),
                child: const Text('Resolve Dispute'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _notifyCustomer(dispute),
                child: const Text('Notify Customer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Data Management Section
class DataManagementSection extends StatefulWidget {
  const DataManagementSection({super.key});

  @override
  State<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends State<DataManagementSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Items'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
            Tab(icon: Icon(Icons.local_laundry_service), text: 'Washers'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ItemsManagementTab(),
              CustomersManagementTab(),
              WashersManagementTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class ItemsManagementTab extends StatefulWidget {
  const ItemsManagementTab({super.key});

  @override
  State<ItemsManagementTab> createState() => _ItemsManagementTabState();
}

class _ItemsManagementTabState extends State<ItemsManagementTab> {
  final ClothesService _clothesService = ClothesService(Supabase.instance.client);
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<ClothesItem> _allItems = []; // All items from database
  List<ClothesItem> _filteredItems = []; // Items after filtering
  List<ClothesItem> _displayedItems = []; // Items for current page
  List<Washer> _washers = [];
  bool _isLoading = true;
  String? _error;
  bool _sortAscending = false; // Default to descending (newest first)
  int _currentPage = 1;
  static const int _itemsPerPage = 5;
  
  // Filter values
  String? _selectedColor;
  String? _selectedBrand;
  String? _selectedType;
  String? _selectedWasherId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadItems(),
      _loadWashers(),
    ]);
  }

  Future<void> _loadItems() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final items = await _clothesService.fetchClothes(
        limit: 1000,
        ascending: _sortAscending,
      );
      if (mounted) {
        setState(() {
          _allItems = items;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadWashers() async {
    try {
      final washers = await _washerService.fetchWashers(role: 'washer');
      if (mounted) {
        setState(() {
          _washers = washers;
          if (!_isLoading) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      // Silently fail - washers filter is optional
      if (mounted && !_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _applyFilters() {
    var filtered = List<ClothesItem>.from(_allItems);
    
    // Filter by color
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      filtered = filtered.where((item) => item.color == _selectedColor).toList();
    }
    
    // Filter by brand
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      filtered = filtered.where((item) => item.brand == _selectedBrand).toList();
    }
    
    // Filter by type
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered.where((item) => item.type == _selectedType).toList();
    }
    
    // Filter by washer
    if (_selectedWasherId != null && _selectedWasherId!.isNotEmpty) {
      filtered = filtered.where((item) => item.washerId == _selectedWasherId).toList();
    }
    
    setState(() {
      _filteredItems = filtered;
      _currentPage = 1; // Reset to first page when filters change
      _updateDisplayedItems();
      _isLoading = false;
    });
  }
  
  List<String> get _uniqueColors {
    return _allItems.map((item) => item.color).where((color) => color.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueBrands {
    return _allItems.map((item) => item.brand).where((brand) => brand.isNotEmpty).toSet().toList()..sort();
  }
  
  List<String> get _uniqueTypes {
    return _allItems.map((item) => item.type).where((type) => type.isNotEmpty).toSet().toList()..sort();
  }

  void _updateDisplayedItems() {
    if (_filteredItems.isEmpty) {
      _displayedItems = [];
      return;
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    _displayedItems = _filteredItems.sublist(
      startIndex,
      endIndex > _filteredItems.length ? _filteredItems.length : endIndex,
    );
  }

  int get _totalPages => _filteredItems.isEmpty ? 1 : (_filteredItems.length / _itemsPerPage).ceil();

  void _changePage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
        _updateDisplayedItems();
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortAscending = !_sortAscending;
      _currentPage = 1; // Reset to first page
    });
    _loadItems();
  }
  
  void _clearFilters() {
    setState(() {
      _selectedColor = null;
      _selectedBrand = null;
      _selectedType = null;
      _selectedWasherId = null;
      _applyFilters();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'voided':
      case 'returned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_allItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Items will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items (${_filteredItems.length}${_filteredItems.length != _allItems.length ? ' of ${_allItems.length}' : ''})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      // Sort order button
                      Tooltip(
                        message: _sortAscending ? 'Sort: Oldest First' : 'Sort: Newest First',
                        child: IconButton(
                          icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          ),
                          onPressed: _toggleSortOrder,
                          tooltip: _sortAscending ? 'Sort: Oldest First' : 'Sort: Newest First',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadData,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filters section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedColor != null || _selectedBrand != null || 
                              _selectedType != null || _selectedWasherId != null)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Color filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedColor,
                              decoration: const InputDecoration(
                                labelText: 'Color',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Colors'),
                                ),
                                ..._uniqueColors.map((color) => DropdownMenuItem<String>(
                                  value: color,
                                  child: Text(color),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedColor = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Brand filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedBrand,
                              decoration: const InputDecoration(
                                labelText: 'Brand',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Brands'),
                                ),
                                ..._uniqueBrands.map((brand) => DropdownMenuItem<String>(
                                  value: brand,
                                  child: Text(brand),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedBrand = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Type filter
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Types'),
                                ),
                                ..._uniqueTypes.map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                          // Washer filter
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _selectedWasherId,
                              decoration: const InputDecoration(
                                labelText: 'Washer',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Washers'),
                                ),
                                ..._washers.map((washer) => DropdownMenuItem<String>(
                                  value: washer.id,
                                  child: Text(washer.name),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedWasherId = value;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Pagination info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Showing ${_displayedItems.length} of ${_filteredItems.length} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No items match the selected filters',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                )
              : _displayedItems.isEmpty
                  ? const Center(
                      child: Text('No items to display'),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _displayedItems.length,
                  itemBuilder: (context, index) {
                    final item = _displayedItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported),
                              )
                            : const Icon(Icons.inventory_2),
                        title: Text('${item.type} - ${item.brand}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Color: ${item.color}'),
                            if (item.status != null) ...[
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(
                                  item.status!.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                                backgroundColor: _getStatusColor(item.status!),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.createdAt != null)
                              Text(
                                DateTime.parse(item.createdAt!)
                                    .toString()
                                    .split(' ')[0],
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Pagination controls
        if (_totalPages > 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: _currentPage > 1
                      ? () => _changePage(1)
                      : null,
                  tooltip: 'First page',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                  tooltip: 'Previous page',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () => _changePage(_currentPage + 1)
                      : null,
                  tooltip: 'Next page',
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _currentPage < _totalPages
                      ? () => _changePage(_totalPages)
                      : null,
                  tooltip: 'Last page',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CustomersManagementTab extends StatefulWidget {
  const CustomersManagementTab({super.key});

  @override
  State<CustomersManagementTab> createState() => _CustomersManagementTabState();
}

class _CustomersManagementTabState extends State<CustomersManagementTab> {
  final supabase = Supabase.instance.client;
  final CustomerService _customerService = CustomerService(Supabase.instance.client);
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<Washer> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final customers = await _customerService.fetchCustomers();
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCustomers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No customers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Customers will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customers (${_customers.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadCustomers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final customer = _customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(customer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${customer.email}'),
                      Text('Role: ${customer.role}'),
                      if (customer.phone != null && customer.phone!.isNotEmpty) 
                        Text('Phone: ${customer.phone}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(customer.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: customer.isActive ? Colors.green : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditCustomerDialog(customer);
                          } else if (value == 'delete') {
                            _deleteCustomer(customer);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditCustomerDialog(Washer customer) async {
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone ?? '');
    bool isActive = customer.isActive;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  enabled: false, // Email shouldn't be changed
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone (Optional)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Prevent user from disabling themselves
                final currentUser = supabase.auth.currentUser;
                if (currentUser != null && customer.id == currentUser.id && !isActive) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot disable your own account'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                try {
                  await _customerService.updateCustomer(customer.id!, {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim().isEmpty 
                        ? null 
                        : phoneController.text.trim(),
                    'is_active': isActive,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer updated successfully')),
                    );
                    _loadCustomers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating customer: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _deleteCustomer(Washer customer) async {
    if (customer.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _customerService.deleteCustomer(customer.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
          _loadCustomers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e')),
          );
        }
      }
    }
  }
}

class WashersManagementTab extends StatefulWidget {
  const WashersManagementTab({super.key});

  @override
  State<WashersManagementTab> createState() => _WashersManagementTabState();
}

class _WashersManagementTabState extends State<WashersManagementTab> {
  final supabase = Supabase.instance.client;
  final WasherService _washerService = WasherService(Supabase.instance.client);
  List<Washer> _washers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWashers();
  }

  Future<void> _loadWashers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final washers = await _washerService.fetchWashers(role: 'washer');
      if (mounted) {
        setState(() {
          _washers = washers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWashers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_washers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_laundry_service_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No washers found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Washers will appear here once they are added to the system',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Washers (${_washers.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadWashers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _washers.length,
            itemBuilder: (context, index) {
              final washer = _washers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(washer.name.isNotEmpty ? washer.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(washer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${washer.email}'),
                      Text('Role: ${washer.role}'),
                      if (washer.createdAt != null)
                        Text(
                          'Created: ${DateTime.parse(washer.createdAt!).toString().split(' ')[0]}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(washer.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: washer.isActive ? Colors.green : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'toggle',
                            child: Text('Toggle Status'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            // TODO: Implement edit washer
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit washer feature coming soon')),
                            );
                          } else if (value == 'toggle') {
                            _toggleWasherStatus(washer);
                          } else if (value == 'delete') {
                            _deleteWasher(washer);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleWasherStatus(Washer washer) async {
    if (washer.id == null) return;
    
    // Prevent user from disabling themselves
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && washer.id == currentUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot disable your own account'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      await _washerService.toggleUserStatus(washer.id!, !washer.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Washer ${washer.isActive ? "disabled" : "enabled"} successfully'),
          ),
        );
        _loadWashers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteWasher(Washer washer) async {
    if (washer.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Washer'),
        content: Text('Are you sure you want to delete ${washer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _washerService.deleteWasher(washer.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Washer deleted successfully')),
          );
          _loadWashers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting washer: $e')),
          );
        }
      }
    }
  }
}

// User Management Section
class UserManagementSection extends StatefulWidget {
  const UserManagementSection({super.key});

  @override
  State<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends State<UserManagementSection> {
  final supabase = Supabase.instance.client;
  final WasherService _userService = WasherService(Supabase.instance.client);
  
  List<Washer> _users = [];
  List<Washer> _filteredUsers = [];
  bool _isLoading = true;
  String _roleFilter = 'all'; // all, washer, checker, admin
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.fetchAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _applyFilters();
          _isLoading = false;
        });
        
        // Show debug info if no users found
        if (users.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users found in database. Users will appear here after registration.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = _users;

    // Filter by role
    if (_roleFilter != 'all') {
      filtered = filtered.where((u) => u.role == _roleFilter).toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((u) {
        return u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = filtered);
  }

  Future<void> _toggleUserStatus(Washer user) async {
    // Prevent user from disabling themselves
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && user.id == currentUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot disable your own account'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await _userService.toggleUserStatus(user.id!, !user.isActive);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.isActive ? "disabled" : "enabled"} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error updating user status';
        if (e.toString().contains('not found')) {
          errorMessage = 'User not found. The user may have been deleted.';
        } else if (e.toString().contains('permission') || e.toString().contains('RLS')) {
          errorMessage = 'Permission denied. You may not have permission to update this user.';
        } else if (e.toString().contains('is_active column does not exist')) {
          errorMessage = 'Database configuration error. The is_active column does not exist. Please contact the administrator.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showEditUserDialog(Washer? user, {String? defaultRole}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    // Normalize role: convert 'manager' to 'admin' for consistency
    // Use defaultRole if provided, otherwise use user's role, otherwise default to 'washer'
    String initialRole = defaultRole ?? user?.role ?? 'washer';
    if (initialRole == 'manager') {
      initialRole = 'admin';
    }

    showDialog(
      context: context,
      builder: (context) {
        // Use a ValueNotifier to properly track the selected role
        final selectedRoleNotifier = ValueNotifier<String>(initialRole);
        
        return ValueListenableBuilder<String>(
          valueListenable: selectedRoleNotifier,
          builder: (context, selectedRole, _) {
            return AlertDialog(
              title: Text(user == null ? 'Add New User' : 'Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: user == null, // Can't change email for existing users
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone (Optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'washer', child: Text('Washer')),
                        DropdownMenuItem(value: 'checker', child: Text('Checker')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin (Manager)')),
                        DropdownMenuItem(value: 'customer', child: Text('Customer')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedRoleNotifier.value = value;
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selectedRoleNotifier.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final roleToSave = selectedRoleNotifier.value;
                    try {
                      if (user == null) {
                        // Create user with Supabase Auth and send invitation email
                        // SQL trigger will automatically create laundry_users record
                        await _userService.createWasherWithAuth(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          role: roleToSave,
                          redirectTo: null, // Optional: set redirect URL if needed
                        );
                      } else {
                        // Validate user ID exists
                        if (user.id == null || user.id!.isEmpty) {
                          throw Exception('Invalid user ID. Cannot update user.');
                        }
                        
                        final updates = <String, dynamic>{
                          'name': nameController.text.trim(),
                          'role': roleToSave,
                        };
                        // Only update email if it changed and user is new
                        if (emailController.text.trim() != user.email) {
                          updates['email'] = emailController.text.trim();
                        }
                        await _userService.updateWasher(user.id!, updates);
                      }
                      selectedRoleNotifier.dispose();
                      Navigator.pop(context);
                      await _loadUsers();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              user == null 
                                ? 'User created successfully! Invitation email sent to ${emailController.text.trim()}'
                                : 'User role updated successfully'
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        String errorMessage = 'Error updating user';
                        final errorString = e.toString().toLowerCase();
                        
                        if (errorString.contains('not found') || 
                            errorString.contains('pgrst116') ||
                            errorString.contains('0 rows')) {
                          errorMessage = 'User not found or update failed. The user may have been deleted.';
                        } else if (errorString.contains('permission') || 
                                   errorString.contains('rls') ||
                                   errorString.contains('create_update_functions')) {
                          errorMessage = 'Permission denied. Please run the SQL in create_update_functions.sql in your Supabase SQL Editor to create the RPC function that bypasses RLS.';
                        } else if (errorString.contains('function') || 
                                   errorString.contains('does not exist')) {
                          errorMessage = 'Database function missing. Please run create_update_functions.sql in your Supabase SQL Editor.';
                        } else {
                          errorMessage = 'Error: ${e.toString()}';
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(user == null ? 'Create' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header with filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Management',
                    style: theme.textTheme.headlineSmall,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showEditUserDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add User'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search users',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'washer', child: Text('Washers')),
                        DropdownMenuItem(value: 'checker', child: Text('Checkers')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'customer', child: Text('Customers')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _roleFilter = value;
                            _applyFilters();
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
        // Users List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _users.isEmpty 
                                ? 'No users found in database' 
                                : 'No users match your filters',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _users.isEmpty
                                ? 'Users will appear here after they register and complete their profile'
                                : 'Try adjusting your search or role filter',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_users.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (user.role == 'admin' || user.role == 'manager')
                                  ? Colors.purple
                                  : user.role == 'checker'
                                      ? Colors.blue
                                      : Colors.green,
                              child: Text(
                                user.name.isNotEmpty 
                                    ? user.name[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(user.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                if (user.phone != null) Text(user.phone!),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(user.role.toUpperCase()),
                                  backgroundColor: (user.role == 'admin' || user.role == 'manager')
                                      ? Colors.purple.withOpacity(0.2)
                                      : user.role == 'checker'
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: user.isActive,
                                  onChanged: (supabase.auth.currentUser?.id == user.id)
                                      ? null // Disable switch for current user
                                      : (_) => _toggleUserStatus(user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditUserDialog(user),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// Reports Section
class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  final supabase = Supabase.instance.client;
  final ReportService _reportService = ReportService(Supabase.instance.client);
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateDailyReport() async {
    setState(() => _isGenerating = true);
    try {
      final report = await _reportService.getDailyReport(_selectedDate);
      if (mounted) {
        _showReportDialog(
          'Daily Report - ${_selectedDate.toString().split(' ')[0]}',
          report,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _viewMonthlyReports() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    setState(() => _isGenerating = true);
    try {
      // Get all items for the current month
      final itemsResponse = await supabase
          .from('clothes')
          .select()
          .gte('created_at', firstDayOfMonth.toIso8601String())
          .lte('created_at', lastDayOfMonth.toIso8601String());

      final items = List<Map<String, dynamic>>.from(itemsResponse);
      
      final report = {
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'scanned': items.length,
        'approved': items.where((i) => i['status'] == 'approved').length,
        'pending': items.where((i) => i['status'] == 'pending_check').length,
        'returned': items.where((i) => i['status'] == 'returned').length,
        'voided': items.where((i) => i['status'] == 'voided').length,
        'items': items,
      };

      if (mounted) {
        _showReportDialog('Monthly Report - ${report['month']}', report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading monthly report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showReportDialog(String title, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportMetric('Items Scanned', report['scanned']?.toString() ?? '0'),
              _buildReportMetric('Approved', report['approved']?.toString() ?? '0'),
              if (report['pending'] != null)
                _buildReportMetric('Pending', report['pending'].toString()),
              if (report['returned'] != null)
                _buildReportMetric('Returned', report['returned'].toString()),
              if (report['voided'] != null)
                _buildReportMetric('Voided', report['voided'].toString()),
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

  Widget _buildReportMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    // Show dialog to select export options
    final exportOptions = await _showExportOptionsDialog();
    if (exportOptions == null) return; // User cancelled

    setState(() => _isGenerating = true);
    try {
      // Build query based on options
      var query = supabase
          .from('clothes')
          .select('id, brand, color, type, status, created_at, washer_id, checker_id');

      // Apply date range filter
      if (exportOptions['useDateRange'] == true) {
        final startDate = exportOptions['startDate'] as DateTime;
        final endDate = exportOptions['endDate'] as DateTime;
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        
        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String());
      }

      // Apply status filter if selected
      if (exportOptions['status'] != null && exportOptions['status'] != 'all') {
        query = query.eq('status', exportOptions['status']);
      }

      final itemsResponse = await query.order('created_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(itemsResponse);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data found for the selected criteria.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate filename with date range if applicable
      String baseFilename;
      if (exportOptions['useDateRange'] == true) {
        final startDate = exportOptions['startDate'] as DateTime;
        final endDate = exportOptions['endDate'] as DateTime;
        baseFilename = 'report_${startDate.toString().split(' ')[0]}_to_${endDate.toString().split(' ')[0]}';
      } else {
        baseFilename = 'report_all_data_${DateTime.now().toIso8601String().split('T')[0]}';
      }
      
      // Add appropriate extension based on format
      String filename;
      if (format == 'CSV') {
        filename = '$baseFilename.csv';
      } else if (format == 'XLSX') {
        filename = '$baseFilename.xlsx';
      } else if (format == 'PDF') {
        filename = '$baseFilename.pdf';
      } else {
        filename = '$baseFilename.csv';
      }

      if (format == 'CSV') {
        _exportToCSV(items, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV file downloaded successfully! (${items.length} items)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (format == 'XLSX') {
        _exportToXLSX(items, filename);
        // Success message is shown inside _exportToXLSX
      } else if (format == 'PDF') {
        await _exportToPDF(items, filename);
        // Success message is shown inside _exportToPDF
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showExportOptionsDialog() async {
    DateTime? startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime? endDate = DateTime.now();
    bool useDateRange = false; // Default to "All Data"
    String selectedStatus = 'all';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      title: const Text('All Data'),
                      value: false,
                      groupValue: useDateRange,
                      onChanged: (value) {
                        setDialogState(() {
                          useDateRange = false;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Date Range'),
                      value: true,
                      groupValue: useDateRange,
                      onChanged: (value) {
                        setDialogState(() {
                          useDateRange = true;
                        });
                      },
                    ),
                    if (useDateRange) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Start Date'),
                        subtitle: Text(startDate != null
                            ? startDate.toString().split(' ')[0]
                            : 'Not selected'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: endDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startDate = picked;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('End Date'),
                        subtitle: Text(endDate != null
                            ? endDate.toString().split(' ')[0]
                            : 'Not selected'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Filter by Status',
                        isDense: true,
                      ),
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'pending_check', child: Text('Pending Check')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'returned', child: Text('Returned')),
                        DropdownMenuItem(value: 'voided', child: Text('Voided')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus = value ?? 'all';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (useDateRange && (startDate == null || endDate == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select both start and end dates')),
                      );
                      return;
                    }
                    if (useDateRange && startDate != null && endDate != null) {
                      if (startDate!.isAfter(endDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Start date must be before end date')),
                        );
                        return;
                      }
                    }
                    Navigator.pop(context, {
                      'useDateRange': useDateRange,
                      'startDate': startDate,
                      'endDate': endDate,
                      'status': selectedStatus,
                    });
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _escapeCsvField(String field) {
    // Escape quotes and wrap in quotes if contains comma, quote, or newline
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  void _exportToCSV(List<Map<String, dynamic>> items, String filename) {
    // Create CSV content with proper escaping
    final csv = StringBuffer();
    csv.writeln('ID,Brand,Color,Type,Status,Created At');
    
    for (var item in items) {
      csv.writeln([
        _escapeCsvField((item['id'] ?? '').toString()),
        _escapeCsvField((item['brand'] ?? '').toString()),
        _escapeCsvField((item['color'] ?? '').toString()),
        _escapeCsvField((item['type'] ?? '').toString()),
        _escapeCsvField((item['status'] ?? '').toString()),
        _escapeCsvField((item['created_at'] ?? '').toString()),
      ].join(','));
    }

    // Download the CSV file
    _downloadFile(filename, csv.toString(), 'text/csv');
  }

  void _exportToXLSX(List<Map<String, dynamic>> items, String filename) {
    try {
      // Create a new Excel file
      final excelFile = excel.Excel.createExcel();
      excelFile.delete('Sheet1'); // Delete default sheet
      final sheet = excelFile['Report'];

      // Add headers
      final headers = ['ID', 'Brand', 'Color', 'Type', 'Status', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: excel.ExcelColor.fromHexString('#E0E0E0'),
        );
      }

      // Add data rows
      for (int row = 0; row < items.length; row++) {
        final item = items[row];
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1)).value = excel.TextCellValue((item['id'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1)).value = excel.TextCellValue((item['brand'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1)).value = excel.TextCellValue((item['color'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row + 1)).value = excel.TextCellValue((item['type'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row + 1)).value = excel.TextCellValue((item['status'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row + 1)).value = excel.TextCellValue((item['created_at'] ?? '').toString());
      }

      // Convert to bytes
      final excelBytes = excelFile.encode();
      if (excelBytes != null) {
        _downloadFileBytes(filename, Uint8List.fromList(excelBytes), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('XLSX file downloaded successfully! (${items.length} items)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to generate XLSX file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to XLSX: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<Map<String, dynamic>> items, String filename) async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Laundry Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Brand', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Color', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Created At', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['id'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['brand'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['color'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['type'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['status'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['created_at'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Items: ${items.length}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ];
          },
        ),
      );

      // Convert to bytes
      final pdfBytes = await pdf.save();
      _downloadFileBytes(filename, Uint8List.fromList(pdfBytes), 'application/pdf');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF file downloaded successfully! (${items.length} items)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadFile(String filename, String content, String mimeType) {
    // Create a blob and download it using dart:html
    final bytes = utf8.encode(content);
    _downloadFileBytes(filename, bytes, mimeType);
  }

  void _downloadFileBytes(String filename, Uint8List bytes, String mimeType) {
    // Create a blob and download it using dart:html
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports & Analytics',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Report',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDate,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text('Date: ${_selectedDate.toString().split(' ')[0]}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _generateDailyReport,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Generate Daily Report'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Report',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Auto-generated nightly'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _viewMonthlyReports,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('View Monthly Reports'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Center',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create custom reports in CSV, XLSX, or PDF format'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('CSV'),
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export CSV'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('XLSX'),
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export XLSX'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('PDF'),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical Reports',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Searchable archive of reports by date, customer, or status'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Reports',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by date, customer, or status...',
                    ),
                    onChanged: (value) {
                      // Implement search functionality if needed
                    },
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

// System Settings Section
class SystemSettingsSection extends StatefulWidget {
  const SystemSettingsSection({super.key});

  @override
  State<SystemSettingsSection> createState() => _SystemSettingsSectionState();
}

class _SystemSettingsSectionState extends State<SystemSettingsSection> {
  final supabase = Supabase.instance.client;
  final SystemSettingsService _settingsService = SystemSettingsService(Supabase.instance.client);
  
  TimeOfDay _cutOffTime = const TimeOfDay(hour: 18, minute: 0);
  String _reportFormat = 'PDF';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final cutOffTime = await _settingsService.getDailyCutOffTime();
      setState(() {
        _cutOffTime = cutOffTime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Use default if loading fails
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      // Save the cut-off time
      await _settingsService.setDailyCutOffTime(_cutOffTime);
      
      // Wait a moment for the database to commit
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Reload settings to verify the save worked and get the actual saved value
      await _loadSettings();
      
      if (mounted) {
        // Show success message with the actual loaded value (not the local state)
        final loadedTime = await _settingsService.getDailyCutOffTime();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved! Washers can edit clothes until ${_formatTime(loadedTime)} (Philippine Time) daily.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // Reload to show the actual saved value from database
        await _loadSettings();
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Settings',
                style: theme.textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSettings,
                tooltip: 'Refresh settings',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Parameters',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListTile(
                      title: const Text('Daily Cut-off Time for Washer Edits'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current: ${_formatTime(_cutOffTime)} (Philippine Time)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Washers can only edit clothes before this time each day (Philippine Time, UTC+8)',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          // Show dialog explaining Philippine Time
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Set Cut-off Time'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Philippine Time: ${_formatTime(TimeOfDay.fromDateTime(SystemSettingsService.getPhilippineTime()))}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'The time you set will be interpreted as Philippine Time (UTC+8).',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );
                          
                          if (proceed == true) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _cutOffTime,
                              helpText: 'Set cut-off time (Philippine Time)',
                            );
                            if (time != null) {
                              setState(() => _cutOffTime = time);
                            }
                          }
                        },
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('Default Report Format'),
                    subtitle: Text(_reportFormat),
                    trailing: DropdownButton<String>(
                      value: _reportFormat,
                      items: const [
                        DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                        DropdownMenuItem(value: 'CSV', child: Text('CSV')),
                        DropdownMenuItem(value: 'XLSX', child: Text('XLSX')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reportFormat = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical Archive & Recovery',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Manage deleted or voided entries with one-click restore'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to archive
                    },
                    child: const Text('View Archive'),
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

// Login History Section
class LoginHistorySection extends StatefulWidget {
  const LoginHistorySection({super.key});

  @override
  State<LoginHistorySection> createState() => _LoginHistorySectionState();
}

class _LoginHistorySectionState extends State<LoginHistorySection> {
  final LoginHistoryService _loginHistoryService = LoginHistoryService(Supabase.instance.client);
  List<LoginHistory> _loginHistory = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedUserId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
  }

  Future<void> _loadLoginHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _loginHistoryService.fetchAllLoginHistory(
        userId: _selectedUserId,
        startDate: _startDate,
        endDate: _endDate,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _loginHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by User ID (optional)',
                    prefixIcon: Icon(Icons.person),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _selectedUserId = value.isEmpty ? null : value;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                      });
                      _loadLoginHistory();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      isDense: true,
                    ),
                    child: Text(_startDate != null
                        ? _startDate!.toString().split(' ')[0]
                        : 'Select date'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                      });
                      _loadLoginHistory();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      isDense: true,
                    ),
                    child: Text(_endDate != null
                        ? _endDate!.toString().split(' ')[0]
                        : 'Select date'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedUserId = null;
                    _startDate = null;
                    _endDate = null;
                  });
                  _loadLoginHistory();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLoginHistory,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Login History List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Error: $_error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadLoginHistory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _loginHistory.isEmpty
                      ? const Center(child: Text('No login history found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _loginHistory.length,
                          itemBuilder: (context, index) {
                            final history = _loginHistory[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: history.logoutAt == null
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Icon(
                                    history.logoutAt == null
                                        ? Icons.check_circle
                                        : Icons.logout,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  history.userName ?? history.userEmail ?? 'Unknown User',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Role: ${history.userRole ?? 'N/A'}'),
                                    Text('Login: ${history.formattedLoginAt}'),
                                    if (history.logoutAt != null)
                                      Text('Logout: ${history.formattedLogoutAt}'),
                                    Text('Duration: ${history.formattedSessionDuration}'),
                                    if (history.ipAddress != null)
                                      Text('IP: ${history.ipAddress}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    history.logoutAt == null ? 'Active' : 'Ended',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                  backgroundColor: history.logoutAt == null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

