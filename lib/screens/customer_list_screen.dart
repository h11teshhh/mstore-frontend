import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async'; // For search debounce
import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // Using your UI Utils

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
      // Optional: Artificial delay to show off skeleton (Remove in production)
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
    // Only SUPERADMIN or ADMIN (Adjust logic as per your need)
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
    // Positioning: 8% from top to be "20-25% upside from center"
    final double topOffset = size.height * 0.08;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Customers", style: AppTypography.heading),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHeading),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
            ),
            onPressed: onAddCustomerPressed,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: topOffset * 0.5), // Responsive Top Spacer
          // 1. SEARCH CONTAINER (Placed High Up)
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
                ? _buildSkeletonList() // <--- SKELETON LOADER
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

  Widget _buildCustomerCard(dynamic customer) {
    final name = customer["name"] ?? "Unknown";
    final mobile = customer["mobile"] ?? "N/A";
    final area = customer["area"] ?? "N/A";
    final due =
        double.tryParse(customer["current_due"]?.toString() ?? "0") ?? 0;
    final id = customer["id"];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
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
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
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
                          color: AppColors.textHeading,
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

  // --- SKELETON LOADER ---
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 120, height: 14, color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Container(width: 80, height: 10, color: Colors.grey[100]),
                  const SizedBox(height: 6),
                  Container(width: 60, height: 10, color: Colors.grey[100]),
                ],
              ),
            ),
            Container(width: 60, height: 20, color: Colors.grey[200]),
          ],
        ),
      ),
    );
  }
}
