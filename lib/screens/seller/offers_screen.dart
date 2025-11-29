// lib/screens/seller/offers_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/data_sources/offer_data_source.dart';
import 'package:my_test_app/models/offer_model.dart';
import 'package:my_test_app/widgets/form_widgets.dart'; // افترض أن هذا هو مكان الـ CustomInputField والـ CustomSelectBox

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final OfferDataSource _dataSource = OfferDataSource();
  final String? _currentSellerId = FirebaseAuth.instance.currentUser?.uid;

  List<ProductOfferModel> _allOffers = [];
  List<ProductOfferModel> _filteredOffers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchTerm = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    if (_currentSellerId != null) {
      _loadOffers();
    } else {
      _errorMessage = 'يجب تسجيل الدخول كبائع لعرض العروض.';
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offers = await _dataSource.loadSellerOffers(_currentSellerId!);
      _allOffers = offers;
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOffers = _allOffers.where((offer) {
        final matchesSearch = (offer.productName.toLowerCase().contains(_searchTerm.toLowerCase()));
        final matchesStatus = _statusFilter.isEmpty || (offer.status == _statusFilter);
        return matchesSearch && matchesStatus;
      }).toList();
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchTerm = value;
    _applyFilters();
  }

  // التصحيح الوظيفي: تقبل dynamic من CustomSelectBox
  void _onStatusFilterChanged(dynamic value) {
    _statusFilter = (value as String?) ?? '';
    _applyFilters();
  }

  void _showEditModal(ProductOfferModel offer) {
    showDialog(
      context: context,
      builder: (context) => _EditOfferModal(
        offer: offer,
        dataSource: _dataSource,
        onUpdateSuccess: _loadOffers, // سيتم استدعاؤها بعد التعديل أو الحذف
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Page Header and Actions (تم تحسين التصميم)
              _buildPageHeader(context),

              const SizedBox(height: 20),

              // 2. Filter Section
              _buildFilterSection(context),

              const SizedBox(height: 20),

              // 3. Offers Table (الآن هي قائمة بطاقات)
              _buildOffersTableContainer(),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐️ دالة مُعدَّلة لتحسين التصميم وإصلاح التجاوز ⭐️
  Widget _buildPageHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // عنوان الصفحة
          Text(
            'عروضي',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary, // لون أساسي للعناوين
            ),
          ),
          Row(
            children: [
              // زر تصدير إلى إكسل (ثانوي)
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تصدير العروض إلى إكسل...')));
                },
                icon: const Icon(Icons.file_download),
                label: const Text('تصدير إكسل'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
                ),
              ),
              const SizedBox(width: 10),
              // زر إنشاء عرض جديد (أساسي)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/seller/add-offer');
                },
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text('إنشاء عرض جديد', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حقل البحث
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: CustomInputField(
                  label: 'بحث:',
                  controller: TextEditingController(text: _searchTerm),
                  keyboardType: TextInputType.text,
                  hintText: 'ابحث باسم المنتج',
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            // فلتر الحالة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: SizedBox(
                width: 150,
                // التصحيح: تم تغيير CustomSelectBox<String> إلى CustomSelectBox<String, String>
                child: CustomSelectBox<String, String>(
                  label: 'الحالة:',
                  hintText: 'الكل',
                  items: const ['active', 'inactive'],
                  selectedValue: _statusFilter.isEmpty ? null : _statusFilter,
                  itemLabel: (item) => item == 'active' ? 'نشط' : 'غير نشط',
                  onChanged: _onStatusFilterChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTableContainer() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text('خطأ في تحميل العروض: $_errorMessage', style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    if (_filteredOffers.isEmpty) {
      return const Center(child: Text('لا توجد عروض متاحة حالياً.', style: TextStyle(fontSize: 18)));
    }

    // الآن نعرض قائمة من البطاقات المُنظَّمة عمودياً
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredOffers.length,
      itemBuilder: (context, index) {
        final offer = _filteredOffers[index];
        return _OfferItemCard(
          offer: offer,
          onViewDetails: _showEditModal, // نستخدم onEdit القديمة كدالة لعرض التفاصيل
        );
      },
    );
  }
}

// ----------------------------------------------------
// 💡 ويدجت لعرض البطاقة المُصغَّرة (Compact Card) - مُحسَّن التصميم والمُصحَّح
// ----------------------------------------------------
class _OfferItemCard extends StatelessWidget {
  final ProductOfferModel offer;
  final Function(ProductOfferModel) onViewDetails;
  const _OfferItemCard({
    required this.offer,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final availableStock = offer.units.isNotEmpty ? offer.units[0].availableStock : 0;
    final isLowStock = availableStock <= (offer.lowStockThreshold ?? 0) && (offer.lowStockThreshold ?? 0) > 0;

    final priceValue = offer.units.isNotEmpty ? offer.units[0].price.toStringAsFixed(2) : 'N/A';
    final unitName = offer.units.isNotEmpty ? offer.units[0].unitName : 'وحدة';
    
    // ⭐️ تصحيح خطأ الصورة: توفير رابط احتياطي في حالة القيمة الفارغة (null) ⭐️
    final String imageUrl = offer.imageUrl ?? 'https://via.placeholder.com/70?text=No+Image';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // زيادة استدارة الحواف
        side: isLowStock ? BorderSide(color: Theme.of(context).colorScheme.error, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => onViewDetails(offer),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. الصورة (أكبر قليلاً)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  // ⭐️ استخدام المتغير المصحح imageUrl ⭐️
                  imageUrl,
                  width: 70, // تم تكبير الصورة
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              // 2. تفاصيل المنتج الرئيسية (الاسم، السعر، المخزون)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج (أكثر بروزاً)
                    Text(
                      offer.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // السعر والوحدة (أكثر بروزاً ولون أساسي)
                    Row(
                      children: [
                        Icon(Icons.payments, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          '$priceValue ج.م / $unitName',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // المخزون المتاح
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: isLowStock ? Theme.of(context).colorScheme.error : Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Text(
                          'المخزون: ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                        Text(
                          availableStock.toString(),
                          style: TextStyle(
                            color: isLowStock ? Theme.of(context).colorScheme.error : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. الحالة (Badge)
              _buildStatusBadge(context, offer.status),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لبناء شارة الحالة
  Widget _buildStatusBadge(BuildContext context, String status) {
    final bool isActive = status == 'active';
    final Color color = isActive ? Colors.green : Colors.grey;
    final String text = isActive ? 'نشط' : 'غير نشط';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // زيادة حجم الـ Padding
      decoration: BoxDecoration(
        color: Color(color.value).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(color.value).withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), // زيادة حجم الخط
      ),
    );
  }
}

// ----------------------------------------------------
// 💡 ويدجت نافذة التفاصيل/التعديل (_EditOfferModal)
// ----------------------------------------------------
class _EditOfferModal extends StatefulWidget {
  final ProductOfferModel offer;
  final OfferDataSource dataSource;
  final VoidCallback onUpdateSuccess;
  const _EditOfferModal({
    required this.offer,
    required this.dataSource,
    required this.onUpdateSuccess,
  });

  @override
  __EditOfferModalState createState() => __EditOfferModalState();
}

class __EditOfferModalState extends State<_EditOfferModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxOrderController;
  late String _status;

  late List<Map<String, dynamic>> _unitsToEdit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialStock = widget.offer.units.isNotEmpty ? widget.offer.units[0].availableStock : 0;
    _stockController = TextEditingController(text: initialStock.toString());
    _thresholdController = TextEditingController(text: (widget.offer.lowStockThreshold ?? 0).toString());
    _minOrderController = TextEditingController(text: (widget.offer.minOrder ?? '').toString());
    _maxOrderController = TextEditingController(text: (widget.offer.maxOrder ?? '').toString());
    _status = widget.offer.status;

    _unitsToEdit = widget.offer.units.map((unit) => {
      'unitName': unit.unitName,
      'price': unit.price.toString(),
      'availableStock': unit.availableStock.toString(),
    }).toList();

    if (_unitsToEdit.isEmpty) {
      _unitsToEdit.add({'unitName': 'افتراضي', 'price': '', 'availableStock': '0'});
    }
  }

  void _addUnit() {
    setState(() {
      _unitsToEdit.add({'unitName': '', 'price': '', 'availableStock': '0'});
    });
  }

  void _removeUnit(int index) {
    if (_unitsToEdit.length > 1) {
      setState(() {
        _unitsToEdit.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب أن يكون هناك وحدة سعر واحدة على الأقل.')));
    }
  }

  Future<void> _handleSave() async {
    // ... (منطق الحفظ يبقى كما هو)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_unitsToEdit.any((u) => u['unitName'].isEmpty || double.tryParse(u['price'] ?? '') == null || double.parse(u['price'] ?? '') <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء التأكد من صحة جميع حقول اسم الوحدة والسعر (أكبر من صفر).')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newStock = int.parse(_stockController.text);

      final newThreshold = int.parse(_thresholdController.text);
      final minOrderValue = _minOrderController.text.trim();
      final maxOrderValue = _maxOrderController.text.trim();
      final newMinOrder = minOrderValue.isNotEmpty ? int.tryParse(minOrderValue) : null;
      final newMaxOrder = maxOrderValue.isNotEmpty ? int.tryParse(maxOrderValue) : null;

      // 1. بناء قائمة الوحدات النهائية (Units)
      final finalUnits = _unitsToEdit.asMap().entries.map((entry) {
        final index = entry.key;
        final map = entry.value;

        // فقط الوحدة الرئيسية (index 0) هي التي تتحكم في المخزون الرئيسي الذي تم تعديله في الحقل العلوي
        final stock = (index == 0)
            ? newStock
            : (int.tryParse(map['availableStock'] ?? '0') ?? 0);

        return OfferUnitModel(
          unitName: map['unitName']!,
          price: double.parse(map['price']!),
          availableStock: stock,
        );
      }).toList();

      // 2. بناء بيانات التحديث (Update Data)
      final Map<String, dynamic> updateData = {
        'units': finalUnits.map((u) => u.toJson()).toList(),
        'status': _status,
        'lowStockThreshold': newThreshold,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3. إدارة الحدود (Min/Max Order)
      if (newMinOrder != null && newMinOrder >= 1) {
        updateData['minOrder'] = newMinOrder;
      } else {
        updateData['minOrder'] = FieldValue.delete();
      }

      if (newMaxOrder != null && newMaxOrder >= 1) {
        updateData['maxOrder'] = newMaxOrder;
      } else {
        updateData['maxOrder'] = FieldValue.delete();
      }

      await widget.dataSource.updateOffer(widget.offer.id!, updateData);

      widget.onUpdateSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات بنجاح!')));
      }
    } catch (e) {
      debugPrint('Error updating offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء حفظ التعديلات: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // إضافة دالة الحذف
  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد أنك تريد حذف العرض للمنتج: ${widget.offer.productName}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.dataSource.deleteOffer(widget.offer.id!);
        widget.onUpdateSuccess();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العرض بنجاح!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _stockController.dispose();
    _thresholdController.dispose();
    _minOrderController.dispose();
    _maxOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تفاصيل/تعديل العرض - ${widget.offer.productName}', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. اسم المنتج (للقراءة فقط)
              _buildReadOnlyField('اسم المنتج:', widget.offer.productName),

              const SizedBox(height: 15),
              Text('تفاصيل الأسعار والوحدات:', style: Theme.of(context).textTheme.titleSmall),
              const Divider(),

              // 2. الوحدات الديناميكية (Units Container)
              _buildUnitsContainer(),

              // 3. زر إضافة وحدة جديدة
              TextButton.icon(
                onPressed: _addUnit,
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                label: const Text('إضافة وحدة سعر جديدة', style: TextStyle(color: Colors.blue)),
              ),

              const SizedBox(height: 15),

              // 4. الكمية المتاحة للمبيعات (Stock)
              CustomInputField(
                label: 'الكمية المتاحة للمبيعات (للوحدة الرئيسية):',
                controller: _stockController,
                keyboardType: TextInputType.number,
                hintText: 'مثال: 100',
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'الرجاء إدخال كمية صحيحة (صفر أو أكبر).';
                  }
                  return null;
                },
              ),

              // 5. حد التحذير لانخفاض المخزون
              CustomInputField(
                label: 'حد التحذير لانخفاض المخزون:',
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                hintText: 'مثال: نبّهني إذا وصل الرصيد إلى 20',
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'الرجاء إدخال حد صحيح (صفر أو أكبر).';
                  }
                  return null;
                },
              ),

              // 6. الحد الأدنى للطلب
              CustomInputField(
                label: 'الحد الأدنى للطلب (اختياري):',
                controller: _minOrderController,
                keyboardType: TextInputType.number,
                hintText: 'الحد الأدنى لكمية الصنف الواحد',
              ),

              // 7. الحد الأقصى للطلب
              CustomInputField(
                label: 'الحد الأقصى للطلب (اختياري):',
                controller: _maxOrderController,
                keyboardType: TextInputType.number,
                hintText: 'الحد الأقصى لكمية الصنف الواحد',
              ),

              // 8. الحالة
              // التصحيح: تم تغيير CustomSelectBox<String> إلى CustomSelectBox<String, String>
              CustomSelectBox<String, String>(
                label: 'الحالة:',
                hintText: 'اختر الحالة',
                items: const ['active', 'inactive'],
                selectedValue: _status,
                itemLabel: (item) => item == 'active' ? 'نشط' : 'غير نشط',
                onChanged: (dynamic value) {
                  if (value != null) {
                    setState(() => _status = value as String);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        // زر الحذف الآن داخل النافذة المنبثقة
        TextButton(
          onPressed: _handleDelete,
          child: const Text('حذف العرض', style: TextStyle(color: Colors.red)),
        ),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التغييرات'),
        ),
      ],
      clipBehavior: Clip.hardEdge,
    );
  }

  // ويدجت مساعد لحقول القراءة فقط
  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        // تصحيح deprecated_member_use في _EditOfferModal
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).disabledColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          width: double.infinity,
          child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }

  // ويدجت مساعد لعرض الوحدات الديناميكية (مُحسَّن)
  Widget _buildUnitsContainer() {
    return Column(
      children: List.generate(_unitsToEdit.length, (index) {
        final unit = _unitsToEdit[index];
        final isRemovable = _unitsToEdit.length > 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // حقل اسم الوحدة
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextFormField(
                    initialValue: unit['unitName'],
                    decoration: const InputDecoration(labelText: 'اسم الوحدة'),
                    onChanged: (value) => unit['unitName'] = value,
                    validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
                  ),
                ),
              ),
              // حقل السعر
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: TextFormField(
                    initialValue: unit['price'],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر'),
                    onChanged: (value) => unit['price'] = value,
                    validator: (value) => (value == null || double.tryParse(value) == null || double.parse(value) <= 0) ? 'سعر صحيح' : null,
                  ),
                ),
              ),
              // زر الحذف
              if (isRemovable)
                Container(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeUnit(index),
                    tooltip: 'حذف الوحدة',
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
