// lib/constants/app_constants.dart (النسخة النهائية والمُصحَّحة)

import 'package:flutter/material.dart';
// ----------------------------------------------------------------------
// ثوابت Firestore للمجموعات (تم تصحيح التسمية لـ SCREAMING_SNAKE_CASE)
// ----------------------------------------------------------------------
const String SELLERS_COLLECTION = 'sellers'; // المتاجر والبائعين
const String STORES_COLLECTION = 'stores';
const String OFFERS_COLLECTION = 'offers';
const String REPORTS_COLLECTION = 'reports';
const String GIFT_PROMO_COLLECTION = 'giftPromos';

// ----------------------------------------------------------------------
// ثوابت Firestore للحقول
// ----------------------------------------------------------------------
// الحقل الذي يحتوي على بيانات مناطق التوصيل ضمن وثيقة المتجر
const String DELIVERY_AREAS_FIELD = 'deliveryAreas'; // الاسم الأصلي
// 💡 التصحيح: إضافة الثابت بالاسم الذي تتوقعه شاشة delivery_area_screen.dart
const String FIRESTORE_DELIVERY_AREAS_FIELD = 'deliveryAreas'; 

// حقل المتجر
const String SELLER_ID_FIELD = 'sellerId';

// ----------------------------------------------------------------------
// ثوابت واجهة برمجة التطبيقات (APIs) - مُستخلصة من كود HTML
// ----------------------------------------------------------------------
// AWS API Gateway Endpoint
const String API_GATEWAY_ENDPOINT = 'https://h9iaac7jee.execute-api.us-east-1.amazonaws.com/div/updateloction';
// مسار ملف GeoJSON للمناطق الإدارية
const String GEOJSON_FILE_PATH = 'OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson';
// مفتاح الوصول لـ Mapbox
const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';

// الإحداثيات الافتراضية لمركز الخريطة
const double MAP_CENTER_LAT = 28.5;
const double MAP_CENTER_LNG = 30.9;
const double MAP_ZOOM = 5.5;

// ----------------------------------------------------------------------
// ثوابت أخرى
// ----------------------------------------------------------------------
const Map<String, Color> ORDER_STATUSES_MAP = {
  'new-order': Colors.blue,
  'pending': Colors.orange,
  'delivered': Colors.green,
  'cancelled': Colors.red,
};
