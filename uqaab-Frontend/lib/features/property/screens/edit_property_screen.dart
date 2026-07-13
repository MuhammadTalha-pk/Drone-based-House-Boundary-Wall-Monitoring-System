import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../provider/property_provider.dart';

class EditPropertyScreen extends StatefulWidget {
  final String propertyId;

  const EditPropertyScreen({super.key, required this.propertyId});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;

  late TextEditingController _xLasersController;
  late TextEditingController _yLasersController;

  late TextEditingController _boxWidthController;
  late TextEditingController _boxLengthController;
  late TextEditingController _gridHeightController;

  double _latitude = 0;
  double _longitude = 0;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();

    final property = context.read<PropertyContextProvider>().selectedProperty;

    _nameController = TextEditingController(text: property?.name ?? '');
    _addressController = TextEditingController(text: property?.address ?? '');

    _xLasersController =
        TextEditingController(text: '${property?.laserGrid.xLasers ?? 3}');
    _yLasersController =
        TextEditingController(text: '${property?.laserGrid.yLasers ?? 8}');

    _boxWidthController =
        TextEditingController(text: '${property?.laserGrid.boxWidth ?? 2.0}');
    _boxLengthController =
        TextEditingController(text: '${property?.laserGrid.boxLength ?? 0.6}');
    _gridHeightController =
        TextEditingController(text: '${property?.laserGrid.gridHeight ?? 2.4}');

    _latitude = property?.latitude ?? 33.6844;
    _longitude = property?.longitude ?? 73.0479;

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

    final provider = context.read<PropertyProvider>();

    final success = await provider.updateProperty(
      id: widget.propertyId,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
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
      Helpers.showSuccessSnackBar(context, 'Property updated!');
      Navigator.of(context).pop();
    } else {
      Helpers.showSnackBar(context, provider.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.editProperty),

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
                hintText: 'Property name',
                labelText: '${AppStrings.propertyName} *',
                prefixIcon: Icons.home_outlined,
                validator: (v) =>
                    Validators.validateRequired(v, 'Property name'),
              ),

              const SizedBox(height: 16),

              /// ADDRESS
              CustomTextField(
                controller: _addressController,
                hintText: 'Address',
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
                                Validators.validateNumber(v, 'X'),
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
                                Validators.validateNumber(v, 'Y'),
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
                                Validators.validateNumber(v, 'Width'),
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
                                Validators.validateNumber(v, 'Length'),
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
                          Validators.validateNumber(v, 'Height'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// MAP
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),

                  child: GoogleMap(

                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude, _longitude),
                      zoom: 15,
                    ),

                    onMapCreated: (controller) {
                      _mapController = controller;
                    },

                    onTap: (LatLng position) {
                      setState(() {
                        _latitude = position.latitude;
                        _longitude = position.longitude;
                      });
                    },

                    markers: {
                      Marker(
                        markerId: const MarkerId("selected"),
                        position: LatLng(_latitude, _longitude),
                      )
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
                    text: AppStrings.saveChanges,
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