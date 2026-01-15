// lib/screens/seller/create_gift_promo_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateGiftPromoScreen extends StatefulWidget {
  final String currentSellerId;
  const CreateGiftPromoScreen({super.key, required this.currentSellerId});

  @override
  State<CreateGiftPromoScreen> createState() => _CreateGiftPromoScreenState();
}

class _CreateGiftPromoScreenState extends State<CreateGiftPromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _promoNameController = TextEditingController();
  final _minOrderValueController = TextEditingController();
  final _triggerQtyBaseController = TextEditingController();
  final _giftQtyPerBaseController = TextEditingController(text: "1");
  final _promoQuantityController = TextEditingController();
  final _expiryDateController = TextEditingController();

  String _triggerType = 'min_order';
  String? _selectedTriggerOfferId;
  String? _selectedGiftOfferId;
  List<Map<String, dynamic>> _availableOffers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSellerOffers();
  }

  // ... (دالة _fetchSellerOffers و _createGiftPromo تبقى كما هي بدون تغيير في المنطق) ...

  TextStyle get _cairoStyle => GoogleFonts.cairo(fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: Text("هدايا العملاء", style: _cairoStyle.copyWith(fontSize: 15.sp, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // تصميم الهيدر بشكل أرشق
            Container(
              padding: EdgeInsets.only(bottom: 4.h),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Center(
                child: Text("قم بإنشاء عرض هدايا جذاب لعملائك", 
                  style: _cairoStyle.copyWith(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.normal)),
              ),
            ),
            
            Transform.translate(
              offset: Offset(0, -3.h),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 5.w),
                padding: EdgeInsets.all(16.sp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))]
                ),
                child: Form(
                  key: _formKey,
                  // تفعيل الفحص التلقائي عند التفاعل
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("بيانات الحملة"),
                      _buildTextField(_promoNameController, "اسم العرض الترويجي", Icons.campaign),
                      
                      // 🛠 إصلاح حقل التاريخ
                      _buildDatePicker(),
                      
                      const Divider(height: 4.h),
                      _sectionLabel("شروط الاستحقاق"),
                      _buildDropdown(),
                      
                      if (_triggerType == 'min_order')
                        _buildTextField(_minOrderValueController, "مبلغ الفاتورة الأدنى", Icons.payments, isNumber: true),
                      
                      const Divider(height: 4.h),
                      _sectionLabel("تفاصيل الهدية"),
                      _buildOfferPicker("اختر منتج الهدية", (id) => setState(() => _selectedGiftOfferId = id)),
                      
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_giftQtyPerBaseController, "كمية الهدية", Icons.card_giftcard, isNumber: true)),
                          SizedBox(width: 3.w),
                          Expanded(child: _buildTextField(_promoQuantityController, "إجمالي المحجوز", Icons.inventory, isNumber: true)),
                        ],
                      ),
                      
                      SizedBox(height: 3.h),
                      
                      // 🛠 زر بتصميم وحجم منطقي
                      _buildSubmitButton(),
                      SizedBox(height: 1.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8.sp),
    child: Text(text, style: _cairoStyle.copyWith(fontSize: 12.sp, color: Colors.green[900])),
  );

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: _cairoStyle.copyWith(fontSize: 12.sp, fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[800]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 4.w),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
    ),
  );

  // 🛠 تعديل اختيار التاريخ لضمان القبول الفوري
  Widget _buildDatePicker() => Padding(
    padding: EdgeInsets.only(bottom: 1.5.h),
    child: TextFormField(
      controller: _expiryDateController,
      readOnly: true,
      style: _cairoStyle.copyWith(fontSize: 12.sp, fontWeight: FontWeight.normal),
      decoration: InputDecoration(
        labelText: "تاريخ انتهاء الصلاحية",
        prefixIcon: const Icon(Icons.event_available, color: Colors.redAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          String formattedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          setState(() {
            _expiryDateController.text = formattedDate;
          });
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? "برجاء اختيار التاريخ" : null,
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 7.h, // حجم زر متناسق (7% من طول الشاشة)
    child: ElevatedButton(
      onPressed: _isLoading ? null : _createGiftPromo,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: _isLoading
        ? const CircularProgressIndicator(color: Colors.white)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 3.w),
              Text("حجز وتفعيل العرض", style: _cairoStyle.copyWith(color: Colors.white, fontSize: 13.sp)),
            ],
          ),
    ),
  );

  // ... (باقي الـ Widgets مثل Dropdown و Picker مع تكبير الخط فيها لـ 12.sp) ...
}
