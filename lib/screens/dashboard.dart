import 'dart:async';
import 'dart:ui'; // For Glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../storage/token_storage.dart';
import '../utils/role_helper.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart'; // ✅ UIUtils + AppToast
import '../utils/skeletal_loader.dart'; // ✅ Skeleton

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // --- EXISTING LOGIC ---
  String name = "";
  String role = "";
  List<String> menuItems = [];
  final TokenStorage storage = TokenStorage();
  bool _isLoading = true;

  // IST midnight auto-logout timer
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _initLoad();
    _scheduleMidnightLogout();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Schedules a timer to fire at exactly 12:00 AM IST (Asia/Kolkata = UTC+5:30).
  void _scheduleMidnightLogout() {
    _midnightTimer?.cancel();
    final due = _durationToMidnightIST();
    _midnightTimer = Timer(due, _onSessionExpired);
  }

  Duration _durationToMidnightIST() {
    const istOffset = Duration(hours: 5, minutes: 30);
    final nowIst = DateTime.now().toUtc().add(istOffset);
    final midnightIst = DateTime(
      nowIst.year,
      nowIst.month,
      nowIst.day + 1,
      0,
      0,
      0,
    );
    final diff = midnightIst.difference(nowIst);
    return diff.isNegative ? const Duration(seconds: 30) : diff;
  }

  Future<void> _onSessionExpired() async {
    await storage.clearAll();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: Color(0xFF5F63F2), size: 24),
            SizedBox(width: 10),
            Text(
              "Session Expired",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        content: const Text(
          "Your session has expired for security reasons.\n"
          "Please log in again to continue.",
          style: TextStyle(fontSize: 14, color: Color(0xFF4A5568), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                "/login",
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F63F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Log In Again"),
          ),
        ],
      ),
    );
  }

  Future<void> _initLoad() async {
    await loadUser();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> loadUser() async {
    try {
      final storedName = await storage.getName();
      final storedRole = await storage.getRole();
      if (storedRole == null) return;
      setState(() {
        name = storedName ?? "User";
        role = storedRole;
        menuItems = RoleHelper.getMenuForRole(role);
      });
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  Future<void> logout() async {
    UIUtils.showProcessingSnackbar(context, message: "Logging out...");
    await Future.delayed(const Duration(milliseconds: 500));
    await storage.clearAll();
    if (mounted) {
      AppToast.dismiss();
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  void navigate(String menu) {
    String route = "";
    switch (menu) {
      case "Create User":
        route = "/createUser";
        break;
      case "Manage Users":
        route = "/manageUsers";
        break;
      case "Add Item":
        route = "/addItem";
        break;
      case "Stock In":
        route = "/stockIn";
        break;
      case "Stock Details":
        route = "/inventoryList";
        break;
      case "Our Customers":
        route = "/customers";
        break;
      case "Create Customer":
        route = "/createCustomer";
        break;
      case "Create Order":
        route = "/createOrder";
        break;
      case "Orders":
        route = "/orders";
        break;
      case "Bills":
        route = "/bills";
        break;
      case "Delivery":
        route = "/delivery";
        break;
      case "Payments":
        route = "/payments";
        break;
      case "Reports":
        route = "/endOfDayReport";
        break;
    }
    if (route.isNotEmpty) Navigator.pushNamed(context, route);
  }

  // --- UI HELPERS ---
  Color _getColorForMenu(String menu) {
    switch (menu) {
      case "Add Item":
        return AppColors.primary;
      case "Stock Details":
        return AppColors.info;
      case "Our Customers":
        return AppColors.warning;
      case "Create Order":
        return AppColors.success;
      case "Delivery":
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForMenu(String menu) {
    switch (menu) {
      case "Add Item":
        return Icons.add_box_rounded;
      case "Stock Details":
        return Icons.inventory_2_rounded;
      case "Our Customers":
        return Icons.people_alt_rounded;
      case "Create Order":
        return Icons.shopping_cart_checkout_rounded;
      case "Delivery":
        return Icons.local_shipping_rounded;
      case "Reports":
        return Icons.bar_chart_rounded;
      case "Payments":
        return Icons.attach_money_rounded;
      case "Create User":
        return Icons.person_add_alt_1_rounded;
      case "Manage Users":
        return Icons.manage_accounts_rounded;
      case "Bills":
        return Icons.receipt_long_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  // --- MAIN UI ---
  @override
  Widget build(BuildContext context) {
    final priorityItems = [
      "Add Item",
      "Stock Details",
      "Our Customers",
      "Create Order",
      "Delivery",
    ];
    final dashboardList = menuItems
        .where((i) => priorityItems.contains(i))
        .toList();
    final drawerList = menuItems
        .where((i) => !priorityItems.contains(i))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,

      // ── APP BAR ────────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: AppColors.background.withOpacity(0.8),
              elevation: 0,
              centerTitle: true,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
              leading: Builder(
                builder: (context) => IconButton(
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
                      Icons.menu_rounded,
                      color: AppColors.textHeading,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: const Column(
                children: [
                  Text(
                    "M-Store",
                    style: TextStyle(
                      color: AppColors.textHeading,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'PublicSans',
                    ),
                  ),
                  Text(
                    "Dashboard",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                // ── PROFILE DROPDOWN ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 46),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AppColors.borderColor, width: 1),
                    ),
                    tooltip: '',
                    onSelected: (value) {
                      if (value == 'logout') logout();
                    },

                    // ── Avatar chip ───────────────────────────────────────
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Initial circle
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.12),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "U",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),

                    // ── Dropdown items ────────────────────────────────────
                    itemBuilder: (context) => [
                      // 1. Profile header
                      PopupMenuItem<String>(
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight,
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "U",
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textHeading,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      role,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 2. Divider
                      const PopupMenuDivider(height: 1),

                      // 3. Logout
                      PopupMenuItem<String>(
                        value: 'logout',
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: AppColors.danger,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Logout",
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      drawer: _buildDrawer(drawerList),

      body: _isLoading
          ? _buildSkeletonDashboard()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.4,
                          ),
                      itemCount: dashboardList.length,
                      itemBuilder: (context, index) {
                        return _buildCompactCard(dashboardList[index]);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCompactCard(String title) {
    final color = _getColorForMenu(title);
    final icon = _getIconForMenu(title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navigate(title),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHeading,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(List<String> drawerList) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer header ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "U",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Welcome back,",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textHeading,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: drawerList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = drawerList[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(
                      _getIconForMenu(item),
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textHeading,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      navigate(item);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: AppColors.danger.withOpacity(0.1),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonDashboard() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.isMobile(context) ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemCount: 6,
                itemBuilder: (_, __) =>
                    const SkeletalLoader(height: 100, borderRadius: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
