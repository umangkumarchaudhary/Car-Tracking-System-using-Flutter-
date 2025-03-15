import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_app.dart';
import 'package:intl/intl.dart'; // For date and time formatting

const String BASE_URL = "http://192.168.108.49:5000/api";

class SecurityGuardDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  SecurityGuardDashboard({required this.token, required this.onLogout});

  @override
  _SecurityGuardDashboardState createState() => _SecurityGuardDashboardState();
}

class _SecurityGuardDashboardState extends State<SecurityGuardDashboard> {
  String? scannedVehicleNumber;
  String selectedAction = "Entry"; // Default action
  TextEditingController kmController = TextEditingController();
  TextEditingController driverNameController = TextEditingController();
  List<Map<String, dynamic>> vehicleHistory = [];
  String filterStatus = "All"; // Filter by status: All, Open, Closed

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    fetchVehicleHistory();
    startPolling(); // ✅ Start real-time polling
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    kmController.dispose();
    driverNameController.dispose();
    super.dispose();
  }

  // ✅ Real-time Polling every 5 seconds
  void startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchVehicleHistory();
    });
  }

  // ✅ Fetch Vehicle History from Backend
  Future<void> fetchVehicleHistory() async {
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
          vehicleHistory = List<Map<String, dynamic>>.from(data["vehicles"] ?? []);
        });
      } else {
        print("❌ Failed to load vehicle history: ${response.body}");
      }
    } catch (error) {
      print("❌ Error fetching vehicle history: $error");
    }
  }

  // ✅ Handle QR Scan
  void handleScan(String qrCode) {
    setState(() {
      scannedVehicleNumber = qrCode;
    });
  }

  // ✅ Submit Entry/Exit Data
  Future<void> submitData() async {
    String vehicleNumber = scannedVehicleNumber ?? "";
    String kmValue = kmController.text.trim();
    String driverName = driverNameController.text.trim();

    if (vehicleNumber.isEmpty || kmValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all required fields!")),
      );
      return;
    }

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
          "eventType": selectedAction,
          "inKM": selectedAction == "Entry" ? kmValue : null,
          "outKM": selectedAction == "Exit" ? kmValue : null,
          "inDriver": selectedAction == "Entry" ? driverName : null,
          "outDriver": selectedAction == "Exit" ? driverName : null,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Vehicle $selectedAction recorded successfully!")),
        );
        fetchVehicleHistory(); // Refresh vehicle history
      } else {
        print("❌ Failed to submit data: ${response.body}");
      }
    } catch (e) {
      print("❌ Error submitting data: $e");
    }

    // ✅ Clear form after submission
    setState(() {
      scannedVehicleNumber = null;
      kmController.clear();
      driverNameController.clear();
    });
  }

  // ✅ Logout Function
  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ✅ Clear token & role
    widget.onLogout(); // ✅ Call parent logout function
  }

  // ✅ Filter vehicles by status
  List<Map<String, dynamic>> getFilteredVehicles() {
    if (filterStatus == "All") {
      return vehicleHistory;
    } else {
      return vehicleHistory
          .where((vehicle) =>
              (filterStatus == "Open" && vehicle['exitTime'] == null) ||
              (filterStatus == "Closed" && vehicle['exitTime'] != null))
          .toList();
    }
  }

  // ✅ Group vehicles by date
  Map<String, List<Map<String, dynamic>>> groupVehiclesByDate(List<Map<String, dynamic>> vehicles) {
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

  // ✅ Format date to DD/MM/YYYY
  String formatDate(String dateTimeString) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return "Unknown Date";
    }
  }

  // ✅ Format time to 12-hour Indian time format
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
    // Filter and group vehicles
    final filteredVehicles = getFilteredVehicles();
    final groupedVehicles = groupVehiclesByDate(filteredVehicles);

    return Scaffold(
      backgroundColor: Colors.black, // Black background
      appBar: AppBar(
        backgroundColor: Colors.black, // Black app bar
        title: Text(
          "Security Guard Dashboard",
          style: TextStyle(
            color: Colors.white, // White text
            fontFamily: 'MercedesBenz', // Use Mercedes-Benz font if available
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white), // White refresh icon
            onPressed: fetchVehicleHistory, // ✅ Refresh button
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white), // White logout icon
            onPressed: logout, // ✅ Logout button
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✅ QR Scanner Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White button
                foregroundColor: Colors.black, // Black text
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.black, // Black background
                    title: Text(
                      "Scan Vehicle QR",
                      style: TextStyle(color: Colors.white), // White text
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
              child: Text("Open Camera to Scan Vehicle"),
            ),

            SizedBox(height: 20),

            // ✅ Display Scanned Vehicle Number
            TextField(
              controller: TextEditingController(text: scannedVehicleNumber),
              readOnly: true,
              style: TextStyle(color: Colors.white), // White text
              decoration: InputDecoration(
                labelText: "Scanned Vehicle Number",
                labelStyle: TextStyle(color: Colors.white), // White label
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
              ),
            ),

            SizedBox(height: 20),

            // ✅ Entry/Exit Dropdown
            DropdownButtonFormField<String>(
              value: selectedAction,
              items: ["Entry", "Exit"].map((String action) {
                return DropdownMenuItem<String>(
                  value: action,
                  child: Text(
                    action,
                    style: TextStyle(color: Colors.white), // White text
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedAction = value!;
                });
              },
              dropdownColor: Colors.black, // Black dropdown background
              decoration: InputDecoration(
                labelText: "Select Action",
                labelStyle: TextStyle(color: Colors.white), // White label
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
              ),
            ),

            SizedBox(height: 20),

            // ✅ IN KM and Driver Name Fields
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white), // White text
              decoration: InputDecoration(
                labelText: "${selectedAction} KM",
                labelStyle: TextStyle(color: Colors.white), // White label
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: driverNameController,
              style: TextStyle(color: Colors.white), // White text
              decoration: InputDecoration(
                labelText: "Driver Name",
                labelStyle: TextStyle(color: Colors.white), // White label
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), // White border
                ),
              ),
            ),

            SizedBox(height: 20),

            // ✅ Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White button
                foregroundColor: Colors.black, // Black text
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
              ),
              onPressed: submitData,
              child: Text("Submit"),
            ),

            SizedBox(height: 20),

            // ✅ Filter Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: filterStatus == "All" ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      filterStatus = "All";
                    });
                  },
                  child: Text("All"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: filterStatus == "Open" ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      filterStatus = "Open";
                    });
                  },
                  child: Text("Open"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: filterStatus == "Closed" ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      filterStatus = "Closed";
                    });
                  },
                  child: Text("Closed"),
                ),
              ],
            ),

            SizedBox(height: 20),

            // ✅ Vehicle History Section
            Expanded(
              child: ListView(
                children: groupedVehicles.entries.map((entry) {
                  String date = entry.key;
                  List<Map<String, dynamic>> vehicles = entry.value;

                  return ExpansionTile(
                    title: Text(
                      date,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: vehicles.map((vehicle) {
                      return Card(
                        color: Colors.grey[900], // Dark grey card background
                        child: ListTile(
                          title: Text(
                            "Vehicle: ${vehicle['vehicleNumber'] ?? 'Unknown'}",
                            style: TextStyle(color: Colors.white), // White text
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Entry Time: ${formatTime(vehicle['entryTime'] ?? 'N/A')}",
                                style: TextStyle(color: Colors.white), // White text
                              ),
                              Text(
                                "IN KM: ${vehicle['stages'][0]['inKM'] ?? 'N/A'}",
                                style: TextStyle(color: Colors.white), // White text
                              ),
                              Text(
                                "IN Driver: ${vehicle['stages'][0]['inDriver'] ?? 'N/A'}",
                                style: TextStyle(color: Colors.white), // White text
                              ),
                              if (vehicle['exitTime'] != null) ...[
                                Text(
                                  "Exit Time: ${formatTime(vehicle['exitTime'] ?? 'N/A')}",
                                  style: TextStyle(color: Colors.white), // White text
                                ),
                                Text(
                                  "OUT KM: ${vehicle['stages'][0]['outKM'] ?? 'N/A'}",
                                  style: TextStyle(color: Colors.white), // White text
                                ),
                                Text(
                                  "OUT Driver: ${vehicle['stages'][0]['outDriver'] ?? 'N/A'}",
                                  style: TextStyle(color: Colors.white), // White text
                                ),
                              ],
                              Text(
                                "Status: ${vehicle['exitTime'] == null ? 'Open' : 'Closed'}",
                                style: TextStyle(color: Colors.white), // White text
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}