import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'manage_gift_promos_screen.dart';

class CreateGiftPromoScreen extends StatefulWidget {
  final String currentSellerId;
  const CreateGiftPromoScreen({super.key, required this.currentSellerId});

  @override
  State<CreateGiftPromoScreen> createState() => _CreateGiftPromoScreenState();
}

class _CreateGiftPromoScreenState extends State<CreateGiftPromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _promoNameController = TextEditingController();
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _triggerQtyBaseController = TextEditingController();
  final TextEditingController _giftQtyPerBaseController = TextEditingController(text: "1");
  final TextEditingController _maxPromoQtyController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

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

  Future<void> _fetchSellerOffers() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('productOffers')
          .where('sellerId', isEqualTo: widget.currentSellerId)
          .get();

      final offers = snapshot.docs.map((doc) {
        final data = doc.data();
        final List units = data['units'] as List? ?? [];
        final unit = units.isNotEmpty ? units.first : {};
        return {
          'id': doc.id,
          'productName': data['productName'] ?? 'بدون اسم',
          'productId': data['productId'] ?? doc.id,
          'imageUrl': data['imageUrl'] ?? '',
          'availableStock': unit['availableStock'] ?? 0,
          'price': unit['price'] ?? 0,
          'unitName': unit['unitName'] ?? 'الوحدة الرئيسية',
        };
      }).toList();

      setState(() {
        _availableOffers = offers;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar("خطأ في تحميل العروض: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGiftPromo() async {
    if (!_formKey.currentState!.validate() || _selectedGiftOfferId == null) {
      _showSnackBar("برجاء استكمال البيانات واختيار الهدية", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final giftOffer = _availableOffers.firstWhere((o) => o['id'] == _selectedGiftOfferId);
      final int requestedQty = int.parse(_maxPromoQtyController.text);
      final String promoName = _promoNameController.text;

      // تنفيذ العملية وحجز الرصيد
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final giftRef = FirebaseFirestore.instance.collection('productOffers').doc(_selectedGiftOfferId);
        final giftDoc = await transaction.get(giftRef);

        if (!giftDoc.exists) throw "وثيقة الهدية غير موجودة";

        List units = List.from(giftDoc.data()?['units'] ?? []);
        Map unit0 = Map.from(units[0]);
        int currentStock = (unit0['availableStock'] ?? 0).toInt();

        if (currentStock < requestedQty) throw "الرصيد غير كافٍ!";

        unit0['availableStock'] = currentStock - requestedQty;
        unit0['reservedForPromos'] = (unit0['reservedForPromos'] ?? 0) + requestedQty;
        units[0] = unit0;

        transaction.update(giftRef, {'units': units});

        final promoRef = FirebaseFirestore.instance.collection('giftPromos').doc();
        transaction.set(promoRef, {
          'sellerId': widget.currentSellerId,
          'promoName': promoName,
          'giftOfferId': _selectedGiftOfferId,
          'giftProductName': giftOffer['productName'],
          'giftUnitName': giftOffer['unitName'],
          'giftQuantityPerBase': int.parse(_giftQtyPerBaseController.text),
          'giftOfferPriceSnapshot': giftOffer['price'],
          'giftProductId': giftOffer['productId'],
          'giftProductImage': giftOffer['imageUrl'],
          'trigger': _triggerType == 'min_order'
              ? {'type': 'min_order', 'value': double.parse(_minOrderController.text)}
              : {
                  'type': 'specific_item',
                  'offerId': _selectedTriggerOfferId,
                  'productName': _availableOffers.firstWhere((o) => o['id'] == _selectedTriggerOfferId)['productName'],
                  'triggerQuantityBase': int.parse(_triggerQtyBaseController.text)
                },
          'expiryDate': Timestamp.fromDate(DateTime.parse(_expiryDateController.text)),
          'maxQuantity': requestedQty,
          'usedQuantity': 0,
          'status': 'active',
          'isNotified': false, // 👈 الحقل الأهم للمدا المجدولة (Cron Job)
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        _showSnackBar("تم إنشاء العرض وحجز المخزن بنجاح ✅");
        setState(() => _isLoading = false);
        Navigator.pop(context);
        // تم حذف _startNotificationBroadcast تماماً
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('إنشاء عرض هدايا', style: TextStyle(fontSize: 14.sp)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManageGiftPromosScreen(currentSellerId: widget.currentSellerId))),
            tooltip: "إدارة الهدايا",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: EdgeInsets.all(12.sp),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionCard([
                      _buildTextField(_promoNameController, "اسم العرض الترويجي", Icons.campaign),
                      _buildDatePicker(),
                    ]),
                    _buildSectionCard([
                      _buildDropdown("متى تُمنح الهدية؟", ['min_order', 'specific_item'], (val) => setState(() => _triggerType = val!)),
                      if (_triggerType == 'min_order')
                        _buildTextField(_minOrderController, "الحد الأدنى للطلب (ج.م)", Icons.payments, isNumber: true),
                      if (_triggerType == 'specific_item') ...[
                        _buildOfferPicker("اختر المنتج المطلوب شراؤه", (id) => _selectedTriggerOfferId = id),
                        _buildTextField(_triggerQtyBaseController, "الكمية المطلوبة للتفعيل", Icons.shopping_basket, isNumber: true),
                      ],
                    ]),
                    _buildSectionCard([
                      _buildOfferPicker("اختر الهدية الممنوحة", (id) => _selectedGiftOfferId = id),
                      _buildTextField(_giftQtyPerBaseController, "كمية الهدية لكل عملية", Icons.card_giftcard, isNumber: true),
                      _buildTextField(_maxPromoQtyController, "إجمالي الهدايا المتاحة للحجز", Icons.inventory, isNumber: true),
                    ]),
                    SizedBox(height: 10.sp),
                    SizedBox(
                      width: 80.w,
                      height: 45.sp,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createGiftPromo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 2,
                        ),
                        child: Text(_isLoading ? "جاري الحفظ..." : "تفعيل العرض وحجز المخزن",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                      ),
                    ),
                    SizedBox(height: 10.sp),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.sp),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(padding: EdgeInsets.all(10.sp), child: Column(children: children)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(fontSize: 11.sp),
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10.sp),
          prefixIcon: Icon(icon, size: 16.sp),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 8.sp),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?) onSelected, {bool isOffer = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        style: TextStyle(fontSize: 11.sp, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10.sp),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 8.sp),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items.map((id) {
          String text = id;
          if (isOffer) {
            final offer = _availableOffers.firstWhere((o) => o['id'] == id);
            text = "${offer['productName']} (${offer['availableStock']})";
          } else {
            text = id == 'min_order' ? "عند الوصول لمبلغ محدد" : "عند شراء منتج معين";
          }
          return DropdownMenuItem(value: id, child: Text(text, overflow: TextOverflow.ellipsis));
        }).toList(),
        onChanged: onSelected,
        validator: (v) => v == null ? "مطلوب" : null,
      ),
    );
  }

  Widget _buildOfferPicker(String label, Function(String?) onSelected) =>
      _buildDropdown(label, _availableOffers.map((e) => e['id'] as String).toList(), onSelected, isOffer: true);

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: _expiryDateController,
        readOnly: true,
        style: TextStyle(fontSize: 11.sp),
        decoration: InputDecoration(
          labelText: "تاريخ انتهاء العرض",
          labelStyle: TextStyle(fontSize: 10.sp),
          prefixIcon: Icon(Icons.calendar_today, size: 16.sp),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onTap: () async {
          DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030));
          if (picked != null) setState(() => _expiryDateController.text = picked.toIso8601String().split('T')[0]);
        },
        validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green, duration: const Duration(seconds: 2)));
  }
}

