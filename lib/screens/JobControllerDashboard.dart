import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

const String baseUrl = 'http://192.168.108.49:5000/api';

class JobControllerDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const JobControllerDashboard({Key? key, required this.token, required this.onLogout})
      : super(key: key);

  @override
  _JobControllerDashboardState createState() => _JobControllerDashboardState();
}

class _JobControllerDashboardState extends State<JobControllerDashboard>
    with TickerProviderStateMixin {
  bool isLoading = false;
  bool isScanning = false;
  bool isCameraOpen = false;
  String? vehicleNumber;

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
    _vehicleNumberController.dispose();
    super.dispose();
  }

  String convertToIST(dynamic utcTimestamp) {
    if (utcTimestamp == null) return "N/A";

    DateTime dateTime;
    try {
      if (utcTimestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestamp, isUtc: true);
      } else if (utcTimestamp is String) {
        dateTime = DateTime.parse(utcTimestamp).toUtc();
      } else {
        return "Invalid Date";
      }

      final istTime = dateTime.add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
    } catch (e) {
      return "Invalid Date Format";
    }
  }

  void handleQRCode(String code) async {
    if (isScanning) return;
    isScanning = true;
    print('QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    await fetchVehicleDetails(code);
    Future.delayed(const Duration(seconds: 2), () => isScanning = false);
    setState(() => isCameraOpen = false);
  }

  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward();

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

      if (data['success'] == true && data.containsKey('vehicle')) {
        setState(() {
          this.vehicleNumber = vehicleNumber;
        });
      } else {
        setState(() {
          this.vehicleNumber = vehicleNumber;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle not found, proceeding as new entry.')),
        );
      }
    } catch (error) {
      print('Error fetching vehicle details: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startBayAllocation() async {
    if (vehicleNumber == null) return;
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward();

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bay Allocation Started')),
        );
      }
    } catch (error) {
      print('Error starting Bay Allocation: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<dynamic>> fetchAllocatedVehicles() async {
    final url = Uri.parse('$baseUrl/vehicles/bay-allocation-started');

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
        if (data['success'] == true && data.containsKey('vehicles')) {
          return data['vehicles'];
        } else {
          print('No allocated vehicles found or error in response');
          return [];
        }
      } else {
        print('Failed to load allocated vehicles: ${response.statusCode}');
        return Future.error('Failed to load allocated vehicles');
      }
    } catch (error) {
      print('Error fetching allocated vehicles: $error');
      return Future.error('Failed to load allocated vehicles');
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade800,
          title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to logout?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Job Controller Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.grey.shade800,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              isCameraOpen = !isCameraOpen;
                            });
                          },
                          icon: Icon(isCameraOpen ? Icons.no_photography : Icons.camera, color: Colors.white),
                          label: Text(isCameraOpen ? 'Close Scanner' : 'Scan Vehicle QR',
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                FadeInDown(
                  controller: (controller) => _animationController = controller,
                  child: TextField(
                    controller: _vehicleNumberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Number',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Scan QR code or enter manually',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade700,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.directions_car, color: Colors.white70),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          vehicleNumber = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (vehicleNumber != null)
                  FadeInUp(
                    child: Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        onPressed: isLoading ? null : startBayAllocation,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Start Bay Allocation',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Allocated vehicles section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInLeft(
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('History of Scanned QR:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            const Spacer(),
                            if (isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: FutureBuilder<List<dynamic>>(
                          future: fetchAllocatedVehicles(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white),));
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                              );
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return FadeInRight(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.car_crash, color: Colors.grey.shade600, size: 48),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No vehicles with Bay Allocation Started',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return FadeInUp(
                                child: ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = snapshot.data![index];
                                    return Card(
                                      elevation: 4,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      color: Colors.grey.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          vehicle['vehicleNumber'] ?? 'Unknown Vehicle',
                                          style: const TextStyle(color: Colors.white, fontSize: 16),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
