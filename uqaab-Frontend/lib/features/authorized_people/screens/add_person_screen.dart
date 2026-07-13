// lib/features/authorized_people/screens/add_person_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../provider/person_provider.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _labels = const ['Front', 'Left', 'Right'];
  final _localImages = <File?>[null, null, null];
  final _photoUrls = <String?>[null, null, null];

  String _selectedRole = 'Guest';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonProvider>().loadRelationships();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  // ─── Pick image ──────────────────────────────────────────────────────────
  void _pickImageForSlot(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                    maxWidth: 800,
                    maxHeight: 800);
                if (img != null) _handleImage(img, index);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                final img = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                    maxWidth: 800,
                    maxHeight: 800);
                if (img != null) _handleImage(img, index);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // JUST saves locally. Waits for the big SAVE button to upload.
  void _handleImage(XFile file, int index) {
    setState(() {
      _localImages[index] = File(file.path);
      _photoUrls[index] = null;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _localImages[index] = null;
      _photoUrls[index] = null;
    });
  }

  // ─── Save All ────────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid == null) return;

    setState(() => _isUploading = true);
    final provider = context.read<PersonProvider>();
    final repo = provider.personRepository;

    try {
      // 1. Upload the files
      List<String> finalUrls = [];
      for (int i = 0; i < 3; i++) {
        if (_localImages[i] != null) {
          final url = await repo.uploadPersonImage(_localImages[i]!);
          if (url.isNotEmpty) finalUrls.add(url);
        } else if (_photoUrls[i] != null) {
          finalUrls.add(_photoUrls[i]!);
        }
      }

      if (finalUrls.isEmpty) {
        Helpers.showSnackBar(context, 'Please add at least one photo.',
            isError: true);
        setState(() => _isUploading = false);
        return;
      }

      // 2. Save to Database
      final nameToSave = _nameCtrl.text.trim();
      final success = await provider.createPerson(
        propertyId: pid,
        name: nameToSave,
        relationship: _selectedRole,
        photoUrls: finalUrls,
      );

      if (success) {
        // 3. Auto Encode
        final newPerson = provider.people.firstWhere(
          (p) => p.name == nameToSave && p.role == _selectedRole,
          orElse: () => provider.people.last,
        );
        await provider.encodeFace(newPerson.id);

        if (mounted) {
          Helpers.showSuccessSnackBar(
              context, 'Person saved and face enrolled!');
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          Helpers.showSnackBar(context, provider.errorMessage, isError: true);
        }
      }
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<PersonProvider>(
      builder: (ctx, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(title: 'Add Authorized Person'),
          body: provider.isLoading && !_isUploading
              ? const LoadingWidget()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          controller: _nameCtrl,
                          hintText: 'Full name',
                          labelText: 'Full Name *',
                          prefixIcon: Icons.person_outline,
                          validator: (v) =>
                              Validators.validateRequired(v, 'Name'),
                        ),
                        const SizedBox(height: 16),
                        const Text('Role',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Consumer<PersonProvider>(
                          builder: (ctx, p, _) {
                            final roles = p.relationships.isNotEmpty
                                ? p.relationships
                                : ['Guard', 'Guest', 'Authorized Person'];
                            if (!roles.contains(_selectedRole)) {
                              _selectedRole = roles.first;
                            }
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  value: _selectedRole,
                                  items: roles
                                      .map((r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(r,
                                              style: const TextStyle(
                                                  color:
                                                      AppColors.textPrimary))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedRole = v);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                color: AppColors.textSecondary, size: 18),
                            SizedBox(width: 8),
                            Text('Face Photos',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add clear face photos for better recognition',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(3, _buildPhotoBox),
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: 'SAVE PERSON',
                          isLoading: provider.isLoading || _isUploading,
                          onPressed: _handleSave,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPhotoBox(int index) {
    final hasLocal = _localImages[index] != null;
    final hasUrl = _photoUrls[index] != null;
    final hasImage = hasLocal || hasUrl;

    return Column(
      children: [
        Text(_labels[index],
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _isUploading ? null : () => _pickImageForSlot(index),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: hasImage ? Colors.transparent : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hasImage
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.surfaceBorder,
                  width: hasImage ? 2 : 1),
            ),
            child: hasImage
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasLocal
                          ? Image.file(_localImages[index]!,
                              width: 100, height: 120, fit: BoxFit.cover)
                          : Image.network(_getFullUrl(_photoUrls[index]!),
                              width: 100,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image,
                                      color: AppColors.textSecondary))),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ])
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          size: 28),
                      const SizedBox(height: 4),
                      Text('Tap to add',
                          style: TextStyle(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.4),
                              fontSize: 9)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
