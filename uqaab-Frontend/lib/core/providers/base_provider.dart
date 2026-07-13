import 'package:flutter/material.dart';

enum ViewState { idle, loading, error, success }

class BaseProvider extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String _errorMessage = '';

  ViewState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;

  void setState(ViewState state) {
    _state = state;
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _state = ViewState.error;
    notifyListeners();
  }

  void setIdle() {
    _state = ViewState.idle;
    notifyListeners();
  }

  void setLoading() {
    _state = ViewState.loading;
    notifyListeners();
  }

  void setSuccess() {
    _state = ViewState.success;
    notifyListeners();
  }
}