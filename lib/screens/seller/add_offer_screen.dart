// lib/screens/seller/add_offer_screen.dart (النسخة النهائية والمُصحَّحة)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/data_sources/add_offer_data_source.dart';
import 'package:my_test_app/models/offer_model.dart';// ⭐️ استيراد النموذج المركزي بدلاً من التعريف المؤقت ⭐️
import 'package:my_test_app/models/select_item_model.dart';
import 'package:my_test_app/widgets/form_widgets.dart';

// تم إزالة تعريف SelectItemModel المؤقت من هنا
class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataSource = AddOfferDataSource();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  final _minOrderController = TextEditingController();
  final _maxOrderController = TextEditingController();

  // حالة التحكم في القوائم المنسدلة
  List<SelectItemModel> _mainCategories = [];
  List<SelectItemModel> _subCategories = [];
  List<SelectItemModel> _products = [];
  Map<String, Set<String>> _offeredUnitsByProduct = {};

  String? _selectedMainCategoryId;
  String? _selectedSubCategoryId;
  String? _selectedProductId;

  String? _selectedUnitName;
  List<String> _availableUnits = [];
  List<String> _sellerDeliveryAreas = [];

  String? _message;
  bool _isSuccess = false;
  bool _isLoading = true;
  final String _currentSellerId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_seller';
  final String _currentSellerName = "البائع";

  // دالة مساعدة للبحث عن الكائن باستخدام ID
  SelectItemModel? _findItemById(List<SelectItemModel> list, String? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _minOrderController.dispose();
    _maxOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_currentSellerId == 'unknown_seller') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'خطأ: لم يتم العثور على مُعرّف البائع (قد تحتاج لتسجيل الدخول).';
        });
      }
      return;
    }

    try {
      final categories = await _dataSource.loadMainCategories();
      final areas = await _dataSource.loadSellerDeliveryAreas(_currentSellerId);

      // Fix: use context only after checking mounted
      if (!mounted) return;

      setState(() {
        _mainCategories = categories;
        _sellerDeliveryAreas = areas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message = 'خطأ في تحميل البيانات الأساسية: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _loadSubCategories(String mainId) async {
    setState(() {
      _selectedSubCategoryId = null;
      _selectedProductId = null;
      _selectedUnitName = null;
      _subCategories = [];
      _products = [];
      _availableUnits = [];
    });
    try {
      final subCats = await _dataSource.loadSubCategories(mainId);
      if (!mounted) return; // Fix: use context only after checking mounted

      setState(() => _subCategories = subCats);
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في تحميل الأقسام الفرعية.', false);
    }
  }

  Future<void> _loadProducts(String subId) async {
    setState(() {
      _selectedProductId = null;
      _selectedUnitName = null;
      _products = [];
      _availableUnits = [];
    });
    try {
      // ⚠️ يجب التأكد أن دالة loadProducts في Data Source تعيد List<SelectItemModel> الموحدة
      final result = await _dataSource.loadProducts(subId, _currentSellerId);
      if (!mounted) return; // Fix: use context only after checking mounted

      setState(() {
        _products = result['allProducts'] as List<SelectItemModel>;
        _offeredUnitsByProduct = result['offeredUnitsByProduct'] as Map<String, Set<String>>;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في تحميل المنتجات.', false);
    }
  }

  void _loadAvailableUnits(String productId) {
    setState(() {
      _selectedUnitName = null;
      _availableUnits = [];
    });

    final product = _findItemById(_products, productId);

    if (product == null) {
      _showMessage('لم يتم العثور على بيانات المنتج. (Debugging)', false);
      return;
    }

    final productUnits = product.units;

    if (productUnits != null && productUnits.isNotEmpty) {
      final offeredUnits = _offeredUnitsByProduct[productId] ?? {};

      final units = productUnits
          .map<String>((unit) => unit['unitName'].toString())
          .where((unitName) => !offeredUnits.contains(unitName))
          .toList();

      if (mounted) {
        setState(() => _availableUnits = units);
      }

      if (units.isEmpty) {
        _showMessage('جميع وحدات هذا المنتج لديها عروض حالية من قبلك.', false);
      }
    } else {
      _showMessage('لا توجد وحدات معرفة لهذا المنتج.', false);
    }
  }

  void _showMessage(String msg, bool isSuccess) {
    setState(() {
      _message = msg;
      _isSuccess = isSuccess;
    });
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMainCategoryId == null || _selectedSubCategoryId == null || _selectedProductId == null || _selectedUnitName == null) {
      _showMessage('الرجاء اختيار القسم والمنتج والوحدة أولاً.', false);
      return;
    }

    // الحصول على كائن المنتج المُختار
    final selectedProduct = _findItemById(_products, _selectedProductId);
    if (selectedProduct == null) {
      _showMessage('خطأ: فشل تحديد بيانات المنتج لإضافة العرض.', false);
      return;
    }

    _showMessage('جاري إضافة العرض...', false);
    try {
      final price = double.parse(_priceController.text);
      final quantity = int.parse(_quantityController.text);
      final minOrder = _minOrderController.text.isNotEmpty ? int.tryParse(_minOrderController.text) : null;
      final maxOrder = _maxOrderController.text.isNotEmpty ? int.tryParse(_maxOrderController.text) : null;

      final offerModel = ProductOfferModel(
        sellerId: _currentSellerId,
        sellerName: _currentSellerName,
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        imageUrl: selectedProduct.imageUrl ?? '',
        deliveryZones: _sellerDeliveryAreas,
        units: [
          OfferUnitModel(
            unitName: _selectedUnitName!,
            price: price,
            availableStock: quantity,
          ),
        ],
        minOrder: minOrder,
        maxOrder: maxOrder,
      );

      final offerId = await _dataSource.addOffer(offerModel);

      if (!mounted) return;

      _showMessage('تم إضافة العرض بنجاح! ID: $offerId', true);
      _formKey.currentState!.reset();
      if (_selectedSubCategoryId != null) {
        await _loadProducts(_selectedSubCategoryId!);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('حدث خطأ أثناء إضافة العرض. يرجى المحاولة مرة أخرى: $e', false);
    }
  }

  // ⭐️ دالة مساعدة لتصحيح تحذيرات الألوان ⭐️
  Color _withAlpha(Color color, double opacity) {
    return color.withAlpha((255 * opacity).round().clamp(0, 255));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedMainCategory = _findItemById(_mainCategories, _selectedMainCategoryId);
    final selectedSubCategory = _findItemById(_subCategories, _selectedSubCategoryId);
    final selectedProduct = _findItemById(_products, _selectedProductId);

    final messageColor = _isSuccess ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                // ⭐️ تصحيح: استخدام withAlpha بدلاً من withOpacity المهمل ⭐️
                color: _withAlpha(Theme.of(context).shadowColor, 0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // رسالة الحالة
                if (_message != null && _message!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // ⭐️ تصحيح: استخدام withAlpha بدلاً من withOpacity المهمل ⭐️
                        color: _withAlpha(messageColor, 0.1),
                        border: Border.all(color: messageColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: messageColor, fontSize: 16),
                      ),
                    ),
                  ),

                // 1. القسم الرئيسي (Items Type: SelectItemModel, Value Type: String ID)
                // 🛠️ تم التعديل لاستخدام CustomSelectBox<T, V>
                CustomSelectBox<SelectItemModel, String>(
                  label: 'القسم الرئيسي:',
                  hintText: 'اختر قسماً رئيسياً',
                  items: _mainCategories,
                  // القيمة المختارة هي الـ ID المخزنة في حالة الـ String
                  selectedValue: _selectedMainCategoryId,
                  itemLabel: (item) => item.name,
                  // نستخدم itemValueGetter لاستخراج الـ ID الذي سيتم تمريره كـ Value في القائمة المنسدلة
                  itemValueGetter: (item) => item.id,
                  onChanged: (String? id) {
                    setState(() {
                      _selectedMainCategoryId = id; // الآن نستقبل ID مباشرة

                      // إعادة تعيين الحالات الفرعية
                      _selectedSubCategoryId = null;
                      _selectedProductId = null;
                      _selectedUnitName = null;
                      _subCategories = [];
                      _products = [];
                      _availableUnits = [];

                      if (_selectedMainCategoryId != null) _loadSubCategories(_selectedMainCategoryId!);
                    });
                  },
                ),

                // 2. القسم الفرعي
                // 🛠️ تم التعديل لاستخدام CustomSelectBox<T, V>
                CustomSelectBox<SelectItemModel, String>(
                  label: 'القسم الفرعي:',
                  hintText: (selectedMainCategory == null) ? 'الرجاء اختيار القسم الرئيسي أولاً' : 'اختر قسماً فرعياً',
                  items: _subCategories,
                  selectedValue: _selectedSubCategoryId, // القيمة المختارة هي الـ ID
                  itemLabel: (item) => item.name,
                  itemValueGetter: (item) => item.id,
                  // 🛑 التصحيح 1: استبدال null بدالة فارغة (String? id) {}
                  onChanged: (_subCategories.isEmpty)
                      ? (String? id) {} // 💡 دالة فارغة لتجنب خطأ النوع
                      : (String? id) { // الآن نستقبل ID مباشرة
                          setState(() {
                            _selectedSubCategoryId = id;

                            _selectedProductId = null;
                            _products = [];
                            _availableUnits = [];

                            if (_selectedSubCategoryId != null) _loadProducts(_selectedSubCategoryId!);
                          });
                        },
                ),

                // 3. المنتج
                // 🛠️ تم التعديل لاستخدام CustomSelectBox<T, V>
                CustomSelectBox<SelectItemModel, String>(
                  label: 'المنتج:',
                  hintText: (selectedSubCategory == null) ? 'الرجاء اختيار القسم الفرعي أولاً' : 'اختر منتجاً',
                  items: _products,
                  selectedValue: _selectedProductId, // القيمة المختارة هي الـ ID
                  itemLabel: (item) => item.name,
                  itemValueGetter: (item) => item.id,
                  // 🛑 التصحيح 2: استبدال null بدالة فارغة (String? id) {}
                  onChanged: (_products.isEmpty)
                      ? (String? id) {} // 💡 دالة فارغة لتجنب خطأ النوع
                      : (String? id) { // الآن نستقبل ID مباشرة
                          setState(() {
                            _selectedProductId = id;

                            if (_selectedProductId != null) _loadAvailableUnits(_selectedProductId!);
                          });
                        },
                ),

                // 4. الوحدة المتاحة (هنا نستخدم String كـ T و V)
                // 🛠️ تم التعديل لاستخدام CustomSelectBox<T, V> (حيث T=V=String)
                CustomSelectBox<String, String>(
                  label: 'الوحدة المتاحة لهذا الصنف:',
                  hintText: (selectedProduct == null) ? 'الرجاء اختيار المنتج أولاً' : (_availableUnits.isEmpty ? 'لا توجد وحدات متاحة لإضافة عرض' : 'اختر وحدة'),
                  items: _availableUnits,
                  selectedValue: _selectedUnitName,
                  itemLabel: (item) => item,
                  // لا حاجة لـ itemValueGetter لأن T و V هما String
                  // 🛑 التصحيح 3: استبدال null بدالة فارغة (String? value) {}
                  onChanged: (_availableUnits.isEmpty)
                      ? (String? value) {} // 💡 دالة فارغة لتجنب خطأ النوع
                      : (String? value) {
                          setState(() => _selectedUnitName = value);
                        },
                ),

                // 5. السعر
                CustomInputField(
                  label: 'السعر (لكل وحدة مختارة):',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  hintText: 'مثال: 15.50',
                  validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) ? 'الرجاء إدخال سعر صحيح.' : null,
                ),

                // 6. الكمية
                CustomInputField(
                  label: 'الكمية المتاحة للبيع:',
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  hintText: 'مثال: 100',
                  validator: (value) => (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) ? 'الرجاء إدخال كمية صحيحة.' : null,
                ),

                // 7. الحد الأدنى للطلب
                CustomInputField(
                  label: 'الحد الأدنى للطلب لهذا الصنف (اختياري):',
                  controller: _minOrderController,
                  keyboardType: TextInputType.number,
                  hintText: 'مثال: 5',
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (int.tryParse(value) == null || int.parse(value) <= 0) return 'الرجاء إدخال قيمة صحيحة أو ترك الحقل فارغاً.';
                    return null;
                  }
                ),

                // 8. الحد الأقصى للطلب
                CustomInputField(
                  label: 'الحد الأقصى للطلب لهذا الصنف (اختياري):',
                  controller: _maxOrderController,
                  keyboardType: TextInputType.number,
                  hintText: 'مثال: 50',
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (int.tryParse(value) == null || int.parse(value) <= 0) return 'الرجاء إدخال قيمة صحيحة أو ترك الحقل فارغاً.';
                    return null;
                  }
                ),

                const SizedBox(height: 30),

                // زر الإرسال
                ElevatedButton.icon(
                  onPressed: _submitOffer,
                  icon: const Icon(Icons.add_circle_outline, size: 24, color: Colors.white),
                  label: const Text('إضافة العرض', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
