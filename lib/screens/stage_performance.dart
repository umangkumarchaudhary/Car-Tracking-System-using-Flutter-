import 'package:flutter/material.dart';
import 'package:car_tracking_new/screens/helpers.dart';

class StagePerformanceScreen extends StatelessWidget {
  final List<dynamic> avgStageTimes;

  const StagePerformanceScreen({Key? key, required this.avgStageTimes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (avgStageTimes.isEmpty) {
      return Center(
        child: Text(
          "No data available",
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
            "🚀 Stage-wise Performance (Avg. Time)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        buildTable(["Stage", "Avg Time"], avgStageTimes.map<List<String>>((stage) {
          return [stage["stageName"].toString(), formatTime(stage["avgTime"])];
        }).toList()),
      ],
    );
  }

  Widget buildTable(List<String> headers, List<List<String>> rows) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Table(
            border: TableBorder.all(color: Colors.black),
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(color: Colors.blueAccent),
                children: headers
                    .map((header) => Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            header,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ))
                    .toList(),
              ),
              // Data Rows
              ...rows.map((row) => TableRow(
                    children: row.map((cell) => Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(cell, textAlign: TextAlign.center),
                        )).toList(),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String formatTime(num milliseconds) {
    return Helpers.formatTime(milliseconds); // Using the formatTime function from helpers.dart
  }
}
