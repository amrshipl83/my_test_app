import 'package:flutter/material.dart';
import '../widgets/order_bubble.dart';
import '../main.dart'; // لاستخدام الـ navigatorKey

class BubbleService {
  static OverlayEntry? _overlayEntry;

  // دالة إظهار الفقاعة
  static void show(String orderId) {
    // إذا كانت الفقاعة موجودة بالفعل، لا تفعل شيئاً
    if (_overlayEntry != null) return;

    // الحصول على الـ Overlay من الـ navigatorKey العالمي
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => OrderBubble(orderId: orderId),
    );

    overlay.insert(_overlayEntry!);
  }

  // دالة إخفاء الفقاعة
  static void hide() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
}

