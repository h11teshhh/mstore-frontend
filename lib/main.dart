import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Storage & Auth
import 'storage/token_storage.dart';
import 'auth/login_page.dart';

// Screens - DASHBOARD & SPLASH
import 'screens/splash_screen.dart';
import 'screens/dashboard.dart';

// Screens - ADMIN
import 'screens/create_user_screen.dart';
import 'screens/user_list_screen.dart'; // Renamed from create_user.dart
import 'screens/end_of_day_report_screen.dart'; // Renamed from end_of_day_report.dart

// Screens - INVENTORY
import 'screens/add_item_screen.dart'; // Renamed from add_item.dart
import 'screens/stock_in_screen.dart'; // Renamed from stock_in.dart
import 'screens/inventory_list_screen.dart'; // Renamed from inventory_list.dart

// Screens - CUSTOMER
import 'screens/create_customer_screen.dart'; // Renamed from create_customer.dart
import 'screens/customer_list_screen.dart'; // Renamed from customer_list.dart
import 'screens/customer_detail_screen.dart'; // Renamed from customer_detail.dart

// Screens - ORDERS & BILLING
import 'screens/create_order_screen.dart'; // Renamed from create_order.dart
import 'screens/orders_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/BillsScreen.dart';

// Screens - LOGISTICS
import 'screens/delivery_screen.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Lock Orientation (Optional but recommended for business apps)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. Initialize Token Storage (Load login data into memory instantly)
  await TokenStorage.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M-Store Inventory',
      debugShowCheckedModeBanner: false,

      // Theme Configuration (Sneat Design System)
      theme: ThemeData(
        useMaterial3: true,
        // fontFamily: 'PublicSans', // Uncomment if you added the font
        scaffoldBackgroundColor: const Color(0xFFF5F5F9),
        primaryColor: const Color(0xFF696CFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF696CFF),
          primary: const Color(0xFF696CFF),
          secondary: const Color(0xFF8592A3),
          surface: Colors.white,
          background: const Color(0xFFF5F5F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF566a7f)),
          titleTextStyle: TextStyle(
            color: Color(0xFF566a7f),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF696CFF),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF696CFF), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8592A3)),
        ),
      ),

      initialRoute: "/",

      // Route Definitions
      routes: {
        // --- Core ---
        "/": (context) => const SplashScreen(),
        "/login": (context) => const LoginPage(),
        "/dashboard": (context) => const Dashboard(),

        // --- Admin ---
        "/createUser": (context) => const CreateUserScreen(),
        "/manageUsers": (context) => const UserListScreen(),
        "/endOfDayReport": (context) => const EndOfDayReportScreen(),

        // --- Inventory ---
        "/addItem": (context) => const AddItemScreen(),
        "/stockIn": (context) => const StockInScreen(),
        "/inventoryList": (context) => const InventoryListScreen(),

        // --- Customers ---
        "/createCustomer": (context) => const CreateCustomerScreen(),
        "/customers": (context) => const CustomerListScreen(),
        "/customerDetail": (context) => const CustomerDetailScreen(),

        // --- Orders & Billing ---
        "/createOrder": (context) => const CreateOrderScreen(),
        "/orders": (context) => const OrdersScreen(),
        "/bills": (context) => const BillsScreen(),
        "/payments": (context) => const PaymentsScreen(),

        // --- Logistics ---
        "/delivery": (context) => const DeliveryScreen(),
      },
    );
  }
}
