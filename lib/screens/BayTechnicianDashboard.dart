import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'http://192.168.108.49:5000/api';

class BayTechnicianDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const BayTechnicianDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _BayTechnicianDashboardState createState() => _BayTechnicianDashboardState();
}

class _BayTechnicianDashboardState extends State<BayTechnicianDashboard> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _workTypeController = TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();

  String? vehicleId;
  bool isCameraOpen = false;
  bool isScanning = false;

  bool hasStartedWork = false;

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

          final List<dynamic> maintenanceStages = stages
              .where((stage) => stage['stageName'] == 'Maintainance')
              .toList();

          print('🔍 Maintenance Stages for $vehicleNumber: $maintenanceStages');

          if (maintenanceStages.isNotEmpty) {
            final lastEvent = maintenanceStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(maintenanceStages.first['timestamp']);
            final String? endTime = (maintenanceStages.length > 1)
                ? convertToIST(maintenanceStages.last['timestamp'])
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
            print('❌ No Maintenance stage found for $vehicleNumber');
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
    final url = Uri.parse('$baseUrl/vehicles/$vehicleNumber');

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

  Future<void> startWork() async {
    if (_vehicleNumberController.text.isEmpty) {
      print('Start Work: No vehicle number entered');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please scan QR'))); // Optional, but user-friendly
      return;
    }

    if (selectedWorkType == null || selectedBayNumber == null) { // CHECK DROPDOWN VALUES
      print('Start Work: Work type or bay number missing');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Work Type and Bay Number')));
      return;
    }

    print('Starting work for: ${_vehicleNumberController.text}');
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
          'role': 'Bay Technician',
          'stageName': 'Maintainance',
          'eventType': 'Start',
          'workType': selectedWorkType, // USE SELECTED VALUES
          'bayNumber': selectedBayNumber, // USE SELECTED VALUES
        }),
      );

      final data = json.decode(response.body);
      print('Start Work Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        setState(() {
          hasStartedWork = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work started')),
        );
      } else {
        print('❌ Start Work Error: ${data['message']}');

        if (data['message']?.contains('already started') == true) {
          print('🔄 Work already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          setState(() {
            hasStartedWork = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start work')),
          );
        }
      }
    } catch (error) {
      print('Error starting work: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> endWorkForVehicle(String vehicleNumber) async {
    print('Ending work for: $vehicleNumber');

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
          'role': 'Bay Technician',
          'stageName': 'Maintainance',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Work Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Work completed for $vehicleNumber')),
        );
        setState(() {
          hasStartedWork = false;
        });

        fetchAllVehicles();
      } else {
        print('❌ End Work Error: ${data['message']}');
      }
    } catch (error) {
      print('Error ending work: $error');
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

  List<String> workTypes = ['PM', 'GR', 'Diagnosis', 'Body and Paint'];
  List<String> bayNumbers = List.generate(15, (index) => (index + 1).toString());

  String? selectedWorkType;
  String? selectedBayNumber;

  @override
  Widget build(BuildContext context) {
    final sortedInProgressVehicles = sortVehicles([...inProgressVehicles]);
    final sortedFinishedVehicles = sortVehicles([...finishedVehicles]);

    final groupedInProgressVehicles = groupVehiclesByDate(sortedInProgressVehicles);
    final groupedFinishedVehicles = groupVehiclesByDate(sortedFinishedVehicles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bay Technician Dashboard'),
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
            const SizedBox(height: 10),
            DropdownButtonFormField(
              decoration: const InputDecoration(
                labelText: 'Work Type',
                border: OutlineInputBorder(),
              ),
              items: workTypes.map((type) {
                return DropdownMenuItem(
                  child: Text(type),
                  value: type,
                );
              }).toList(),
              value: selectedWorkType,
              onChanged: (value) {
                setState(() {
                  selectedWorkType = value as String?;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              decoration: const InputDecoration(
                labelText: 'Bay Number',
                border: OutlineInputBorder(),
              ),
              items: bayNumbers.map((number) {
                return DropdownMenuItem(
                  child: Text(number),
                  value: number,
                );
              }).toList(),
              value: selectedBayNumber,
              onChanged: (value) {
                setState(() {
                  selectedBayNumber = value as String?;
                });
              },
            ),
            const SizedBox(height: 20),
            hasStartedWork
                ? ElevatedButton(
                    onPressed: isLoading ? null : () => endWorkForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Finish Work'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : ElevatedButton(
                    onPressed: isLoading ? null : startWork,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Start Work'),
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
                  child: const Text('Work in Progress'),
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
                  child: const Text('Completed Jobs'),
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
                                      onPressed: () => endWorkForVehicle(vehicle['vehicleNumber']),
                                      child: const Text('Finish Work'),
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
