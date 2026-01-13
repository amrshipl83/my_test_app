// lib/screens/delivery/delivery_offers_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/models/product_offer.dart';

import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';

enum MessageType { success, error, info }

class DeliveryOffersScreen extends StatefulWidget {
  static const routeName = '/delivery-offers';
  const DeliveryOffersScreen({super.key});

  @override
  State<DeliveryOffersScreen> createState() => _DeliveryOffersScreenState();
}

class _DeliveryOffersScreenState extends State<DeliveryOffersScreen> {
  String? _statusMessage;
  MessageType _messageType = MessageType.info;
  String _searchTerm = '';
  String _currentUserId = '';
  String _welcomeMessage = 'جاري التحقق من الهوية...';

  @override
  void initState() {
    super.initState();
    // استخدام Microtask لضمان أن الـ Context جاهز قبل مناداة البروفايدر
    Future.microtask(() => _loadUserInfoAndFetchOffers());
  }

  Future<void> _loadUserInfoAndFetchOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedUserString = prefs.getString('loggedUser');
    
    if (!mounted) return;
    final provider = Provider.of<ProductOfferProvider>(context, listen: false);

    if (loggedUserString != null) {
      try {
        final loggedUser = LoggedInUser.fromJson(jsonDecode(loggedUserString));
        if (loggedUser.id != null) {
          _currentUserId = loggedUser.id!;

          // تأمين جلب البيانات الأساسية
          await provider.initializeData(_currentUserId);

          if (mounted) {
            setState(() {
              _welcomeMessage = 'أهلاً بك، ${loggedUser.fullname ?? 'تاجرنا'}';
              _setStatusMessage('جاري تحديث قائمة العروض...', MessageType.info);
            });
          }

          await provider.fetchOffers(_currentUserId);
        }
      } catch (e) {
        _setStatusMessage('خطأ في البيانات: $e', MessageType.error);
      }
    }
  }

  void _setStatusMessage(String message, MessageType type) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _messageType = type;
    });
    // إخفاء تلقائي للرسالة
    if (type != MessageType.info) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _statusMessage = null);
      });
    }
  }

  // ----------------------------------------------------------------
  // حماية الحذف والتعديل
  // ----------------------------------------------------------------

  Future<void> _deleteOffer(String offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('تأكيد الحذف', textAlign: TextAlign.right),
        content: const Text('هل تريد إزالة هذا المنتج من قائمة أسعارك؟', textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<ProductOfferProvider>(context, listen: false).deleteOffer(offerId);
        _setStatusMessage('تم الحذف بنجاح', MessageType.success);
      } catch (e) {
        _setStatusMessage('فشل الحذف: $e', MessageType.error);
      }
    }
  }

  // ----------------------------------------------------------------
  // بناء الواجهة مع تأمين الجدول
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قائمة الأسعار'),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: Consumer<ProductOfferProvider>(
        builder: (context, provider, child) {
          final offers = provider.offers.where((o) {
            final name = o.productDetails.name.toLowerCase();
            return name.contains(_searchTerm.toLowerCase());
          }).toList();

          return Column(
            children: [
              if (_statusMessage != null) _buildMessageBox(),
              _buildTopHeader(),
              _buildSearchBar(),
              Expanded(
                child: provider.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : offers.isEmpty 
                    ? _buildEmptyState()
                    : _buildOffersTable(offers),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(_welcomeMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchTerm = v),
        decoration: InputDecoration(
          hintText: 'ابحث في منتجاتك...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildOffersTable(List<ProductOffer> offers) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 50,
          columns: const [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('الوحدات/السعر')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: offers.map((offer) => DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    if (offer.productDetails.imageUrls.isNotEmpty)
                      Image.network(offer.productDetails.imageUrls[0], width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.broken_image)),
                    const SizedBox(width: 8),
                    Text(offer.productDetails.name),
                  ],
                ),
              ),
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: offer.units.map((u) => Text('${u.unitName}: ${u.price}ج')).toList(),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.amber),
                      onPressed: () => _showEditPriceModal(offer, 0), // تعديل أول وحدة كمثال
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _deleteOffer(offer.id),
                    ),
                  ],
                ),
              ),
            ],
          )).toList(),
        ),
      ),
    );
  }

  // --- ميثود تعديل السعر الآمنة ---
  Future<void> _showEditPriceModal(ProductOffer offer, int index) async {
    final controller = TextEditingController(text: offer.units[index].price.toString());
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحديث سعر ${offer.units[index].unitName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'جنيه مصري'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && mounted) {
                await Provider.of<ProductOfferProvider>(context, listen: false).updateUnitPrice(
                  offerId: offer.id,
                  unitIndex: index,
                  newPrice: newPrice,
                );
                if (mounted) Navigator.pop(ctx);
                _setStatusMessage('تم تحديث السعر', MessageType.success);
              }
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: _messageType == MessageType.error ? Colors.red[100] : Colors.blue[100],
      child: Text(_statusMessage!, textAlign: TextAlign.center, style: TextStyle(color: _messageType == MessageType.error ? Colors.red[900] : Colors.blue[900])),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('لا توجد منتجات مطابقة للبحث'));
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, DeliveryMerchantDashboardScreen.routeName),
            icon: const Icon(Icons.dashboard),
            label: const Text('لوحة التحكم'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, BuyerHomeScreen.routeName),
            icon: const Icon(Icons.store),
            label: const Text('عرض المتجر'),
          ),
        ],
      ),
    );
  }
}
