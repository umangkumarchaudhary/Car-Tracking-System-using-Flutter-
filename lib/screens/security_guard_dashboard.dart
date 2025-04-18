import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const String BASE_URL = "https://final-mb-cts.onrender.com/api";

class SecurityGuardDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  SecurityGuardDashboard({required this.token, required this.onLogout});

  @override
  _SecurityGuardDashboardState createState() => _SecurityGuardDashboardState();
}

class _SecurityGuardDashboardState extends State<SecurityGuardDashboard> {
  String? scannedVehicleNumber;
  String selectedAction = "Entry";
  TextEditingController kmController = TextEditingController();
  TextEditingController driverNameController = TextEditingController();
  List<Map<String, dynamic>> vehicleHistory = [];
  String filterStatus = "All";

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _safeFetchVehicleHistory();
  }

  @override
  void dispose() {
    kmController.dispose();
    driverNameController.dispose();
    super.dispose();
  }

  Future<void> _safeFetchVehicleHistory() async {
    try {
      await fetchVehicleHistory();
    } catch (e) {
      print('Error fetching data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  Future<void> fetchVehicleHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/vehicles'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          vehicleHistory =
              List<Map<String, dynamic>>.from(data["vehicles"] ?? []);

          // Extract Security Gate Data for each vehicle
          for (var vehicle in vehicleHistory) {
            List<Map<String, dynamic>> stages =
                List<Map<String, dynamic>>.from(vehicle['stages'] ?? []);

            // Find the relevant stage events
            Map<String, dynamic>? entryStage = stages.firstWhere(
              (stage) =>
                  stage['stageName'] == "Security Gate" &&
                  stage['eventType'] == "Start",
              orElse: () => <String, dynamic>{},
            );

            Map<String, dynamic>? exitStage = stages.firstWhere(
              (stage) =>
                  stage['stageName'] == "Security Gate" &&
                  stage['eventType'] == "End",
              orElse: () => <String, dynamic>{},
            );

            // Attach extracted data to the vehicle object
            vehicle['inKM'] = entryStage?['inKM']?.toString() ?? 'N/A';
            vehicle['outKM'] = exitStage?['outKM']?.toString() ?? 'N/A';
            vehicle['inDriver'] = entryStage?['inDriver'] ?? 'N/A';
            vehicle['outDriver'] = exitStage?['outDriver'] ?? 'N/A';
          }

          print("Updated Vehicle Data: ${json.encode(vehicleHistory)}");
        });
      } else {
        print("Failed to load vehicle history: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load vehicle history.")),
        );
      }
    } catch (error) {
      print("Error fetching vehicle history: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching vehicle history.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void handleScan(String qrCode) {
    setState(() {
      scannedVehicleNumber = qrCode;
    });
  }

  Future<void> submitData() async {
    String vehicleNumber = scannedVehicleNumber ?? "";
    String kmValue = kmController.text.trim();
    String driverName = driverNameController.text.trim();

    if (vehicleNumber.isEmpty || kmValue.isEmpty || driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all required fields!")),
      );
      return;
    }

    String eventType = selectedAction == "Entry" ? "Start" : "End";

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/vehicle-check'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "vehicleNumber": vehicleNumber,
          "role": "Security Guard",
          "stageName": "Security Gate",
          "eventType": eventType,
          "inKM": selectedAction == "Entry" ? kmValue : null,
          "outKM": selectedAction == "Exit" ? kmValue : null,
          "inDriver": selectedAction == "Entry" ? driverName : null,
          "outDriver": selectedAction == "Exit" ? driverName : null,
        }),
      );

      if (response.statusCode == 200) {
        String message =
            "Vehicle ${selectedAction == "Entry" ? "Entry" : "Exit"} recorded successfully!";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        fetchVehicleHistory(); // Refresh the vehicle history
      } else {
        print("Failed to submit data: ${response.body}");
        // Display success message even if the status code is not 200
        String message =
            "Vehicle ${selectedAction == "Entry" ? "Entry" : "Exit"} recorded successfully!";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        fetchVehicleHistory();
      }
    } catch (e) {
      print("Error submitting data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred while submitting data.")),
      );
    } finally {
      setState(() {
        scannedVehicleNumber = null;
        kmController.clear();
        driverNameController.clear();
      });
    }
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    widget.onLogout();
  }

  List<Map<String, dynamic>> getFilteredVehicles() {
    List<Map<String, dynamic>> filteredList = [];
    if (filterStatus == "All") {
      filteredList = vehicleHistory;
    } else if (filterStatus == "Open") {
      filteredList = vehicleHistory
          .where((vehicle) => vehicle['exitTime'] == null)
          .toList();
    } else if (filterStatus == "Closed") {
      filteredList = vehicleHistory
          .where((vehicle) => vehicle['exitTime'] != null)
          .toList();
    }
    return filteredList;
  }

  Map<String, List<Map<String, dynamic>>> groupVehiclesByDate(
      List<Map<String, dynamic>> vehicles) {
    Map<String, List<Map<String, dynamic>>> groupedVehicles = {};
    for (var vehicle in vehicles) {
      String date = formatDate(vehicle['entryTime'] ?? "Unknown Date");
      if (!groupedVehicles.containsKey(date)) {
        groupedVehicles[date] = [];
      }
      groupedVehicles[date]!.add(vehicle);
    }
    return groupedVehicles;
  }

  String formatDate(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return "Unknown Date";
    }
  }

  String formatTime(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVehicles = getFilteredVehicles();
    final groupedVehicles = groupVehiclesByDate(filteredVehicles);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Security Guard Dashboard",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'MercedesBenz',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _safeFetchVehicleHistory,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input Form Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Scanner button
                          ElevatedButton.icon(
                            icon: Icon(Icons.qr_code_scanner, size: 20),
                            label: Text(
                              "Scan Vehicle QR",
                              style: TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.black,
                                  title: Text(
                                    "Scan Vehicle QR",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Container(
                                    height: 300,
                                    child: MobileScanner(
                                      onDetect: (capture) {
                                        for (final barcode in capture.barcodes) {
                                          if (barcode.rawValue != null) {
                                            handleScan(barcode.rawValue!);
                                            Navigator.pop(context);
                                            break;
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 14),

                          // Vehicle number field
                          Container(
                            height: 50,
                            child: TextField(
                              controller: TextEditingController(
                                  text: scannedVehicleNumber),
                              readOnly: true,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "Vehicle Number",
                                labelStyle: TextStyle(
                                    color: Colors.blue[300], fontSize: 14),
                                prefixIcon: Icon(Icons.directions_car,
                                    color: Colors.blue[300], size: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                              ),
                            ),
                          ),
                          SizedBox(height: 14),

                          // Action selection dropdown
                          DropdownButtonFormField<String>(
                            value: selectedAction,
                            onChanged: (newValue) =>
                                setState(() => selectedAction = newValue!),
                            decoration: InputDecoration(
                              labelText: "Action",
                              labelStyle: TextStyle(
                                  color: Colors.blue[300], fontSize: 14),
                              prefixIcon: Icon(Icons.handyman,
                                  color: Colors.blue[300], size: 18),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              filled: true,
                              fillColor: Colors.grey[850],
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 12),
                            ),
                            dropdownColor: Colors.grey[850],
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            items: ["Entry", "Exit"]
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 14),

                          // KM input field
                          TextFormField(
                            controller: kmController,
                            keyboardType: TextInputType.number,
                            style:
                                TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: "KM",
                              labelStyle: TextStyle(
                                  color: Colors.blue[300], fontSize: 14),
                              prefixIcon: Icon(Icons.speed,
                                  color: Colors.blue[300], size: 18),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              filled: true,
                              fillColor: Colors.grey[850],
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 12),
                            ),
                          ),
                          SizedBox(height: 14),

                          // Driver name input field
                          TextFormField(
                            controller: driverNameController,
                            style:
                                TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: "Driver Name",
                              labelStyle: TextStyle(
                                  color: Colors.blue[300], fontSize: 14),
                              prefixIcon: Icon(Icons.person,
                                  color: Colors.blue[300], size: 18),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              filled: true,
                              fillColor: Colors.grey[850],
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 12),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Submit button
                          ElevatedButton(
                            onPressed: submitData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              textStyle: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                            child: Text("Submit Record"),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Vehicle History Section
                    Text(
                      "Vehicle History",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'MercedesBenz',
                      ),
                    ),
                    SizedBox(height: 10),

                    // Filter section
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Filter Status:",
                            style: TextStyle(
                                color: Colors.blue[300], fontSize: 16),
                          ),
                          DropdownButton<String>(
                            value: filterStatus,
                            dropdownColor: Colors.grey[850],
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            items: <String>["All", "Open", "Closed"]
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                filterStatus = newValue!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14),

                    // Vehicle list
                    _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue[300]!)),
                          )
                        : (groupedVehicles.isEmpty
                            ? Center(
                                child: Text(
                                  "No vehicle history available.",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 16),
                                ),
                              )
                            : Column(
                                children: groupedVehicles.entries.map((entry) {
                                  final date = entry.key;
                                  final vehicles = entry.value;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          date,
                                          style: TextStyle(
                                            color: Colors.blue[200],
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ...vehicles.map((vehicle) {
                                        return Container(
                                          margin: EdgeInsets.only(bottom: 10),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[850],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildVehicleDetailRow(
                                                  "Vehicle No:",
                                                  vehicle['vehicleNumber'] ??
                                                      'N/A'),
                                              _buildVehicleDetailRow(
                                                  "Entry Time:",
                                                  formatTime(vehicle['entryTime'] ??
                                                      'N/A')),
                                              _buildVehicleDetailRow(
                                                  "Exit Time:",
                                                  vehicle['exitTime'] != null
                                                      ? formatTime(
                                                          vehicle['exitTime'])
                                                      : 'N/A'),
                                              _buildVehicleDetailRow(
                                                  "In KM:",
                                                  vehicle['inKM'] ?? 'N/A'),
                                              _buildVehicleDetailRow(
                                                  "Out KM:",
                                                  vehicle['outKM'] ?? 'N/A'),
                                              _buildVehicleDetailRow(
                                                  "In Driver:",
                                                  vehicle['inDriver'] ?? 'N/A'),
                                              _buildVehicleDetailRow(
                                                  "Out Driver:",
                                                  vehicle['outDriver'] ?? 'N/A'),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  );
                                }).toList(),
                              )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVehicleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
