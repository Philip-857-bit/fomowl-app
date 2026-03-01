import 'package:flutter/foundation.dart';

/// Base service that provides common functionality
abstract class BaseService extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  @protected
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }
}
