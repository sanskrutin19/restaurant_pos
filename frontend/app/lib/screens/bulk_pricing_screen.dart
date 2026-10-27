import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/menu_model.dart';
import '../core/pos_theme.dart';

class BulkPricingScreen extends ConsumerStatefulWidget {
  const BulkPricingScreen({super.key});

  @override
  ConsumerState<BulkPricingScreen> createState() => _BulkPricingScreenState();
}

class _BulkPricingScreenState extends ConsumerState<BulkPricingScreen> {
  String _searchQuery = '';
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Control Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(menuItemsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search items...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) => DropdownButtonFormField<int?>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ...categories.map<DropdownMenuItem<int?>>((dynamic c) => DropdownMenuItem(value: (c as Category).id, child: Text(c.name))),
                      ],
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error'),
                  ),
                ),
              ],
            ),
          ),
          
          // Items Table
          Expanded(
            child: menuItemsAsync.when(
              data: (items) {
                final filteredItems = items.where((item) {
                  final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesCategory = _selectedCategoryId == null || item.categoryId == _selectedCategoryId;
                  return matchesSearch && matchesCategory;
                }).toList();

                return ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Category ID: ${item.categoryId}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: POSTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editPrice(context, ref, item),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _editPrice(BuildContext context, WidgetRef ref, MenuItem item) {
    final controller = TextEditingController(text: item.price.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Price (₹)',
            prefixText: '₹ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                final apiClient = ref.read(apiClientProvider);
                // Using existing updateMenuItem method but only changing price
                await apiClient.updateMenuItem(
                  item.id,
                  item.name,
                  newPrice,
                  item.categoryId,
                  item.description,
                  item.isAvailable,
                  item.stockQuantity,
                  kitchenCounterId: item.kitchenCounterId,
                );
                ref.invalidate(menuItemsProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
