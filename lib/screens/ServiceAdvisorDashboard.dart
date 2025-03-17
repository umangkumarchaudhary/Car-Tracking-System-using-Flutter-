import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

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
  bool isCameraOpen = false;
  String? vehicleId;
  String? vehicleNumber;
  String? searchedVehicleNumber;
  List<Map<String, dynamic>> scannedStages = [];
  List<Map<String, dynamic>> searchedStages = [];
  List<Map<String, dynamic>> additionalWorkStages = [];
  List<Map<String, dynamic>> stages = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _scannedVehicleController = TextEditingController();
  late AnimationController _animationController;
  bool showSearchStages = false;

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
    _searchController.dispose();
    _scannedVehicleController.dispose();
    super.dispose();
  }

  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  }

  Future<void> fetchVehicleDetails(String vehicleNumber, {bool isQRScan = false}) async {
    setState(() => isLoading = true);
    _animationController.reset();
    _animationController.forward();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/$vehicleNumber'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (isQRScan) {
        // Handle QR Scan case
        if (data['success'] == true && data.containsKey('vehicle')) {
          setState(() {
            vehicleId = data['vehicle']['_id'];
            this.vehicleNumber = vehicleNumber;
            _scannedVehicleController.text = vehicleNumber;
            scannedStages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
            stages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
          });
        } else {
          // If vehicle doesn't exist, still set the vehicleNumber and clear other data
          setState(() {
            vehicleId = null;
            this.vehicleNumber = vehicleNumber;
            _scannedVehicleController.text = vehicleNumber;
            scannedStages = [];
            stages = []; // Clear stages
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle not found. Proceeding with the new vehicle entry.')),
          );
        }
      } else {
        // Handle Search case
        if (data['success'] == true && data.containsKey('vehicle')) {
          setState(() {
            searchedVehicleNumber = vehicleNumber;
            searchedStages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
          });
        } else {
          setState(() {
            searchedVehicleNumber = vehicleNumber;
            searchedStages = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle not found.')),
          );
        }
      }

      //Common logic to set additionalWorkStages always
      additionalWorkStages = stages
          .where((stage) => stage['stageName'] == 'Additional Work Job Approval')
          .toList();

    } catch (error) {
      print('Error fetching vehicle details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching vehicle details. Please try again.')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startJobCard() async {
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
        // Fetch the updated vehicle details after starting the job card
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
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
        // Fetch the updated vehicle details after starting additional work
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
      }
    } catch (error) {
      print('Error starting additional work: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                 // Removed refresh button
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
            children: [
              /// QR Scan Section
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.grey.shade800,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "QR CODE SCANNER",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Divider(color: Colors.white54),
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => setState(() => isCameraOpen = !isCameraOpen),
                          icon: Icon(
                            isCameraOpen ? Icons.no_photography : Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 28,
                          ),
                          label: Text(
                            isCameraOpen ? 'CLOSE SCANNER' : 'SCAN VEHICLE QR',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (isCameraOpen)
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade700, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: MobileScanner(
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty) {
                                  fetchVehicleDetails(barcodes.first.rawValue!, isQRScan: true);
                                  setState(() => isCameraOpen = false);
                                }
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 15),
                      // Read-only field for scanned vehicle number
                      const Text(
                        "SCANNED VEHICLE",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade700),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car, color: Colors.white70),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _scannedVehicleController.text.isEmpty
                                    ? "No vehicle scanned"
                                    : _scannedVehicleController.text,
                                style: TextStyle(
                                  color: _scannedVehicleController.text.isEmpty
                                      ? Colors.grey
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: _scannedVehicleController.text.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (scannedStages.isNotEmpty) ...[
                        const Text(
                          "SCANNED VEHICLE STAGES",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: scannedStages.length,
                          itemBuilder: (context, index) {
                            final stage = scannedStages[index];
                            return Card(
                              color: Colors.grey.shade700,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.timeline, color: Colors.white70),
                                title: Text(stage['stageName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text('Time: ${convertToIST(stage['timestamp'])}', style: const TextStyle(color: Colors.grey)),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// Action Buttons
              if (vehicleNumber != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : startJobCard,
                      icon: const Icon(Icons.assignment, color: Colors.white),
                      label: const Text('Start Job Card', style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : startAdditionalWork,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Additional Work', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showSearchStages = !showSearchStages;
                    if (!showSearchStages) {
                      // Clear search results when closing the search section
                      searchedVehicleNumber = null;
                      searchedStages = [];
                      _searchController.clear();
                    }
                  });
                },
                child: Text(showSearchStages ? 'Close Search' : 'Search Vehicle'),
              ),

              /// Vehicle Search Section
              if (showSearchStages)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.grey.shade700,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SEARCH VEHICLE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Divider(color: Colors.white54),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Enter Vehicle Number',
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: 'e.g., KA01AB1234',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade800,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search, color: Colors.amber),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () => _searchController.clear(),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            onPressed: () {
                              if (_searchController.text.isNotEmpty) {
                                fetchVehicleDetails(_searchController.text.trim());
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a vehicle number')),
                                );
                              }
                            },
                            child: const Text('Search Stages', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (searchedStages.isNotEmpty) ...[
                          const Text(
                            "SEARCHED VEHICLE STAGES",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: searchedStages.length,
                            itemBuilder: (context, index) {
                              final stage = searchedStages[index];
                              return Card(
                                color: Colors.grey.shade700,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: const Icon(Icons.timeline, color: Colors.amber),
                                  title: Text(stage['stageName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text('Time: ${convertToIST(stage['timestamp'])}', style: const TextStyle(color: Colors.grey)),
                                ),
                              );
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
