// lib/screens/search/search_screen.dart             
import 'package:flutter/material.dart';              
import 'package:cloud_firestore/cloud_firestore.dart';                                                    
import 'package:provider/provider.dart';             
import 'dart:async'; // نحتاجها في حال استخدام Debounce                                                                                                        
// ✅ الاستيراد الصحيح لـ UserRole                   
import 'package:my_test_app/models/user_role.dart';  
// ✅ الاستيراد الصحيح لـ CategoryModel (يجب أن يبقى)
import 'package:my_test_app/models/category_model.dart';                                                  
// ✅ التعديل لحل التعارض: استيراد ProductModel وإخفاء CategoryModel منه                                  
import 'package:my_test_app/models/product_model.dart' hide CategoryModel;                                                                                     
// ⚠️ يجب التأكد من وجود ProductRepository.dart في مساره الصحيح.                                           
import 'package:my_test_app/repositories/product_repository.dart';                                        

class SearchScreen extends StatefulWidget {            
  static const String routeName = '/search';                                                                
  final UserRole userRole;
  
  const SearchScreen({super.key, required this.userRole});
                                                       
  @override                                            
  State<SearchScreen> createState() => _SearchScreenState();                                              
}
                                                     
class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();                                                                                       
  // حالة الفلاتر
  String? _selectedMainCategory;
  String? _selectedSubCategory;                        
  ProductSortOption _selectedSort = ProductSortOption.nameAsc;
                                                       
  // قوائم التصنيفات                                   
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  // حالة البحث                                        
  List<ProductModel> _searchResults = [];
  bool _isLoading = false;                             
  bool _isInitial = true;                                                                                   
  //Timer? _debounce;                                
  
  @override
  void initState() {
    super.initState();                                   
    _fetchCategories();                                  
    // ⚠️ لإطلاق البحث عند الكتابة: يجب تفعيل هذا السطر إذا كنت تستخدم Debounce                                
    // _searchController.addListener(_debouncedSearch);                                                     
  }                                                                                                         
  
  // @override
  // void dispose() {                                  
  //   _searchController.dispose();                    
  //   // _debounce?.cancel();                         
  //   super.dispose();                                
  // }                                                                                                                                                           
  
  // --- دوال جلب البيانات ---                         
  Future<void> _fetchCategories() async {                
    final repo = ProductRepository();                    
    try {                                                  
      final main = await repo.fetchMainCategories();
      setState(() {                                          
        _mainCategories = main;                              
        // جلب الكل في البداية                               
        _fetchSubCategories(null);                         
      });                                                
    } catch (e) {                                          
      print("Error fetching categories: $e");
    }
  }

  Future<void> _fetchSubCategories(String? mainCatId) async {                                                 
    final repo = ProductRepository();                    
    try {
      final sub = await repo.fetchSubCategories(mainCatId);                                                     
      setState(() {
        _subCategories = sub;
      });                                                
    } catch (e) {                                          
      print("Error fetching sub categories: $e");        
    }                                                  
  }                                                                                                         
  
  // --- منطق البحث ---                                
  void _debouncedSearch() {                              
    if (!_isLoading) {                                     
      _performSearch();
    }                                                  
  }
                                                       
  Future<void> _performSearch() async {                  
    setState(() {
      _isLoading = true;                                   
      _isInitial = false;                                
    });                                                                                                       
    
    final repo = ProductRepository();                    
    final searchTerm = _searchController.text.trim();    
    try {                                                  
      final results = await repo.searchProducts(             
        userRole: widget.userRole,                           
        searchTerm: searchTerm,                              
        mainCategoryId: _selectedMainCategory,               
        subCategoryId: _selectedSubCategory,                 
        sortOption: _selectedSort,                         
      );                                                                                                        
      
      setState(() {                                          
        _searchResults = results;                            
        _isLoading = false;                                
      });                                            
    } catch (e) {                                          
      print("Error searching products: $e");               
      setState(() {
        _searchResults = [];                                 
        _isLoading = false;                                
      });                                                
    }                                                  
  }                                                                                                         
  
  // --- بناء المكونات ---                             
  Widget _buildProductCard(ProductModel product) {       
    final displayPrice = product.displayPrice != null ? '${product.displayPrice!.toStringAsFixed(2)} ج' : 'غير متوفر';
    
    // 🟢 [التصحيح]: استخلاص رابط الصورة من القائمة
    final imageUrl = product.imageUrls.isNotEmpty 
        ? product.imageUrls.first 
        : 'https://via.placeholder.com/100'; 
    
    final linkTarget = widget.userRole == UserRole.consumer
        ? '/product-offer-details/${product.id}'             
        : '/product-details/${product.id}';                                                                   
    
    return Card(                                           
      elevation: 3,                                        
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),                                   
      child: InkWell(                                        
        onTap: () => Navigator.pushNamed(context, linkTarget),                                                    
        borderRadius: BorderRadius.circular(10),             
        child: Padding(                                        
          padding: const EdgeInsets.all(8.0),
          child: Column(                                         
            mainAxisAlignment: MainAxisAlignment.center,                                                              
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [                                            
              ClipOval(                                              
                child: Image.network(                                  
                  imageUrl, // 🟢 استخدام الرابط المصحح
                  width: 100, 
                  height: 100, 
                  fit: BoxFit.cover,                                                               
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 100),
                ),
              ),                                                   
              const SizedBox(height: 8),                           
              Text(
                product.name,
                textAlign: TextAlign.center,                         
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),                                        
                maxLines: 2,                                         
                overflow: TextOverflow.ellipsis,
              ),                                                   
              const SizedBox(height: 5),                           
              Text(                                                  
                displayPrice,                                        
                textAlign: TextAlign.center,                         
                style: TextStyle(                                      
                  fontWeight: FontWeight.bold,                         
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.primary,                                                           
                ),                                                 
              ),
              const SizedBox(height: 8),                           
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, linkTarget),
                icon: const Icon(Icons.visibility, size: 18),                                                             
                label: const Text('عرض التفاصيل', style: TextStyle(fontSize: 12)),                                        
                style: OutlinedButton.styleFrom(                       
                  padding: const EdgeInsets.symmetric(vertical: 5),                                                         
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),                                    
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),                                         
                ),                                                 
              ),                                                 
            ],                                                 
          ),                                                 
        ),                                                 
      ),                                                 
    );                                                 
  }                                                  
  
  // 💡 [البديل المؤقت]: استبدال CustomDropdown بـ DropdownButton العادي                                    
  Widget _buildFilterDropdown<T>({                       
    required T? value,
    required String hintText,                            
    required List<T> items,                              
    required String Function(T) itemLabel,               
    required T Function(T) itemValue,
    required void Function(T?) onChanged,              
  }) {                                                   
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),                                         
      decoration: BoxDecoration(                             
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),                                                   
      child: DropdownButtonHideUnderline(                    
        child: DropdownButton<T>(
          isExpanded: true,                                    
          value: value,
          hint: Text(hintText),                                
          items: items.map((item) {                              
            return DropdownMenuItem<T>(                            
              value: itemValue(item),                              
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            );                                                 
          }).toList(),
          onChanged: onChanged,
        ),                                                 
      ),                                                 
    );
  }                                                                                                         
  
  Widget _buildFilters() {                               
    return Padding(                                        
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),                                      
      child: Column(                                         
        children: [                                            
          // فلتر الأقسام الرئيسية
          _buildFilterDropdown<CategoryModel>(                   
            value: _selectedMainCategory != null && _mainCategories.any((c) => c.id == _selectedMainCategory)
                ? _mainCategories.firstWhere((c) => c.id == _selectedMainCategory)                                        
                : null,                                          
            hintText: 'جميع الأقسام الرئيسية',                   
            items: _mainCategories,                              
            itemLabel: (cat) => cat.name,
            itemValue: (cat) => cat,                             
            onChanged: (CategoryModel? category) {
              final value = category?.id;
              setState(() {                                          
                _selectedMainCategory = value;
                _selectedSubCategory = null;                       
              });                                                  
              _fetchSubCategories(value);                          
              _performSearch();                                  
            },                                                 
          ),                                                   
          const SizedBox(height: 10),
                                                               
          // فلتر الأقسام الفرعية                              
          _buildFilterDropdown<CategoryModel>(                   
            value: _selectedSubCategory != null && _subCategories.any((c) => c.id == _selectedSubCategory)
                ? _subCategories.firstWhere((c) => c.id == _selectedSubCategory)                                          
                : null,                                          
            hintText: 'جميع الأقسام الفرعية',
            items: _subCategories,                               
            itemLabel: (cat) => cat.name,                        
            itemValue: (cat) => cat,
            onChanged: (CategoryModel? category) {                 
              setState(() => _selectedSubCategory = category?.id);                                                      
              _performSearch();                                  
            },                                                 
          ),                                                   
          const SizedBox(height: 10),                                                                               
          // فلتر الفرز
          _buildFilterDropdown<ProductSortOption>(               
            value: _selectedSort,
            hintText: 'الفرز',
            items: ProductSortOption.values.toList(),            
            itemLabel: (option) {
              switch (option) {                                      
                case ProductSortOption.nameAsc: return 'الاسم (أ - ي)';                                                   
                case ProductSortOption.nameDesc: return 'الاسم (ي - أ)';
                case ProductSortOption.priceAsc: return 'السعر (الأقل أولاً)';
                case ProductSortOption.priceDesc: return 'السعر (الأعلى أولاً)';                                         
              }
            },
            itemValue: (option) => option,
            onChanged: (value) {
              setState(() => _selectedSort = value ?? ProductSortOption.nameAsc);
              _performSearch();                                  
            },
          ),                                                 
        ],                                                 
      ),
    );                                                 
  }                                                  
  
  @override
  Widget build(BuildContext context) {                   
    return Scaffold(                                       
      appBar: AppBar(                                        
        title: const Text('البحث في أسواق أكسب', style: TextStyle(color: Colors.white)),                          
        backgroundColor: Theme.of(context).colorScheme.primary,                                                   
        iconTheme: const IconThemeData(color: Colors.white),                                                      
        actions: [                                             
          IconButton(                                            
            icon: const Icon(Icons.brightness_4),
            onPressed: () {                                        
              // منطق تبديل الثيم
            },                                                 
          ),
        ],                                                 
      ),                                                   
      body: Column(                                          
        children: [                                            
          // شريط البحث
          Container(                                             
            padding: const EdgeInsets.all(16.0),                 
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,                  
              boxShadow: [                                           
                BoxShadow(                                             
                  color: Theme.of(context).shadowColor.withOpacity(0.1),                                                    
                  blurRadius: 5,                                     
                ),                                                 
              ],                                                 
            ),                                                   
            child: TextField(                                      
              controller: _searchController,                       
              onChanged: (_) => _debouncedSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',                         
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),                                      
                prefixIcon: const Icon(Icons.search),              
              ),
            ),                                                 
          ),                                                                                                        
          // الفلاتر                                           
          _buildFilters(),                           
          
          // منطقة النتائج                                     
          Expanded(                                              
            child: _isLoading                                        
                ? const Center(child: CircularProgressIndicator())                                                        
                : _searchResults.isEmpty                                 
                    ? Center(
                        child: Text(                                           
                          _isInitial
                              ? 'ابدأ البحث للعثور على ما تريد...'                                                                      
                              : 'لا توجد منتجات مطابقة لبحثك أو فلاترك.',                                                           
                          style: TextStyle(color: Theme.of(context).colorScheme.secondary),                                         
                          textAlign: TextAlign.center,                                                                            
                        ),
                      )                                                  
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(                                              
                          crossAxisCount: 2,                                   
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,                                 
                          childAspectRatio: 0.75,
                        ),                                                   
                        itemCount: _searchResults.length,                                                                         
                        itemBuilder: (context, index) {
                          return _buildProductCard(_searchResults[index]);
                        },                                                 
                      ),
          ),
        ],                                                 
      ),                                                 
    );                                                 
  }                                                  
}
