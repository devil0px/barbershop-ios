import 'package:flutter/material.dart';

class FilterModal extends StatefulWidget {
  final Map<String, dynamic> currentFilters;

  const FilterModal({super.key, required this.currentFilters});

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late double _minRating;
  late bool _showOnlyOpen;
  late bool _showOnlyFavorites;
  late bool _sortByNearest;

  @override
  void initState() {
    super.initState();
    _minRating = widget.currentFilters['minRating'] ?? 0.0;
    _showOnlyOpen = widget.currentFilters['showOnlyOpen'] ?? false;
    _showOnlyFavorites = widget.currentFilters['showOnlyFavorites'] ?? false;
    _sortByNearest = widget.currentFilters['sortByNearest'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تصفية النتائج',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('الحد الأدنى للتقييم', style: TextStyle(color: Colors.white70)),
          Slider(
            value: _minRating,
            min: 0,
            max: 5,
            divisions: 5,
            label: _minRating.toString(),
            activeColor: const Color(0xFFD4AF37),
            onChanged: (val) => setState(() => _minRating = val),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('عرض المفتوحة فقط', style: TextStyle(color: Colors.white70)),
            value: _showOnlyOpen,
            activeColor: const Color(0xFFD4AF37),
            onChanged: (val) => setState(() => _showOnlyOpen = val),
          ),
          SwitchListTile(
            title: const Text('المفضلة فقط', style: TextStyle(color: Colors.white70)),
            value: _showOnlyFavorites,
            activeColor: const Color(0xFFD4AF37),
            onChanged: (val) => setState(() => _showOnlyFavorites = val),
          ),
          SwitchListTile(
            title: const Text('الأقرب إلي أولاً', style: TextStyle(color: Colors.white70)),
            subtitle: const Text('ترتيب حسب المسافة من موقعك', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _sortByNearest,
            activeColor: const Color(0xFFD4AF37),
            onChanged: (val) => setState(() => _sortByNearest = val),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'minRating': _minRating,
                'showOnlyOpen': _showOnlyOpen,
                'showOnlyFavorites': _showOnlyFavorites,
                'sortByNearest': _sortByNearest,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('تطبيق الفلتر', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'minRating': 0.0,
                'showOnlyOpen': false,
                'showOnlyFavorites': false,
                'sortByNearest': false,
              });
            },
            child: const Text('إعادة تعيين', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}
