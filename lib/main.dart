// lib/main.dart (النسخة المحدثة والمصححة مع إضافة SellerDashboardController)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/firebase_options.dart';
// 💡 استيراد شاشات التوجيه 💡
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart'; // مسار المشتري الرئيسي
import 'package:my_test_app/screens/seller_screen.dart'; // شاشة البائع
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart'; // شاشة الأقسام الفرعية
// 🆕 استيراد شاشة قائمة المنتجات الجديدة
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart';
// 🆕 [التصحيح]: استيراد شاشة السلة التي تم إرسالها
import 'package:my_test_app/screens/buyer/cart_screen.dart';

import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
// 💡 [تعديل 1]: استيراد الـ Provider الجديد
import 'package:my_test_app/providers/manufacturers_provider.dart';
// 🆕 [تعديل 3]: استيراد CartProvider
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
// 💡 استيراد GoogleFonts لاستخدامه في الـ Theme
import 'package:google_fonts/google_fonts.dart';
// 🚨🚨 التصحيح الهيكلي: استيراد SellerDashboardController 🚨🚨
import 'package:my_test_app/controllers/seller_dashboard_controller.dart'; 


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🚨 FATAL FIREBASE INIT ERROR: $e');
  }

  // ⭐️⭐️ تغليف التطبيق بـ MultiProvider ⭐️⭐️
  runApp(
    MultiProvider(
      providers: [
        // ⭐️ إضافة BuyerDataProvider ⭐️
        ChangeNotifierProvider(
          create: (context) => BuyerDataProvider(),
        ),
        // 💡 [تعديل 2]: إضافة ManufacturersProvider إلى قائمة الـ Providers
        ChangeNotifierProvider(
          create: (context) => ManufacturersProvider(),
        ),
        // 🆕 [التعديل الرئيسي]: إضافة CartProvider إلى قائمة الـ Providers
        ChangeNotifierProvider(
          create: (context) => CartProvider(),
        ),
        // 🎯 إضافة SellerDashboardController لتجنب خطأ ProviderNotFound 🎯
        ChangeNotifierProvider(
          create: (context) => SellerDashboardController(),
        ),
      ],
      child: const MyApp(), // تطبيقنا الآن ابن لـ MultiProvider
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // يتم استخدام Theme.of(context) لضبط الثيم (فاتح/داكن) تلقائيًا بناءً على إعدادات الجهاز.
    return MaterialApp(
      title: 'My Test App',
      debugShowCheckedModeBanner: false,
      // 3. الثيم الفاتح - استخدام الثوابت الجديدة
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppTheme.primaryGreen,
        colorScheme: ColorScheme.light(
          primary: AppTheme.primaryGreen,
          secondary: AppTheme.accentBlueLight,
        ),
        scaffoldBackgroundColor: AppTheme.scaffoldLight,
        cardColor: Colors.white,
        // 💡💡 توحيد الخط لـ Noto Sans Arabic في الثيم الفاتح 💡💡
        textTheme: GoogleFonts.notoSansArabicTextTheme(
          const TextTheme(
            bodyLarge: TextStyle(color: Color(0xff343a40)),
          ),
        ),
      ),
      // 4. الثيم الداكن - استخدام الثوابت الجديدة
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        primaryColor: AppTheme.primaryGreen,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.primaryGreen,
          secondary: const Color(0xff64B5F6),
          surface: const Color(0xff121212),
          onSurface: const Color(0xffe0e0e0),
        ),
        scaffoldBackgroundColor: const Color(0xff121212),
        cardColor: AppTheme.cardDark,
        drawerTheme: DrawerThemeData(backgroundColor: AppTheme.darkSidebarBg),
        // 💡💡 توحيد الخط لـ Noto Sans Arabic في الثيم الداكن 💡💡
        textTheme: GoogleFonts.notoSansArabicTextTheme(
          const TextTheme(
            bodyLarge: TextStyle(color: Color(0xffe0e0e0)),
          ),
        ),
      ),
      // 🔹 ضبط اتجاه النصوص مركزي لكل التطبيق
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      // ⭐️⭐️ تعريف المسارات المُسمّاة 'routes' ⭐️⭐️
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(), // 💡 المسار الرئيسي يوجه إلى الـ Wrapper
        // 💡 تعريف المسارات الأساسية
        LoginScreen.routeName: (context) => const LoginScreen(),
        BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
        SellerScreen.routeName: (context) => const SellerScreen(),
        // 🆕 [التصحيح الرئيسي]: إضافة مسار شاشة السلة باستخدام ملف CartScreen الذي تم إرساله
        CartScreen.routeName: (context) => const CartScreen(),
      },
      // 🆕 استخدام onGenerateRoute لفك الـ Map الخاص بـ '/products'
      onGenerateRoute: (settings) {
        if (settings.name == '/products') {
          // نستقبل الـ Map الذي يحتوي على {'subId': ..., 'mainId': ...}
          final args = settings.arguments as Map<String, String>? ?? {};
          return MaterialPageRoute(
            builder: (context) {
              return BuyerProductListScreen(
                mainCategoryId: args['mainId'] ?? '',
                subCategoryId: args['subId'] ?? '',
              );
            },
          );
        }
        // ✅ توحيد معالجة مسار /category هنا لتوحيد طريقة استقبال الـ arguments
        if (settings.name == '/category') {
          final mainCategoryId = settings.arguments as String? ?? 'default_id';
          return MaterialPageRoute(
            builder: (context) => BuyerCategoryScreen(mainCategoryId: mainCategoryId),
          );
        }

        // إذا كان المسار غير معروف في routes ولم تتم معالجته هنا، نرجع null
        return null;
      },
    );
  }
}

// ⭐️⭐️ الـ Wrapper الذي يعكس منطق onAuthStateChanged في Flutter ⭐️⭐️
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {

  Future<LoggedInUser?>? _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _checkUserLoginStatus();
  }

  Future<LoggedInUser?> _checkUserLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonString = prefs.getString('loggedUser');

    if (userJsonString != null) {
      final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));
      // ⭐️ استدعاء initializeData لمزود البيانات ⭐️
      final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);

      // نمرر id مرتين لـ currentUserId و currentDealerId (حسب المنطق الأصلي)
      await buyerProvider.initializeData(userData.id, userData.id, userData.fullname);

      return userData;
    }
    return null; // لا يوجد مستخدم مسجل
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // عرض شاشة تحميل بسيطة أثناء التحقق من الشيرد بريفرينسز
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 💡 منطق التوجيه بناءً على حالة تسجيل الدخول والدور 💡
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // توجيه بناءً على الدور المخزن
          if (user.role == "seller") {
            return const SellerScreen(); // 🎯 توجه مباشرة لـ SellerScreen
          } else {
            // "consumer" أو "buyer" أو أي شيء آخر يذهب إلى شاشة المشتري/المتجر
            return const BuyerHomeScreen(); // 🎯 توجه لـ BuyerHomeScreen
          }
        } else {
          // لم يتم تسجيل الدخول: اذهب إلى شاشة الدخول (Login Screen)
          return const LoginScreen();
        }
      },
    );
  }
}
