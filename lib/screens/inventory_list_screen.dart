import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import 'dart:async'; // For search debounce

import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  String role = "";
  List<dynamic> allItems = [];
  List<dynamic> filteredItems = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRole();
    fetchInventory();
  }

  Future<void> _loadRole() async {
    final r = await storage.getRole();
    if (mounted) setState(() => role = r ?? "");
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> fetchInventory() async {
    setState(() => loading = true);

    try {
      // Optional: Delay to show off skeleton
      // await Future.delayed(const Duration(milliseconds: 1000));

      final response = await api.getInventoryStock();
      if (!mounted) return;

      setState(() {
        allItems = response.data ?? [];
        filteredItems = allItems;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      String msg = "Failed to load inventory";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showSnackBar(context, msg, isError: true);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          filteredItems = allItems;
        } else {
          filteredItems = allItems.where((item) {
            final name = item["item_name"].toString().toLowerCase();
            return name.contains(query.toLowerCase());
          }).toList();
        }
      });
    });
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Sneat Background
      extendBodyBehindAppBar: true, // ✅ Content goes behind AppBar
      // ✅ 1. PRODUCTIVE SNEAT APP BAR
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        centerTitle: true,
        // ✅ Status Bar Visibility
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textHeading,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "Inventory Stock",
          style: TextStyle(
            color: AppColors.textHeading,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Refresh Button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              onPressed: () {
                UIUtils.showProcessingSnackbar(
                  context,
                  message: "Refreshing inventory...",
                );
                fetchInventory();
              },
              tooltip: "Refresh Stock",
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Spacer for AppBar
          SizedBox(
            height: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
          ),

          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.cardPadding,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search items...",
                  hintStyle: AppTypography.label,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. STATS ROW
          if (!loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    "TOTAL ITEMS: ${filteredItems.length}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "All Items",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // 3. LIST CONTENT
          Expanded(
            child: loading
                ? _buildSkeletonList() // ✅ SKELETON LOADER
                : RefreshIndicator(
                    onRefresh: fetchInventory,
                    color: AppColors.primary,
                    child: filteredItems.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.cardPadding,
                              vertical: 10,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildInventoryCard(filteredItems[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.pushNamed(
            context,
            "/addItem",
          ).then((_) => fetchInventory());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- WIDGETS ---

  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Item",
            style: TextStyle(color: AppColors.textHeading, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete \"$itemName\"?\n\nThis action cannot be undone.",
            style: const TextStyle(color: AppColors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await api.deleteInventoryItem(itemId);
      UIUtils.showSnackBar(context, "Item deleted successfully");
      fetchInventory();
    } catch (_) {}
  }

  Widget _buildInventoryCard(dynamic item) {
    final name = item["item_name"] ?? "Unknown";
    final price = item["price"] ?? 0;
    final stock = item["current_stock"] ?? 0;
    final id = item["id"];

    // Logic for Colors
    Color statusColor = AppColors.success;
    String statusText = "In Stock";
    IconData statusIcon = Icons.check_circle_outline;

    if (stock == 0) {
      statusColor = AppColors.danger;
      statusText = "Out of Stock";
      statusIcon = Icons.cancel_outlined;
    } else if (stock < 10) {
      statusColor = AppColors.warning;
      statusText = "Low Stock";
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        // Icon Box
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 24),
        ),

        // Content
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textHeading,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Price: ₹$price",
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Trailing Stock Count
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "STOCK",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$stock",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            if (role == "SUPERADMIN") ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteItem(id.toString(), name),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "No items found",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          if (searchController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                searchController.clear();
                _onSearchChanged('');
              },
              child: const Text("Clear Search"),
            ),
        ],
      ),
    );
  }

  // ✅ SKELETON LOADER
  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: 10,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Skeleton Icon
            const SkeletalLoader(width: 48, height: 48, borderRadius: 10),
            const SizedBox(width: 16),
            // Skeleton Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SkeletalLoader(width: 120, height: 14),
                  SizedBox(height: 8),
                  SkeletalLoader(width: 80, height: 12),
                  SizedBox(height: 6),
                  SkeletalLoader(width: 60, height: 10),
                ],
              ),
            ),
            // Skeleton Trailing
            const SkeletalLoader(width: 40, height: 20),
          ],
        ),
      ),
    );
  }
}
