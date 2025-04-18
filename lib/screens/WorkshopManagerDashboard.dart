import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define the base URL
const String baseUrl = 'https://final-mb-cts.onrender.com/api';

class WorkshopManager extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const WorkshopManager({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _WorkshopManagerState createState() => _WorkshopManagerState();
}

class _WorkshopManagerState extends State<WorkshopManager> {
  bool isLoading = false;

  List<Map<String, dynamic>> inProgressVehicles = [];
  List<Map<String, dynamic>> finishedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String? vehicleId;
  bool isCameraOpen = false;
  bool isScanning = false;
  bool hasStartedChecking = false; // Tracks if checking has started

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

          final List<dynamic> checkingStages = stages
              .where((stage) => stage['stageName'] == 'Checked')
              .toList();

          print('🔍 Checked Stages for $vehicleNumber: $checkingStages');

          if (checkingStages.isNotEmpty) {
            final lastEvent = checkingStages.last;
            final String lastEventType = lastEvent['eventType'];
            final String startTime = convertToIST(checkingStages.first['timestamp']);
            final String? endTime = (checkingStages.length > 1)
                ? convertToIST(checkingStages.last['timestamp'])
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
            print('❌ No Checked stage found for $vehicleNumber');
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Vehicle Details: $data');

        if (data['success'] == true && data.containsKey('vehicle')) {
          setState(() {
            vehicleId = data['vehicle']['_id'];
            hasStartedChecking = data['vehicle']['stages'].any((stage) => stage['stageName'] == 'Checked' && stage['eventType'] == 'Start');
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
                    await startChecking();
                  },
                  child: const Text('Register'),
                ),
              ],
            ),
          );
        }
      } else {
        print('Failed to fetch vehicle details. Status code: ${response.statusCode}');
        // Handle error as needed
      }
    } catch (error) {
      print('❌ Error fetching vehicle details: $error');
    }
  }


  Future<void> startChecking() async {
    if (_vehicleNumberController.text.isEmpty) {
      print('Start Checking: No vehicle number entered');
      return;
    }

    print('Starting checking for: ${_vehicleNumberController.text}');
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
          'role': 'Workshop Manager',
          'stageName': 'Checked',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      print('Start Checking Response: $data');

      if (data['success'] == true) {
        vehicleId = data['vehicle']['_id'];
        setState(() {
          hasStartedChecking = true; // UPDATE STATE
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checking started')),
        );
      } else {
        print('❌ Start Checking Error: ${data['message']}');

        if (data['message']?.contains('already started') == true) {
          print('🔄 Checking already started, refreshing details...');
          await fetchVehicleDetails(_vehicleNumberController.text);

          setState(() {
            hasStartedChecking = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to start checking')),
          );
        }
      }
    } catch (error) {
      print('Error starting Checking: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing vehicle start')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> endCheckingForVehicle(String vehicleNumber) async {
    print('Ending Checking for: $vehicleNumber');

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
          'role': 'Workshop Manager',
          'stageName': 'Checked',
          'eventType': 'End',
        }),
      );

      final data = json.decode(response.body);
      print('End Checking Response: $data');

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checking completed for $vehicleNumber')),
        );
        setState(() {
          hasStartedChecking = false; // RESET STATE AFTER ENDING
        });
        fetchAllVehicles();
      } else {
        print('❌ End Checking Error: ${data['message']}');
      }
    } catch (error) {
      print('Error ending Checking: $error');
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
        title: const Text('Workshop Manager', style: TextStyle(color: Colors.white)),
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
            (vehicleId != null && hasStartedChecking)
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : () => endCheckingForVehicle(_vehicleNumberController.text),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('End Checking'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading ? null : startChecking,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Start Checking'),
                  ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      fontSize: 18,
                      color: showInProgress ? Colors.blueAccent : Colors.white70,
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
                      fontSize: 18,
                      color: !showInProgress ? Colors.blueAccent : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : (showInProgress
                      ? buildVehicleList(groupedInProgressVehicles)
                      : buildVehicleList(groupedFinishedVehicles)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVehicleList(Map<String, List<Map<String, dynamic>>> groupedVehicles) {
    if (groupedVehicles.isEmpty) {
      return const Center(
        child: Text(
          'No vehicles to display.',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: groupedVehicles.length,
      itemBuilder: (context, index) {
        final date = groupedVehicles.keys.elementAt(index);
        final vehicles = groupedVehicles[date]!;
        bool isExpanded = expanded[date] ?? false;

        return Card(
          color: Colors.grey[800],
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(
              date,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (bool expanding) {
              setState(() => expanded[date] = expanding);
            },
            children: vehicles.map((vehicle) {
              return ListTile(
                leading: const Icon(Icons.directions_car, color: Colors.white),
                title: Text(
                  vehicle['vehicleNumber'],
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time: ${vehicle['startTime']}',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    if (vehicle['endTime'] != null)
                      Text(
                        'End Time: ${vehicle['endTime']}',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                  ],
                ),
                onTap: () {
                  // Handle vehicle tap
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
