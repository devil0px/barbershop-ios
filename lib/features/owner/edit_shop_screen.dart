import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'owner_repository.dart';
import '../../core/models/barbershop_model.dart';

class EditShopScreen extends StatefulWidget {
  final Barbershop shop;
  const EditShopScreen({super.key, required this.shop});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _whatsappController;
  final _repository = OwnerRepository();
  final _picker = ImagePicker();
  
  File? _imageFile;
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  bool _isGettingLocation = false;

  // Working hours state
  late Map<String, _DayHours> _workingHours;

  static const _dayOrder = ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  static const _dayNames = {
    'saturday': 'السبت',
    'sunday': 'الأحد',
    'monday': 'الاثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop.name);
    _addressController = TextEditingController(text: widget.shop.address);
    _descriptionController = TextEditingController(text: widget.shop.description);
    _whatsappController = TextEditingController(text: widget.shop.whatsappNumber ?? '');
    _latitude = widget.shop.latitude;
    _longitude = widget.shop.longitude;

    // Initialize working hours from shop data
    _workingHours = {};
    for (final day in _dayOrder) {
      final data = widget.shop.workingHours[day];
      if (data is Map) {
        _workingHours[day] = _DayHours(
          isOpen: data['is_open'] ?? true,
          open: data['open'] ?? data['start'] ?? '09:00',
          close: data['close'] ?? data['end'] ?? '18:00',
        );
      } else {
        _workingHours[day] = _DayHours(
          isOpen: day != 'friday',
          open: day == 'friday' ? '10:00' : '09:00',
          close: day == 'friday' ? '15:00' : '18:00',
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الموقع بنجاح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديد الموقع')));
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickTime(String day, bool isOpen) async {
    final current = isOpen ? _workingHours[day]!.open : _workingHours[day]!.close;
    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpen) {
          _workingHours[day] = _DayHours(isOpen: _workingHours[day]!.isOpen, open: formatted, close: _workingHours[day]!.close);
        } else {
          _workingHours[day] = _DayHours(isOpen: _workingHours[day]!.isOpen, open: _workingHours[day]!.open, close: formatted);
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم المحل'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال العنوان'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Build working hours JSON
    final Map<String, dynamic> hoursJson = {};
    for (final day in _dayOrder) {
      final h = _workingHours[day]!;
      hoursJson[day] = {
        'is_open': h.isOpen,
        'open': h.open,
        'close': h.close,
        'start': h.open,
        'end': h.close,
      };
    }

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'description': _descriptionController.text.trim(),
      'whatsapp_number': _whatsappController.text.trim(),
    };

    if (_imageFile != null) data['image_path'] = _imageFile!.path;
    if (_latitude != null) data['latitude'] = double.parse(_latitude!.toStringAsFixed(6));
    if (_longitude != null) data['longitude'] = double.parse(_longitude!.toStringAsFixed(6));

    final result = await _repository.updateBarbershopWithResult(widget.shop.id, data);

    // Also update working hours via settings
    if (result.isSuccess) {
      await _repository.updateBarbershopSettings(widget.shop.id, {'working_hours': hoursJson});
    }

    setState(() => _isSaving = false);

    if (!mounted) return;

    result.when(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحديث بيانات المحل بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      },
      onFailure: (error) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('فشل التحديث', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(error.message, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً', style: TextStyle(color: Color(0xFFD4AF37))),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('إعدادات المحل'),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Color(0xFFD4AF37))))
          else
            TextButton(onPressed: _saveChanges, child: const Text('حفظ', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                  image: _imageFile != null 
                    ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                    : (widget.shop.logoUrl != null ? DecorationImage(image: NetworkImage(widget.shop.logoUrl!), fit: BoxFit.cover) : null),
                ),
                child: (_imageFile == null && widget.shop.logoUrl == null)
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Color(0xFFD4AF37)),
                          SizedBox(height: 8),
                          Text('تغيير صورة المحل', style: TextStyle(color: Colors.white60)),
                        ],
                      )
                    : Container(
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.all(12),
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(icon: const Icon(Icons.edit, color: Color(0xFFD4AF37)), onPressed: _pickImage),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField('اسم المحل', _nameController, Icons.store),
            const SizedBox(height: 20),
            _buildTextField('العنوان', _addressController, Icons.location_on),
            const SizedBox(height: 20),
            
            // Location Selection
            InkWell(
              onTap: _isGettingLocation ? null : _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _latitude != null ? Colors.green.withOpacity(0.3) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: _latitude != null ? Colors.green : const Color(0xFFD4AF37)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _latitude != null 
                            ? 'الموقع محدد (${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)})' 
                            : 'تحديث الموقع الجغرافي (GPS)',
                        style: TextStyle(color: _latitude != null ? Colors.white : Colors.white60),
                      ),
                    ),
                    if (_isGettingLocation)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildTextField('رقم الواتساب', _whatsappController, Icons.message, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            
            _buildTextField('الوصف', _descriptionController, Icons.description, maxLines: 4),
            const SizedBox(height: 30),

            // ── Working Hours Section ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule, color: Color(0xFFD4AF37), size: 20),
                      SizedBox(width: 8),
                      Text('ساعات العمل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._dayOrder.map((day) => _buildDayRow(day)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(String day) {
    final h = _workingHours[day]!;
    final label = _dayNames[day] ?? day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Day name
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(color: h.isOpen ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          // Toggle
          SizedBox(
            height: 28,
            child: Switch(
              value: h.isOpen,
              activeColor: const Color(0xFFD4AF37),
              onChanged: (val) {
                setState(() {
                  _workingHours[day] = _DayHours(isOpen: val, open: h.open, close: h.close);
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          if (h.isOpen) ...[
            // Open time
            GestureDetector(
              onTap: () => _pickTime(day, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Text(h.open, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(color: Colors.white38)),
            ),
            // Close time
            GestureDetector(
              onTap: () => _pickTime(day, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Text(h.close, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else
            Text('مغلق', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _DayHours {
  final bool isOpen;
  final String open;
  final String close;
  const _DayHours({required this.isOpen, required this.open, required this.close});
}
