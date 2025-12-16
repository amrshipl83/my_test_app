// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/firebase_options.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/date_symbol_data_local.dart';

// استيراد شاشات المشتري والمستهلك
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/my_details_screen.dart';
import 'package:my_test_app/screens/about_screen.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/delivery_settings_screen.dart';
import 'package:my_test_app/screens/update_delivery_settings_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';
import 'package:my_test_app/screens/consumer_orders_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';
import 'package:my_test_app/screens/product_details_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_sub_category_screen.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';

// 🆕 استيراد شاشة النقاط وشاشة مشتريات المستهلك الجديدة
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_purchase_history_screen.dart';

// استيراد الثيم والمزودات
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/screens/delivery/product_offer_screen.dart';
import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/providers/customer_orders_provider.dart';
import 'package:my_test_app/screens/delivery/delivery_offers_screen.dart';
import 'package:my_test_app/screens/buyer/wallet_screen.dart';
import 'package:my_test_app/providers/cashback_provider.dart';
import 'package:my_test_app/screens/search/search_screen.dart';
import 'package:my_test_app/models/user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('last_error', details.toString());
    debugPrint('🚨 FATAL FLUTTER ERROR LOGGED: ${details.exceptionAsString()}');
  };

  try {
    await initializeDateFormatting('ar', null);
  } catch (e) {
    debugPrint('🚨 Error initializing Date Formatting for Arabic: $e');
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('🚨 FATAL FIREBASE INIT ERROR: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeNotifier(ThemeMode.system)),
        ChangeNotifierProvider(create: (context) => BuyerDataProvider()),
        ChangeNotifierProvider(create: (context) => ManufacturersProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => SellerDashboardController()),
        ChangeNotifierProxyProvider<BuyerDataProvider, CustomerOrdersProvider>(
          create: (context) => CustomerOrdersProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => CustomerOrdersProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, ProductOfferProvider>(
          create: (context) => ProductOfferProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => ProductOfferProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, CashbackProvider>(
          create: (context) => CashbackProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => CashbackProvider(buyerData),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'My Test App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen, secondary: AppTheme.accentBlueLight),
            scaffoldBackgroundColor: AppTheme.scaffoldLight,
            cardColor: Colors.white,
            textTheme: GoogleFonts.notoSansArabicTextTheme(const TextTheme(bodyLarge: TextStyle(color: Color(0xff343a40)))),
          ),
          darkTheme: ThemeData.dark().copyWith(
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
            textTheme: GoogleFonts.notoSansArabicTextTheme(const TextTheme(bodyLarge: TextStyle(color: Color(0xffe0e0e0)))),
          ),
          builder: (context, child) {
            return Directionality(textDirection: TextDirection.rtl, child: child!);
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            ConsumerHomeScreen.routeName: (context) => ConsumerHomeScreen(),
            ConsumerStoreSearchScreen.routeName: (context) => const ConsumerStoreSearchScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
            
            // 1. طلبات الجملة (للمورد)
            MyOrdersScreen.routeName: (context) => const MyOrdersScreen(),
            
            // 2. طلبات الدليفري (للسوبر ماركت)
            '/con-orders': (context) => const ConsumerOrdersScreen(),
            
            // 3. مشتريات المستهلك الشخصية (جديد)
            ConsumerPurchaseHistoryScreen.routeName: (context) => const ConsumerPurchaseHistoryScreen(),

            '/deliverySettings': (context) => const DeliverySettingsScreen(),
            '/updatsupermarket': (context) => const UpdateDeliverySettingsScreen(),
            '/deliveryPrices': (context) => const DeliveryMerchantDashboardScreen(),
            DeliveryOffersScreen.routeName: (context) => const DeliveryOffersScreen(),
            '/myDetails': (context) => const MyDetailsScreen(),
            '/about': (context) => const AboutScreen(),
            TradersScreen.routeName: (context) => const TradersScreen(),
            '/register': (context) => const NewClientScreen(),
            '/post_registration_message': (context) => const PostRegistrationMessageScreen(),

            '/wallet': (context) => const WalletScreen(),
            PointsLoyaltyScreen.routeName: (context) => const PointsLoyaltyScreen(),

            SearchScreen.routeName: (context) {
              final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
              final role = buyerData.userClassification == 'seller' ? UserRole.buyer : UserRole.consumer;
              return SearchScreen(userRole: role);
            },
          },
          onGenerateRoute: (settings) {
            // ... (باقي منطق onGenerateRoute كما هو بدون تغيير)
            if (settings.name == '/productDetails') {
              String? productId;
              String? offerId;
              if (settings.arguments is String) {
                productId = settings.arguments as String;
              } else if (settings.arguments is Map<String, dynamic>) {
                final args = settings.arguments as Map<String, dynamic>;
                productId = args['productId'] as String?;
                offerId = args['offerId'] as String?;
              }
              if (productId != null && productId.isNotEmpty) {
                return MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId!, offerId: offerId));
              }
              return null;
            }
            if (settings.name == MarketplaceHomeScreen.routeName) {
              final args = settings.arguments as Map<String, dynamic>?;
              final storeId = args?['storeId'] as String?;
              final storeName = args?['storeName'] as String?;
              if (storeId != null && storeName != null) {
                return MaterialPageRoute(builder: (context) => MarketplaceHomeScreen(currentStoreId: storeId, currentStoreName: storeName));
              }
              return null;
            }
            if (settings.name == ProductOfferScreen.routeName) {
              return MaterialPageRoute(builder: (context) => const ProductOfferScreen());
            }
            if (settings.name == '/subcategories') {
              final args = settings.arguments as Map<String, dynamic>?;
              final mainCategoryId = args?['mainId'] as String?;
              final ownerId = args?['ownerId'] as String?;
              final mainCategoryName = args?['mainCategoryName'] as String?;
              if (mainCategoryId != null && ownerId != null) {
                return MaterialPageRoute(builder: (context) => ConsumerSubCategoryScreen(mainCategoryId: mainCategoryId, ownerId: ownerId, mainCategoryName: mainCategoryName ?? 'الأقسام الفرعية'));
              }
              return null;
            }
            if (settings.name == ConsumerProductListScreen.routeName) {
              final args = settings.arguments as Map<String, dynamic>?;
              final ownerId = args?['ownerId'] as String?;
              final mainId = args?['mainId'] as String?;
              final subId = args?['subId'] as String?;
              final subCategoryName = args?['subCategoryName'] as String?;
              if (ownerId != null && mainId != null && subId != null) {
                return MaterialPageRoute(builder: (context) => ConsumerProductListScreen(ownerId: ownerId, mainId: mainId, subId: subId, subCategoryName: subCategoryName ?? 'المنتجات'));
              }
              return null;
            }
            if (settings.name == TraderOffersScreen.routeName) {
              final sellerId = settings.arguments as String? ?? '';
              return MaterialPageRoute(builder: (context) => TraderOffersScreen(sellerId: sellerId));
            }
            if (settings.name == '/products') {
              final args = settings.arguments as Map<String, String>? ?? {};
              return MaterialPageRoute(builder: (context) => BuyerProductListScreen(mainCategoryId: args['mainId'] ?? '', subCategoryId: args['subId'] ?? ''));
            }
            if (settings.name == '/category') {
              final mainCategoryId = settings.arguments as String? ?? 'default_id';
              return MaterialPageRoute(builder: (context) => BuyerCategoryScreen(mainCategoryId: mainCategoryId));
            }
            return null;
          },
        );
      },
    );
  }
}

// ... باقي الكلاسات (AuthWrapper و PostRegistrationMessageScreen) كما هي
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
      try {
        final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));
        await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(userData.id, userData.id, userData.fullname);
        return userData;
      } catch (e) {
        debugPrint('🚨 AuthWrapper User Load/Init Error: $e');
        await prefs.remove('loggedUser');
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (user.role == "seller") return const SellerScreen();
          if (user.role == "consumer") return ConsumerHomeScreen();
          return const BuyerHomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class PostRegistrationMessageScreen extends StatelessWidget {
  const PostRegistrationMessageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isSeller = args?['isSeller'] ?? false;
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    });
    final String message;
    final IconData icon;
    final Color color;
    if (isSeller) {
      message = 'تم تسجيل حساب التاجر بنجاح.\nحسابك قيد المراجعة في انتظار النقل إلى التجار النشطين.';
      icon = Icons.pending_actions;
      color = Colors.orange;
    } else {
      message = 'تم تسجيل بياناتك بنجاح.\nسيتم نقلك الآن لتسجيل الدخول والمصادقة.';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 80),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
