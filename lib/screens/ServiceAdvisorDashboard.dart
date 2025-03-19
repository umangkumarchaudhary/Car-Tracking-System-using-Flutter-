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
  List<Map<String, dynamic>> additionalWorkStages = [];
  List<Map<String, dynamic>> stages = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _scannedVehicleController = TextEditingController();
  late AnimationController _animationController;
  Map<String, dynamic> latestSearchedStages = {}; // Store latest timestamp for each stage

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

  /// Convert UTC timestamp to IST format
  String convertToIST(String utcTimestamp) {
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
    final utcTime = dateFormat.parseUTC(utcTimestamp);
    final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
  }

  /// Find the latest stages with event type (start or end)
  Map<String, dynamic> findLatestStagesWithEvent(List<Map<String, dynamic>> stages) {
    Map<String, dynamic> latestStages = {};
    for (var stage in stages) {
      String key = "${stage['stageName']} (${stage['eventType']})"; // Combine stage name and event type
      if (!latestStages.containsKey(key) || stage['timestamp'].compareTo(latestStages[key]['timestamp']) > 0) {
        latestStages[key] = stage;
      }
    }
    return latestStages;
  }

  /// Fetch vehicle details and update UI
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
            // Sort stages in descending order by timestamp
            scannedStages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
            stages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
            // Sort stages in descending order by timestamp
            stages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
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
            const SnackBar(
              content: Text('Vehicle not found. Proceeding with the new vehicle entry.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
      } else {
        // Handle Search case
        if (data['success'] == true && data.containsKey('vehicle')) {
          setState(() {
            searchedVehicleNumber = vehicleNumber;
            List<Map<String, dynamic>> allStages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
            // Sort all stages in descending order before finding latest
            allStages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
            latestSearchedStages = findLatestStagesWithEvent(allStages);
          });
        } else {
          setState(() {
            searchedVehicleNumber = vehicleNumber;
            latestSearchedStages = {};
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle not found.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      //Common logic to set additionalWorkStages always
      additionalWorkStages = stages
          .where((stage) => stage['stageName'] == 'Additional Work Job Approval')
          .toList();
      // Sort additionalWorkStages in descending order if needed
      additionalWorkStages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    } catch (error) {
      print('Error fetching vehicle details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error fetching vehicle details. Please try again.'),
          backgroundColor: Colors.red,
        ),
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
          const SnackBar(
            content: Text('Job Card started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Fetch the updated vehicle details after starting the job card
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
      }
    } catch (error) {
      print('Error starting job card: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error starting job card. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
          const SnackBar(
            content: Text('Additional Work started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Fetch the updated vehicle details after starting additional work
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
      }
    } catch (error) {
      print('Error starting additional work: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error starting additional work. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: widget.onLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 20),
                    FadeIn(
                      child: Text(
                        "Loading...",
                        style: TextStyle(color: Colors.blue.shade300, fontSize: 16),
                      ),
                    )
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    /// QR Scan Section
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: Colors.grey.shade800,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "QR CODE SCANNER",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white54, thickness: 1),
                            const SizedBox(height: 15),
                            Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCameraOpen ? Colors.red.shade700 : Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  elevation: 8,
                                ),
                                onPressed: () => setState(() => isCameraOpen = !isCameraOpen),
                                icon: Icon(
                                  isCameraOpen ? Icons.close : Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                label: Text(
                                  isCameraOpen ? 'CLOSE SCANNER' : 'SCAN VEHICLE QR',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            if (isCameraOpen)
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue.shade700, width: 3),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
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
                            const SizedBox(height: 20),
                            // Read-only field for scanned vehicle number
                            Row(
                              children: [
                                const Icon(Icons.car_rental, color: Colors.white70),
                                const SizedBox(width: 10),
                                const Text(
                                  "SCANNED VEHICLE",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade700),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_car, color: Colors.blue.shade300, size: 28),
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
                                        fontSize: 18,
                                        fontWeight: _scannedVehicleController.text.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (scannedStages.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.timeline, color: Colors.white70),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "SCANNED VEHICLE STAGES",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade900),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: scannedStages.length,
                                  itemBuilder: (context, index) {
                                    final stage = scannedStages[index];
                                    return Card(
                                      color: index % 2 == 0 ? Colors.grey.shade700 : Colors.grey.shade800,
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        leading: Icon(
                                          stage['eventType'] == 'Start' ? Icons.play_arrow : Icons.stop,
                                          color: stage['eventType'] == 'Start' ? Colors.green : Colors.red,
                                          size: 28,
                                        ),
                                        title: Text(
                                          "${stage['stageName']} (${stage['eventType']})",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          "Timestamp: ${convertToIST(stage['timestamp'])}",
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Fixed action buttons layout
                            LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                // Check if width is sufficient for side-by-side buttons
                                if (constraints.maxWidth > 450) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: _buildJobCardButton(),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: _buildAdditionalWorkButton(),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Stack vertically if width is insufficient
                                  return Column(
                                    children: [
                                      _buildJobCardButton(),
                                      const SizedBox(height: 12),
                                      _buildAdditionalWorkButton(),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// Search Vehicle Section
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: Colors.grey.shade800,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "SEARCH VEHICLE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white54, thickness: 1),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: "Enter Vehicle Number",
                                labelStyle: TextStyle(color: Colors.amber.shade300),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.amber.shade700),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.amber.shade400, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(Icons.search, color: Colors.amber.shade300),
                                fillColor: Colors.grey.shade900,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  elevation: 8,
                                ),
                                onPressed: () {
                                  if (_searchController.text.isNotEmpty) {
                                    fetchVehicleDetails(_searchController.text);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a vehicle number to search.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                                label: const Text(
                                  'SEARCH VEHICLE',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (searchedVehicleNumber != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade700),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.amber.shade300),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Results for: $searchedVehicleNumber",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (latestSearchedStages.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.timeline, color: Colors.white70),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "SEARCHED VEHICLE LAST STAGES",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade900),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: latestSearchedStages.length,
                                  itemBuilder: (context, index) {
                                    String key = latestSearchedStages.keys.elementAt(index);
                                    Map<String, dynamic> stage = latestSearchedStages[key];
                                    
                                    // Determine if this is a start or end event
                                    bool isStart = key.contains("(Start)");
                                    
                                    return Card(
                                      color: index % 2 == 0 ? Colors.grey.shade700 : Colors.grey.shade800,
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        leading: Icon(
                                          isStart ? Icons.play_arrow : Icons.stop,
                                          color: isStart ? Colors.green : Colors.red,
                                          size: 28,
                                        ),
                                        title: Text(
                                          key,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          "Timestamp: ${convertToIST(stage['timestamp'])}",
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (searchedVehicleNumber != null && latestSearchedStages.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.amber.shade300, size: 48),
                                      const SizedBox(height: 10),
                                      Text(
                                        "No stages found for vehicle $searchedVehicleNumber",
                                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildJobCardButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        elevation: 8,
      ),
      onPressed: vehicleNumber == null 
        ? null
        : startJobCard,
      icon: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
      label: const Text(
        'Start Job Card',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAdditionalWorkButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        elevation: 8,
      ),
      onPressed: vehicleNumber == null
        ? null 
        : startAdditionalWork,
      icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
      label: const Text(
        'Add. Work Job',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}