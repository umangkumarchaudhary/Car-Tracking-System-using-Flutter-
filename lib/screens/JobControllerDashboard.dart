import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'qr_scanner_component.dart';

const String baseUrl = 'http://192.168.58.49:5000/api';

class JobControllerDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const JobControllerDashboard({
    Key? key, 
    required this.token, 
    required this.onLogout
  }) : super(key: key);

  @override
  _JobControllerDashboardState createState() => _JobControllerDashboardState();
}

class _JobControllerDashboardState extends State<JobControllerDashboard>
    with TickerProviderStateMixin {
  bool isLoading = false;
  bool isCameraOpen = false;
  String? vehicleNumber;
  Map<String, dynamic>? vehicleDetails;
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

  void handleQRCode(String code) async {
    if (code.isEmpty) {
      setState(() => isCameraOpen = !isCameraOpen);
      return;
    }
    
    print('QR Code Scanned: $code');
    _vehicleNumberController.text = code;
    setState(() {
      vehicleNumber = code;
      isCameraOpen = false;
    });
  }

  Future<void> startBayAllocation() async {
    if (vehicleNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter vehicle number')),
      );
      return;
    }

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
          'stageName': 'Job Card Received + Bay Allocation',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bay Allocation Started')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to start Bay Allocation')),
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

  Future<void> receiveFromTechnician() async {
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
          'stageName': 'Job Card Received (by Technician)',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Received from Technician')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to record receipt from Technician')),
        );
      }
    } catch (error) {
      print('Error receiving from Technician: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> receiveFromFI() async {
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
          'stageName': 'Job Card Received (by FI)',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Received from Final Inspector')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to record receipt from Final Inspector')),
        );
      }
    } catch (error) {
      print('Error receiving from FI: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
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
          child: SingleChildScrollView(
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
                    child: QRScannerComponent(
                      onQRCodeDetected: handleQRCode,
                      isCameraOpen: isCameraOpen,
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
                      setState(() {
                        vehicleNumber = value.isNotEmpty ? value : null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                if (vehicleNumber != null) ...[
                  // Bay Allocation Button
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.grey.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
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
                  const SizedBox(height: 16),
                  
                  // Receive from Technician Button
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.grey.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        onPressed: isLoading ? null : receiveFromTechnician,
                        icon: const Icon(Icons.handshake, color: Colors.white),
                        label: const Text('Receive from Technician',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Receive from FI Button
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.grey.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        onPressed: isLoading ? null : receiveFromFI,
                        icon: const Icon(Icons.verified_user, color: Colors.white),
                        label: const Text('Receive from Final Inspector',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}