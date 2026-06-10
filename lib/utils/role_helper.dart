class RoleHelper {
  static List<String> getMenuForRole(String role) {
    switch (role) {
      case "SUPERADMIN":
        return [
          "Create User",
          "Manage Users",
          "Add Item",
          "Stock In",
          "Stock Details",
          "Create Customer",
          "Our Customers",
          "Create Order",
          "Orders",
          "Bills",
          "Delivery",
          "Payments",
          "Reports",
        ];
      case "ADMIN":
        return [
          "Our Customers",
          "Add Item",
          "Create Order",
          "Orders",
          "Bills",
          "Delivery",
          "Payments",
        ];
      case "DELIVERY":
        return ["Delivery", "Payments"];
      default:
        return [];
    }
  }
}
