import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const AdminDashboard({
    Key? key,
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Vehicle> vehicles = [];
  List<StageData> stageData = [];
  int totalVehicles = 0;
  int activeVehiclesInInteractiveBay = 0;
  int activeVehiclesInMaintenance = 0;
  int activeVehiclesInWashing = 0;
  int activeVehiclesInFinalInspection = 0;

  Future<void> fetchVehicles() async {
    setState(() => vehicles = []);
    final url = Uri.parse('http://192.168.108.49:5000/api/vehicles');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          vehicles = data['vehicles']
              .map<Vehicle>((json) => Vehicle.fromJson(json))
              .toList();
          totalVehicles = vehicles.length;
          stageData = calculateStageData(vehicles);
          activeVehiclesInInteractiveBay = stageData
              .firstWhere((element) => element.stageName == 'Interactive Bay')
              .activeVehicles;
          activeVehiclesInMaintenance = stageData
              .firstWhere((element) => element.stageName == 'Maintainance')
              .activeVehicles;
          activeVehiclesInWashing = stageData
              .firstWhere((element) => element.stageName == 'Washing')
              .activeVehicles;
          activeVehiclesInFinalInspection = stageData
              .firstWhere((element) => element.stageName == 'Final Inspection')
              .activeVehicles;
        });
      } else {
        print('Failed to load vehicles');
      }
    } catch (error) {
      print('Error fetching vehicles: $error');
    }
  }

  List<StageData> calculateStageData(List<Vehicle> vehicles) {
    final stageData = [
      StageData(stageName: 'Interactive Bay', activeVehicles: 0),
      StageData(stageName: 'Maintainance', activeVehicles: 0),
      StageData(stageName: 'Washing', activeVehicles: 0),
      StageData(stageName: 'Final Inspection', activeVehicles: 0),
    ];

    for (var vehicle in vehicles) {
      for (var stage in vehicle.stages) {
        if (stage['stageName'] == 'Interactive Bay' &&
            stage['eventType'] == 'Start') {
          stageData
              .firstWhere((element) => element.stageName == 'Interactive Bay')
              .activeVehicles++;
        } else if (stage['stageName'] == 'Maintainance' &&
            stage['eventType'] == 'Start') {
          stageData
              .firstWhere((element) => element.stageName == 'Maintainance')
              .activeVehicles++;
        } else if (stage['stageName'] == 'Washing' &&
            stage['eventType'] == 'Start') {
          stageData
              .firstWhere((element) => element.stageName == 'Washing')
              .activeVehicles++;
        } else if (stage['stageName'] == 'Final Inspection' &&
            stage['eventType'] == 'Start') {
          stageData
              .firstWhere((element) => element.stageName == 'Final Inspection')
              .activeVehicles++;
        }
      }
    }

    return stageData;
  }

  @override
  void initState() {
    super.initState();
    fetchVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 20),
            _buildStageChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildDashboardCard(
            "Total Vehicles", totalVehicles.toString(), Colors.blue),
        _buildDashboardCard("Active in Interactive Bay",
            activeVehiclesInInteractiveBay.toString(), Colors.green),
        _buildDashboardCard("Active in Maintenance",
            activeVehiclesInMaintenance.toString(), Colors.orange),
        _buildDashboardCard("Active in Washing",
            activeVehiclesInWashing.toString(), Colors.red),
        _buildDashboardCard("Active in Final Inspection",
            activeVehiclesInFinalInspection.toString(), Colors.purple),
      ],
    );
  }

  Widget _buildDashboardCard(String title, String value, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24,
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Active Vehicles by Stage",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: stageData
                          .asMap()
                          .entries
                          .map((entry) => FlSpot(entry.key.toDouble(),
                              entry.value.activeVehicles.toDouble()))
                          .toList(),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.blue],
                      ),
                      barWidth: 5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < stageData.length) {
                            return Text(
                              stageData[value.toInt()].stageName,
                              style: const TextStyle(fontSize: 10),
                            );
                          } else {
                            return const Text('');
                          }
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Vehicle {
  final String vehicleNumber;
  final List<dynamic> stages;

  Vehicle({required this.vehicleNumber, required this.stages});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vehicleNumber: json['vehicleNumber'],
      stages: json['stages'],
    );
  }
}

class StageData {
  final String stageName;
  int activeVehicles;

  StageData({required this.stageName, required this.activeVehicles});
}
