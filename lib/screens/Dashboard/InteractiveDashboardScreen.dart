import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class InteractiveDashboardScreen extends StatefulWidget {
  final String authToken;

  const InteractiveDashboardScreen({Key? key, required this.authToken}) 
    : super(key: key);

  @override
  State<InteractiveDashboardScreen> createState() => _InteractiveDashboardScreenState();
}

class _InteractiveDashboardScreenState extends State<InteractiveDashboardScreen> {
  String _filter = "today";
  bool _showActive = true;
  bool _showCompleted = true;
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _dashboardData = {};
  final Map<String, Color> _statusColors = {
    'active': Colors.orange,
    'completed': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!await _checkInternetConnection()) {
      _showErrorSnackbar('No internet connection');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse("http://192.168.58.49:5000/api/dashboard/interactive-bay?filter=$_filter");
      final response = await http.get(
        url, 
        headers: {
          "Authorization": "Bearer ${widget.authToken}",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is Map) {
          setState(() {
            _dashboardData = Map<String, dynamic>.from(body['data']);
          });
        } else {
          _showErrorSnackbar('Invalid data format received');
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "-";
    try {
      final date = DateTime.parse(isoString);
      return DateFormat("dd-MM-yyyy HH:mm:ss").format(date.toLocal());
    } catch (e) {
      return "Invalid Date";
    }
  }

  void _showVehicleDetails(BuildContext context, Map<String, dynamic> vehicle, bool isActive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Vehicle Details",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Vehicle Number: ${vehicle['vehicleNumber']?.toString() ?? 'N/A'}"),
                Text("Entry Time: ${_formatTime(vehicle['entryTime']?.toString())}"),
                Text("Start Time: ${_formatTime(vehicle['startTime']?.toString())}"),
                Text("End Time: ${_formatTime(vehicle['endTime']?.toString())}"),
                Text("Performed By: ${vehicle['performedBy']?.toString() ?? 'Unknown'}"),
                Text("Duration: ${vehicle['durationMinutes']?.toString() ?? '0'} minutes"),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicleTile(Map<String, dynamic> vehicle, bool isActive) {
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'N/A';
    final performedBy = vehicle['performedBy']?.toString() ?? 'Unknown';
    final duration = vehicle['durationMinutes']?.toString() ?? '0';

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
                height: 60,
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
                          vehicleNumber,
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
                    const SizedBox(height: 6),
                    Text(
                      "By: $performedBy",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$duration mins",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
    final totalProcessed = summary['totalProcessed']?.toString() ?? '0';
    final totalCompleted = summary['totalCompleted']?.toString() ?? '0';
    final totalActive = summary['totalActive']?.toString() ?? '0';
    final avgDuration = "${summary['averageDurationMinutes']?.toString() ?? '0'} mins";
    final delayedVehicles = summary['delayedVehicles']?.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF283593)],
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
                    _filter.toUpperCase(),
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
                _buildStatItem(Icons.loop, "Processed", totalProcessed),
                _buildStatItem(Icons.check_circle, "Completed", totalCompleted),
                _buildStatItem(Icons.timelapse, "Active", totalActive),
                _buildStatItem(Icons.timer, "Avg. Duration", avgDuration),
                _buildStatItem(Icons.warning, "Delayed", delayedVehicles),
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

  void _handleApiError(http.Response response) {
    final statusCode = response.statusCode;
    _showErrorSnackbar('API Error: $statusCode');
  }

  void _handleNetworkError(Object error) {
    debugPrint('Network error: $error');
    _showErrorSnackbar('Network error occurred');
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getActiveVehicles() {
    final data = _filter == "all" 
        ? _dashboardData['allTime'] 
        : _dashboardData['today'];
    
    if (data is Map && data['activeVehicles'] is List) {
      return List<Map<String, dynamic>>.from(data['activeVehicles']);
    }
    return [];
  }

  List<Map<String, dynamic>> _getCompletedVehicles() {
    final data = _filter == "all" 
        ? _dashboardData['allTime'] 
        : _dashboardData['today'];
    
    if (data is Map && data['completedVehicles'] is List) {
      return List<Map<String, dynamic>>.from(data['completedVehicles']);
    }
    return [];
  }

  Map<String, dynamic> _getSummaryData() {
    final data = _filter == "all" 
        ? _dashboardData['allTime'] 
        : _dashboardData['today'];
    
    if (data is Map && data['summary'] is Map) {
      return Map<String, dynamic>.from(data['summary']);
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final activeVehicles = _getActiveVehicles();
    final completedVehicles = _getCompletedVehicles();
    final summary = _getSummaryData();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Interactive Bay Dashboard"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1A237E)],
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
                onPressed: _fetchDashboardData,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Time Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                            value: _filter,
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(value: "today", child: Text("Today")),
                              DropdownMenuItem(value: "all", child: Text("All Time")),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _filter = value);
                                _fetchDashboardData();
                              }
                            },
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Toggles
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatusToggle(
                            "Active",
                            activeVehicles.length,
                            _showActive,
                            () => setState(() => _showActive = !_showActive),
                          ),
                          _buildStatusToggle(
                            "Completed",
                            completedVehicles.length,
                            _showCompleted,
                            () => setState(() => _showCompleted = !_showCompleted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summary Card
                    _buildSummaryCard(summary),
                    const SizedBox(height: 20),

                    // Vehicle Lists
                    if (_showActive && activeVehicles.isNotEmpty) ...[
                      const Text(
                        "Active Vehicles",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...activeVehicles.map((vehicle) => _buildVehicleTile(vehicle, true)),
                    ],
                    if (_showCompleted && completedVehicles.isNotEmpty) ...[
                      const Text(
                        "Completed Vehicles",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...completedVehicles.map((vehicle) => _buildVehicleTile(vehicle, false)),
                    ],

                    if ((activeVehicles.isEmpty && _showActive) && (completedVehicles.isEmpty && _showCompleted))
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          "No vehicles to display.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}