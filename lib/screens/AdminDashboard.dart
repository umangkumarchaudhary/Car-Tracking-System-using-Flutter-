import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:car_tracking_new/screens/VehicleSummary.dart';
import 'package:car_tracking_new/screens/VehicleStagesSummary.dart';
import 'package:car_tracking_new/screens/LiveStatusScreen.dart';
import 'package:car_tracking_new/screens/UserList.dart';
import 'package:car_tracking_new/screens/Dashboard/StageDashboard.dart';  // Importing StageDashboard.dart

class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const AdminDashboard({
    required this.token,
    required this.onLogout,
    super.key,
  });

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? searchedVehicle;

  Future<void> fetchVehicleByNumber(String vehicleNumber) async {
    final trimmedNumber = vehicleNumber.trim().toUpperCase();
    if (trimmedNumber.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://final-mb-cts.onrender.com/api/vehicles/$trimmedNumber'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => searchedVehicle = data['vehicle']);
      } else {
        setState(() => searchedVehicle = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vehicle not found')),
        );
      }
    } catch (e) {
      print("Error: $e");
      setState(() => searchedVehicle = null);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> navigateToVehicleSummary() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://final-mb-cts.onrender.com/api/vehicle-summary'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: const Text("Vehicle Summary", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.black,
              ),
              body: SingleChildScrollView(
                child: VehicleSummary(
                  vehiclesInside: data['vehiclesInside'],
                  stats: data['stats'],
                  avgTimeSpent: data['avgTimeSpent'],
                  longestActive: data['longestActive'],
                ),
              ),
            ),
          ),
        );
      } else {
        throw Exception('Failed to load summary');
      }
    } catch (e) {
      print("Error fetching vehicle summary: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading summary: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void navigateToVehicleStagesSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleStagesSummary(token: widget.token),
      ),
    );
  }

  void navigateToLiveStatus() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStatusScreen(token: widget.token),
      ),
    );
  }

  void navigateToUserList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserList(authToken: widget.token),
      ),
    );
  }

  void navigateToStageDashboard() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StageDashboard(authToken: widget.token),  // Pass the authToken here
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter vehicle number',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => fetchVehicleByNumber(_searchController.text),
                      ),
                    ),
                  ),
                  if (searchedVehicle != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.grey[850],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("🚗 Vehicle: ${searchedVehicle!['vehicleNumber']}", style: const TextStyle(color: Colors.white)),
                          Text("📅 Entry Time: ${searchedVehicle!['entryTime']}", style: const TextStyle(color: Colors.white)),
                          Text("🛑 Exit Time: ${searchedVehicle!['exitTime'] ?? 'Still inside'}", style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 5),
                          const Text("📍 Stages:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ...List<Widget>.from((searchedVehicle!['stages'] as List).map((stage) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                "${stage['timestamp']} - ${stage['eventType']} - ${stage['stageName']}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          })),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton(
                        onPressed: navigateToVehicleSummary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[850],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Vehicle Summary"),
                      ),
                      ElevatedButton(
                        onPressed: navigateToVehicleStagesSummary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Vehicle Stages"),
                      ),
                      ElevatedButton(
                        onPressed: navigateToLiveStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Live Status"),
                      ),
                      ElevatedButton(
                        onPressed: navigateToUserList,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("User Management"),
                      ),
                      ElevatedButton(
                        onPressed: navigateToStageDashboard,  // Button to navigate to StageDashboard
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Stage Dashboard"),  // Text for the button
                      ),
                    ],
                  )
                ],
              ),
      ),
    );
  }
}
