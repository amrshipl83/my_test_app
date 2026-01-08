// lib/screens/auth/new_client_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/data_sources/client_data_source.dart';
import 'package:my_test_app/screens/auth/client_selection_step.dart';
import 'package:my_test_app/screens/auth/client_details_step.dart';

class NewClientScreen extends StatefulWidget {
  const NewClientScreen({super.key});

  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final PageController _pageController = PageController();
  final ClientDataSource _dataSource = ClientDataSource();

  String _selectedCountry = 'egypt';
  String _selectedUserType = '';

  // تم توحيد المفاتيح لتطابق الـ HTML تماماً
  final Map<String, TextEditingController> _controllers = {
    'fullname': TextEditingController(),
    'phone': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'address': TextEditingController(),
    'merchantName': TextEditingController(),
    'additionalPhone': TextEditingController(),
    'businessType': TextEditingController(), // أضفنا هذا لربطه بالـ Dropdown
  };

  // سنخزن روابط Cloudinary هنا بعد الرفع
  String? _logoUrl;
  String? _crUrl;
  String? _tcUrl;
  
  Map<String, double>? _location;
  int _currentStep = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ يرجى تفعيل GPS في الهاتف')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _location = {'lat': position.latitude, 'lng': position.longitude};
      });
    } catch (e) {
      debugPrint("Error location: $e");
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleSelectionStep({required String country, required String userType}) {
    setState(() {
      _selectedCountry = country;
      _selectedUserType = userType;
    });
    _goToStep(3);
  }

  void _showSuccessDialog() {
    bool isSeller = _selectedUserType == 'seller';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF2D9E68), size: 60),
        title: const Text(
          'تم التسجيل بنجاح',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isSeller
              ? "تم استلام طلب انضمامك بنجاح! يسعدنا تواجدك معنا، يمكنك تسجيل الدخول فور موافقة الإدارة على حسابك."
              : "مرحباً بك في أكسب! تم إنشاء حسابك بنجاح، يرجى تسجيل الدخول للاستمتاع بخدماتنا.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.sp),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D9E68),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('الذهاب لتسجيل الدخول',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 الدالة الجوهرية: تحويل الهاتف لميل ذكي وحفظ البيانات
  Future<void> _handleRegistration() async {
    final phone = _controllers['phone']!.text.trim();
    final pass = _controllers['password']!.text;
    final confirmPass = _controllers['confirmPassword']!.text;

    if (phone.isEmpty || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يرجى إدخال رقم هاتف صحيح')));
      return;
    }
    
    // التوافق مع الـ HTML: تحويل الرقم لميل ذكي
    // ملاحظة: الـ HTML استخدم @aksab.com أو @aswaq.com، سنثبتها حسب رغبتك
    String smartEmail = "$phone@aksab.com";

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ كلمة المرور غير متطابقة')));
      return;
    }

    if (_location == null) {
      await _determinePosition();
    }

    setState(() => _isSaving = true);
    try {
      // إرسال الروابط (URLs) القادمة من Cloudinary إلى الـ Data Source
      await _dataSource.registerClient(
        fullname: _controllers['fullname']!.text,
        email: smartEmail,
        password: pass,
        address: _controllers['address']!.text,
        country: _selectedCountry,
        userType: _selectedUserType,
        location: _location,
        // هذه الروابط تم جلبها من Cloudinary داخل الـ Details Step
        logoUrl: _logoUrl, 
        crUrl: _crUrl,
        tcUrl: _tcUrl,
        merchantName: _controllers['merchantName']!.text,
        businessType: _controllers['businessType']!.text, // تم السحب من الـ controller
        additionalPhone: _controllers['additionalPhone']!.text,
      );

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFB),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              child: Column(
                children: [
                  const _LogoHeader(),
                  SizedBox(height: 3.h),
                  _buildStepProgress(),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: 60.h, maxHeight: 85.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ClientSelectionStep(
                            stepNumber: 1,
                            onCountrySelected: (country) {
                              setState(() => _selectedCountry = country);
                              _goToStep(2);
                            },
                            initialCountry: _selectedCountry,
                            initialUserType: _selectedUserType,
                          ),
                          ClientSelectionStep(
                            stepNumber: 2,
                            initialCountry: _selectedCountry,
                            initialUserType: _selectedUserType,
                            onCompleted: _handleSelectionStep,
                            onGoBack: () => _goToStep(1),
                            onCountrySelected: (_) {},
                          ),
                          ClientDetailsStep(
                            controllers: _controllers,
                            selectedUserType: _selectedUserType,
                            isSaving: _isSaving,
                            // استلام الروابط من Cloudinary وتخزينها في الصفحة الحالية
                            onUploadComplete: ({required field, required url}) {
                              setState(() {
                                if (field == 'logo') _logoUrl = url;
                                if (field == 'cr') _crUrl = url;
                                if (field == 'tc') _tcUrl = url;
                              });
                            },
                            onLocationChanged: ({required lat, required lng}) {
                              setState(() => _location = {'lat': lat, 'lng': lng});
                            },
                            onRegister: _handleRegistration,
                            onGoBack: () => _goToStep(2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (نفس الـ Widgets الخاصة بـ _buildStepProgress و _LogoHeader و _Footer كما في الكود الأصلي)
  Widget _buildStepProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        int stepNum = index + 1;
        bool isCompleted = _currentStep > stepNum;
        bool isActive = _currentStep == stepNum;
        return Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive || isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade200,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text('$stepNum',
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            if (index < 2)
              Container(
                  width: 15.w,
                  height: 2,
                  color: isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade200),
          ],
        );
      }),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.person_add_rounded, size: 50, color: Color(0xFF2D9E68)),
        const SizedBox(height: 12),
        Text('إنشاء حساب جديد',
            style: TextStyle(
                fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        Text('سجل برقم هاتفك لسهولة الوصول',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text.rich(
        TextSpan(
          text: 'لديك حساب بالفعل؟ ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
          children: const [
            TextSpan(
              text: 'تسجيل الدخول',
              style: TextStyle(color: Color(0xFF2D9E68), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
