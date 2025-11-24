// المسار: lib/widgets/home_sections_grid.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 💡 تعريف الكلاس HomeSectionsGrid بشكل صحيح.
class HomeSectionsGrid extends StatelessWidget {
  const HomeSectionsGrid({super.key});

  // نموذج بيانات وهمي للأقسام
  static const List<Map<String, dynamic>> sections = [
    {'name': 'المتاجر القريبة', 'icon': LucideIcons.mapPin, 'color': Color(0xFF42a5f5), 'route': '/storesNearMe'},
    {'name': 'عروض وتخفيضات', 'icon': LucideIcons.tags, 'color': Color(0xFFf57c00), 'route': '/offers'},
    {'name': 'سجل المشتريات', 'icon': LucideIcons.history, 'color': Color(0xFF6d4c41), 'route': '/orders'},
    {'name': 'أقسام أخرى', 'icon': LucideIcons.grid, 'color': Color(0xFF66bb6a), 'route': '/categories'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sections.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5, // لجعل الخلايا مستطيلة ومناسبة للموبايل
        ),
        itemBuilder: (context, index) {
          final section = sections[index];
          return _SectionCard(
            name: section['name'],
            icon: section['icon'],
            color: section['color'],
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('الذهاب إلى: ${section['name']}')),
              );
              // يمكنك استخدام Navigator.of(context).pushNamed(section['route']) هنا
            },
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SectionCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // النص
            Expanded(
              child: Text(
                name,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // الأيقونة
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
