import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers.dart';
import '../models/menu_model.dart';
import '../models/system_model.dart';
import '../core/pos_theme.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  int? _selectedCounterId;
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isCategoryLoading = false;

  @override
  Widget build(BuildContext context) {
    final countersAsync = ref.watch(kitchenCountersProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      backgroundColor: POSTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. KITCHEN COUNTERS SIDEBAR ────────────────────────────────
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                _buildSidebarHeader('KITCHEN COUNTERS', onAdd: () => _manageCounters(context)),
                Expanded(
                  child: countersAsync.when(
                    data: (counters) {
                      if (counters.isEmpty) return _buildEmptyState('No counters', Icons.store_outlined);
                      
                      if (_selectedCounterId == null && counters.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedCounterId = counters.first.id);
                        });
                      }

                      return ListView.builder(
                        itemCount: counters.length,
                        itemBuilder: (context, index) {
                          final counter = counters[index];
                          final isSelected = _selectedCounterId == counter.id;
                          return _buildCounterTile(
                            counter,
                            isSelected,
                            onTap: () => setState(() {
                              _selectedCounterId = counter.id;
                              _selectedCategoryId = null;
                            }),
                            onEdit: () => _manageCounters(context), // Handled by manager
                            onDelete: () => _manageCounters(context),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. GROUPED CATEGORIES BAR ───────────────────────────────────────
          Container(
            width: 280, // Increased width for better grouped layout
            decoration: BoxDecoration(
              color: POSTheme.surface,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                _buildSidebarHeader('CATEGORIES BY STATION', 
                  onAdd: () => _showCategoryDialog(context)),
                Expanded(
                  child: countersAsync.when(
                    data: (counters) => categoriesAsync.when(
                      data: (allCats) {
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            // 1. Unassigned Section (Move to top for visibility)
                            if (allCats.any((c) => (c as Category).kitchenCounterId == null)) ...[
                              _buildSectionHeader('UNASSIGNED / NO STATION', Colors.deepOrange),
                              ...(allCats as List<Category>).where((c) => c.kitchenCounterId == null).map((cat) => _buildSubCategoryTile(
                                cat.name,
                                _selectedCategoryId == cat.id,
                                onTap: () => setState(() {
                                  _selectedCategoryId = cat.id;
                                  _selectedCounterId = null;
                                }),
                                onEdit: () => _showCategoryDialog(context, category: cat),
                                onDelete: () => _confirmDelete(context, 'Category ${cat.name}', () async {
                                  await ref.read(apiClientProvider).deleteCategory(cat.id);
                                  ref.invalidate(menuCategoriesProvider);
                                }),
                              )),
                              const Divider(height: 1),
                            ],

                            // 2. Existing Counter Sections
                            ...counters.map((counter) {
                              final cats = (allCats as List<Category>).where((c) => c.kitchenCounterId == counter.id).toList();
                                                          
                              int colorValue = 0xFFFF7043; // Default
                              try { if (counter.color.isNotEmpty) colorValue = int.parse(counter.color.replaceFirst('#', '0xFF')); } catch (_) {}

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(counter.name, Color(colorValue)),
                                  if (cats.isEmpty)
                                    _buildEmptyCategoriesPlaceholder()
                                  else
                                    ...(cats as List<Category>).map((cat) => _buildSubCategoryTile(
                                      cat.name,
                                      _selectedCategoryId == cat.id,
                                      onTap: () => setState(() {
                                        _selectedCategoryId = cat.id;
                                        _selectedCounterId = counter.id;
                                      }),
                                      onEdit: () => _showCategoryDialog(context, category: cat),
                                      onDelete: () => _confirmDelete(context, 'Category ${cat.name}', () async {
                                        await ref.read(apiClientProvider).deleteCategory(cat.id);
                                        ref.invalidate(menuCategoriesProvider);
                                      }),
                                    )),
                                  const Divider(height: 1),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (e, _) => Center(child: Text('Error loading categories')),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),

          // ─── 3. ITEMS GRID ───────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: itemsAsync.when(
                    data: (allItems) {
                      // Filter by category and counter
                      var items = allItems.where((i) {
                        if (_selectedCategoryId != null) {
                          return i.categoryId == _selectedCategoryId;
                        } else if (_selectedCounterId != null) {
                          final cats = categoriesAsync.value ?? [];
                          final catIds = cats.where((c) => c.kitchenCounterId == _selectedCounterId).map((c) => c.id).toSet();
                          return catIds.contains(i.categoryId);
                        }
                        return true;
                      }).toList();

                      if (_searchQuery.isNotEmpty) {
                        items = items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      }

                      if (items.isEmpty) return _buildEmptyState('No items found', Icons.restaurant_menu_rounded);

                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 110,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _PremiumItemCard(
                          item: items[index],
                          onEdit: () => _showItemDialog(context, item: items[index]),
                          onDelete: () => _confirmDelete(context, 'Item ${items[index].name}', () async {
                            await ref.read(apiClientProvider).deleteMenuItem(items[index].id);
                            ref.invalidate(menuItemsProvider);
                          }),
                          onToggle: (val) async {
                            await ref.read(apiClientProvider).updateMenuItem(
                              items[index].id,
                              items[index].name,
                              items[index].price,
                              items[index].categoryId,
                              items[index].description,
                              val,
                              items[index].stockQuantity,
                              allowDiscount: items[index].allowDiscount,
                              taxEnabled: items[index].taxEnabled,
                              taxPercentage: items[index].taxPercentage,
                            );
                            ref.invalidate(menuItemsProvider);
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedCounterId != null ? FloatingActionButton.extended(
        onPressed: () => _showItemDialog(context),
        label: const Text('Add Menu Item'),
        icon: const Icon(Icons.add),
        backgroundColor: POSTheme.primary,
        foregroundColor: Colors.white,
      ) : null,
    );
  }

  void _manageCounters(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _KitchenCounterManager(ref: ref),
    );
  }

  Widget _buildSidebarHeader(String title, {required VoidCallback onAdd}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: POSTheme.textMuted, letterSpacing: 0.5)),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline, size: 18, color: POSTheme.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Add New',
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTile(KitchenCounter counter, bool isSelected, {
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    // We can use the generic icons map or parsed color if available
    int colorValue = 0xFF000000;
    try {
      if (counter.color.isNotEmpty && counter.color.startsWith('#')) {
        colorValue = int.parse(counter.color.replaceFirst('#', '0xFF'));
      }
    } catch (_) {}

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? POSTheme.primary.withOpacity(0.08) : Colors.transparent,
            border: Border(right: BorderSide(color: isSelected ? POSTheme.primary : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Icon(Icons.kitchen_rounded, size: 20, color: isSelected ? POSTheme.primary : Color(colorValue)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(counter.name, style: GoogleFonts.inter(
                  fontSize: 14, 
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? POSTheme.primary : POSTheme.textPrimary,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isSelected)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (val) {
                    if (val == 'manage') onEdit();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'manage', child: Text('Manage Counters')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategoryTile(String name, bool isSelected, {
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Colors.white,
      onTap: onTap,
      title: Text(name, style: GoogleFonts.inter(
        fontSize: 13, 
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      )),
      trailing: isSelected && onEdit != null ? PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 14),
        onSelected: (val) {
          if (val == 'edit') onEdit();
          if (val == 'delete') onDelete!();
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: POSTheme.danger))),
        ],
      ) : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: POSTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => ref.invalidate(menuItemsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 16)),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? category, int? counterId}) {
    final nameController = TextEditingController(text: category?.name);
    final descController = TextEditingController(text: category?.description);
    int? selectedCounterId = category?.kitchenCounterId ?? counterId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
        backgroundColor: const Color(0xFFFCEFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category == null ? 'New Category' : 'Edit Category',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
              ),
              const SizedBox(height: 24),
              _buildModernTextField(nameController, 'Name'),
              const SizedBox(height: 16),
              _buildModernTextField(descController, 'Description'),
              const SizedBox(height: 16),
              const Text('Assigned Kitchen Counter', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ref.watch(kitchenCountersProvider).when(
                  data: (counters) => DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedCounterId,
                      isExpanded: true,
                      hint: const Text('Select Counter'),
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Unassigned (No Station)', style: TextStyle(color: Colors.grey)),
                        ),
                        ...counters.map((s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedCounterId = val),
                    ),
                  ),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Safe API call
                      try {
                        String counterName = "Default";
                        if (selectedCounterId != null) {
                          final counters = ref.read(kitchenCountersProvider).value ?? [];
                          counterName = counters.firstWhere((c) => c.id == selectedCounterId).name;
                        }

                        if (category == null) {
                          await ref.read(apiClientProvider).createCategory(nameController.text, descController.text, kitchenCounterId: selectedCounterId);
                        } else {
                          await ref.read(apiClientProvider).updateCategory(category.id, nameController.text, descController.text, kitchenCounterId: selectedCounterId);
                        }
                        
                        ref.invalidate(menuCategoriesProvider);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Category moved to $counterName successfully.'),
                              backgroundColor: POSTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                         debugPrint('Error saving category: $e');
                      }
                    },
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildModernTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      color: color.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.kitchen_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoriesPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'No categories assigned to this counter.',
        style: GoogleFonts.inter(
            fontSize: 11, fontStyle: FontStyle.italic, color: POSTheme.textMuted),
      ),
    );
  }

  void _showItemDialog(BuildContext context, {MenuItem? item}) {
    showDialog(
      context: context,
      builder: (context) => _ItemEditDialog(item: item, ref: ref, 
        selectedCounterId: _selectedCounterId, 
        selectedCategoryId: _selectedCategoryId
      ),
    );
  }

  void _confirmDelete(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $title?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { onConfirm(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ItemEditDialog extends StatefulWidget {
  final MenuItem? item;
  final WidgetRef ref;
  final int? selectedCounterId;
  final int? selectedCategoryId;

  const _ItemEditDialog({this.item, required this.ref, this.selectedCounterId, this.selectedCategoryId});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  late bool _isAvailable;
  late bool _allowDiscount;
  late bool _taxEnabled;
  late TextEditingController _taxPercentageController;
  int? _catId;
  int? _counterId;
  
  List<MenuItemModifier> _modifiers = [];
  List<ComboItem> _comboItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nameController = TextEditingController(text: widget.item?.name);
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _descController = TextEditingController(text: widget.item?.description);
    _isAvailable = widget.item?.isAvailable ?? true;
    _allowDiscount = widget.item?.allowDiscount ?? true;
    _taxEnabled = widget.item?.taxEnabled ?? true;
    _taxPercentageController = TextEditingController(text: widget.item?.taxPercentage.toString() ?? '5.0');
    _catId = widget.item?.categoryId ?? widget.selectedCategoryId;
    _counterId = widget.item?.kitchenCounterId ?? widget.selectedCounterId;
    
    if (widget.item != null) {
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    final apiClient = widget.ref.read(apiClientProvider);
    final mods = await apiClient.getItemModifiers(widget.item!.id);
    // Combos are already in MenuItem if we update the backend to return them, 
    // but for now let's assume we might need a fetch or they are in the item.
    setState(() {
      _modifiers = mods;
      _comboItems = widget.item?.comboItems ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFCEFE9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null ? 'Add Menu Item' : 'Edit ${widget.item!.name}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: POSTheme.primary,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: POSTheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              dividerColor: Colors.grey[300],
              tabs: const [
                Tab(text: 'General Information'),
                Tab(text: 'Modifiers'),
                Tab(text: 'Combo Components'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildModifiersTab(),
                  _buildComboTab(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _save,
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernTextField(_nameController, 'Item Name'),
          const SizedBox(height: 16),
          _buildModernTextField(_priceController, 'Price', isNumber: true),
          const SizedBox(height: 16),
          _buildModernTextField(_descController, 'Description', maxLines: 3),
          const SizedBox(height: 24),
          const Text('Target Category', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _catId,
                isExpanded: true,
                style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                items: ((widget.ref.read(menuCategoriesProvider).value ?? []) as List<Category>).map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                )).toList(),
                onChanged: (val) => setState(() => _catId = val),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Kitchen Counter', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _KitchenCounterManager(ref: widget.ref),
                  );
                },
                icon: const Icon(Icons.settings, size: 14),
                label: const Text('Manage Counters', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.ref.watch(kitchenCountersProvider).when(
              data: (counters) => DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _counterId,
                  isExpanded: true,
                  hint: const Text('Inherit from Category'),
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Unassigned (Inherit from Category)', style: TextStyle(color: Colors.grey)),
                    ),
                    ...counters.map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name),
                    )),
                  ],
                  onChanged: (val) => setState(() => _counterId = val),
                ),
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Available', style: TextStyle(fontSize: 16)),
                  value: _isAvailable,
                  onChanged: (v) => setState(() => _isAvailable = v),
                  activeColor: Colors.deepOrange,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  title: const Text('Allow Discount', style: TextStyle(fontSize: 16)),
                  value: _allowDiscount,
                  onChanged: (v) => setState(() => _allowDiscount = v),
                  activeColor: Colors.deepOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SwitchListTile(
                  title: const Text('Tax Enabled', style: TextStyle(fontSize: 16)),
                  value: _taxEnabled,
                  onChanged: (v) => setState(() => _taxEnabled = v),
                  activeColor: Colors.deepOrange,
                ),
              ),
              if (_taxEnabled)
                Expanded(
                  flex: 1,
                  child: _buildModernTextField(_taxPercentageController, 'Tax %', isNumber: true),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModifiersTab() {
    if (widget.item == null) return const Center(child: Text('Save item first to add modifiers'));
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _modifiers.length,
            itemBuilder: (context, index) {
              final mod = _modifiers[index];
              return ListTile(
                title: Text(mod.name),
                subtitle: Text('${mod.modifierGroup} | +₹${mod.priceDelta}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: POSTheme.danger),
                  onPressed: () async {
                    await widget.ref.read(apiClientProvider).deleteMenuItemModifier(mod.id);
                    _loadDetails();
                  },
                ),
              );
            },
          ),
        ),
        ElevatedButton.icon(
          onPressed: _addModifier,
          icon: const Icon(Icons.add),
          label: const Text('Add Modifier'),
        ),
      ],
    );
  }

  void _addModifier() {
    final nameC = TextEditingController();
    final priceC = TextEditingController(text: '0');
    final groupC = TextEditingController(text: 'Extras');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFCEFE9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Modifier', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
              const SizedBox(height: 24),
              _buildModernTextField(nameC, 'Name (e.g. Extra Cheese)'),
              const SizedBox(height: 16),
              _buildModernTextField(priceC, 'Price Delta', isNumber: true),
              const SizedBox(height: 16),
              _buildModernTextField(groupC, 'Group (e.g. Add-ons)'),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (nameC.text.isEmpty) return;
                      await widget.ref.read(apiClientProvider).addMenuItemModifier(
                        widget.item!.id, 
                        name: nameC.text, 
                        priceDelta: double.tryParse(priceC.text) ?? 0,
                        group: groupC.text,
                      );
                      _loadDetails();
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComboTab() {
    if (widget.item == null) return const Center(child: Text('Save item first to add combo components'));
    
    return Column(
      children: [
        Expanded(
          child: _comboItems.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_motion_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No components added yet', style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _comboItems.length,
                itemBuilder: (context, index) {
                  final combo = _comboItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFCEFE9),
                        child: Icon(Icons.shopping_basket_outlined, size: 18, color: Colors.deepOrange),
                      ),
                      title: Text(combo.name ?? 'Item ${combo.componentItemId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Quantity: ${combo.quantity}', style: TextStyle(color: Colors.grey[600])),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: POSTheme.danger, size: 20),
                        onPressed: () async {
                          await widget.ref.read(apiClientProvider).removeComboComponent(widget.item!.id, combo.componentItemId);
                          _loadDetails();
                        },
                      ),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _addComboComponent,
          icon: const Icon(Icons.add),
          label: const Text('Add Component'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _addComboComponent() {
    int? selectedCompId;
    final qtyC = TextEditingController(text: '1');
    final allItems = widget.ref.read(menuItemsProvider).value ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFFFCEFE9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Component Item', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<int>(
                      value: selectedCompId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Item'),
                      items: allItems.where((i) => i.id != widget.item?.id).map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                      onChanged: (v) => setDialogState(() => selectedCompId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildModernTextField(qtyC, 'Quantity', isNumber: true),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedCompId == null) return;
                        await widget.ref.read(apiClientProvider).addComboComponent(
                          widget.item!.id, 
                          selectedCompId!, 
                          int.tryParse(qtyC.text) ?? 1
                        );
                        _loadDetails();
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _save() async {
    if (_catId == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name cannot be empty'), backgroundColor: Colors.red));
      return;
    }
    
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final taxPercentage = double.tryParse(_taxPercentageController.text) ?? 5.0;
    
    try {
      if (widget.item == null) {
        await widget.ref.read(apiClientProvider).createMenuItem(
          _nameController.text.trim(), price, _catId!, _descController.text, _isAvailable, 100,
          kitchenCounterId: _counterId,
          allowDiscount: _allowDiscount,
          taxEnabled: _taxEnabled,
          taxPercentage: taxPercentage,
        );
      } else {
        await widget.ref.read(apiClientProvider).updateMenuItem(
          widget.item!.id, _nameController.text, price, _catId!, _descController.text, _isAvailable, 100,
          kitchenCounterId: _counterId,
          allowDiscount: _allowDiscount,
          taxEnabled: _taxEnabled,
          taxPercentage: taxPercentage,
        );
      }
      
      widget.ref.invalidate(menuItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item saved successfully'), backgroundColor: POSTheme.primary));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving item: $e'), backgroundColor: POSTheme.danger));
      }
    }
  }
}

class _PremiumItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _PremiumItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: POSTheme.shadowSM,
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: POSTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: POSTheme.primary))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13))),
                          if (item.comboItems.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('C', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            ),
                        ],
                      ),
                      Text('₹${item.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, color: POSTheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: item.isAvailable,
                        onChanged: onToggle,
                        activeColor: POSTheme.success,
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18, color: POSTheme.danger),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
}
class _KitchenCounterManager extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _KitchenCounterManager({required this.ref});

  @override
  ConsumerState<_KitchenCounterManager> createState() => _KitchenCounterManagerState();
}

class _KitchenCounterManagerState extends ConsumerState<_KitchenCounterManager> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final countersAsync = ref.watch(kitchenCountersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Counters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Counter Name (e.g. Bar)',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCounter,
                  style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            SizedBox(
              height: 300,
              child: countersAsync.when(
                data: (counters) => ListView.builder(
                  itemCount: counters.length,
                  itemBuilder: (context, index) {
                    final c = counters[index];
                    return ListTile(
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: POSTheme.danger),
                        onPressed: () => _deleteCounter(c.id!),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCounter() async {
    if (_nameController.text.trim().isEmpty) return;
    try {
      await ref.read(kitchenCountersProvider.notifier).addCounter(_nameController.text.trim());
      _nameController.clear();
      ref.invalidate(kitchenCountersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCounter(int id) async {
    try {
      await ref.read(kitchenCountersProvider.notifier).removeCounter(id);
      ref.invalidate(kitchenCountersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
