import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Define API Base URL
const String baseUrl = 'http://192.168.108.49:5000/api';

class ServiceAdvisorDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ServiceAdvisorDashboard({Key? key, required this.token, required this.onLogout})
      : super(key: key);

  @override
  _ServiceAdvisorDashboardState createState() => _ServiceAdvisorDashboardState();
}

class _ServiceAdvisorDashboardState extends State<ServiceAdvisorDashboard> {
  bool isLoading = false;
  bool isScanning = false;
  bool isCameraOpen = false;
  String? vehicleId;
  String? vehicleNumber;
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> additionalWorkStages = [];

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
        setState(() {
          vehicleId = data['vehicle']['_id'];
          this.vehicleNumber = vehicleNumber;
          stages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
          additionalWorkStages = stages
              .where((stage) => stage['stageName'] == 'Additional Work Job Approval')
              .toList();
        });
      }
    } catch (error) {
      print('❌ Error fetching vehicle details: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startJobCard() async {
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
          'role': 'Service Advisor',
          'stageName': 'Job Card Creation + Customer Approval',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Job Card started')),
        );
        fetchVehicleDetails(vehicleNumber!);
      }
    } catch (error) {
      print('❌ Error starting job card: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startAdditionalWork() async {
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
          'role': 'Service Advisor',
          'stageName': 'Additional Work Job Approval',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚀 Additional Work started')),
        );
        fetchVehicleDetails(vehicleNumber!);
      }
    } catch (error) {
      print('❌ Error starting additional work: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Advisor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (vehicleNumber != null) fetchVehicleDetails(vehicleNumber!);
            },
          ),
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
            Center(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : startJobCard,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Job Card & Customer Approval'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(height: 30),
            Text('📌 Vehicle Stages', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            stages.isEmpty
                ? const Center(child: Text('No stages recorded'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stages.length,
                    itemBuilder: (context, index) {
                      final stage = stages[index];
                      return Card(
                        child: ListTile(
                          title: Text('📍 ${stage['stageName']}'),
                          subtitle: Text('Time: ${convertToIST(stage['timestamp'])}'),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isLoading ? null : startAdditionalWork,
              icon: const Icon(Icons.add),
              label: const Text('Start Additional Work Approval'),
            ),
          ],
        ),
      ),
    );
  }
}
