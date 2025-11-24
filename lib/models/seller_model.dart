// lib/models/seller_model.dart (مُعدل قليلاً ليتوافق مع مجموعة 'sellers')

class SellerModel {
  final String id;
  final String name;
  final String phone;
  final String address;

  SellerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
  });

  // دالة تحويل من Firestore
  factory SellerModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return SellerModel(
      id: docId,
      // ⭐️⭐️ نحاول قراءة 'name' أولاً، ثم 'supermarketName' كخيار احتياطي ⭐️⭐️
      name: data['name'] ?? data['supermarketName'] ?? 'متجر غير معروف', 
      phone: data['phone'] ?? '---',
      address: data['address'] ?? '---',
    );
  }

  // دالة بيانات افتراضية (Placeholder)
  factory SellerModel.defaultPlaceholder() {
    return SellerModel(
      id: '',
      name: 'جاري تحميل بيانات البائع...',
      phone: '---',
      address: '---',
    );
  }
}
