import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VehicleStagesSummary extends StatefulWidget {
  final String token;

  const VehicleStagesSummary({required this.token, Key? key}) : super(key: key);

  @override
  _VehicleStagesSummaryState createState() => _VehicleStagesSummaryState();
}

class _VehicleStagesSummaryState extends State<VehicleStagesSummary> {
  final String baseUrl = "https://final-mb-cts.onrender.com/api/dashboard";
  Map<String, dynamic> stageAverages = {};
  Map<String, dynamic> specialStages = {};
  Map<String, dynamic> jobCardReceived = {};
  Map<String, dynamic> bayWork = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    try {
      final headers = {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json'
      };

      final responses = await Future.wait([
        http.get(Uri.parse("$baseUrl/stage-averages"), headers: headers),
        http.get(Uri.parse("$baseUrl/special-stage-averages"), headers: headers),
        http.get(Uri.parse("$baseUrl/job-card-received-metrics"), headers: headers),
        http.get(Uri.parse("$baseUrl/bay-work-metrics"), headers: headers),
      ]);

      setState(() {
        stageAverages = jsonDecode(responses[0].body)["data"];
        specialStages = jsonDecode(responses[1].body)["data"];
        jobCardReceived = jsonDecode(responses[2].body)["data"];
        bayWork = jsonDecode(responses[3].body)["data"];
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error: $e");
      setState(() => isLoading = false);
    }
  }

  Widget buildSection(String title, Map<String, dynamic> data) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: data.entries.map((periodEntry) {
        return ExpansionTile(
          title: Text("📅 ${periodEntry.key}"),
          children: (periodEntry.value as Map<String, dynamic>).entries.map((stageEntry) {
            final details = stageEntry.value["details"] ?? [];
            return ExpansionTile(
              title: Text("🔧 ${stageEntry.key}"),
              subtitle: Text("Avg: ${stageEntry.value["average"]}, Count: ${stageEntry.value["count"]}"),
              children: details.map<Widget>((item) {
                return ListTile(
                  title: Text("🚗 ${item["vehicleNumber"]}"),
                  subtitle: Text("⏱ ${item["duration"]}"),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Start: ${item["startTime"]}"),
                      Text("End: ${item["endTime"]}"),
                    ],
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget buildBayWorkSection() {
    return ExpansionTile(
      title: const Text(
        "Bay Work Summary",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: bayWork.entries.map((periodEntry) {
        final data = periodEntry.value as Map<String, dynamic>;
        return ExpansionTile(
          title: Text("📅 ${periodEntry.key}"),
          children: [
            ExpansionTile(
              title: const Text("📊 Overall"),
              subtitle: Text("Avg: ${data["overall"]["average"]}, Count: ${data["overall"]["count"]}"),
            ),
            ...data["byWorkType"].entries.map<Widget>((entry) {
              return ExpansionTile(
                title: Text("🔧 ${entry.key}"),
                subtitle: Text("Avg: ${entry.value["average"]}, Count: ${entry.value["count"]}"),
              );
            })
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Stage Summary"),
        backgroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAllData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    buildSection("Restricted Stage Averages", stageAverages),
                    buildSection("Special Stage Averages", specialStages),
                    buildSection("Job Card Received Metrics", jobCardReceived),
                    buildBayWorkSection(),
                  ],
                ),
              ),
            ),
    );
  }
}
