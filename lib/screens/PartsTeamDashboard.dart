import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'http://192.168.58.49:5000/api';

class PartsTeamDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const PartsTeamDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _PartsTeamDashboardState createState() => _PartsTeamDashboardState();
}

class _PartsTeamDashboardState extends State<PartsTeamDashboard> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String? vehicleId;
  bool isCameraOpen = false;
  bool isScanning = false;
  bool hasStartedEstimate = false; // Tracks if estimate creation has started

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

          final List<dynamic> partsStages = stages
              .where((stage) => stage['stageName'] == 'Creation of Parts Estimate')
              .toList();

          print('🔍 Parts Estimate Stages for $vehicleNumber: $partsStages');

          if (partsStages.isNotEmpty) {
            final lastEvent = partsStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(partsStages.first['timestamp']);
            final String? endTime = (partsStages.length > 1)
                ? convertToIST(partsStages.last['timestamp'])
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
            print('❌ No Parts Estimate stage found for $vehicleNumber');
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
          hasStartedEstimate = data['vehicle']['stages'].any((stage) => 
            stage['stageName'] == 'Creation of Parts Estimate' && stage['eventType'] == 'Start');
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
                  await startPartsEstimate();
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

  Future<void> startPartsEstimate() async {
    if (_vehicleNumberController.text.isEmpty) {
      print('Start Parts Estimate: No vehicle number entered');
      return;
    }

    print('Starting parts estimate for: ${_vehicleNumberController.text}');
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
          'role': 'Parts Team',
          'stageName': 'Creation of Parts Estimate',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      print('Start Parts Estimate Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        setState(() {
          hasStartedEstimate = true; // UPDATE STATE
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parts Estimate creation started')),
        );
      } else {
        print('❌ Start Parts Estimate Error: ${data['message']}');

        if (data['message']?.contains('already started') == true) {
          print('🔄 Parts Estimate already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          setState(() {
            hasStartedEstimate = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start parts estimate')),
          );
        }
      }
    } catch (error) {
      print('Error starting Parts Estimate: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> endPartsEstimateForVehicle(String vehicleNumber) async {
    print('Ending Parts Estimate for: $vehicleNumber');

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
          'role': 'Parts Team',
          'stageName': 'Creation of Parts Estimate',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Parts Estimate Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parts Estimate completed for $vehicleNumber')),
        );
        setState(() {
          hasStartedEstimate = false; // RESET STATE AFTER ENDING
        });

        fetchAllVehicles();
      } else {
        print('❌ End Parts Estimate Error: ${data['message']}');
      }
    } catch (error) {
      print('Error ending Parts Estimate: $error');
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
        title: const Text('Parts Team Dashboard', style: TextStyle(color: Colors.white)),
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
            (vehicleId != null && hasStartedEstimate)
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : () => endPartsEstimateForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('End Estimate'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : startPartsEstimate,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Start Estimate'),
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