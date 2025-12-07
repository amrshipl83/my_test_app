// lib/models/product_model.dart

class ProductModel {
  final String id;
  final String name;
  final String? mainCategoryId;
  final String? subCategoryId;
  final String imageUrl;
  final double? displayPrice;
  
  // خاص بالـ MarketOffer
  final bool isAvailable;

  ProductModel({
    required this.id,
    required this.name,
    this.mainCategoryId,
    this.subCategoryId,
    required this.imageUrl,
    this.displayPrice,
    this.isAvailable = true,
  });
}

class CategoryModel {
  final String id;
  final String name;

  CategoryModel({required this.id, required this.name});
}

// enum لخيارات الفرز
enum ProductSortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
}
