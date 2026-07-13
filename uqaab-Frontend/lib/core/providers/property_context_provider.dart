import 'package:flutter/material.dart';
import '../../models/property_model.dart';

class PropertyContextProvider extends ChangeNotifier {
  String? _selectedPropertyId;
  PropertyModel? _selectedProperty;

  String? get selectedPropertyId => _selectedPropertyId;
  PropertyModel? get selectedProperty => _selectedProperty;

  void selectProperty(PropertyModel property) {
    _selectedPropertyId = property.id;
    _selectedProperty = property;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPropertyId = null;
    _selectedProperty = null;
    notifyListeners();
  }
}