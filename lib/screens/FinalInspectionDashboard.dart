import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'http://192.168.108.49:5000/api';

class FinalInspectionDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const FinalInspectionDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _FinalInspectionDashboardState createState() => _FinalInspectionDashboardState();
}

class _FinalInspectionDashboardState extends State<FinalInspectionDashboard> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String? vehicleId;
  //bool isReceptionActive = false;  // REMOVE THIS LINE
  bool isCameraOpen = false;
  bool isScanning = false; // Prevent multiple QR scans

  // NEW STATE VARIABLE
  bool hasStartedFinalInspection = false;


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
    _vehicleNumberController.text = code;
    // REMOVE THIS LINE  await fetchVehicleDetails(code); // DO NOT AUTOMATICALLY FETCH VEHICLE DETAILS

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

          final List<dynamic> finalInspectionStages = stages
              .where((stage) => stage['stageName'] == 'Final Inspection')
              .toList();

          print('🔍 Final Inspection Stages for $vehicleNumber: $finalInspectionStages');

          if (finalInspectionStages.isNotEmpty) {
            final lastEvent = finalInspectionStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(finalInspectionStages.first['timestamp']);
            final String? endTime = (finalInspectionStages.length > 1)
                ? convertToIST(finalInspectionStages.last['timestamp'])
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
            print('❌ No Final Inspection stage found for $vehicleNumber');
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
          //isReceptionActive = true; // Enable "End Reception" button if needed
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
      print('Start Reception: No vehicle number entered');
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
          'role': 'Final Inspection Technician',
          'stageName': 'Final Inspection',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      print('Start Reception Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        //isReceptionActive = true; // ✅ Show "End Reception" button
        setState(() {
          hasStartedFinalInspection = true; // UPDATE STATE
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final Inspection started')),
        );
      } else {
        print('❌ Start Reception Error: ${data['message']}');

        // ✅ If backend says "already started", refresh details
        if (data['message']?.contains('already started') == true) {
          print('🔄 Final Inspection already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          // ✅ Force update UI after fetching details
          setState(() {
            //isReceptionActive = true; // Ensure "End Reception" button appears
            hasStartedFinalInspection = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start inspection')),
          );
        }
      }
    } catch (error) {
      print('Error starting Final Inspection: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // End Reception
  Future<void> endReceptionForVehicle(String vehicleNumber) async {
    print('Ending Final Inspection for: $vehicleNumber');

    final url = Uri.parse('$baseUrl/vehicle-check');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'vehicleNumber': vehicleNumber,
          'role': 'Final Inspection Technician',
          'stageName': 'Final Inspection',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Final Inspection Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Final Inspection completed for $vehicleNumber')),
        );
        setState(() {
          hasStartedFinalInspection = false; // RESET STATE AFTER ENDING
        });

        // ✅ Refresh vehicle list after completion
        fetchAllVehicles();
      } else {
        print('❌ End Final Inspection Error: ${data['message']}');
      }
    } catch (error) {
      print('Error ending Final Inspection: $error');
    }
  }

  bool showInProgress = true;

  // Function to sort vehicles by date
  List<Map<String, dynamic>> sortVehicles(List<Map<String, dynamic>> vehicles) {
    vehicles.sort((a, b) {
      final DateTime aDate = DateFormat('dd-MM-yyyy hh:mm a').parse(a['startTime']);
      final DateTime bDate = DateFormat('dd-MM-yyyy hh:mm a').parse(b['startTime']);
      return bDate.compareTo(aDate);
    });
    return vehicles;
  }

  // Function to group vehicles by date
  Map<String, List<Map<String, dynamic>>> groupVehiclesByDate(List<Map<String, dynamic>> vehicles) {
    final groupedVehicles = <String, List<Map<String, dynamic>>>{};
    for (var vehicle in vehicles) {
      final date = DateFormat('dd-MM-yyyy').format(DateFormat('dd-MM-yyyy hh:mm a').parse(vehicle['startTime']));
      if (!groupedVehicles.containsKey(date)) {
        groupedVehicles[date] = [];
      }
      groupedVehicles[date]!.add(vehicle);
    }
    return groupedVehicles;
  }

  Map<String, bool> expanded = {};

  @override
  Widget build(BuildContext context) {
    final sortedInProgressVehicles = sortVehicles([...inProgressVehicles]);
    final sortedFinishedVehicles = sortVehicles([...finishedVehicles]);

    final groupedInProgressVehicles = groupVehiclesByDate(sortedInProgressVehicles);
    final groupedFinishedVehicles = groupVehiclesByDate(sortedFinishedVehicles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Inspection Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllVehicles,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isCameraOpen = !isCameraOpen;
                });
              },
              child: Text(isCameraOpen ? 'Close Camera' : 'Open Camera'),
            ),
            const SizedBox(height: 10),
            isCameraOpen
                ? SizedBox(
                    height: 200,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                          handleQRCode(barcodes.first.rawValue!);
                        }
                      },
                    ),
                  )
                : Container(),
            const SizedBox(height: 20),
            TextField(
              controller: _vehicleNumberController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),


            // CONDITIONAL BUTTON RENDERING
            hasStartedFinalInspection
                ? ElevatedButton(
                    onPressed: isLoading ? null : () => endReceptionForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('End Final Inspection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : ElevatedButton(
                    onPressed: isLoading ? null : startReception,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Start Final Inspection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
            const SizedBox(height: 30),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showInProgress = true;
                    });
                  },
                  child: const Text('In-Progress Vehicles'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showInProgress ? Colors.blue : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showInProgress = false;
                    });
                  },
                  child: const Text('Finished Vehicles'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !showInProgress ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: showInProgress
                  ? ListView(
                      children: groupedInProgressVehicles.keys.map((date) {
                        final vehicles = groupedInProgressVehicles[date]!;
                        return Column(
                          children: [
                            ListTile(
                              title: Text(date),
                              trailing: IconButton(
                                icon: Icon(expanded[date] ?? false ? Icons.expand_less : Icons.expand_more),
                                onPressed: () {
                                  setState(() {
                                    expanded[date] = !(expanded[date] ?? false);
                                  });
                                },
                              ),
                            ),
                            if (expanded[date] ?? false)
                              Column(
                                children: vehicles.map((vehicle) {
                                  return ListTile(
                                    title: Text('Vehicle No: ${vehicle['vehicleNumber']}'),
                                    subtitle: Text('Start Time: ${vehicle['startTime']}'),
                                    trailing: ElevatedButton(
                                      onPressed: () => endReceptionForVehicle(vehicle['vehicleNumber']),
                                      child: const Text('End Final Inspection'),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        );
                      }).toList(),
                    )
                  : ListView(
                      children: groupedFinishedVehicles.keys.map((date) {
                        final vehicles = groupedFinishedVehicles[date]!;
                        return Column(
                          children: [
                            ListTile(
                              title: Text(date),
                              trailing: IconButton(
                                icon: Icon(expanded[date] ?? false ? Icons.expand_less : Icons.expand_more),
                                onPressed: () {
                                  setState(() {
                                    expanded[date] = !(expanded[date] ?? false);
                                  });
                                },
                              ),
                            ),
                            if (expanded[date] ?? false)
                              Column(
                                children: vehicles.map((vehicle) {
                                  return ListTile(
                                    title: Text('Vehicle No: ${vehicle['vehicleNumber']}'),
                                    subtitle: Text(
                                        'Start Time: ${vehicle['startTime']}\nEnd Time: ${vehicle['endTime'] ?? "N/A"}'),
                                  );
                                }).toList(),
                              ),
                          ],
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
