import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'owner_repository.dart';

class ManageServicesScreen extends StatefulWidget {
  final int shopId;
  const ManageServicesScreen({super.key, required this.shopId});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final _repository = OwnerRepository();
  final _picker = ImagePicker();
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    final services = await _repository.getServices(widget.shopId);
    setState(() {
      _services = services;
      _isLoading = false;
    });
  }

  void _showServiceDialog({Map<String, dynamic>? service}) {
    final nameController = TextEditingController(text: service?['name'] ?? '');
    final priceController = TextEditingController(text: service?['price']?.toString() ?? '');
    final durationController = TextEditingController(text: service?['duration']?.toString() ?? '30');
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            service == null ? 'إضافة خدمة جديدة' : 'تعديل الخدمة',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📸 Service Image Picker
                GestureDetector(
                  onTap: () async {
                    // ⚡ Media Efficiency Mutation: Compress image before picking
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setDialogState(() => selectedImagePath = image.path);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: selectedImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(selectedImagePath!), fit: BoxFit.cover),
                          )
                        : service?['image'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(service!['image'], fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 32),
                                  SizedBox(height: 8),
                                  Text('اضغط لإضافة صورة', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'اسم الخدمة',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'السعر (جنيه)',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'المدة (بالدقائق)',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                
                final data = {
                  'name': nameController.text,
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'duration': int.tryParse(durationController.text) ?? 30,
                  'category': 'haircut',
                  if (selectedImagePath != null) 'image_path': selectedImagePath,
                };

                final result = service == null
                    ? await _repository.addService(widget.shopId, data)
                    : await _repository.updateService(service['id'], data);

                if (!context.mounted) return;

                result.when(
                  onSuccess: (_) {
                    Navigator.pop(context);
                    _fetchServices();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ الخدمة بنجاح'), backgroundColor: Colors.green),
                    );
                  },
                  onFailure: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message), backgroundColor: Colors.red),
                    );
                  },
                );
              },
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteService(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('حذف الخدمة', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذه الخدمة؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (await _repository.deleteService(id)) _fetchServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('إدارة الخدمات'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      // 🖼️ Service Image Thumbnail
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: service['image'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(service['image'], fit: BoxFit.cover),
                              )
                            : const Icon(Icons.cut, color: Color(0xFFD4AF37), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${service['price']} جنيه - ${service['duration']} دقيقة', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => _showServiceDialog(service: service), icon: const Icon(Icons.edit, color: Colors.blue, size: 22)),
                      IconButton(onPressed: () => _deleteService(service['id']), icon: const Icon(Icons.delete, color: Colors.red, size: 22)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4AF37),
        onPressed: () => _showServiceDialog(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
