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
  List<Map<String, dynamic>> allocatedVehicles = [];


  final TextEditingController _vehicleNumberController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fetchAllocatedVehicles();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  String convertToIST(dynamic utcTimestamp) {
  if (utcTimestamp == null) return "N/A"; // Handle null case

  DateTime dateTime;
  try {
    if (utcTimestamp is int) {
      // Convert from milliseconds since epoch
      dateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestamp, isUtc: true);
    } else if (utcTimestamp is String) {
      // Convert from ISO 8601 string format
      dateTime = DateTime.parse(utcTimestamp).toUtc();
    } else {
      return "Invalid Date"; // Unknown format
    }

    // Convert to IST (UTC +5:30)
    final istTime = dateTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  } catch (e) {
    return "Invalid Date Format"; // If parsing fails
  }
}


  void handleQRCode(String code) async {
    if (isScanning) return;
    isScanning = true;
    print('QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    await fetchVehicleDetails(code);
    Future.delayed(const Duration(seconds: 2), () => isScanning = false);
    setState(() => isCameraOpen = false); // Close camera after scan
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
          this.vehicleNumber = vehicleNumber; // Allow new vehicle entry
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
        await fetchAllocatedVehicles(); // Refresh allocated vehicles
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

  // Using the correct endpoint based on available routes in vehicleRoute.js
 Future<void> fetchAllocatedVehicles() async {
  setState(() => isLoading = true);
  
  // Using the "/vehicles/bay-allocation-in-progress" endpoint from your vehicleRoute.js
  final url = Uri.parse('$baseUrl/vehicle-check');

  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);
    
    if (data['success'] == true && data.containsKey('vehicles')) {
      print('Allocated vehicles data: ${data['vehicles']}');
      
      // Handle the vehicles data as a List<String> instead of List<Map>
      setState(() {
        // Simple approach: just extract the vehicle numbers as strings
        allocatedVehicles = List<Map<String, dynamic>>.from(data['vehicles'] ?? []);

      });
    } else {
      print('No allocated vehicles found or error in response');
      setState(() {
        allocatedVehicles = [];
      });
    }
  } catch (error) {
    print('Error fetching allocated vehicles: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load allocated vehicles: ${error.toString()}')),
    );
  } finally {
    setState(() => isLoading = false);
  }
}

  // Show confirmation dialog before logout
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
            onPressed: _confirmLogout, // Use confirmation dialog for logout
          ),
        ],
      ),
      body: Container(
        // Full screen coverage with no white space
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
                // Scanner card
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
                
                // Vehicle input field
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
                
                // Start allocation button
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
                
                // Allocated vehicles section - expanded to fill remaining space
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInLeft(
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Allocated Vehicles:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      
                      // List of allocated vehicles
                      Expanded(
                        child: allocatedVehicles.isEmpty
                            ? FadeInRight(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.car_crash, color: Colors.grey.shade600, size: 48),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No vehicles allocated yet',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : FadeInUp(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: allocatedVehicles.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = allocatedVehicles[index];
                                    return Card(
                                      elevation: 4,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      color: Colors.grey.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        leading: const Icon(Icons.location_on, color: Colors.white70),
                                        title: Text(
                                          '📍 ${allocatedVehicles[index]}',
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                           subtitle: vehicle is Map<String, dynamic> && vehicle["entryTime"] != null
  ? Text(
      'Entered: ${convertToIST(vehicle["entryTime"].toString())}', 
      style: TextStyle(color: Colors.grey.shade300),
    )
  : Text("Entry time not available", style: TextStyle(color: Colors.grey.shade500)),


                                      ),
                                    );
                                  },
                                ),
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