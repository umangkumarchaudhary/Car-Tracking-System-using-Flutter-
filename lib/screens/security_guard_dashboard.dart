import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_app.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart'; // Add this package for Excel functionality
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // For file storage

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
  String selectedAction = "Entry";
  TextEditingController kmController = TextEditingController();
  TextEditingController driverNameController = TextEditingController();
  List<Map<String, dynamic>> vehicleHistory = [];
  String filterStatus = "All";
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    fetchVehicleHistory();
    startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    kmController.dispose();
    driverNameController.dispose();
    super.dispose();
  }

  void startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchVehicleHistory();
    });
  }

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
        print("Failed to load vehicle history: ${response.body}");
      }
    } catch (error) {
      print("Error fetching vehicle history: $error");
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

    if (vehicleNumber.isEmpty || kmValue.isEmpty) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Vehicle $selectedAction recorded successfully!")),
        );
        fetchVehicleHistory();
      } else {
        print("Failed to submit data: ${response.body}");
      }
    } catch (e) {
      print("Error submitting data: $e");
    }

    setState(() {
      scannedVehicleNumber = null;
      kmController.clear();
      driverNameController.clear();
    });
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    widget.onLogout();
  }

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

  Future<void> downloadExcelFile() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/vehicles?role=Security Guard'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> securityGuardEntries =
            List<Map<String, dynamic>>.from(data["vehicles"] ?? []);

        // Create an Excel file
        var excel = Excel.createExcel();
        Sheet sheetObject = excel['SecurityGuardData'];

        // Add headers
        sheetObject.appendRow([
          "Vehicle Number",
          "Entry Time",
          "Exit Time",
          "Entry KM",
          "Exit KM",
          "Driver Name"
        ]);

        // Add data rows
        for (var entry in securityGuardEntries) {
          sheetObject.appendRow([
            entry['vehicleNumber'] ?? '',
            entry['entryTime'] ?? '',
            entry['exitTime'] ?? '',
            entry['inKM'] ?? '',
            entry['outKM'] ?? '',
            entry['inDriver'] ?? ''
          ]);
        }

        // Save file to temporary directory
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = tempDir.path;
        File file = File('$tempPath/SecurityGuardData.xlsx');
        file.writeAsBytesSync(excel.encode()!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Excel file downloaded to $tempPath")),
        );
      } else {
        print("Failed to fetch security guard data: ${response.body}");
      }
    } catch (e) {
      print("Error downloading Excel file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVehicles = getFilteredVehicles();
    final groupedVehicles = groupVehiclesByDate(filteredVehicles);

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
            onPressed: fetchVehicleHistory,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: downloadExcelFile,
              child: Text("Download Security Guard Data"),
            ),

            SizedBox(height: 20),

            // QR Scanner Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              child: Text("Open Camera to Scan Vehicle"),
            ),

            SizedBox(height: 20),

            // Display Scanned Vehicle Number
            TextField(
              controller: TextEditingController(text: scannedVehicleNumber),
              readOnly: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Scanned Vehicle Number",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Entry/Exit Dropdown
            DropdownButtonFormField<String>(
              value: selectedAction,
              items: ["Entry", "Exit"].map((String action) {
                return DropdownMenuItem<String>(
                  value: action,
                  child: Text(
                    action,
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedAction = value!;
                });
              },
              dropdownColor: Colors.black,
              decoration: InputDecoration(
                labelText: "Select Action",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),

            SizedBox(height: 20),

            // IN KM and Driver Name Fields
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "${selectedAction} KM",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: driverNameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Driver Name",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: submitData,
              child: Text("Submit"),
            ),

            SizedBox(height: 20),

            // Filter Buttons
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

            // Vehicle History Section
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
                        color: Colors.grey[900],
                        child: ListTile(
                          title: Text(
                            "Vehicle: ${vehicle['vehicleNumber'] ?? 'Unknown'}",
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Entry Time: ${formatTime(vehicle['entryTime'] ?? 'N/A')}",
                                style: TextStyle(color: Colors.white),
                              ),
                              if (vehicle['exitTime'] == null) ...[
                                // Open Section: Display inKM and inDriver
                                vehicle['inKM'] != null ? Text(
                                  "Entry KM: ${vehicle['inKM']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                                vehicle['inDriver'] != null ? Text(
                                  "Entry Driver: ${vehicle['inDriver']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                              ] else ...[
                                // Closed Section: Display inKM, inDriver, outKM, outDriver, and Exit Time
                                vehicle['inKM'] != null ? Text(
                                  "Entry KM: ${vehicle['inKM']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                                vehicle['inDriver'] != null ? Text(
                                  "Entry Driver: ${vehicle['inDriver']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                                vehicle['outKM'] != null ? Text(
                                  "Exit KM: ${vehicle['outKM']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                                vehicle['outDriver'] != null ? Text(
                                  "Exit Driver: ${vehicle['outDriver']}",
                                  style: TextStyle(color: Colors.white),
                                ) : SizedBox.shrink(),
                                Text(
                                  "Exit Time: ${formatTime(vehicle['exitTime'] ?? 'N/A')}",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
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
