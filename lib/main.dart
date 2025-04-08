import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Add this import
import 'newAuth_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  runApp(MyApp(initialToken: token));
}