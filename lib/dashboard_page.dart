import 'package:ailaundry_web/clothing_preview_dialog.dart';
import 'package:ailaundry_web/login_page.dart';
import 'package:ailaundry_web/models/clothes_item.dart';
import 'package:ailaundry_web/services/clothes_services.dart';
import 'package:ailaundry_web/widgets/clothes_card.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final ClothesService service;
  final TextEditingController _searchController = TextEditingController();

  List<ClothesItem> _clothes = [];
  List<ClothesItem> _filtered = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _selectedFilter = 'All';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filterOptions = ['All', 'Shirt', 'Pants', 'Dress', 'Jacket', 'Shoes'];

  @override
  void initState() {
    super.initState();
    service = ClothesService(supabase);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fetchClothes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClothes() async {
    setState(() => _isLoading = true);
    try {
      _clothes = await service.fetchClothes();
      _applyFilters();
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    String searchQuery = _searchController.text.toLowerCase();

    setState(() {
      _filtered = _clothes.where((item) {
        bool matchesSearch = searchQuery.isEmpty ||
            item.brand.toLowerCase().contains(searchQuery) ||
            item.type.toLowerCase().contains(searchQuery) ||
            item.color.toLowerCase().contains(searchQuery);

        bool matchesFilter = _selectedFilter == 'All' ||
            item.type.toLowerCase().contains(_selectedFilter.toLowerCase());

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    _applyFilters();
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    _applyFilters();
  }

  void _onCardTap(ClothesItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClothingPreviewDialog(
        item: item,
        supabase: supabase,
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 4;
    if (screenWidth > 800) return 3;
    if (screenWidth > 600) return 2;
    return 1;
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth > 1200) return 0.8;
    if (screenWidth > 800) return 0.75;
    return 0.7;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'AI Laundry Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_clothes.length} Total Items',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() => _isGridView = !_isGridView);
                  },
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by brand, type, or color...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterOptions.length,
                      itemBuilder: (context, index) {
                        final filter = _filterOptions[index];
                        final isSelected = _selectedFilter == filter;

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) => _onFilterChanged(filter),
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            selectedColor: colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading inventory...'),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No items found',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchController.text.isNotEmpty || _selectedFilter != 'All'
                          ? 'Try adjusting your search or filters'
                          : 'Your inventory is empty',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchController.text.isNotEmpty || _selectedFilter != 'All')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            _onFilterChanged('All');
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Filters'),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverAnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: 1.0,
              sliver: _isGridView
                  ? SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(screenWidth),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: _getChildAspectRatio(screenWidth),
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 300,
                          maxHeight: 400,
                        ),
                        child: ClothesCard(
                          item: _filtered[index],
                          onTap: () => _onCardTap(_filtered[index]),
                          isGridView: true,
                        ),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              )
                  : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: const BoxConstraints(
                          maxHeight: 120,
                        ),
                        child: ClothesCard(
                          item: _filtered[index],
                          onTap: () => _onCardTap(_filtered[index]),
                          isGridView: false,
                        ),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchClothes,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}