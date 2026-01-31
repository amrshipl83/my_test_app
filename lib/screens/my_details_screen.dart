import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🟢 الألوان المعتمدة للهوية البصرية
const Color _primaryColor = Color(0xFF2c3e50);
const Color _accentColor = Color(0xFF4CAF50);
const Color _deleteColor = Color(0xFFE74C3C);

class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key});
  static const routeName = '/myDetails';

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;

  // المتحكمات لتعديل البيانات المسموحة
  late TextEditingController _nameController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // محاولة الجلب من المجموعتين
      DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection('consumers').doc(user.uid).get();
      String col = 'consumers';
      
      if (!docSnap.exists) {
        col = 'users';
        docSnap = await FirebaseFirestore.instance.collection(col).doc(user.uid).get();
      }

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        setState(() {
          _userData = data;
          _userData?['activeCollection'] = col;
          // تعبئة المتحكمات بالبيانات الحالية
          _nameController.text = data['fullname'] ?? data['name'] ?? '';
          _addressController.text = data['address'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 🟢 دالة التحديث الاحترافية (تعديل الاسم والعنوان فقط)
  Future<void> _updateProfile() async {
    setState(() => _isUpdating = true);
    final user = FirebaseAuth.instance.currentUser;
    final col = _userData?['activeCollection'];

    try {
      Map<String, dynamic> updates = {
        'address': _addressController.text.trim(),
      };
      
      // تحديث حقل الاسم حسب نوع المجموعة
      if (col == 'consumers') {
        updates['fullname'] = _nameController.text.trim();
      } else {
        updates['name'] = _nameController.text.trim();
      }

      await FirebaseFirestore.instance.collection(col).doc(user!.uid).update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث البيانات بنجاح'), backgroundColor: _accentColor),
      );
      _fetchProfile(); // إعادة الجلب للتأكيد
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل التحديث')));
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _accentColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 25),
                    _buildEditableSection(),
                    const SizedBox(height: 25),
                    _buildReadOnlySection(),
                    const SizedBox(height: 40),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  // 1. كارت الهوية (عرض النقاط والاسم الحالي)
  Widget _buildHeaderCard() {
    bool isConsumer = _userData?['activeCollection'] == 'consumers';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nameController.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (isConsumer)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('نقاط أكسب: ${_userData?['loyaltyPoints'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. قسم البيانات القابلة للتعديل
  Widget _buildEditableSection() {
    return _buildSectionContainer(
      title: 'بيانات مسموح بتعديلها',
      icon: Icons.edit_note,
      children: [
        _buildTextField('الاسم بالكامل', _nameController, Icons.person_outline),
        _buildTextField('العنوان المعتمد', _addressController, Icons.location_on_outlined),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updateProfile,
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: _isUpdating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // 3. قسم البيانات الثابتة (للعرض فقط)
  Widget _buildReadOnlySection() {
    return _buildSectionContainer(
      title: 'بيانات ثابتة (للأمان)',
      icon: Icons.lock_outline,
      children: [
        _buildReadOnlyField('رقم الهاتف (معرف الحساب)', _userData?['phone'] ?? 'غير متوفر', Icons.phone_android),
        _buildReadOnlyField('البريد الإلكتروني', _userData?['email'] ?? 'غير متوفر', Icons.alternate_email),
        _buildReadOnlyField('تاريخ الانضمام', _userData?['createdAt'] != null ? (_userData!['createdAt'] as Timestamp).toDate().toString().split(' ')[0] : 'غير متوفر', Icons.calendar_today),
      ],
    );
  }

  // 4. أزرار التحكم السفلى
  Widget _buildActionButtons() {
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => _showDeleteDialog(),
          icon: const Icon(Icons.no_accounts, color: _deleteColor),
          label: const Text('طلب إغلاق الحساب نهائياً', style: TextStyle(color: _deleteColor)),
        ),
        const SizedBox(height: 10),
        const Text('منصة أسواق أكسب - النسخة v2.0', style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  // --- Widgets مساعدة للتصميم الاحترافي ---

  Widget _buildSectionContainer({required String title, required IconData icon, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _primaryColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _accentColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من رغبتك في تعطيل الحساب؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: _deleteColor), child: const Text('تأكيد', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
