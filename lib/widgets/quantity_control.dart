// المسار: lib/widgets/quantity_control.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // 💡 استدعاء Google Fonts

class QuantityControl extends StatefulWidget {
  final int initialQuantity;
  final int minQuantity;
  final int maxStock;
  final ValueChanged<int> onQuantityChanged;
  final bool isDisabled;

  const QuantityControl({
    super.key,
    required this.initialQuantity,
    required this.minQuantity,
    required this.maxStock,
    required this.onQuantityChanged,
    this.isDisabled = false,
  });

  @override
  State<QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<QuantityControl> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
    // التأكد من تطبيق المنطق الأولي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQuantity(widget.initialQuantity);
    });
  }

  @override
  void didUpdateWidget(covariant QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity || oldWidget.maxStock != widget.maxStock || oldWidget.minQuantity != widget.minQuantity) {
      _updateQuantity(widget.initialQuantity);
    }
  }

  void _updateQuantity(int newQty) {
    int max = widget.maxStock;
    int min = widget.minQuantity;
    int calculatedQty = newQty;

    if (calculatedQty > max || max == 0 || widget.isDisabled) {
      calculatedQty = 0;
    } else if (calculatedQty < min) {
      calculatedQty = min;
    }

    if (_quantity != calculatedQty) {
      setState(() {
        _quantity = calculatedQty;
      });
      widget.onQuantityChanged(calculatedQty);
    }
  }

  void _increment() {
    if (_quantity < widget.maxStock && !widget.isDisabled) {
      _updateQuantity(_quantity + 1);
    }
  }

  void _decrement() {
    if (_quantity > widget.minQuantity && !widget.isDisabled) {
      _updateQuantity(_quantity - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canDecrease = _quantity > widget.minQuantity && !widget.isDisabled;
    final bool canIncrease = _quantity < widget.maxStock && !widget.isDisabled;
    final bool isZeroStock = widget.maxStock == 0 || widget.isDisabled;

    // 💡 [تحسين 1]: تغيير الـ Container ليكون شريحة موحدة بارزة (Pill Shape)
    return Container(
      decoration: BoxDecoration(
        color: isZeroStock ? Colors.grey.shade200 : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12), // زوايا دائرية أكبر وأكثر نعومة
        border: Border.all(color: Colors.grey.shade300, width: 1), // إطار خفيف
      ),
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max, // ملء العرض المتاح (لأن البطاقة كلها Double.infinity)
        children: [
          // 1. زر الإنقاص (-)
          // 💡 [تحسين 2]: تصميم زر الإنقاص كطرف للشريحة
          _buildButton(
            context,
            icon: MdiIcons.minus, // أيقونة Minus بسيطة
            onPressed: _decrement,
            isEnabled: canDecrease,
            isStart: true, // لتحديد الزاوية اليسرى
          ),

          // 2. قيمة الكمية (Text)
          Expanded( // استخدام Expanded لضمان أن الكمية تأخذ مساحة كافية في المنتصف
            child: Center(
              child: isZeroStock
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline, // أيقونة خطأ واضحة
                            size: 16,
                            color: Colors.red.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'غير متوفر',
                            // 💡 [تحسين 3]: استخدام Google Fonts للخط
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      '$_quantity',
                      // 💡 [تحسين 4]: استخدام خط أغمق وأكثر وضوحاً
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
            ),
          ),

          // 3. زر الزيادة (+)
          // 💡 [تحسين 2]: تصميم زر الزيادة كطرف للشريحة
          _buildButton(
            context,
            icon: MdiIcons.plus, // أيقونة Plus بسيطة
            onPressed: _increment,
            isEnabled: canIncrease,
            isStart: false, // لتحديد الزاوية اليمنى
          ),
        ],
      ),
    );
  }

  // 💡 دالة بناء الأزرار بتصميم موحد مع الـ Container
  Widget _buildButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback onPressed,
        required bool isEnabled,
        required bool isStart, // لتحديد إذا كان الزر هو الأول (للإنقاص)
      }) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color disabledColor = Colors.grey.shade400;

    // 💡 [تحسين 5]: استخدام ClipRRect لتحديد شكل الزر عند الزوايا
    return ClipRRect(
      borderRadius: isStart
          ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
          : const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
      child: Material(
        color: isEnabled ? primaryColor : Colors.grey.shade300, // لون خلفية للزر
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          child: SizedBox(
            width: 45, // عرض ثابت للزر
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: isEnabled ? Colors.white : disabledColor.withOpacity(0.8), // لون الأيقونة
            ),
          ),
        ),
      ),
    );
  }
}
