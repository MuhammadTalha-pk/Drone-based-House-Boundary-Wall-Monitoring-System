import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../models/camera_model.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/camera_provider.dart';

class EditCameraScreen extends StatefulWidget {
  final String cameraId;
  const EditCameraScreen({super.key, required this.cameraId});

  @override
  State<EditCameraScreen> createState() => _EditCameraScreenState();
}

class _EditCameraScreenState extends State<EditCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rtspController;
  late int _selectedRow;
  late int _selectedCol;
  CameraModel? _camera;

  @override
  void initState() {
    super.initState();
    final cam = context.read<CameraProvider>().getCameraById(widget.cameraId);
    _camera = cam;
    _nameController = TextEditingController(text: cam?.name ?? '');
    _rtspController = TextEditingController(text: cam?.rtspUrl ?? '');
    _selectedRow = cam?.gridCell.row ?? 0;
    _selectedCol = cam?.gridCell.col ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rtspController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid == null) return;

    final success = await context.read<CameraProvider>().updateCamera(
          cameraId: widget.cameraId,
          propertyId: pid,
          name: _nameController.text.trim(),
          rtspUrl: _rtspController.text.trim(),
          row: _selectedRow,
          col: _selectedCol,
        );

    if (!mounted) return;
    if (success) {
      Helpers.showSuccessSnackBar(context, 'Camera updated!');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = context.read<PropertyContextProvider>().selectedProperty;
    final grid = property?.laserGrid;
    final cols = grid?.xLasers ?? 3;
    final rows = grid?.yLasers ?? 8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Edit Camera'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _nameController,
                hintText: 'Camera name',
                labelText: 'Camera Name',
                prefixIcon: Icons.videocam_outlined,
                validator: (v) => Validators.validateRequired(v, 'Camera name'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _rtspController,
                hintText: 'rtsp://...',
                labelText: 'RTSP Stream URL',
                prefixIcon: Icons.link,
                validator: (v) => Validators.validateRequired(v, 'RTSP URL'),
              ),
              const SizedBox(height: 16),
              const Text('Grid Cell Location *',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    value: '$_selectedRow,$_selectedCol',
                    items: [
                      for (int r = 0; r < rows; r++)
                        for (int c = 0; c < cols; c++)
                          DropdownMenuItem(
                            value: '$r,$c',
                            child: Text(
                              Formatters.gridCellWithPosition(
                                  r,
                                  c,
                                  grid?.boxWidth ?? 2.0,
                                  grid?.boxLength ?? 0.6),
                              style:
                                  const TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        final parts = value.split(',');
                        setState(() {
                          _selectedRow = int.parse(parts[0]);
                          _selectedCol = int.parse(parts[1]);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if ((_camera?.cameraType ?? '').toString().toLowerCase() ==
                  'fence')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: OutlinedButton(
                    onPressed: () {
                      context.push(
                        '/cameras/calibrate/${widget.cameraId}?name=${Uri.encodeComponent(_nameController.text)}&mode=update',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('UPDATE POLYGON'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: OutlinedButton(
                  onPressed: () {
                    final propertyId = context
                        .read<PropertyContextProvider>()
                        .selectedPropertyId;
                    if (propertyId == null) return;

                    context.push(
                      '/property/$propertyId/camera/${widget.cameraId}/cells?name=${Uri.encodeComponent(_nameController.text)}&streamUrl=${Uri.encodeComponent(_rtspController.text)}&cameraType=${Uri.encodeComponent(_camera?.cameraType ?? 'entrance')}&row=$_selectedRow&col=$_selectedCol&mode=update',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('UPDATE FENCE CELL'),
                ),
              ),
              Consumer<CameraProvider>(
                builder: (context, provider, _) {
                  return CustomButton(
                    text: 'UPDATE CAMERA',
                    isLoading: provider.isLoading,
                    onPressed: _handleUpdate,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
