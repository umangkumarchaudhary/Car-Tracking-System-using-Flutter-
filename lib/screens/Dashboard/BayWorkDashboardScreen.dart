import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BayWorkDashboardScreen extends StatefulWidget {
  final String authToken;
  final String dashboardTitle;

  const BayWorkDashboardScreen({Key? key, required this.authToken, required this.dashboardTitle})
      : super(key: key);

  @override
  State<BayWorkDashboardScreen> createState() => _BayWorkDashboardScreenState();
}

class _BayWorkDashboardScreenState extends State<BayWorkDashboardScreen> {
  String filter = "today";
  bool showActive = true;
  bool showCompleted = true;
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse("http://192.168.58.49:5000/api/dashboard/bay-work?filter=$filter");
      final response = await http.get(url, headers: {"Authorization": "Bearer ${widget.authToken}"});

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success']) {
          setState(() {
            dashboardData = body['data'];
          });
        } else {
          print("❌ API Error: ${body['message']}");
        }
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error: $e");
    }
    setState(() => isLoading = false);
  }

  String formatTime(String? isoString) {
    if (isoString == null) return "-";
    final date = DateTime.parse(isoString);
    return DateFormat("dd-MM-yyyy HH:mm:ss").format(date.toLocal());
  }

  void _showVehicleDetails(BuildContext context, Map<String, dynamic> vehicle, bool isActive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Bay Work Details",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Vehicle Number: ${vehicle['vehicleNumber'] ?? 'N/A'}"),
                Text("Entry Time: ${formatTime(vehicle['entryTime'])}"),
                Text("Work Type: ${vehicle['workType'] ?? '-'}"),
                Text("Bay Number: ${vehicle['bayNumber']?.toString() ?? '-'}"),
                Text("Start Time: ${formatTime(vehicle['startTime'])}"),
                Text("End Time: ${formatTime(vehicle['endTime'])}"),
                Text("Performed By: ${vehicle['performedBy'] ?? 'Unknown'}"),
                Text("Total Duration: ${vehicle['durationMinutes'] ?? '0'} mins"),
                Text("Paused Time: ${vehicle['pausedMinutes'] ?? '0'} mins"),
                Text("Pause Count: ${vehicle['pauseCount'] ?? '0'}"),
                const SizedBox(height: 10),
                Text(
                  isActive ? "Status: Active" : "Status: Completed",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleTile(Map<String, dynamic> vehicle, bool isActive) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade100, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVehicleDetails(context, vehicle, isActive),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Colors.orangeAccent, Colors.deepOrange]
                        : [Colors.greenAccent, Colors.teal],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vehicle['vehicleNumber'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'COMPLETED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Work Type: ${vehicle['workType'] ?? '-'} | Bay: ${vehicle['bayNumber']?.toString() ?? '-'}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "By: ${vehicle['performedBy'] ?? 'Unknown'}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Work: ${vehicle['durationMinutes'] ?? '0'}m | Pause: ${vehicle['pausedMinutes'] ?? '0'}m",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Pauses: ${vehicle['pauseCount'] ?? '0'}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade800, Colors.indigo.shade900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "SUMMARY",
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: Colors.blue.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    filter.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildStatItem(Icons.loop, "Processed", (summary['totalCompleted'] + summary['totalActive']).toString()),
                _buildStatItem(Icons.check_circle, "Completed", summary['totalCompleted']?.toString() ?? '0'),
                _buildStatItem(Icons.timelapse, "Active", summary['totalActive']?.toString() ?? '0'),
                _buildStatItem(Icons.timer, "Avg. Work Time", "${summary['averageDuration'] ?? '0'} mins"),
                _buildStatItem(Icons.pause_circle, "Avg. Paused", "${summary['averagePausedTime'] ?? '0'} mins"),
                _buildStatItem(Icons.pause, "Avg. Pauses", "${summary['averagePauses'] ?? '0'}"),
                _buildStatItem(Icons.speed, "Efficiency", "${summary['efficiency'] ?? '0'}%"),
                _buildStatItem(Icons.warning, "Delayed", summary['delayedVehicles']?.toString() ?? '0'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade200,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusToggle(String label, int count, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.blue.shade800 : Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = filter == "all"
        ? dashboardData?['allTime']?['summary'] ?? {}
        : dashboardData?['today']?['summary'] ?? {};

    final activeVehicles = filter == "all"
        ? dashboardData?['allTime']?['activeVehicles'] ?? []
        : dashboardData?['today']?['activeVehicles'] ?? [];

    final completedVehicles = filter == "all"
        ? dashboardData?['allTime']?['completedVehicles'] ?? []
        : dashboardData?['today']?['completedVehicles'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dashboardTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.1),
              child: IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: fetchDashboardData,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchDashboardData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Time Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Time Filter", style: TextStyle(fontWeight: FontWeight.w500)),
                          DropdownButton<String>(
                            value: filter,
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(value: "today", child: Text("Today")),
                              DropdownMenuItem(value: "all", child: Text("All Time")),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  filter = newValue;
                                  fetchDashboardData();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summary Card
                    _buildSummaryCard(summary),
                    const SizedBox(height: 20),

                    // Status Toggles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusToggle(
                          "Active",
                          activeVehicles.length,
                          showActive,
                          () {
                            setState(() => showActive = !showActive);
                          },
                        ),
                        _buildStatusToggle(
                          "Completed",
                          completedVehicles.length,
                          showCompleted,
                          () {
                            setState(() => showCompleted = !showCompleted);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Lists
                    if (showActive) ...[
                      const Text(
                        "Active Bay Work",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (activeVehicles.isEmpty)
                        const Text("No active bay work vehicles.")
                      else
                        ...activeVehicles.map((vehicle) => _buildVehicleTile(vehicle, true)).toList(),
                    ],
                    if (showCompleted) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "Completed Bay Work",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (completedVehicles.isEmpty)
                        const Text("No completed bay work vehicles.")
                      else
                        ...completedVehicles.map((vehicle) => _buildVehicleTile(vehicle, false)).toList(),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}
