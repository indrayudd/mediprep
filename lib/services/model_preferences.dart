import 'package:shared_preferences/shared_preferences.dart';

class ModelPreferences {
  static const _selectedModelKey = 'selected_model_id';
  static const _hfTokenKey = 'hf_access_token';

  static Future<void> setSelectedModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, modelId);
  }

  static Future<String?> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey);
  }

  static Future<void> clearSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedModelKey);
  }

  static Future<void> setHfToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hfTokenKey, token);
  }

  static Future<String?> getHfToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hfTokenKey);
  }

  static Future<void> clearHfToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hfTokenKey);
  }
}
