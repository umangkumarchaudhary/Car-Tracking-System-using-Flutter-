import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'https://mercedes-benz-car-tracking-system.onrender.com/api';

class ActiveReceptionDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ActiveReceptionDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _ActiveReceptionDashboardState createState() => _ActiveReceptionDashboardState();
}

class _ActiveReceptionDashboardState extends State<ActiveReceptionDashboard> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String? vehicleId;
  bool isReceptionActive = false;
  bool isCameraOpen = false;
  bool isScanning = false; // Prevent multiple QR scans
  bool isStartButtonPressed = false; // Flag to track if start button is pressed

  @override
  void initState() {
    super.initState();
    // ✅ Check vehicle status after login
    fetchAllVehicles(); // Load vehicles when dashboard opens
  }

  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(Duration(hours: 5, minutes: 30)); // IST is UTC+5:30
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime); // Format as per your requirement
  }

  // Handle QR Code Scanning
  void handleQRCode(String code) async {
    if (isScanning) return; // Prevent multiple scans
    isScanning = true; // Lock scanning

    print('QR Code Scanned: $code');
    setState(() {
      _vehicleNumberController.text = code;
      isCameraOpen = false; // Close camera after successful scan
    });

    // Check vehicle status in Interactive Bay
    await checkVehicleInteractiveBayStatus(code);

    Future.delayed(Duration(seconds: 2), () => isScanning = false); // Unlock scanning
  }

  bool requestInProgress = false; // Prevent duplicate requests

  Future<void> fetchAllVehicles() async {
    setState(() => isLoading = true);
    final url = Uri.parse('$baseUrl/vehicles');
    print('🔄 Fetching all vehicles from: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📩 API Response Status Code: ${response.statusCode}');
      print('📦 Raw API Response: ${response.body}');

      final data = json.decode(response.body);

      if (data['success'] == true && data.containsKey('vehicles')) {
        final List<dynamic> vehicles = data['vehicles'];
        List<Map<String, dynamic>> inProgress = [];
        List<Map<String, dynamic>> finished = [];

        print('✅ Found ${vehicles.length} vehicles in response');

        for (var vehicle in vehicles) {
          final String vehicleNumber = vehicle['vehicleNumber'];
          final List<dynamic> stages = vehicle['stages'];

          print('🚗 Checking vehicle: $vehicleNumber');
          print('📜 Stages: $stages');

          final List<dynamic> interactiveStages = stages
              .where((stage) => stage['stageName'] == 'Interactive Bay')
              .toList();

          print('🔍 Interactive Bay Stages for $vehicleNumber: $interactiveStages');

          if (interactiveStages.isNotEmpty) {
            final lastEvent = interactiveStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(interactiveStages.first['timestamp']);
            final String? endTime = (interactiveStages.length > 1)
                ? convertToIST(interactiveStages.last['timestamp'])
                : null;

            print('📍 Last Event Type: $lastEventType');

            if (lastEventType == 'Start') {
              inProgress.add({
                'vehicleNumber': vehicleNumber,
                'startTime': startTime,
                'endTime': null,
              });
            } else if (lastEventType == 'End') {
              finished.add({
                'vehicleNumber': vehicleNumber,
                'startTime': startTime,
                'endTime': endTime,
              });
            }
          } else {
            print('❌ No Interactive Bay stage found for $vehicleNumber');
          }
        }

        setState(() {
          inProgressVehicles = inProgress;
          finishedVehicles = finished;
        });
        print('🚗 In-Progress Vehicles: $inProgressVehicles');
        print('✅ Finished Vehicles: $finishedVehicles');
      } else {
        print('❌ Unexpected API response format or "vehicles" key missing');
      }
    } catch (error) {
      print('❌ Error fetching vehicles: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    final url = Uri.parse('$baseUrl/vehicles/$vehicleNumber'); // Adjust API as needed

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);
      print('Vehicle Details: $data');

      if (data['success'] == true && data.containsKey('vehicle')) {
        setState(() {
          vehicleId = data['vehicle']['_id'];
        });
      } else {
        print('❌ Vehicle not found');
      }
    } catch (error) {
      print('❌ Error fetching vehicle details: $error');
    }
  }

  Future<void> startReception() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a vehicle QR code first')),
      );
      return;
    }

    print('Starting reception for: ${_vehicleNumberController.text}');
    setState(() => isLoading = true);

    final url = Uri.parse('$baseUrl/vehicle-check');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Inspection Technician',
          'stageName': 'Interactive Bay',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      print('Start Reception Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        setState(() {
          isStartButtonPressed = true;
          isReceptionActive = true; // ✅ Show "End Reception" button
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Active Reception started')),
        );
        fetchAllVehicles(); // Refresh the list of vehicles
      } else {
        print('❌ Start Reception Error: ${data['message']}');

        // ✅ If backend says "already started", refresh details
        if (data['message']?.contains('already started') == true) {
          print('🔄 Interactive Bay already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          // ✅ Force update UI after fetching details
          setState(() {
            isReceptionActive = true; // Ensure "End Reception" button appears
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start reception')),
          );
        }
      }
    } catch (error) {
      print('Error starting reception: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // End Reception
  Future<void> endReceptionForVehicle(String vehicleNumber) async {
    print('Ending reception for: $vehicleNumber');

    final url = Uri.parse('$baseUrl/vehicle-check');
    try {
      setState(() => isLoading = true);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'role': 'Inspection Technician',
          'stageName': 'Interactive Bay',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Reception Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Active Reception completed for $vehicleNumber')),
        );
        // ✅ Refresh vehicle list after completion
        await fetchAllVehicles();
        setState(() {
          isReceptionActive = false;
          isStartButtonPressed = false;
          _vehicleNumberController.clear();
        });
      } else {
        print('❌ End Reception Error: ${data['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to end reception')),
        );
      }
    } catch (error) {
      print('Error ending reception: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle end')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Check Vehicle Interactive Bay Status
  Future<void> checkVehicleInteractiveBayStatus(String vehicleNumber) async {
    setState(() => isLoading = true);
    final url = Uri.parse('$baseUrl/vehicles'); // Adjust endpoint if necessary
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      final data = json.decode(response.body);

      if (data['success'] == true && data.containsKey('vehicles')) {
        final List<dynamic> vehicles = data['vehicles'];

        for (var vehicle in vehicles) {
          if (vehicle['vehicleNumber'] == vehicleNumber) {
            final List<dynamic> stages = vehicle['stages'];
            final List<dynamic> interactiveStages = stages
                .where((stage) => stage['stageName'] == 'Interactive Bay')
                .toList();

            if (interactiveStages.isNotEmpty) {
              final lastEvent = interactiveStages.last;
              final String lastEventType = lastEvent['eventType'];

              if (lastEventType == 'Start') {
                // Vehicle is in progress
                setState(() {
                  isStartButtonPressed = true;
                  isReceptionActive = true;
                });
                return; // Exit the function as status is found
              }
            }
            break; // Vehicle found, exit the loop
          }
        }
        // If loop completes without finding vehicle in "Start" state
        setState(() {
          isStartButtonPressed = false;
          isReceptionActive = false;
        });
      } else {
        print('❌ Error checking vehicle status: ${data['message']}');
        setState(() {
          isStartButtonPressed = false;
          isReceptionActive = false;
        });
      }
    } catch (error) {
      print('❌ Error checking vehicle status: $error');
      setState(() {
        isStartButtonPressed = false;
        isReceptionActive = false;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Interactive Bay Reception",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'MercedesBenz',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchAllVehicles,
            tooltip: 'Refresh Vehicle Data',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scanner Section
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                isCameraOpen ? Icons.camera_alt : Icons.qr_code_scanner,
                                size: 20,
                              ),
                              label: Text(
                                isCameraOpen ? 'Close Scanner' : 'Scan Vehicle QR',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCameraOpen ? Colors.red[700] : Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                              ),
                              onPressed: () {
                                setState(() {
                                  isCameraOpen = !isCameraOpen;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      // QR Scanner View
                      if (isCameraOpen)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: MobileScanner(
                              fit: BoxFit.cover,
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                  handleQRCode(barcodes.first.rawValue!);
                                }
                              },
                            ),
                          ),
                        ),
                      SizedBox(height: 10),
                      // Vehicle Number Display
                      TextField(
                        controller: _vehicleNumberController,
                        readOnly: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Scanned Vehicle No',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // Start/End Reception Button
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!isStartButtonPressed) {
                            await startReception();
                          } else {
                            await endReceptionForVehicle(_vehicleNumberController.text);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStartButtonPressed ? Colors.red[700] : Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 5,
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(isStartButtonPressed ? 'End Interactive Bay' : 'Start Interactive Bay'),
                ),
                SizedBox(height: 30),
                // In-Progress Vehicles Section
                Text(
                  'Vehicles in Interactive Bay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'MercedesBenz',
                  ),
                ),
                SizedBox(height: 10),
                inProgressVehicles.isEmpty
                    ? Text('No vehicles currently in Interactive Bay.', style: TextStyle(color: Colors.grey[400]))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: inProgressVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = inProgressVehicles[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.directions_car, color: Colors.blue[300]),
                              title: Text(vehicle['vehicleNumber'], style: TextStyle(color: Colors.white)),
                              subtitle: Text(
                                'Start Time: ${vehicle['startTime']}',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ),
                          );
                        },
                      ),
                SizedBox(height: 20),
                // Finished Vehicles Section
                Text(
                  'Completed Vehicles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'MercedesBenz',
                  ),
                ),
                SizedBox(height: 10),
                finishedVehicles.isEmpty
                    ? Text('No vehicles have completed Interactive Bay.', style: TextStyle(color: Colors.grey[400]))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: finishedVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = finishedVehicles[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.check_circle, color: Colors.green[300]),
                              title: Text(vehicle['vehicleNumber'], style: TextStyle(color: Colors.white)),
                              subtitle: Text(
                                'Start: ${vehicle['startTime']}\nEnd: ${vehicle['endTime']}',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
