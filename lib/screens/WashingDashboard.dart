import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'http://192.168.108.49:5000/api';

class WashingDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const WashingDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _WashingDashboardState createState() => _WashingDashboardState();
}

class _WashingDashboardState extends State<WashingDashboard> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String? vehicleId;
  bool isCameraOpen = false;
  bool isScanning = false;
  bool hasStartedWashing = false; // Tracks if washing has started

  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  }

  void handleQRCode(String code) async {
    if (isScanning) return;
    isScanning = true;

    print('QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    await fetchVehicleDetails(code); // Fetch details upon scanning

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

          final List<dynamic> washingStages = stages
              .where((stage) => stage['stageName'] == 'Washing')
              .toList();

          print('🔍 Washing Stages for $vehicleNumber: $washingStages');

          if (washingStages.isNotEmpty) {
            final lastEvent = washingStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(washingStages.first['timestamp']);
            final String? endTime = (washingStages.length > 1)
                ? convertToIST(washingStages.last['timestamp'])
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
            print('❌ No Washing stage found for $vehicleNumber');
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
          hasStartedWashing = data['vehicle']['stages'].any((stage) => stage['stageName'] == 'Washing' && stage['eventType'] == 'Start');
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
                  await startWashing();
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

  Future<void> startWashing() async {
    if (_vehicleNumberController.text.isEmpty) {
      print('Start Washing: No vehicle number entered');
      return;
    }

    print('Starting washing for: ${_vehicleNumberController.text}');
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
          'role': 'Washing Boy',
          'stageName': 'Washing',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      print('Start Washing Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        setState(() {
          hasStartedWashing = true; // UPDATE STATE
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Washing started')),
        );
      } else {
        print('❌ Start Washing Error: ${data['message']}');

        if (data['message']?.contains('already started') == true) {
          print('🔄 Washing already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          setState(() {
            hasStartedWashing = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start washing')),
          );
        }
      }
    } catch (error) {
      print('Error starting Washing: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> endWashingForVehicle(String vehicleNumber) async {
    print('Ending Washing for: $vehicleNumber');

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
          'role': 'Washing Boy',
          'stageName': 'Washing',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Washing Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Washing completed for $vehicleNumber')),
        );
        setState(() {
          hasStartedWashing = false; // RESET STATE AFTER ENDING
        });

        fetchAllVehicles();
      } else {
        print('❌ End Washing Error: ${data['message']}');
      }
    } catch (error) {
      print('Error ending Washing: $error');
    }
  }

  bool showInProgress = true;

  List<Map<String, dynamic>> sortVehicles(List<Map<String, dynamic>> vehicles) {
    vehicles.sort((a, b) {
      final DateTime aDate = DateFormat('dd-MM-yyyy hh:mm a').parse(a['startTime']);
      final DateTime bDate = DateFormat('dd-MM-yyyy hh:mm a').parse(b['startTime']);
      return bDate.compareTo(aDate);
    });
    return vehicles;
  }

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
        title: const Text('Washing Dashboard', style: TextStyle(color: Colors.white)),
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
            (vehicleId != null && hasStartedWashing)
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : () => endWashingForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('End Washing'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : startWashing,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Start Washing'),
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
              child: showInProgress
                  ? ListView(
                      children: groupedInProgressVehicles.keys.map((date) {
                        final vehicles = groupedInProgressVehicles[date]!;
                        return Column(
                          children: [
                            ListTile(
                              title: Text(date, style: const TextStyle(color: Colors.white)),
                              trailing: IconButton(
                                icon: Icon(expanded[date] ?? false ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
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
                                  return Card(
                                    color: Colors.grey[800],
                                    margin: const EdgeInsets.symmetric(vertical: 5),
                                    child: ListTile(
                                      leading: const Icon(Icons.directions_car, color: Colors.white70),
                                      title: Text('Vehicle No: ${vehicle['vehicleNumber']}', style: const TextStyle(color: Colors.white)),
                                      subtitle: Text('Start Time: ${vehicle['startTime']}', style: TextStyle(color: Colors.grey[400])),
                                      // REMOVED THE END BUTTON HERE
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
                              title: Text(date, style: const TextStyle(color: Colors.white)),
                              trailing: IconButton(
                                icon: Icon(expanded[date] ?? false ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
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
                                  return Card(
                                    color: Colors.grey[800],
                                    margin: const EdgeInsets.symmetric(vertical: 5),
                                    child: ListTile(
                                      leading: const Icon(Icons.check_circle_outline, color: Colors.white70),
                                      title: Text('Vehicle No: ${vehicle['vehicleNumber']}', style: const TextStyle(color: Colors.white)),
                                      subtitle: Text(
                                          'Start Time: ${vehicle['startTime']}\nEnd Time: ${vehicle['endTime']}',
                                          style: TextStyle(color: Colors.grey[400])),
                                    ),
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
