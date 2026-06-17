import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For Status Bar Control
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ Using UIUtils
import '../utils/skeletal_loader.dart'; // ✅ Using Skeleton Loader

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final ApiService api = ApiService();

  bool isLoading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    fetchTruckLoad();
  }

  Future<void> fetchTruckLoad() async {
    setState(() => isLoading = true);

    try {
      // Optional delay to show off skeleton
      // await Future.delayed(const Duration(milliseconds: 1000));

      final response = await api.getTodayTruckLoad();
      if (!mounted) return;

      setState(() {
        data = response.data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      String msg = "Failed to load truck data";
      if (e is DioException) {
        msg = e.response?.data["detail"]?.toString() ?? msg;
      }
      // ✅ Using UIUtils
      UIUtils.showErrorToast(msg);
    }
  }

  // --- UI HELPERS ---
  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Today";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: const Text(
          "Delivery Load",
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
                  message: "Refreshing manifest...",
                );
                fetchTruckLoad();
              },
              tooltip: "Refresh Data",
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

      // ✅ 2. BODY CONTENT
      body: isLoading
          ? _buildSkeletonLoader() // ✅ Using SkeletalLoader
          : RefreshIndicator(
              onRefresh: fetchTruckLoad,
              color: AppColors.primary,
              child: data == null || (data?["items"] as List).isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        // Spacer for AppBar
                        SizedBox(
                          height:
                              kToolbarHeight +
                              MediaQuery.of(context).padding.top +
                              20,
                        ),

                        // 1. SUMMARY CARD
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.cardPadding,
                          ),
                          child: _buildSummaryCard(),
                        ),

                        const SizedBox(height: 20),

                        // 2. ITEMS HEADER
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.list_alt_rounded,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "LOADING MANIFEST",
                                style: AppTypography.label,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 3. SCROLLABLE LIST
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.cardPadding,
                              vertical: 10,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: (data!["items"] as List).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildDeliveryItemCard(
                                data!["items"][index],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSummaryCard() {
    final items = data?["items"] as List? ?? [];
    final totalCount = items.fold(
      0,
      (sum, item) =>
          sum + (int.tryParse(item["quantity_to_load"].toString()) ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Calendar Icon Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.info,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Date & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scheduled For",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(data?["date"]),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
              ],
            ),
          ),

          // Total Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  "TOTAL QTY",
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "$totalCount",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryItemCard(dynamic item) {
    final qty = item["quantity_to_load"] ?? 0;
    final name = item["item_name"] ?? "Unknown Item";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: AppColors.textHeading,
            size: 24,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textHeading,
          ),
        ),
        subtitle: const Text(
          "Ready to load",
          style: TextStyle(fontSize: 12, color: Colors.green),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Text(
            "$qty Units",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 13,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No deliveries scheduled today",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ✅ SKELETON LOADER
  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
      ),
      child: Column(
        children: [
          SizedBox(
            height: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
          ),
          // Summary Card Skeleton
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SkeletalLoader(width: 50, height: 50, borderRadius: 25),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SkeletalLoader(width: 80, height: 10),
                      SizedBox(height: 10),
                      SkeletalLoader(width: 150, height: 16),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const SkeletalLoader(width: 60, height: 50, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // List Skeletons
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const SkeletalLoader(
                height: 70,
                width: double.infinity,
                borderRadius: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
