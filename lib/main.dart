// lib/main.dart (النسخة المحدثة والمصححة)
import 'package:flutter/material.dart';         
import 'package:firebase_core/firebase_core.dart';                                              
import 'package:provider/provider.dart';        // ⭐️⭐️ استيراد المكونات الجديدة ⭐️⭐️
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';                          
import 'package:my_test_app/firebase_options.dart';                                             
import 'package:my_test_app/screens/login_screen.dart';                                         
// 💡 استيراد شاشات التوجيه بعد الدخول          
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart'; // افترضنا أن هذا هو مسار المشتري                                            
import 'package:my_test_app/screens/seller_screen.dart'; // 💡 تم تحديث استيراد شاشة البائع 
import 'package:my_test_app/theme/app_theme.dart';                                              
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/models/logged_user.dart'; // 💡 نموذج المستخدم
                                                
void main() async {
  WidgetsFlutterBinding.ensureInitialized();    
  try {                                             
    await Firebase.initializeApp(                     
      options: DefaultFirebaseOptions.currentPlatform,                                              
    );                                            
  } catch (e) {                                     
    debugPrint('🚨 FATAL FIREBASE INIT ERROR: $e');                                               
  }                                                                                               
  // ⭐️⭐️ 1. تغليف التطبيق بـ MultiProvider ⭐️⭐️
  runApp(                                           
    MultiProvider(                                    
      providers: [                                      
        // ⭐️ 2. إضافة BuyerDataProvider ⭐️             
        ChangeNotifierProvider(                           
          create: (context) => BuyerDataProvider(),
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
    // ... (تم حذف تعريف الثوابت المحلية القديمة للحفاظ على نظافة الكود)
                                                                                                  
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
        textTheme: const TextTheme(                       
          bodyLarge: TextStyle(color: Color(0xff343a40)),                                               
        ).apply(fontFamily: 'Tajawal'),               
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xffe0e0e0)),                                               
        ).apply(fontFamily: 'Tajawal'),               
      ),
                                                      
      // 🔹 ضبط اتجاه النصوص مركزي لكل التطبيق
      builder: (context, child) {                       
        return Directionality(                            
          textDirection: TextDirection.rtl,               
          child: child!,
        );                                            
      },
      
      // ⭐️⭐️ تم استبدال 'home' بـ 'initialRoute' وإضافة خريطة المسارات 'routes' ⭐️⭐️
      initialRoute: '/',
      routes: {
          '/': (context) => const AuthWrapper(), // 💡 المسار الرئيسي يوجه إلى الـ Wrapper
          // 💡 تعريف المسارات المُسمّاة
          LoginScreen.routeName: (context) => const LoginScreen(),
          BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
          SellerScreen.routeName: (context) => const SellerScreen(), // 💡 تم تحديث المسار ليتطابق مع SellerScreen
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
    // 💡 عند بدأ التطبيق، نقوم بفحص حالة تسجيل الدخول مرة واحدة                                    
    _userFuture = _checkUserLoginStatus();
  }                                                                                               
  
  Future<LoggedInUser?> _checkUserLoginStatus() async {                                             
    final prefs = await SharedPreferences.getInstance();                                            
    final userJsonString = prefs.getString('loggedUser');                                       
    
    if (userJsonString != null) {                     
      final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));                                                                             
      // ⭐️ استدعاء initializeData لمزود البيانات ⭐️                                                  
      // نستخدم listen: false لأننا لا نبني (Build) Widget هنا                                        
      final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);
                                                      
      // في الكود الأصلي، كان id المستخدم هو نفسه id التاجر: currentUserId = user.id, currentDealerId = user.id                                       
      // لذلك نمرر id مرتين                           
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
                                                        
        // 💡 منطق التوجيه بناءً على حالة تسجيل الدخول والدور (مطابقة لمنطق LoginFormWidget) 💡          
        if (snapshot.hasData && snapshot.data != null) {                                                  
          final user = snapshot.data!;                    
          // توجيه بناءً على الدور المخزن                  
          if (user.role == "seller") {                      
            return const SellerScreen(); // 💡 تم تحديث اسم الكلاس 
          } else {                                          
            // "consumer" أو "buyer" أو أي شيء آخر يذهب إلى شاشة المشتري/المتجر                             
            return const BuyerHomeScreen();               
          }                                             
        } else {                                          
          // لم يتم تسجيل الدخول: اذهب إلى شاشة الدخول (Login Screen)                                     
          return const LoginScreen();                   
        }                                             
      },
    );                                            
  }                                             
}
