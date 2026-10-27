import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/menu_model.dart';

class GuestMenuScreen extends ConsumerStatefulWidget {
  final int tableId;
  const GuestMenuScreen({super.key, required this.tableId});

  @override
  ConsumerState<GuestMenuScreen> createState() => _GuestMenuScreenState();
}

class _GuestMenuScreenState extends ConsumerState<GuestMenuScreen> {
  final List<MenuItem> _guestCart = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // One-time sync on startup to ensure latest restaurant details are loaded
    Future.microtask(() {
      ref.read(settingsProvider.notifier).syncWithBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(settings),
          _buildCategoryFilter(categoriesAsync),
          _buildMenuContent(menuAsync, categoriesAsync),
        ],
      ),
      floatingActionButton: _guestCart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCart,
              backgroundColor: Colors.deepOrange,
              icon: const Icon(Icons.shopping_basket_outlined, color: Colors.white),
              label: Text(
                '${_guestCart.length} Items - Proceed',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildAppBar(dynamic settings) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.deepOrange,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Table ${widget.tableId}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepOrange, Color(0xFFFF8E53)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  settings.restaurantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Build Date: 2026-04-04 13:08',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) => SliverToBoxAdapter(
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildCategoryChip('All', null);
              }
              final cat = categories[index - 1];
              return _buildCategoryChip(cat.name, cat.id);
            },
          ),
        ),
      ),
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildCategoryChip(String label, int? id) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategoryId = selected ? id : null);
        },
        selectedColor: Colors.deepOrange,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildMenuContent(AsyncValue<List<MenuItem>> menuAsync, AsyncValue<List<Category>> categoriesAsync) {
    if (menuAsync.isLoading || categoriesAsync.isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }

    if (menuAsync.hasError || categoriesAsync.hasError) {
      return const SliverFillRemaining(child: Center(child: Text('Failed to load menu.')));
    }

    final allItems = menuAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];

    // Filter by selected category IF selected
    final filteredItems = _selectedCategoryId == null 
        ? allItems 
        : allItems.where((i) => i.categoryId == _selectedCategoryId).toList();

    // Group items by category for the UI
    final Map<int, List<MenuItem>> grouped = {};
    for (var item in filteredItems) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }

    final categoryList = categories.where((c) => grouped.containsKey(c.id)).toList();

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // We use a pattern of Title -> List of items for each category
            // This is a simplified flat list but we'll add headers
            int currentItemIndex = 0;
            for (var cat in categoryList) {
              final items = grouped[cat.id]!;
              
              // If this index is for a category header
              if (index == currentItemIndex) {
                 return _buildCategoryHeader(cat.name);
              }
              
              // Check if index falls within this category's items
              if (index > currentItemIndex && index <= currentItemIndex + items.length) {
                return _buildMenuCard(items[index - currentItemIndex - 1]);
              }
              
              currentItemIndex += items.length + 1;
            }
            return null;
          },
          childCount: filteredItems.length + categoryList.length,
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Container(height: 3, width: 40, decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuCard(MenuItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _addToCart(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.fastfood, color: Colors.deepOrange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description ?? 'Delicious freshly prepared dish',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${item.price}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(MenuItem item) {
    setState(() => _guestCart.add(item));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${item.name} to cart'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.black87,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CartBottomSheet(
        cartItems: _guestCart,
        onPlaceOrder: () => _placeOrder(context),
      ),
    );
  }

  void _placeOrder(BuildContext context) async {
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      ),
    );

    try {
      final itemsMap = _guestCart.map((i) => {
        'menu_item_id': i.id,
        'quantity': 1,
        'notes': 'Guest order via QR',
      }).toList();

      await ref.read(apiClientProvider).createOrder(
        tableNumber: widget.tableId,
        items: itemsMap,
        taxRate: ref.read(settingsProvider).taxRate,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() => _guestCart.clear());
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Order Placed Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Thank you for ordering.\nYour food is being prepared.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Great!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CartBottomSheet extends StatelessWidget {
  final List<MenuItem> cartItems;
  final VoidCallback onPlaceOrder;

  const _CartBottomSheet({
    required this.cartItems,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    double total = cartItems.fold(0, (sum, i) => sum + i.price);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Review Order',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    '₹${item.price}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹$total',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: cartItems.isEmpty ? null : onPlaceOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Text(
              'CONFIRM & ORDER',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}