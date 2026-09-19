import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'owner_repository.dart';

class ManageStaffScreen extends StatefulWidget {
  final int shopId;
  const ManageStaffScreen({super.key, required this.shopId});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final _repository = OwnerRepository();
  final _picker = ImagePicker();
  List<dynamic> _staff = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    final staff = await _repository.getStaff(widget.shopId);
    setState(() {
      _staff = staff;
      _isLoading = false;
    });
  }

  void _showStaffDialog({Map<String, dynamic>? member}) {
    final nameController = TextEditingController(text: member?['name'] ?? '');
    final phoneController = TextEditingController(text: member?['phone'] ?? '');
    final roleController = TextEditingController(text: member?['specialization'] ?? 'حلاق محترف');
    bool isAvailable = member?['is_available'] ?? true;
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(member == null ? 'إضافة حلاق جديد' : 'تعديل بيانات الحلاق', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📸 Staff Photo Picker
                GestureDetector(
                  onTap: () async {
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
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: selectedImagePath != null
                        ? ClipOval(
                            child: Image.file(File(selectedImagePath!), fit: BoxFit.cover),
                          )
                        : member?['photo'] != null
                            ? ClipOval(
                                child: Image.network(member!['photo'], fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 28),
                                  SizedBox(height: 4),
                                  Text('صورة', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'اسم الحلاق',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                TextField(
                  controller: roleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'التخصص (مثلاً: حلاق محترف)',
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('متاح للعمل', style: TextStyle(color: Colors.white)),
                  value: isAvailable,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (val) => setDialogState(() => isAvailable = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: _isSaving ? null : () async {
                if (nameController.text.isEmpty) return;
                
                setDialogState(() => _isSaving = true);

                final data = {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'specialization': roleController.text.isEmpty ? 'حلاق' : roleController.text,
                  'is_available': isAvailable,
                  'is_active': true,
                  'role': 'barber',
                  'hire_date': member?['hire_date'] ?? DateTime.now().toIsoStringDate(),
                  if (selectedImagePath != null) 'photo_path': selectedImagePath,
                };

                final result = member == null 
                    ? await _repository.addStaff(widget.shopId, data)
                    : await _repository.updateStaff(member['id'], data);

                if (!context.mounted) {
                  setDialogState(() => _isSaving = false);
                  return;
                }

                setDialogState(() => _isSaving = false);

                result.when(
                  onSuccess: (_) {
                    Navigator.pop(context);
                    _fetchStaff();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ البيانات بنجاح'), backgroundColor: Colors.green),
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

  Future<void> _deleteStaff(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('حذف الموظف', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا الموظف؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (await _repository.deleteStaff(id)) _fetchStaff();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('إدارة الموظفين (الحلاقين)'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _staff.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final member = _staff[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                            backgroundImage: member['photo'] != null ? NetworkImage(member['photo']) : null,
                            child: member['photo'] == null
                                ? Text(
                                    member['name']?[0] ?? 'B',
                                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member['name'] ?? 'حلاق غير مسمى',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  member['specialization'] ?? 'حلاق محترف',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildStatBadge('اليوم', member['bookings_count_today'] ?? 0),
                                    const SizedBox(width: 4),
                                    _buildStatBadge('الشهر', member['bookings_count_month'] ?? 0),
                                    const SizedBox(width: 4),
                                    _buildStatBadge('السنة', member['bookings_count_year'] ?? 0),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(member['is_available'] ?? true),
                          IconButton(onPressed: () => _showStaffDialog(member: member), icon: const Icon(Icons.edit, color: Colors.blue, size: 20)),
                          IconButton(onPressed: () => _deleteStaff(member['id']), icon: const Icon(Icons.delete, color: Colors.red, size: 20)),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4AF37),
        onPressed: () => _showStaffDialog(),
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }

  Widget _buildStatusChip(bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        available ? 'متاح' : 'مشغول',
        style: TextStyle(color: available ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('لا يوجد موظفين مسجلين', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          const Text('أضف حلاقين لصالونك لتبدأ في استقبال الحجوزات', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    );
  }
}

extension DateTimeFormat on DateTime {
  String toIsoStringDate() => "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
}
