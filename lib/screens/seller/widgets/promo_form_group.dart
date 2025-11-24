// lib/screens/seller/widgets/promo_form_group.dart

import 'package:flutter/material.dart';

// الـ Widget المساعد الذي كان يسمى _buildFormGroup
class PromoFormGroup extends StatelessWidget {
  final String label;
  final Widget child;
  final BoxDecoration? groupStyle;
  final bool isLastInGroup;

  const PromoFormGroup({
    super.key,
    required this.label,
    required this.child,
    this.groupStyle,
    this.isLastInGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      // 🚨 نستخدم نفس منطق الـ BorderStyle.solid المُصحح 🚨
      decoration: groupStyle ?? BoxDecoration(
        border: Border(
          bottom: isLastInGroup
              ? BorderSide.none
              : const BorderSide(
                  color: Color(0xffe9ecef), 
                  style: BorderStyle.solid, 
                ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 17.0,
              color: Color(0xff343a30),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8.0),
          child,
        ],
      ),
    );
  }
}
