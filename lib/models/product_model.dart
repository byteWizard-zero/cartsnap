class Product {
  final String barcode;
  final String name;
  double price;
  final String? imageUrl;
  int quantity; // Tracks how many of this item are in the current cart

  Product({
    required this.barcode,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity =
        1, // Whenever an item is scanned the first time, quantity defaults to 1
  });

  // Helper method to easily create a copy of a product with an updated quantity
  Product copyWith({int? quantity, double? price}) {
    return Product(
      barcode: barcode,
      name: name,
      price: price ?? this.price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }
}
