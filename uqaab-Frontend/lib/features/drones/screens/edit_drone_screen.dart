import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/drone_provider.dart';

class EditDroneScreen extends StatefulWidget {
  final String droneId;
  const EditDroneScreen({super.key, required this.droneId});
  @override
  State<EditDroneScreen> createState() => _EditDroneScreenState();
}

class _EditDroneScreenState extends State<EditDroneScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _connectionController;
  late int _selectedRow;
  late int _selectedCol;

  @override
  void initState() {
    super.initState();
    final drone = context.read<DroneProvider>().getDroneById(widget.droneId);
    _nameController = TextEditingController(text: drone?.name ?? '');
    _connectionController = TextEditingController(text: drone?.connectionString ?? '');
    _selectedRow = drone?.homeCell.row ?? 0;
    _selectedCol = drone?.homeCell.col ?? 0;
  }

  @override
  void dispose() { _nameController.dispose(); _connectionController.dispose(); super.dispose(); }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid == null) return;
    final success = await context.read<DroneProvider>().updateDrone(droneId: widget.droneId, propertyId: pid, name: _nameController.text.trim(), connectionString: _connectionController.text.trim(), row: _selectedRow, col: _selectedCol);
    if (!mounted) return;
    if (success) { Helpers.showSuccessSnackBar(context, 'Drone updated!'); Navigator.of(context).pop(); }
  }

  @override
  Widget build(BuildContext context) {
    final property = context.read<PropertyContextProvider>().selectedProperty;
    final grid = property?.laserGrid;
    final cols = grid?.xLasers ?? 3;
    final rows = grid?.yLasers ?? 8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Edit Drone'),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomTextField(controller: _nameController, hintText: 'Drone name', labelText: 'Drone Name', prefixIcon: Icons.flight_outlined, validator: (v) => Validators.validateRequired(v, 'Drone name')),
        const SizedBox(height: 16),
        CustomTextField(controller: _connectionController, hintText: 'udp://:14540', labelText: 'MAVLink Connection String', prefixIcon: Icons.link, validator: (v) => Validators.validateRequired(v, 'Connection string')),
        const SizedBox(height: 16),
        const Text('Home Location *', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: AppColors.surface, value: '$_selectedRow,$_selectedCol', items: [for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) DropdownMenuItem(value: '$r,$c', child: Text(Formatters.gridCellWithPosition(r, c, grid?.boxWidth ?? 2.0, grid?.boxLength ?? 0.6), style: const TextStyle(color: AppColors.textPrimary)))], onChanged: (v) { if (v != null) { final p = v.split(','); setState(() { _selectedRow = int.parse(p[0]); _selectedCol = int.parse(p[1]); }); } }))),
        const SizedBox(height: 32),
        Consumer<DroneProvider>(builder: (context, p, _) => CustomButton(text: 'UPDATE DRONE', isLoading: p.isLoading, onPressed: _handleUpdate)),
      ]))),
    );
  }
}