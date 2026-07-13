import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/camera_provider.dart';
import 'fence_calibration_screen.dart';
import 'camera_cell_calibration_screen.dart';

const List<Map<String, String>> _kCameraTypes = [
  {
    'value': 'entrance',
    'label': '🚪 Entrance',
    'hint': 'Entry/exit point — face recognition runs here',
  },
  {
    'value': 'fence',
    'label': '🔒 Fence',
    'hint': 'Perimeter / boundary — wall climbing detection',
  },
  {
    'value': 'insider',
    'label': '🏠 Insider',
    'hint': 'Interior area — person tracking only',
  },
];

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rtspController = TextEditingController();

  int _selectedRow = 0;
  int _selectedCol = 0;
  String _selectedCameraType = 'entrance';

  @override
  void dispose() {
    _nameController.dispose();
    _rtspController.dispose();
    super.dispose();
  }

  // ── Navigation flow ────────────────────────────────────────────────────────
  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final rtspUrl = _rtspController.text.trim();

    // 2. Navigate to calibration based on camera type
    if (_selectedCameraType == 'fence') {
      // fence → polygon screen → cell screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FenceCalibrationScreen(
            cameraId: '',
            cameraName: name,
            isUpdate: false,
            draftStreamUrl: rtspUrl,
            draftCameraType: _selectedCameraType,
            draftRow: _selectedRow,
            draftCol: _selectedCol,
          ),
        ),
      );
    } else {
      // entrance / insider → straight to cell calibration
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraCellCalibrationScreen(
            cameraId: '',
            cameraName: name,
            isUpdate: false,
            draftStreamUrl: rtspUrl,
            draftCameraType: _selectedCameraType,
            draftRow: _selectedRow,
            draftCol: _selectedCol,
          ),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final property = context.read<PropertyContextProvider>().selectedProperty;
    final grid = property?.laserGrid;
    final cols = grid?.xLasers ?? 3;
    final rows = grid?.yLasers ?? 8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Add New Camera'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Camera Name
              CustomTextField(
                controller: _nameController,
                hintText: 'Camera name',
                labelText: 'Camera Name',
                prefixIcon: Icons.videocam_outlined,
                validator: (v) => Validators.validateRequired(v, 'Camera name'),
              ),
              const SizedBox(height: 16),

              // Stream URL
              CustomTextField(
                controller: _rtspController,
                hintText: 'http://192.168.1.5:8080/video',
                labelText: 'Camera Stream URL',
                prefixIcon: Icons.link,
                validator: (v) => Validators.validateRequired(v, 'Stream URL'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Using IP Webcam? Enter: http://YOUR_PHONE_IP:8080/video',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Camera Type
              const Text(
                'Camera Zone Type *',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildTypeDropdown(),
              const SizedBox(height: 20),

              // Grid Cell
              const Text(
                'Grid Cell Location *',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildGridDropdown(rows, cols, grid),
              const SizedBox(height: 32),

              // Next button
              Consumer<CameraProvider>(
                builder: (_, provider, __) => CustomButton(
                  text: _selectedCameraType == 'fence'
                      ? 'NEXT: CALIBRATE FENCE'
                      : 'NEXT: DEFINE CELLS',
                  isLoading: provider.isLoading,
                  onPressed: _handleNext,
                  icon: _selectedCameraType == 'fence'
                      ? Icons.grid_on
                      : Icons.numbers,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _buildTypeDropdown() {
    return Container(
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
          value: _selectedCameraType,
          items: _kCameraTypes
              .map((t) => DropdownMenuItem<String>(
                    value: t['value'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t['label']!,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          t['hint']!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCameraType = v);
          },
          itemHeight: 64,
        ),
      ),
    );
  }

  Widget _buildGridDropdown(int rows, int cols, dynamic grid) {
    return Container(
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
                      grid?.boxLength ?? 0.6,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
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
    );
  }
}
