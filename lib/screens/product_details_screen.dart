// المسار: lib/screens/product_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

// 🎯 يجب تحديث هذه الشاشة لاستقبال المعرفات الصحيحة 
class ProductDetailsScreen extends StatefulWidget {
    // 🎯 [تصحيح الخطأ رقم 3]: إضافة المسار الثابت
    static const routeName = '/productDetails'; 

    // يمكن أن نستقبل productId أو OfferId أو كلاهما 
    final String? productId;
    final String? offerId; // يستخدم لتوجيه المستهلكين لعرض محدد

    const ProductDetailsScreen({
        super.key,
        required this.productId,
        this.offerId,
    });

    @override
    State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
    // بيانات المنتج الأساسية
    Map<String, dynamic>? _productData;
    // قائمة العروض المتاحة (لتاجر الجملة) أو عرض واحد (للمستهلك)
    List<Map<String, dynamic>> _offers = [];

    bool _isLoadingProduct = true;
    bool _isLoadingOffers = true;
    String? _errorMessage;

    @override
    void initState() {
        super.initState();
        _loadProductAndOffers();
    }

    // ----------------------------------------------------
    // 📡 منطق جلب بيانات البائع (Seller)
    // ----------------------------------------------------
    Future<Map<String, String>> _fetchSellerInfo(String sellerId) async {
        // نستخدم نفس المنطق الموجود في كود HTML
        String sellerName = 'تاجر غير معروف';
        String sellerLogo = ''; // أو رابط صورة افتراضية

        if (sellerId.isEmpty) return {'name': sellerName, 'logo': sellerLogo};

        try {
            final sellerDocSnap = await _db.collection('sellers').doc(sellerId).get();
            if (sellerDocSnap.exists && sellerDocSnap.data() != null) {
                final sellerData = sellerDocSnap.data()!;
                sellerName = sellerData['fullname'] as String? ?? sellerData['name'] as String? ?? sellerName;
                sellerLogo = sellerData['imageUrl'] as String? ?? sellerLogo;
            }
        } catch (e) {
            debugPrint('Error fetching seller $sellerId: $e');
        }
        return {'name': sellerName, 'logo': sellerLogo};
    }

    // ----------------------------------------------------
    // 🚀 دالة تحميل المنتج والعروض (مطابقة لمنطق HTML/JS)
    // ----------------------------------------------------
    Future<void> _loadProductAndOffers() async {
        if (widget.productId == null || widget.productId!.isEmpty) {
            setState(() {
                _errorMessage = 'لم يتم تحديد معرّف المنتج.';
                _isLoadingProduct = false;
            });
            return;
        }

        // 1. جلب بيانات المنتج الأساسية
        try {
            final productDocSnap = await _db.collection('products').doc(widget.productId!).get();

            if (!productDocSnap.exists || productDocSnap.data() == null) {
                setState(() {
                    _errorMessage = 'المنتج غير موجود.';
                    _isLoadingProduct = false;
                });
                return;
            }
            _productData = productDocSnap.data()!;
        } catch (e) {
            setState(() {
                _errorMessage = 'حدث خطأ أثناء جلب تفاصيل المنتج: $e';
                _isLoadingProduct = false;
            });
            return;
        } finally {
            setState(() {
                _isLoadingProduct = false;
            });
        }

        // 2. جلب العروض بناءً على دور المستخدم (باستخدام offerId كدلالة للمستهلك)
        if (widget.offerId != null && widget.offerId!.isNotEmpty) {
            await _loadSpecificConsumerOffer(widget.productId!, widget.offerId!);
        } else {
            await _loadAllOffers(widget.productId!);
        }
    }

