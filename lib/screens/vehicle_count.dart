import 'package:flutter/material.dart';

class VehicleCountScreen extends StatelessWidget {
  final List<dynamic> vehicleCountPerStage;

  const VehicleCountScreen({Key? key, required this.vehicleCountPerStage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (vehicleCountPerStage.isEmpty) {
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
            "📊 Vehicle Count Per Stage",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        buildTable(["Stage", "Total Vehicles"], vehicleCountPerStage.map<List<String>>((stage) {
          return [stage["stageName"].toString(), stage["totalVehicles"].toString()];
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
}
