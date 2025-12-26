// lib/services/user_session.dart

class UserSession {
  // جعل الكلاس Singleton لضمان وجود نسخة واحدة فقط من البيانات في الذاكرة
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  // البيانات التي سيتم تخزينها فور تسجيل الدخول
  static String? userId;      // الـ UID الخاص بالمستخدم الحالي (الموظف أو المدير)
  static String? ownerId;     // معرف المورد الأساسي (صاحب العمل)
  static String? role;        // الدور: 'full' (مدير/صلاحية كاملة) أو 'read_only' (موظف عرض فقط)
  static String? phoneNumber; // رقم الهاتف

  // دالة ذكية لفحص الصلاحية (تستخدمها في أي مكان في التطبيق)
  static bool get isReadOnly => role == 'read_only';
  static bool get canEdit => role == 'full' || role == null; // null تعني أنه صاحب الحساب الأساسي

  // دالة لمسح البيانات عند تسجيل الخروج
  static void clear() {
    userId = null;
    ownerId = null;
    role = null;
    phoneNumber = null;
  }
}

