import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'UserDashboard.dart'; // ✅ Import UserDashboard

const String BASE_URL = "http://192.168.58.49:5000/api";

class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  AdminDashboard({required this.token, required this.onLogout});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> avgStageTimes = [];
  List<dynamic> vehicleCountPerStage = [];
  List<dynamic> allVehicles = [];
  int selectedSection = 0;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    await fetchStagePerformance();
    await fetchVehicleCountPerStage();
    await fetchAllVehicles();
  }

  Future<void> fetchStagePerformance() async {
    final response = await http.get(Uri.parse('$BASE_URL/dashboard/stage-performance'));
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body)['avgStageTimes'];
      List<String> stageOrder = [
        "Interactive Bay",
        "Job Card Creation + Customer Approval",
        "Bay Allocation Started",
        "Bay Work: PM",
        "Additional Work Job Approval",
        "Final Inspection",
        "Washing"
      ];
      data.sort((a, b) => stageOrder.indexOf(a["stageName"]).compareTo(stageOrder.indexOf(b["stageName"])));
      setState(() => avgStageTimes = data);
    }
  }

  Future<void> fetchVehicleCountPerStage() async {
    final response = await http.get(Uri.parse('$BASE_URL/dashboard/vehicle-count-per-stage'));
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body)['vehicleCountPerStage'];
      List<String> stageOrder = [
        "Security Gate",
        "Interactive Bay",
        "Job Card Creation + Customer Approval",
        "Bay Allocation Started",
        "Bay Work: PM",
        "Final Inspection",
        "Washing"
      ];
      data.sort((a, b) => stageOrder.indexOf(a["stageName"]).compareTo(stageOrder.indexOf(b["stageName"])));
      setState(() => vehicleCountPerStage = data);
    }
  }

  Future<void> fetchAllVehicles() async {
    final response = await http.get(Uri.parse('$BASE_URL/dashboard/all-vehicles'));
    if (response.statusCode == 200) {
      setState(() => allVehicles = jsonDecode(response.body)['vehicles']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_account), // ✅ New button
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDashboard(
                    token: widget.token,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            tooltip: "Go to User Dashboard",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchDashboardData,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                SectionButton("📊 Stage Performance", 0),
                SizedBox(height: 10),
                SectionButton("🚗 Vehicle Count", 1),
                SizedBox(height: 10),
                SectionButton("📜 All Vehicles", 2),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedSection == 0) ...[
                    SectionTitle("🚀 Stage-wise Performance (Avg. Time)"),
                    buildStagePerformance(),
                  ],
                  if (selectedSection == 1) ...[
                    SectionTitle("📊 Vehicle Count Per Stage"),
                    buildVehicleCount(),
                  ],
                  if (selectedSection == 2) ...[
                    SectionTitle("🚗 All Vehicles & Stage History"),
                    buildAllVehicles(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget SectionButton(String title, int index) {
    return ElevatedButton(
      onPressed: () => setState(() => selectedSection = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: selectedSection == index ? Colors.blue : Colors.grey,
        minimumSize: Size(double.infinity, 50),
      ),
      child: Text(title, style: TextStyle(color: Colors.white)),
    );
  }

  Widget buildStagePerformance() {
    return buildTable(["Stage", "Avg Time"], avgStageTimes.map<List<String>>((stage) {
      return [stage["stageName"].toString(), formatTime(stage["avgTime"])];
    }).toList());
  }

  Widget buildVehicleCount() {
    return buildTable(["Stage", "Total Vehicles"], vehicleCountPerStage.map<List<String>>((stage) {
      return [stage["stageName"].toString(), stage["totalVehicles"].toString()];
    }).toList());
  }

  Widget buildAllVehicles() {
    return Column(
      children: allVehicles.map((vehicle) {
        return Card(
          child: ExpansionTile(
            title: Text("🚗 ${vehicle['vehicleNumber']}"),
            subtitle: Text(vehicle['currentStage'] != null ? "Current: ${vehicle['currentStage']}" : "Completed"),
            children: vehicle['stageTimeline'].map<Widget>((stage) {
              return ListTile(
                title: Text("🔹 ${stage['stageName']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date: ${formatDate(stage['startTime'])}"),
                    Text("Start: ${formatTimeOnly(stage['startTime'])}"),
                    Text("End: ${stage['endTime'] != null ? formatTimeOnly(stage['endTime']) : 'In Progress'}"),
                  ],
                ),
                trailing: Text(stage['duration']),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  DateTime toIST(String timestamp) {
    DateTime utcDate = DateTime.parse(timestamp).toUtc();
    return utcDate.add(Duration(hours: 5, minutes: 30));
  }

  String formatDate(String timestamp) {
    DateTime date = toIST(timestamp);
    return DateFormat('dd-MM-yyyy').format(date);
  }

  String formatTimeOnly(String timestamp) {
    DateTime date = toIST(timestamp);
    return DateFormat('hh:mm a').format(date);
  }

  String formatTime(num milliseconds) {
    if (milliseconds == 0) return "N/A";
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final hours = (minutes / 60).floor();
    return "${hours}h ${minutes % 60}m ${seconds % 60}s";
  }

  Widget SectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Widget buildTable(List<String> headers, List<List<String>> rows) {
    return Card(
      child: Column(
        children: [
          Table(
            border: TableBorder.all(color: Colors.black),
            children: rows.map((row) => TableRow(
              children: row.map((cell) => Padding(padding: EdgeInsets.all(8), child: Text(cell))).toList(),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
