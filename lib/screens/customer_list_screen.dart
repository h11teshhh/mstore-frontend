import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import 'dart:async'; // For search debounce

import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  List<dynamic> allCustomers = [];
  List<dynamic> filteredCustomers = [];
  String role = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await loadRole();
    await fetchCustomers();
  }

  Future<void> loadRole() async {
    final savedRole = await storage.getRole();
    if (mounted) {
      setState(() => role = savedRole ?? "");
    }
  }

  Future<void> fetchCustomers() async {
    setState(() => loading = true);

    try {
      // Optional: Artificial delay to show off skeleton
      // await Future.delayed(const Duration(milliseconds: 1000));

      final response = await api.getCustomers();
      if (!mounted) return;

      setState(() {
        allCustomers = response.data ?? [];
        filteredCustomers = allCustomers;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      String msg = "Failed to load customers";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showErrorToast(msg);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          filteredCustomers = allCustomers;
        } else {
          filteredCustomers = allCustomers.where((c) {
            final name = c["name"].toString().toLowerCase();
            final mobile = c["mobile"].toString();
            final area = c["area"].toString().toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || mobile.contains(q) || area.contains(q);
          }).toList();
        }
      });
    });
  }

  void onAddCustomerPressed() {
    if (role == "SUPERADMIN" || role == "ADMIN") {
      Navigator.pushNamed(
        context,
        "/createCustomer",
      ).then((_) => fetchCustomers());
    } else {
      UIUtils.showErrorToast("Permission Denied: Contact Administrator");
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Positioning: Adjusted to account for AppBar
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9), // Sneat Background
      extendBodyBehindAppBar: true, // ✅ Content goes behind AppBar
      // ✅ 1. PRODUCTIVE SNEAT APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F9).withOpacity(0.95),
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
                color: Color(0xFF566a7f),
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          "Customers",
          style: TextStyle(
            color: Color(0xFF566a7f),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PublicSans',
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Refresh Button
          IconButton(
            onPressed: () {
              UIUtils.showProcessingSnackbar(
                context,
                message: "Refreshing list...",
              );
              fetchCustomers();
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          // Add Customer Button (Sneat Style)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              onPressed: onAddCustomerPressed,
              tooltip: "Add Customer",
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary, // Primary color for main action
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Spacer for AppBar + Offset
          SizedBox(
            height:
                kToolbarHeight +
                MediaQuery.of(context).padding.top +
                (topOffset * 0.5),
          ),

          // 1. SEARCH CONTAINER
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
                  hintText: "Search Name, Mobile or Area...",
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

          // 2. LIST CONTENT
          Expanded(
            child: loading
                ? _buildSkeletonList() // ✅ SKELETON LOADER
                : RefreshIndicator(
                    onRefresh: fetchCustomers,
                    color: AppColors.primary,
                    child: filteredCustomers.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.cardPadding,
                              vertical: 10,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildCustomerCard(
                                filteredCustomers[index],
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Future<void> _deleteCustomer(String customerId, String customerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Customer",
            style: TextStyle(color: AppColors.textHeading, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete \"$customerName\"?\n\nThis action cannot be undone.",
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
      await api.deleteCustomer(customerId);
      UIUtils.showSuccessToast("Customer deleted successfully");
      fetchCustomers();
    } catch (_) {}
  }

  Widget _buildCustomerCard(dynamic customer) {
    final name = customer["name"] ?? "Unknown";
    final mobile = customer["mobile"] ?? "N/A";
    final area = customer["area"] ?? "N/A";
    final due =
        double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0;
    final id = customer["id"];

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(
              context,
              "/customerDetail",
              arguments: id.toString(),
            ).then((_) => fetchCustomers()); // Refresh on return
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF566a7f),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            area,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            mobile,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing Due Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "DUE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${due.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: due > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                if (role == "SUPERADMIN") ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _deleteCustomer(id.toString(), name),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
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
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "No customers found",
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Skeleton Avatar
            const SkeletalLoader(width: 48, height: 48, borderRadius: 24),
            const SizedBox(width: 16),
            // Skeleton Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SkeletalLoader(width: 120, height: 14),
                  SizedBox(height: 8),
                  SkeletalLoader(width: 80, height: 10),
                  SizedBox(height: 6),
                  SkeletalLoader(width: 60, height: 10),
                ],
              ),
            ),
            // Skeleton Due Amount
            const SkeletalLoader(width: 60, height: 20),
          ],
        ),
      ),
    );
  }
}
