import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'https://mercedes-benz-car-tracking-system.onrender.com/api';

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
  bool isCameraOpen = false;
  bool isScanning = false;
  bool hasStartedFinalInspection = false;

  // Convert UTC to IST
  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  }

  // Handle QR Code Scanning
  void handleQRCode(String code) async {
    if (isScanning) return;
    isScanning = true;

    print('QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    await fetchVehicleDetails(code);

    Future.delayed(const Duration(seconds: 2), () => isScanning = false);
  }

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
          hasStartedFinalInspection = data['vehicle']['stages'].any((stage) => stage['stageName'] == 'Final Inspection' && stage['eventType'] == 'Start');
        });
      } else {
        print('❌ Vehicle not found');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
            contentTextStyle: const TextStyle(color: Colors.white70),
            title: const Text('No Entry Found'),
            content: const Text('This vehicle has no previous entry. Do you want to register it as a new vehicle?'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blueGrey,
                ),
                onPressed: () async {
                  Navigator.pop(context); // Dismiss the dialog
                  await startReception();
                },
                child: const Text('Register'),
              ),
            ],
          ),
        );
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
        setState(() {
          hasStartedFinalInspection = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final Inspection started')),
        );
      } else {
        print('❌ Start Reception Error: ${data['message']}');

        if (data['message']?.contains('already started') == true) {
          print('🔄 Final Inspection already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          setState(() {
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
          hasStartedFinalInspection = false;
        });

        // Refresh vehicle list after completion
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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Final Inspection Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchAllVehicles,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.grey],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: isCameraOpen ? Colors.redAccent : Colors.blueGrey,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  isCameraOpen = !isCameraOpen;
                });
              },
              child: Text(isCameraOpen ? 'Close Camera' : 'Open Camera'),
            ),
            const SizedBox(height: 10),
            isCameraOpen
                ? Container(
                    height: 200,
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                    child: MobileScanner(
                      fit: BoxFit.contain,
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(
  borderSide: BorderSide(color: Colors.blueAccent),
),

              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),

            // Conditionally render "Start" or "End" button
            (vehicleId != null && hasStartedFinalInspection)
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : () => endReceptionForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('End Final Inspection'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : startReception,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Start Final Inspection'),
                  ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: showInProgress ? Colors.blueGrey : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => showInProgress = true),
                  child: const Text('In-Progress', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: !showInProgress ? Colors.blueGrey : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => showInProgress = false),
                  child: const Text('Finished', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: (showInProgress ? inProgressVehicles : finishedVehicles).map((vehicle) {
                  return Card(
                    color: Colors.grey[800],
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: Icon(showInProgress ? Icons.directions_car : Icons.check_circle_outline,
                          color: Colors.white70),
                      title: Text(vehicle['vehicleNumber'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          'Start: ${vehicle['startTime'] ?? 'N/A'} ${showInProgress ? '' : '\nEnd: ${vehicle['endTime'] ?? 'N/A'}'}',
                          style: TextStyle(color: Colors.grey[400])),
                    ),
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
