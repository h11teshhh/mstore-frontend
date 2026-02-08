import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import '../utils/ui_utils.dart'; // Import the UI Utils for Toasts

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://mstore-backend.onrender.com",
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  final TokenStorage _storage = TokenStorage();

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Securely attach token
          final token = await _storage.getToken();
          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },

        onResponse: (response, handler) {
          // Pass success response directly
          return handler.next(response);
        },

        onError: (DioException e, handler) {
          String errorMessage = "An unexpected error occurred.";

          // 1. Check if the Backend sent a specific response
          if (e.response != null && e.response!.data != null) {
            final data = e.response!.data;

            // Handle different backend error formats (Map or String)
            if (data is Map<String, dynamic>) {
              if (data.containsKey('message')) {
                errorMessage = data['message'].toString();
              } else if (data.containsKey('error')) {
                errorMessage = data['error'].toString();
              } else if (data.containsKey('detail')) {
                errorMessage = data['detail'].toString();
              }
            } else if (data is String) {
              errorMessage = data;
            }
          }
          // 2. Handle Network/Connection Errors (No Response)
          else {
            switch (e.type) {
              case DioExceptionType.connectionTimeout:
                errorMessage = "Connection timeout. Please try again.";
                break;
              case DioExceptionType.receiveTimeout:
                errorMessage = "Server is taking too long to respond.";
                break;
              case DioExceptionType.connectionError:
                errorMessage =
                    "No internet connection. Please check your network.";
                break;
              default:
                errorMessage = "Network error occurred.";
            }
          }

          // 3. Show the error to the user via Toast (No terminal logs)
          UIUtils.showErrorToast(errorMessage);

          // 4. Pass the error along so the UI can stop skeletal loading
          return handler.next(e);
        },
      ),
    );
  }

  // -----------------------------------------------------------------------
  // EXISTING METHODS (UNCHANGED)
  // -----------------------------------------------------------------------

  Future<Response> login(String mobile, String password) async {
    return await _dio.post(
      "/auth/login",
      data: {"mobile": mobile, "password": password},
    );
  }

  Future<Response> createUser(Map<String, dynamic> data) async {
    return await _dio.post("/users/", data: data);
  }

  Future<Response> addInventoryItem(String itemName, double price) async {
    return await _dio.post(
      "/inventory/",
      data: {"item_name": itemName, "price": price},
    );
  }

  // Fetch inventory stock list
  Future<Response> getInventoryStock() async {
    return await _dio.get("/inventory/stock");
  }

  // Add stock movement (IN)
  Future<Response> addInventoryMovement({
    required String itemId,
    required int quantity,
  }) async {
    return await _dio.post(
      "/inventory-movement/",
      data: {"item_id": itemId, "quantity": quantity, "movement_type": "IN"},
    );
  }

  //List of customers
  Future<Response> getCustomers() async {
    return await _dio.get("/customers/");
  }

  //to create a customer
  Future<Response> createCustomer({
    required String name,
    required String mobile,
    required String area,
  }) async {
    return await _dio.post(
      "/customers/",
      data: {"name": name, "mobile": mobile, "area": area},
    );
  }

  // Customers all details apis already given cgt
  Future<Response> getCustomerById(String customerId) async {
    return await _dio.get("/customers/$customerId/");
  }

  Future<Response> getOrdersByCustomer(String customerId) async {
    return await _dio.get(
      "/orders",
      queryParameters: {"customer_id": customerId},
    );
  }

  Future<Response> getPaymentsByCustomer(String customerId) async {
    return await _dio.get(
      "/payments",
      queryParameters: {"customer_id": customerId},
    );
  }

  // Create Order
  Future<Response> createOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _dio.post(
      "/orders/",
      data: {"customer_id": customerId, "items": items},
    );
  }

  //specific customer order detial.
  Future<Response> getTodayOrderReport(String customerId) async {
    return await _dio.get("/order-reports/today/$customerId");
  }

  Future<Response> getTodayTruckLoad() async {
    return await _dio.get("/reports/truck-load/today");
  }

  Future<Response> getTodayBillsByArea(String area) async {
    return await _dio.get(
      "/reports/bills/today",
      queryParameters: {"area": area},
    );
  }

  // ---------------- CUSTOMER BASED PAYMENT ----------------
  Future<Response> customerPayment({
    required String customerId,
    required double amount,
  }) async {
    return await _dio.post(
      "/payments/customer",
      data: {"customer_id": customerId, "amount": amount},
    );
  }

  Future<Response> getEndOfDaySummary() async {
    return await _dio.get("/reports/end-of-day/summary");
  }
}
