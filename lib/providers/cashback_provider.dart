// lib/providers/cashback_provider.dart

  Future<List<Map<String, dynamic>>> fetchCashbackGoals() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return [];

    try {
      final now = DateTime.now();
      
      // ✅ التعديل: الفلترة فقط على الحالة النشطة كما في الويب والجدول
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> goalsList = [];

      for (var docSnap in querySnapshot.docs) {
        final offer = docSnap.data();
        
        // جلب التاريخ وفحصه (نفس منطق الويب)
        if (offer['endDate'] == null) continue;
        final endDate = (offer['endDate'] as Timestamp).toDate();
        final startDate = (offer['startDate'] as Timestamp).toDate();

        // فحص الصلاحية الزمنية
        if (now.isBefore(startDate) || now.isAfter(endDate)) continue;

        // 🎯 مطابقة أسماء الحقول بدقة من جدولك (minPurchaseAmount)
        double minAmount = double.tryParse(offer['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        
        // التعامل مع goalBasis (لو فارغ في Firestore نعتبره تراكمي)
        String goalBasis = offer['goalBasis']?.toString().trim() ?? 'cumulative_spending';

        // --- هنا نضع منطق حساب المشتريات من الـ Orders كما فعلنا سابقاً ---
        // (الاستعلام على كولكشن orders بفلترة الـ buyer.id والـ status == 'delivered')
        
        // قيمة افتراضية للتقدم حتى نربط كود الـ Orders
        double finalProgressValue = 0.0; 
        
        // ... منطق الحساب يوضع هنا ...

        double progressPercentage = (finalProgressValue / minAmount) * 100;
        if (progressPercentage > 100) progressPercentage = 100;

        goalsList.add({
          'id': docSnap.id,
          'title': offer['description'] ?? 'هدف كاش باك',
          'minAmount': minAmount,
          'value': offer['value'],
          'type': offer['type'], // سيقرأ fixedAmount أو percentage
          'endDate': endDate,
          'goalBasis': goalBasis,
          'currentProgress': finalProgressValue,
          'progressPercentage': progressPercentage,
        });
      }
      return goalsList;
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }
