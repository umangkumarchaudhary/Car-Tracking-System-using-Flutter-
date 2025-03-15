import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// API Base URL
const String baseUrl = 'http://192.168.108.49:5000/api';

class JobControllerDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const JobControllerDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  _JobControllerDashboardState createState() => _JobControllerDashboardState();
}

class _JobControllerDashboardState extends State<JobControllerDashboard> {
  bool isLoading = false;
  bool isScanning = false;
  bool isCameraOpen = false;
  String? vehicleNumber;
  String? startTime;
  List<String> allocatedVehicles = [];

  final TextEditingController _vehicleNumberController = TextEditingController();

  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  }

  void handleQRCode(String code) async {
    if (isScanning) return;
    isScanning = true;
    print('🚀 QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    await fetchVehicleDetails(code);
    Future.delayed(const Duration(seconds: 2), () => isScanning = false);
  }

  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    setState(() => isLoading = true);
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
      print('📋 Vehicle Details: $data');

      if (data['success'] == true && data.containsKey('vehicle')) {
        final stages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
        final jobCardStage = stages.firstWhere(
          (stage) => stage['stageName'] == 'Job Card Creation + Customer Approval',
          orElse: () => {},
        );

        setState(() {
          this.vehicleNumber = vehicleNumber;
          startTime = jobCardStage.isNotEmpty ? convertToIST(jobCardStage['timestamp']) : 'Not Recorded';
        });
      } else {
        setState(() {
          vehicleNumber = vehicleNumber;
          startTime = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚨 Vehicle not found, please enter manually!')),
        );
      }
    } catch (error) {
      print('❌ Error fetching vehicle details: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startBayAllocation() async {
    if (vehicleNumber == null) return;
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
          'vehicleNumber': vehicleNumber,
          'role': 'Job Controller',
          'stageName': 'Bay Allocation Started',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          allocatedVehicles.add(vehicleNumber!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bay Allocation Started')),
        );
      }
    } catch (error) {
      print('❌ Error starting Bay Allocation: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Controller Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isCameraOpen = !isCameraOpen;
                        });
                      },
                      icon: Icon(isCameraOpen ? Icons.camera_alt : Icons.camera),
                      label: Text(isCameraOpen ? 'Close Camera' : 'Open Camera'),
                    ),
                    const SizedBox(height: 10),
                    if (isCameraOpen)
                      SizedBox(
                        height: 200,
                        child: MobileScanner(
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                              handleQRCode(barcodes.first.rawValue!);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _vehicleNumberController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            vehicleNumber != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📌 Job Card Received Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(startTime ?? 'Not Recorded', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : startBayAllocation,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Bay Allocation'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  )
                : const Center(child: Text('Scan or enter a vehicle number')),
            const SizedBox(height: 30),
            const Text('🚗 Allocated Vehicles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            allocatedVehicles.isEmpty
                ? const Center(child: Text('No vehicles allocated yet'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allocatedVehicles.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text('📍 ${allocatedVehicles[index]}'),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