    // ----------------------------------------------------
    // 💰 منطق جلب العروض المتعددة (لتاجر الجملة/المشتري)
    // ----------------------------------------------------
    Future<void> _loadAllOffers(String productId) async {
        try {
            // جلب جميع العروض المرتبطة بـ productId من مجموعة productOffers
            final offersQuery = _db.collection('productOffers')
                .where('productId', isEqualTo: productId);
            final offersSnapshot = await offersQuery.get();

            if (offersSnapshot.docs.isEmpty) {
                setState(() {
                    _isLoadingOffers = false;
                });
                return;
            }

            final List<Map<String, dynamic>> loadedOffers = [];

            // جلب معلومات البائع بالتزامن (لتحسين الأداء)
            final fetchPromises = offersSnapshot.docs.map((doc) async {
                // 🚀 التصحيح: التصريح الصريح بالنوع لـ doc.data() لحل خطأ "Object is not a Map"
                final data = doc.data() as Map<String, dynamic>;

                final sellerId = data['sellerId'] as String? ?? '';
                final sellerInfo = await _fetchSellerInfo(sellerId);

                // إعادة بناء العرض ليتضمن معلومات البائع
                return {
                    ...data,
                    'id': doc.id,
                    'sellerInfo': sellerInfo,
                    'isMarketOffer': false, // ليس عرض سوق محدد
                };
            }).toList();

            loadedOffers.addAll(await Future.wait(fetchPromises));

            setState(() {
                _offers = loadedOffers;
            });

        } catch (e) {
            debugPrint('Error loading all offers: $e');
        } finally {
            setState(() {
                _isLoadingOffers = false;
            });
        }
    }

    // ----------------------------------------------------
    // 🌟 منطق جلب العرض المحدد (للمستهلك)
    // ----------------------------------------------------
    Future<void> _loadSpecificConsumerOffer(String productId, String offerId) async {
        try {
            DocumentSnapshot? offerDocSnap;
            bool isMarketOffer = false;

            // 1. محاولة الجلب من 'marketOffer'
            final marketOfferRef = _db.collection('marketOffer').doc(offerId);
            offerDocSnap = await marketOfferRef.get();

            if (offerDocSnap.exists) {
                isMarketOffer = true;
            } else {
                // 2. محاولة الجلب من 'productOffers'
                final productOfferRef = _db.collection('productOffers').doc(offerId);
                offerDocSnap = await productOfferRef.get();
            }

            if (offerDocSnap.exists && offerDocSnap.data() != null) {
                // 🚀 التصحيح: التصريح الصريح بالنوع لـ offerDocSnap.data() لحل خطأ "Object is not a Map"
                final offerData = offerDocSnap.data()! as Map<String, dynamic>;
                final sellerId = offerData['sellerId'] as String? ?? '';
                final sellerInfo = await _fetchSellerInfo(sellerId);

                setState(() {
                    // نضيف العرض المحدد كعنصر وحيد في القائمة
                    _offers = [{
                        ...offerData,
                        'id': offerDocSnap!.id,
                        'sellerInfo': sellerInfo,
                        'isMarketOffer': isMarketOffer,
                    }];
                });
            }

        } catch (e) {
            debugPrint('Error loading specific consumer offer: $e');
        } finally {
            setState(() {
                _isLoadingOffers = false;
            });
        }
    }

    // ----------------------------------------------------
    // 🧱 أدوات البناء (Widgets)
    // ----------------------------------------------------

    // يُستخدم لعرض تفاصيل العرض الفردي
    Widget _buildOfferCard(Map<String, dynamic> offerData) {
        final sellerInfo = offerData['sellerInfo'] as Map<String, String>;
        final offerDocId = offerData['id'] as String;

        // يجب التعامل مع حقل الوحدات (units) هنا كما في كود HTML
        final unitsList = offerData['units'] as List<dynamic>?;
        final unitData = (unitsList != null && unitsList.isNotEmpty)
            ? unitsList.first : {
                'price': offerData['price'],
                'availableStock': offerData['availableQuantity'],
                'unitName': 'الكمية الأساسية'
            };

        final unitName = unitData['unitName'] as String? ?? 'الكمية الأساسية';
        final availableStock = unitData['availableStock'] as int? ?? 0;
        final price = unitData['price'] as num? ?? 0;
        final isAvailable = availableStock > 0;
        final displayPrice = '${price.toStringAsFixed(2)} جنيه';

        return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 15),
            child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        // معلومات التاجر
                        Row(
                            children: [
                                CircleAvatar(
                                    backgroundImage: sellerInfo['logo']!.isNotEmpty
                                        ? NetworkImage(sellerInfo['logo']!)
                                        : null,
                                    child: sellerInfo['logo']!.isEmpty ? const Icon(Icons.store) : null,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                    sellerInfo['name']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    textDirection: TextDirection.rtl,
                                ),
                            ],
                        ),
                        const Divider(height: 20),

