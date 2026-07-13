import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/property_provider.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  final _xLasersController = TextEditingController(text: '3');
  final _yLasersController = TextEditingController(text: '8');

  final _boxWidthController = TextEditingController(text: '2.0');
  final _boxLengthController = TextEditingController(text: '0.6');
  final _gridHeightController = TextEditingController(text: '2.4');

  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    final userLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _selectedLocation = userLocation;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(userLocation),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _xLasersController.dispose();
    _yLasersController.dispose();
    _boxWidthController.dispose();
    _boxLengthController.dispose();
    _gridHeightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {

    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      Helpers.showSnackBar(context, "Please select property location", isError: true);
      return;
    }

    final provider = context.read<PropertyProvider>();

    final success = await provider.createProperty(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      laserGrid: {
        'x_lasers': int.parse(_xLasersController.text),
        'y_lasers': int.parse(_yLasersController.text),
        'box_width': double.parse(_boxWidthController.text),
        'box_length': double.parse(_boxLengthController.text),
        'grid_height': double.parse(_gridHeightController.text),
      },
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSuccessSnackBar(context, "Property created!");
      context.go(AppRoutes.propertyList);
    } else {
      Helpers.showSnackBar(context, provider.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.addNewProperty),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// PROPERTY NAME
              CustomTextField(
                controller: _nameController,
                hintText: "e.g., Ali's Warehouse",
                labelText: '${AppStrings.propertyName} *',
                prefixIcon: Icons.home_outlined,
                validator: (v) =>
                    Validators.validateRequired(v, "Property name"),
              ),

              const SizedBox(height: 16),

              /// ADDRESS
              CustomTextField(
                controller: _addressController,
                hintText: "Address",
                labelText: AppStrings.address,
                prefixIcon: Icons.location_on_outlined,
              ),

              const SizedBox(height: 24),

              /// LASER GRID SETUP
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      AppStrings.laserGridSetup,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [

                        Expanded(
                          child: CustomTextField(
                            controller: _xLasersController,
                            hintText: '3',
                            labelText: AppStrings.xLasers,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.validateNumber(v, 'X Lasers'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: CustomTextField(
                            controller: _yLasersController,
                            hintText: '8',
                            labelText: AppStrings.yLasers,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.validateNumber(v, 'Y Lasers'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [

                        Expanded(
                          child: CustomTextField(
                            controller: _boxWidthController,
                            hintText: '2.0',
                            labelText: AppStrings.boxWidth,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.validateNumber(v, 'Box width'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: CustomTextField(
                            controller: _boxLengthController,
                            hintText: '0.6',
                            labelText: AppStrings.boxLength,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                Validators.validateNumber(v, 'Box length'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    CustomTextField(
                      controller: _gridHeightController,
                      hintText: '2.4',
                      labelText: AppStrings.gridHeight,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.validateNumber(v, 'Grid height'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// PIN LOCATION
              const Text(
                '${AppStrings.pinLocation} *',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),

                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(33.6844, 73.0479),
                      zoom: 15,
                    ),

                    onMapCreated: (controller) {
                      _mapController = controller;
                    },

                    onTap: (LatLng position) {
                      setState(() {
                        _selectedLocation = position;
                      });
                    },

                    markers: _selectedLocation == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId("selected"),
                              position: _selectedLocation!,
                            ),
                          },

                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              /// SAVE BUTTON
              Consumer<PropertyProvider>(
                builder: (context, provider, _) {
                  return CustomButton(
                    text: AppStrings.saveProperty,
                    isLoading: provider.isLoading,
                    onPressed: _handleSave,
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}