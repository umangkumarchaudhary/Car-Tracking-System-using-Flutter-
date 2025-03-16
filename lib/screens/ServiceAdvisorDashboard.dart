import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do package

const String baseUrl = 'http://192.168.108.49:5000/api';

class ServiceAdvisorDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ServiceAdvisorDashboard({Key? key, required this.token, required this.onLogout})
      : super(key: key);

  @override
  _ServiceAdvisorDashboardState createState() => _ServiceAdvisorDashboardState();
}

class _ServiceAdvisorDashboardState extends State<ServiceAdvisorDashboard> with TickerProviderStateMixin {
  bool isLoading = false;
  bool isScanning = false;
  bool isCameraOpen = false;
  String? vehicleId;
  String? vehicleNumber;
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> additionalWorkStages = [];

  final TextEditingController _vehicleNumberController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
    Future.delayed(const Duration(seconds: 2), () => isScanning = false);
  }

  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward(); // Start animation
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
          this.vehicleNumber = vehicleNumber;
          stages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
          additionalWorkStages = stages
              .where((stage) => stage['stageName'] == 'Additional Work Job Approval')
              .toList();
        });
      }
    } catch (error) {
      print('Error fetching vehicle details: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startJobCard() async {
    if (vehicleNumber == null) return;
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward(); // Start animation

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
          const SnackBar(content: Text('Job Card started')),
        );
        fetchVehicleDetails(vehicleNumber!);
      }
    } catch (error) {
      print('Error starting job card: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startAdditionalWork() async {
    if (vehicleNumber == null) return;
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward(); // Start animation

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
          const SnackBar(content: Text('Additional Work started')),
        );
        fetchVehicleDetails(vehicleNumber!);
      }
    } catch (error) {
      print('Error starting additional work: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> searchVehicle() async {
    final vehicleNumber = _vehicleNumberController.text.trim();
    if (vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vehicle number')),
      );
      return;
    }

    await fetchVehicleDetails(vehicleNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Add this
          children: [
            Row(
              children: [
                Image.asset('assets/mercedes_logo.jpg', height: 40),
                const SizedBox(width: 10),
                const Text(
                  'Service Advisor Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min, // Add this
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    if (vehicleNumber != null) fetchVehicleDetails(vehicleNumber!);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: widget.onLogout,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            isCameraOpen = !isCameraOpen;
                          });
                        },
                        icon: Icon(isCameraOpen ? Icons.camera_alt : Icons.camera, color: Colors.white),
                        label: Text(isCameraOpen ? 'Close Camera' : 'Open Camera',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      TextField(
                        controller: _vehicleNumberController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Enter Vehicle Number',
                          labelStyle:
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.directions_car, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: searchVehicle,
                        icon: const Icon(Icons.search, color: Colors.black),
                        label: const Text('Search Vehicle',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: isLoading ? null : startJobCard,
                    icon: const Icon(Icons.assignment, color: Colors.white),
                    label: const Text('Start Job Card',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: isLoading ? null : startAdditionalWork,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Additional Work',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              FadeInDown(
                // Wrap the stages list with FadeInDown
                animate: true,
                controller: (controller) => _animationController = controller,
                child: Text('Vehicle Stages',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              stages.isEmpty
                  ? const Center(
                      child: Text('No stages recorded',
                          style: TextStyle(color: Colors.white, fontSize: 16)))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stages.length,
                      itemBuilder: (context, index) {
                        final stage = stages[index];
                        return Card(
                          color: Colors.grey.shade800,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.timeline, color: Colors.white),
                            title: Text(stage['stageName'],
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('Time: ${convertToIST(stage['timestamp'])}',
                                style: const TextStyle(color: Colors.grey)),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
