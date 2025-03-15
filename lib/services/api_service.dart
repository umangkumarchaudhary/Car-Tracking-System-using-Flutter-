import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:5000"; // Change this for deployment

  // ✅ Function to check in/out vehicle
  static Future<Map<String, dynamic>> checkVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/vehicle-check"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(vehicleData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Error: ${response.body}"};
      }
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }
}
