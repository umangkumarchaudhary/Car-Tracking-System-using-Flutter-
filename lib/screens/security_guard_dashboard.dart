import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // For file storage
import 'package:permission_handler/permission_handler.dart'; // Add permission_handler
import 'package:file_saver/file_saver.dart'; // Add file_saver package
import 'dart:typed_data';

const String BASE_URL = "https://mercedes-benz-car-tracking-system.onrender.com/api";

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
        vehicleHistory = List<Map<String, dynamic>>.from(data["vehicles"] ?? []);
        
        // ✅ Extract Security Gate Data for each vehicle
        for (var vehicle in vehicleHistory) {
          List<Map<String, dynamic>> stages = List<Map<String, dynamic>>.from(vehicle['stages'] ?? []);

          // ✅ Find the relevant stage events
          Map<String, dynamic>? entryStage = stages.firstWhere(
            (stage) => stage['stageName'] == "Security Gate" && stage['eventType'] == "Start",
            orElse: () => {},
          );

          Map<String, dynamic>? exitStage = stages.firstWhere(
            (stage) => stage['stageName'] == "Security Gate" && stage['eventType'] == "End",
            orElse: () => {},
          );

          // ✅ Attach extracted data to the vehicle object
          vehicle['inKM'] = entryStage?['inKM']?.toString() ?? 'N/A';
          vehicle['outKM'] = exitStage?['outKM']?.toString() ?? 'N/A';
          vehicle['inDriver'] = entryStage?['inDriver'] ?? 'N/A';
          vehicle['outDriver'] = exitStage?['outDriver'] ?? 'N/A';
        }

        print("🚗 Updated Vehicle Data: ${json.encode(vehicleHistory)}");
      });
    } else {
      print("❌ Failed to load vehicle history: ${response.body}");
    }
  } catch (error) {
    print("❌ Error fetching vehicle history: $error");
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
    // ignore: invalid_use_of_protected_member
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
  // ✅ Check & Request Storage Permission
  if (await Permission.storage.request().isDenied) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storage permission is required to download the file.')),
    );
    return;
  }

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
          entry['inDriver'] ?? '',
          entry['outDriver'] ?? ''
        ]);
      }

      // Encode the Excel data
      List<int>? bytes = excel.encode();

      if (bytes != null) {
        // ✅ Save the file using FileSaver
        final String fileName = 'SecurityGuardData.xlsx';
        final String? path = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          ext: 'xlsx',
          mimeType: MimeType.other,
        );

        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Excel file saved to $path")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save the Excel file.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error encoding Excel file.")),
        );
      }
    } else {
      print("Failed to fetch security guard data: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch security guard data.")),
      );
    }
  } catch (e) {
    print("Error downloading Excel file: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error downloading Excel file: $e")),
    );
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
                              controller: TextEditingController(text: scannedVehicleNumber),
                              readOnly: true,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "Vehicle Number",
                                labelStyle: TextStyle(color: Colors.blue[300], fontSize: 14),
                                prefixIcon: Icon(Icons.directions_car, color: Colors.blue[300], size: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Entry/Exit selection
                          Container(
                            height: 50,
                            child: DropdownButtonFormField<String>(
                              value: selectedAction,
                              items: ["Entry", "Exit"].map((String action) {
                                return DropdownMenuItem<String>(
                                  value: action,
                                  child: Text(
                                    action,
                                    style: TextStyle(color: Colors.blue, fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedAction = value!;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Select Action",
                                labelStyle: TextStyle(color: Colors.blue[300], fontSize: 14),
                                prefixIcon: Icon(Icons.compare_arrows, color: Colors.blue[300], size: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Driver Name input
                          Container(
                            height: 50,
                            child: TextField(
                              controller: driverNameController,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "Driver Name",
                                labelStyle: TextStyle(color: Colors.blue[300], fontSize: 14),
                                prefixIcon: Icon(Icons.person, color: Colors.blue[300], size: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),

                          // KM input
                          Container(
                            height: 50,
                            child: TextField(
                              controller: kmController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "${selectedAction == 'Entry' ? 'Entry' : 'Exit'} KM",
                                labelStyle: TextStyle(color: Colors.blue[300], fontSize: 14),
                                prefixIcon: Icon(Icons.speed, color: Colors.blue[300], size: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue[500]!, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[850],
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Submit button
                          ElevatedButton(
                            onPressed: submitData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[900],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 5,
                            ),
                            child: Text("Submit"),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Vehicles Stage Section
                    Text(
                      "📌 Vehicle Stages",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Vehicle list header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              filterStatus = "All";
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: filterStatus == "All" ? Colors.blue[500] : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            textStyle: TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text("All"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              filterStatus = "Open";
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: filterStatus == "Open" ? Colors.blue[500] : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            textStyle: TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text("Open"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              filterStatus = "Closed";
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: filterStatus == "Closed" ? Colors.blue[500] : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            textStyle: TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text("Closed"),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Vehicle list
                    _isLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.white))
                        : filteredVehicles.isEmpty
                            ? Text("No vehicles found.", style: TextStyle(color: Colors.white))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: filteredVehicles.length,
                                itemBuilder: (context, index) {
                                  final vehicle = filteredVehicles[index];

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[850],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue[700]!, width: 1),

                                    ),
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    padding: EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Vehicle Number: ${vehicle['vehicleNumber'] ?? 'N/A'}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        _buildInfoRow("Entry Time", formatTime(vehicle['entryTime'] ?? ''), Icons.login),
                                        _buildInfoRow("Exit Time", formatTime(vehicle['exitTime'] ?? ''), Icons.logout),
                                        _buildInfoRow("Entry KM", vehicle['inKM']?.toString() ?? 'N/A', Icons.input),
                                        _buildInfoRow("Exit KM", vehicle['outKM']?.toString() ?? 'N/A', Icons.output),
                                        _buildInfoRow("In Driver Name", vehicle['inDriver'] ?? 'N/A', Icons.drive_file_rename_outline),
                                        _buildInfoRow("Out Driver Name", vehicle['outDriver'] ?? 'N/A', Icons.drive_file_rename_outline),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    SizedBox(height: 20),

                    // Download Excel Button
                    ElevatedButton.icon(
                      onPressed: downloadExcelFile,
                      icon: Icon(Icons.download, size: 20),
                      label: Text(
                        "Download Security Guard Data",
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[300], size: 16),
          SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
