import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String BASE_URL = "https://mercedes-benz-car-tracking-system.onrender.com/api";

  Future<List<dynamic>> fetchStagePerformance(String days) async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/dashboard/stage-performance?days=$days'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['avgStageTimes'];
      } else {
        print("❌ Error: Failed to fetch stage performance. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Exception in fetchStagePerformance: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchVehicleCountPerStage(String days) async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/dashboard/vehicle-count-per-stage?days=$days'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['vehicleCountPerStage'];
      } else {
        print("❌ Error: Failed to fetch vehicle count per stage. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Exception in fetchVehicleCountPerStage: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchAllVehicles() async {
    try {
      final response = await http.get(Uri.parse('$BASE_URL/dashboard/all-vehicles'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['vehicles'];
      } else {
        print("❌ Error: Failed to fetch all vehicles. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Exception in fetchAllVehicles: $e");
      return [];
    }
  }
}
