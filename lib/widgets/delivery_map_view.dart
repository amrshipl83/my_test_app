// lib/widgets/delivery_map_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// ثوابت الخريطة
const String TILE_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
const List<String> TILE_SUBDOMAINS = ['a', 'b', 'c', 'd'];
const LatLng MAP_CENTER = LatLng(30.9, 28.5);
const double MAP_ZOOM = 5.5;
// ثابت GeoJSON File Path - تأكد من تطابقه مع pubspec.yaml
const String GEOJSON_FILE_PATH = 'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson';

class DeliveryMapView extends StatefulWidget {
  final Map<String, dynamic>? initialGeoJsonData;
  final List<String> initialSelectedAreas;
  final Function(List<String> selectedAreas) onAreasChanged;

  const DeliveryMapView({
    super.key,
    required this.initialGeoJsonData,
    required this.initialSelectedAreas,
    required this.onAreasChanged,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  List<String> _selectedAreaNames = [];
  List<Polygon> _polygons = [];
  final MapController _mapController = MapController();

  Map<String, dynamic>? _geoJsonData;
  bool _isLoading = true;
  String? _loadingError;

  // ----------------------------------------------------------------------
  // LIFECYCLE
  // ----------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _selectedAreaNames = List.from(widget.initialSelectedAreas);
    _loadGeoJsonAndInitialize();
  }

  // ----------------------------------------------------------------------
  // دالة تحميل GeoJSON
  // ----------------------------------------------------------------------
  Future<void> _loadGeoJsonAndInitialize() async {
    _geoJsonData = widget.initialGeoJsonData;

    if (_geoJsonData == null) {
      try {
        final geoJsonString = await rootBundle.loadString(GEOJSON_FILE_PATH);
        _geoJsonData = jsonDecode(geoJsonString) as Map<String, dynamic>;
        _loadingError = null;
      } catch (e) {
        _loadingError = '❌ فشل تحميل ملف GeoJSON من الأصول. تأكد من pubspec.yaml والمسار.';
        _geoJsonData = null;
        print('FATAL ERROR: Failed to load GeoJSON from assets: $e');
      }
    }

    setState(() {
      _isLoading = false;
      if (_geoJsonData != null) {
        _updateMapAndPolygons(_selectedAreaNames);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedAreas != oldWidget.initialSelectedAreas) {
      _selectedAreaNames = List.from(widget.initialSelectedAreas);
      _updateMapAndPolygons(_selectedAreaNames);
    }
  }

  // ----------------------------------------------------------------------
  // MAP LOGIC
  // ----------------------------------------------------------------------

  void _handleDropdownChange(List<String> newSelection) {
    setState(() {
      _selectedAreaNames = newSelection;
    });
    // استدعاء الدالة الأم لحفظ البيانات
    widget.onAreasChanged(newSelection);
    _updateMapAndPolygons(newSelection);
  }

  void _updateMapAndPolygons(List<String> areaNames) {
    if (_geoJsonData == null || areaNames.isEmpty) {
      setState(() {
        _polygons = [];
      });
      return;
    }

    final selectedFeatures = (_geoJsonData!['features'] as List)
        // الحقل المؤكد: 'name'
        .where((f) => areaNames.contains(f['properties']['name']))
        .toList();

    if (selectedFeatures.isEmpty) {
      setState(() {
        _polygons = [];
      });
      return;
    }

    final geoJsonParser = GeoJsonParser(
      defaultPolygonBorderColor: const Color(0xff28a745),
      defaultPolygonFillColor: const Color(0xff28a745).withOpacity(0.5),
    );

    final geojsonData = {
      'type': 'FeatureCollection',
      'features': selectedFeatures
    };

    geoJsonParser.parseGeoJson(geojsonData);

    setState(() {
      _polygons = geoJsonParser.polygons;
    });

    final allPoints = _polygons.expand((p) => p.points).toList();

    LatLngBounds? bounds;
    if (allPoints.isNotEmpty) {
      bounds = LatLngBounds.fromPoints(allPoints);
    }

    // 🟢 [التصحيح 3]: تغيير fitBounds إلى fitCamera
    if (bounds != null && bounds.south != null && bounds.north != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  // ----------------------------------------------------------------------
  // UI BUILDER
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🛑 عرض رسالة الخطأ في حالة فشل التحميل
    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _loadingError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final List<dynamic> features = _geoJsonData!['features'] as List;

    // استخراج أسماء المناطق (باستخدام حقل 'name' المؤكد)
    final List<String> allAreaNames = features
        .map((f) => f['properties']['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();

    // ✅ التشخيص: عدد المناطق المستخرجة
    final int areaCount = allAreaNames.length;
    // رسالة التشخيص البديلة (في الـ UI)
    final String hintText = areaCount == 0
        ? '⚠️ تم تحميل GeoJSON لكن لم يتم استخراج أي مناطق.'
        : 'تم اختيار ${_selectedAreaNames.length} مناطق من أصل $areaCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختيار مناطق التوصيل:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // 1. قائمة الاختيار المتعدد (Multi-Select Dropdown)
        // 🎯 التصحيح الحاسم: استخدام InkWell لتجاوز فشل النقر الافتراضي
        InkWell(
          onTap: () async {
            // هذا التأكيد يمنع فتح الحوار إذا لم يتم تحميل المناطق
            if (areaCount == 0) return;

            final List<String>? result = await showDialog<List<String>>(
              context: context,
              builder: (context) => MultiSelectAreaDialog(
                allAreas: allAreaNames,
                initialSelection: _selectedAreaNames,
              ),
            );
            if (result != null) {
              _handleDropdownChange(result);
            }
          },
          child: IgnorePointer( // يمنع الـ Dropdown الداخلي من الاستجابة للنقر
            child: DropdownButtonFormField<String>(
              value: null,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: hintText,
              ),
              // يجب إبقاء items فارغًا
              items: const [],
              onChanged: (String? value) {}, // نتركها فارغة لكن ضرورية
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. الخريطة لعرض الحدود
        Container(
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // 🟢 [التصحيح 1]: تغيير center إلى initialCenter
                initialCenter: MAP_CENTER,
                // 🟢 [التصحيح 2]: تغيير zoom إلى initialZoom
                initialZoom: MAP_ZOOM,
              ),
              children: [
                TileLayer(
                  urlTemplate: TILE_URL,
                  subdomains: TILE_SUBDOMAINS,
                  userAgentPackageName: 'com.example.app',

                  maxZoom: 19,
                ),
                PolygonLayer(
                  polygons: _polygons,
                  polygonCulling: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET مساعد: حوار الاختيار المتعدد للمناطق
// ----------------------------------------------------------------------

class MultiSelectAreaDialog extends StatefulWidget {
  final List<String> allAreas;
  final List<String> initialSelection;

  const MultiSelectAreaDialog({
    super.key,
    required this.allAreas,
    required this.initialSelection,
  });

  @override
  State<MultiSelectAreaDialog> createState() => _MultiSelectAreaDialogState();
}

class _MultiSelectAreaDialogState extends State<MultiSelectAreaDialog> {
  final List<String> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _selectedItems.addAll(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار المناطق الإدارية'),
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.allAreas.map((item) {
            return CheckboxListTile(
              value: _selectedItems.contains(item),
              title: Text(item),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked ?? false) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedItems),
          child: Text('حفظ (${_selectedItems.length})'),
        ),
      ],
    );
  }
}

