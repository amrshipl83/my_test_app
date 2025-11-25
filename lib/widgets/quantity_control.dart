// المسار: lib/widgets/quantity_control.dart
    
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
              
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
    _updateQuantity(widget.initialQuantity);
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
                                                    
    return Container(
      decoration: BoxDecoration(
        color: isZeroStock ? Colors.grey.shade100 : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. زر الإنقاص (-)
          _buildButton(
            context,
            icon: MdiIcons.minusCircle,
            onPressed: _decrement,
            isEnabled: canDecrease,
          ),

          // 2. قيمة الكمية (Text) 💡 التعديل لحل مشكلة Overflow نهائياً
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: isZeroStock
                ? FittedBox( // 💡💡 تغليف بـ FittedBox لضمان عدم Overflow وتصغير النص تلقائياً
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 14,
                          color: Colors.red.shade500 // لون أحمر معتدل
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'غير متوفر',
                          style: TextStyle(
                            fontSize: 14, // حجم أقل لمنع الـ Overflow
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700.withOpacity(0.8), // لون أقل حدة
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    '$_quantity',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
          ),
                                    
          // 3. زر الزيادة (+)
          _buildButton(
            context,
            icon: MdiIcons.plusCircle,
            onPressed: _increment,
            isEnabled: canIncrease,
          ),
        ],
      ),
    );
  }

  // 💡 دالة بناء الأزرار بتصميم دائري ومحسن (كما كانت في التعديل السابق)
  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required bool isEnabled,
  }) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color disabledColor = Colors.grey.shade400;
                                            
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Icon(
          icon,
          size: 30,
          color: isEnabled ? primaryColor : disabledColor,
        ),
      ),
    );
  }
}
