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

    await fetchVehicleDetails(code);

    setState(() {
      isCameraOpen = false; // Close camera after scanning
    });

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

          // Adjusted to use the new "Bay Work: [WorkType]" stage names
          final List<dynamic> maintenanceStages = stages
              .where((stage) => stage['stageName'].startsWith('Bay Work:'))
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
              // Extract work type from stage name
              String stageName = maintenanceStages.first['stageName'];
              String workType = stageName.replaceFirst('Bay Work: ', '');

              inProgress.add({
                'vehicleNumber': vehicleNumber,
                'startTime': startTime,
                'endTime': null,
                'workType': workType, // Include work type
              });
            } else if (lastEventType == 'End') {
              // Extract work type from stage name
              String stageName = maintenanceStages.first['stageName'];
              String workType = stageName.replaceFirst('Bay Work: ', '');

              finished.add({
                'vehicleNumber': vehicleNumber,
                'startTime': startTime,
                'endTime': endTime,
                'workType': workType, // Include work type
              });
            }
          } else {
            print('❌ No Bay Work stage found for $vehicleNumber');
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
        final vehicleData = data['vehicle'];
        final stages = vehicleData['stages'];

        setState(() {
          vehicleId = vehicleData['_id'];

          // Check if there's a previous 'Start' event
          bool foundStartEvent = false;
          String? prevWorkType;
          String? prevBayNumber;

          if (stages != null && stages.isNotEmpty) {
            for (var i = stages.length - 1; i >= 0; i--) {
              if (stages[i]['eventType'] == 'Start' && stages[i]['stageName'] == 'Bay Allocation Started') {
                foundStartEvent = true;
                prevWorkType = stages[i]['workType'];
                prevBayNumber = stages[i]['bayNumber'];
                break;
              }
            }
          }

          if (foundStartEvent) {
            hasStartedWork = true;
            selectedWorkType = prevWorkType;
            selectedBayNumber = prevBayNumber;
          } else {
            hasStartedWork = false;
            selectedWorkType = null;
            selectedBayNumber = null;
          }
        });
      } else {
        print('❌ Vehicle not found');
        setState(() {
          hasStartedWork = false;
          selectedWorkType = null;
          selectedBayNumber = null;
        });
      }
    } catch (error) {
      print('❌ Error fetching vehicle details: $error');
      setState(() {
        hasStartedWork = false;
        selectedWorkType = null;
        selectedBayNumber = null;
      });
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
          'stageName': 'Bay Work: $selectedWorkType', // ✅ CORRECT
          'eventType': 'Start',
          'workType': selectedWorkType,
          'bayNumber': selectedBayNumber,
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
          'stageName': 'Bay Work: $selectedWorkType', // Ensure this matches how you start the work
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

        await fetchAllVehicles();
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
  void initState() {
    super.initState();
    fetchAllVehicles();
  }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : startWork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Start Work'),
                ),
                ElevatedButton(
                  onPressed: () => endWorkForVehicle(_vehicleNumberController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('End Work'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      showInProgress = true;
                    });
                  },
                  child: Text(
                    'In-Progress',
                    style: TextStyle(
                      color: showInProgress ? Colors.blue : Colors.grey,
                      fontWeight: showInProgress ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      showInProgress = false;
                    });
                  },
                  child: Text(
                    'Finished',
                    style: TextStyle(
                      color: !showInProgress ? Colors.blue : Colors.grey,
                      fontWeight: !showInProgress ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: showInProgress
                  ? buildVehicleList(groupedInProgressVehicles)
                  : buildVehicleList(groupedFinishedVehicles),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVehicleList(Map<String, List<Map<String, dynamic>>> groupedVehicles) {
    return ListView.builder(
      itemCount: groupedVehicles.length,
      itemBuilder: (context, index) {
        final date = groupedVehicles.keys.elementAt(index);
        final vehicles = groupedVehicles[date]!;
        return ExpansionTile(
          title: Text(date),
          initiallyExpanded: expanded[date] ?? false,
          onExpansionChanged: (bool expanding) {
            setState(() {
              expanded[date] = expanding;
            });
          },
          children: vehicles.map((vehicle) {
            return ListTile(
              title: Text(vehicle['vehicleNumber']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work Type: ${vehicle['workType']}'),
                  Text('Start Time: ${vehicle['startTime']}'),
                  if (vehicle['endTime'] != null) Text('End Time: ${vehicle['endTime']}'),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
