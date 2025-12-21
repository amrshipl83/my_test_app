import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../screens/customer_tracking_screen.dart';
// 🎯 استيراد الـ main للوصول للـ notifier
import '../main.dart'; 

class OrderBubble extends StatefulWidget {
  final String orderId;
  const OrderBubble({super.key, required this.orderId});

  @override
  State<OrderBubble> createState() => _OrderBubbleState();
}

class _OrderBubbleState extends State<OrderBubble> with SingleTickerProviderStateMixin {
  Offset position = Offset(80.w, 70.h);
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 🎯 تعديل دالة المسح لتعمل مع الـ Notifier العالمي
  Future<void> _clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_special_order_id');
    
    // إبلاغ الـ main.dart فوراً ليقوم بإزالة الـ Widget من الـ Stack
    activeOrderNotifier.value = null; 
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        // إذا لم توجد بيانات، نبلغ الـ Notifier بالمسح ونختفي
        if (!snapshot.hasData || !snapshot.data!.exists) {
           return const SizedBox.shrink();
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';

        // إذا اكتمل الطلب، نقوم بإخفاء الفقاعة ومسح المعرف
        if (status == 'delivered') {
          // نستخدم Future.microtask لتجنب أخطاء الـ Rebuild أثناء الـ build
          Future.microtask(() => _clearOrder());
          return const SizedBox.shrink();
        }

        bool isAccepted = status != 'pending';

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 100),
          left: position.dx,
          top: position.dy,
          // 🎯 إضافة Material هنا لضمان عدم حدوث خطأ في الثيم داخل الـ Stack العالمي
          child: Material(
            type: MaterialType.transparency,
            child: Draggable(
              feedback: _buildBubbleUI(isAccepted, true),
              childWhenDragging: const SizedBox.shrink(),
              onDragEnd: (details) {
                setState(() {
                  position = Offset(
                    details.offset.dx.clamp(5.w, 82.w),
                    details.offset.dy.clamp(10.h, 85.h),
                  );
                });
              },
              child: GestureDetector(
                onTap: () => _openOrderTracking(context, widget.orderId),
                onLongPress: () {
                  _showOptionsDialog(context);
                },
                child: isAccepted
                    ? _buildBubbleUI(isAccepted, false)
                    : ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                        child: _buildBubbleUI(isAccepted, false),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إخفاء التتبع؟"),
        content: const Text("هل تريد إخفاء فقاعة التتبع؟ لن يتم إلغاء الطلب."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              _clearOrder();
              Navigator.pop(ctx);
            },
            child: const Text("إخفاء", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleUI(bool isAccepted, bool isDragging) {
    return Container(
      width: 16.w,
      height: 16.w,
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green[700] : Colors.orange[900],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? Colors.green : Colors.orange).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAccepted ? Icons.delivery_dining : Icons.search,
            color: Colors.white,
            size: 20.sp,
          ),
          if (!isAccepted)
            Text(
              "بحث..",
              style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  void _openOrderTracking(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerTrackingScreen(orderId: id),
      ),
    );
  }
}

