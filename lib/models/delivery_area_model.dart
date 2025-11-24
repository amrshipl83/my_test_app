// lib/models/delivery_area_model.dart
// نموذج منطقة التوصيل (Delivery Area Model)
// يمثل منطقة جغرافية يمكن للبائع اختيار التوصيل إليها.

class DeliveryAreaModel {
  // ⭐️ التصحيح 1: إضافة حقل id كمرجع لمفتاح المستند في حالة الحاجة إليه، وسنستخدم الـ code كقيمة له.
  final String? id;

  // كود المنطقة (مثال: 'Riyadh-North') - سنستخدمه كقيمة مرجعية
  final String code;

  // اسم المنطقة المعروض (مثال: 'شمال الرياض')
  final String name;

  // مؤشر لتحديد ما إذا كان البائع الحالي قد اختار هذه المنطقة
  bool isSelected;

  // ⭐️ التصحيح 2: إضافة حقل ownerId المطلوب لتفادي الأخطاء في دوال الحفظ
  final String? ownerId; 

  DeliveryAreaModel({
    this.id, // ID يمكن أن يكون null في حالة التحويل من JSON الأولي لملف GeoJSON
    required this.code,
    required this.name,
    this.isSelected = false,
    this.ownerId,
  });

  // دالة تحويل من Firestore/JSON
  // 💡 نفترض أن البيانات تأتي من GeoJSON أو كائن يحتوي على 'code' و 'name'
  factory DeliveryAreaModel.fromJson(Map<String, dynamic> json) {
    // 💡 نستخدم 'code' كمفتاح أساسي (ID) ما لم يتم توفير id صريح
    final String areaCode = json['code'] ?? '';
    
    return DeliveryAreaModel(
      id: json['id'] ?? areaCode, 
      code: areaCode,
      name: json['name'] ?? 'منطقة غير معروفة',
      // isSelected يتم تعيينها لاحقاً في الكنترولر بناءً على بيانات البائع
      isSelected: false,
      // ownerId يتم تعيينه فقط عند القراءة من مجموعة deliverySupermarkets (إذا كانت تُستخدم)
      ownerId: json['ownerId'], 
    );
  }

  // دالة تحويل إلى JSON/Map (تستخدم غالباً في التخزين المؤقت أو الإرسال)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      // 💡 إضافة ownerId ليتم حفظه في Firestore إذا كنا سنستخدم مجموعة deliverySupermarkets
      if (ownerId != null) 'ownerId': ownerId, 
    };
  }
}
