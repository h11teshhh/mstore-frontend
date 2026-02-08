import 'package:flutter/material.dart';
// For Glassmorphism
import '../storage/token_storage.dart';
import '../utils/role_helper.dart';
import '../utils/app_constants.dart'; // Ensure this file exists

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // --- EXISTING LOGIC (UNTOUCHED) ---
  String name = "";
  String role = "";
  List<String> menuItems = [];
  final TokenStorage storage = TokenStorage();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
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
        name = storedName ?? "";
        role = storedRole;
        menuItems = RoleHelper.getMenuForRole(role);
      });
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  Future<void> logout() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Logging out..."),
        duration: Duration(milliseconds: 800),
        backgroundColor: AppColors.primary,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await storage.clearAll();
    if (mounted) Navigator.pushReplacementNamed(context, "/login");
  }

  void navigate(String menu) {
    switch (menu) {
      case "Create User":
        Navigator.pushNamed(context, "/createUser");
        break;
      case "Add Item":
        Navigator.pushNamed(context, "/addItem");
        break;
      case "Stock In":
        Navigator.pushNamed(context, "/stockIn");
        break;
      case "Stock Details":
        Navigator.pushNamed(context, "/inventoryList");
        break;
      case "Our Customers":
        Navigator.pushNamed(context, "/customers");
        break;
      case "Create Customer":
        Navigator.pushNamed(context, "/createCustomer");
        break;
      case "Create Order":
        Navigator.pushNamed(context, "/createOrder");
        break;
      case "Orders":
        Navigator.pushNamed(context, "/orders");
        break;
      case "Bills":
        Navigator.pushNamed(context, "/bills");
        break;
      case "Delivery":
        Navigator.pushNamed(context, "/delivery");
        break;
      case "Payments":
        Navigator.pushNamed(context, "/payments");
        break;
      case "Reports":
        Navigator.pushNamed(context, "/endOfDayReport");
        break;
    }
  }

  // --- UI HELPERS: ICONS & COLORS ---
  Color _getColorForMenu(String menu) {
    switch (menu) {
      case "Add Item":
        return AppColors.primary;
      case "Stock Details":
        return const Color(0xFF03C3EC);
      case "Our Customers":
        return const Color(0xFFFFAB00);
      case "Create Order":
        return const Color(0xFF71DD37);
      case "Delivery":
        return const Color(0xFF8592A3);
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
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF566a7f)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              _buildDrawerHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: drawerList.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final item = drawerList[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 0,
                      ),
                      leading: Icon(
                        _getIconForMenu(item),
                        color: const Color(0xFF566a7f),
                        size: 20,
                      ),
                      title: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF566a7f),
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
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: AppColors.danger,
                  size: 20,
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: logout,
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                ), // Tighter padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Welcome back, $name",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF566a7f),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // The Grid
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12, // Tighter spacing
                              mainAxisSpacing: 12,
                              childAspectRatio:
                                  1.6, // Makes cards shorter (Rectangular)
                            ),
                        itemCount: dashboardList.length,
                        itemBuilder: (context, index) {
                          return _buildCompactCard(dashboardList[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET: COMPACT DASHBOARD CARD ---
  Widget _buildCompactCard(String title) {
    final color = _getColorForMenu(title);
    final icon = _getIconForMenu(title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navigate(title),
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9E9E9E).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Icon on the Left (Smaller, Cleaner)
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),

              // 2. Text on the Right
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF566a7f),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: DRAWER HEADER ---
  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF566a7f),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
