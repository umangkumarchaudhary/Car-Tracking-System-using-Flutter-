import 'package:flutter/material.dart';
import 'package:car_tracking_new/screens/helpers.dart';

class AllVehiclesScreen extends StatelessWidget {
  final List<dynamic> allVehicles;

  const AllVehiclesScreen({Key? key, required this.allVehicles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (allVehicles.isEmpty) {
      return Center(
        child: Text(
          "No vehicles available",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            "🚗 All Vehicles & Stage History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        Column(
          children: allVehicles.map((vehicle) {
            return Card(
              elevation: 3,
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: ExpansionTile(
                title: Text(
                  "🚗 ${vehicle['vehicleNumber']}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  vehicle['currentStage'] != null ? "Current: ${vehicle['currentStage']}" : "Completed",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                children: vehicle['stageTimeline'].map<Widget>((stage) {
                  return ListTile(
                    title: Text(
                      "🔹 ${stage['stageName']}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📅 Date: ${formatDate(stage['startTime'])}"),
                        Text("⏳ Start: ${formatTimeOnly(stage['startTime'])}"),
                        Text("✅ End: ${stage['endTime'] != null ? formatTimeOnly(stage['endTime']) : 'In Progress'}"),
                      ],
                    ),
                    trailing: Text(
                      stage['duration'],
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String formatDate(String timestamp) {
    return Helpers.formatDate(timestamp);
  }

  String formatTimeOnly(String timestamp) {
    return Helpers.formatTimeOnly(timestamp);
  }
}
