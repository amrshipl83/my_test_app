// lib/services/user_session.dart

class UserSession {
  // جعل الكلاس Singleton لضمان وجود نسخة واحدة فقط من البيانات في الذاكرة
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;

  UserSession._internal();

  // البيانات التي سيتم تخزينها فور تسجيل الدخول
  static String? userId;      // الـ UID من Firebase Auth
  static String? ownerId;     // معرف المورد الأساسي (صاحب العمل)
  static String? role;        // 'full' أو 'read_only'
  static String? phoneNumber; // رقم الهاتف
  static String? merchantName; // اسم النشاط التجاري
  static bool isSubUser = false; // 🎯 حقل جديد لتمييز الموظف عن التاجر صاحب الحساب

  // دالة ذكية لفحص الصلاحية
  static bool get isReadOnly => role == 'read_only';

  // الصلاحية الكاملة تكون للمدير أو إذا لم يتم تحديد دور (كحساب تاجر أساسي)
  static bool get canEdit => role == 'full' || !isSubUser; 

  // دالة لمسح البيانات عند تسجيل الخروج
  static void clear() {
    userId = null;
    ownerId = null;
    role = null;
    phoneNumber = null;
    merchantName = null;
    isSubUser = false;
  }
}

