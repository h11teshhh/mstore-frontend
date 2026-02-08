class InventoryItem {
  final String id;
  final String name;
  final double price;
  final int currentStock;

  InventoryItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currentStock,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json["_id"],
      name: json["item_name"],
      price: (json["price"] as num).toDouble(),
      currentStock: json["current_stock"],
    );
  }
}