                        // الوحدة والسعر
                        Text('الوحدة: $unitName', textAlign: TextAlign.right),
                        const SizedBox(height: 5),
                        Text(
                            displayPrice,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF388e3c), // Primary Dark Color
                            ),
                        ),
                        const SizedBox(height: 10),

                        // الكمية المتاحة
                        Text(
                            'المتاح: $availableStock وحدة',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 15),

                        // زر الإضافة للسلة
                        ElevatedButton.icon(
                            onPressed: isAvailable ? () {
                                // 💡 هنا سيكون منطق إضافة المنتج للسلة (addToCart)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تم إضافة ${unitName} من عرض ${offerDocId} إلى السلة.')),
                                );
                            } : null,
                            icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                            label: Text(isAvailable ? 'أضف للسلة' : 'نفذت الكمية', style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50), // Primary Color
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    // ----------------------------------------------------
    // 🖼️ بناء معرض الصور (بشكل مبسط الآن)
    // ----------------------------------------------------
    Widget _buildImageGallery(List<dynamic> imageUrls, String productName) {
        // يمكننا استخدام PageView.builder هنا كما في home_content.dart
        final imageUrl = imageUrls.isNotEmpty ? imageUrls.first as String : '';

        return Container(
            height: 300,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5)),
                ],
                border: Border.all(color: const Color(0xFF4CAF50), width: 4),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator(color: const Color(0xFF4CAF50)));
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                            child: Text('لا توجد صورة', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                    )
                    : Center(child: Text('لا توجد صور للمنتج', style: TextStyle(color: Colors.grey.shade600))),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoadingProduct) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ),
            );
        }

        if (_errorMessage != null) {
            return Scaffold(
                appBar: AppBar(title: const Text('خطأ')),
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                    ),
                ),
            );
        }

        // يجب أن يكون _productData موجود الآن
        final productName = _productData!['name'] as String? ?? 'منتج غير مُسمى';
        final productDescription = _productData!['description'] as String? ?? 'لا يوجد وصف متاح.';
        final imageUrls = _productData!['imageUrls'] as List<dynamic>? ?? [];


        return Scaffold(
            appBar: AppBar(
                title: Text(productName, textDirection: TextDirection.rtl),
                backgroundColor: const Color(0xFF4CAF50), // Top Header BG
                foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            // 1. معرض الصور
                            _buildImageGallery(imageUrls, productName),

                            // 2. اسم ووصف المنتج
                            Text(
                                productName,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 10),
                            Text(
                                productDescription,
                                textAlign: TextAlign.justify,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 30),

                            // 3. عنوان العروض
                            Container(
                                alignment: Alignment.centerRight,
                                child: Text(
                                    _offers.length > 1 ? 'جميع العروض المتاحة' : 'العرض المتاح',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4CAF50),
                                    ),
                                ),
                            ),
                            const SizedBox(height: 15),

                            // 4. قائمة العروض
                            _isLoadingOffers
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                                : _offers.isEmpty
                                    ? const Center(
                                        child: Text(
                                            'لا توجد عروض متاحة حالياً لهذا المنتج.',
                                            style: TextStyle(fontSize: 16, color: Colors.red),
                                            textDirection: TextDirection.rtl,
                                        ),
                                    )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _offers.length,
                                        itemBuilder: (context, index) {
                                            return _buildOfferCard(_offers[index]);
                                        },
                                    ),
                        ],
                    ),
                ),
            ),
        );
    }
}
