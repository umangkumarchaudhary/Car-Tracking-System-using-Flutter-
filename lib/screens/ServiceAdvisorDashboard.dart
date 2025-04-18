import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const String baseUrl = 'http://192.168.58.49:5000/api';

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
  String trackingLink = ''; // Track N-1 Calling link

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

  void showFuturisticMessage(String message, {Color color = Colors.cyanAccent}) {
  final snackBar = SnackBar(
    content: Text(
      message,
      style: const TextStyle(
        fontFamily: 'Orbitron', // Make sure this font is in pubspec.yaml or use default
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    duration: const Duration(seconds: 2),
    backgroundColor: color.withOpacity(0.9),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}


  /// Fetch vehicle details and update UI
  Future<void> fetchVehicleDetails(String vehicleNumber, {bool isQRScan = false}) async {
  setState(() => isLoading = true);
  _animationController.reset();
  _animationController.forward();
  HapticFeedback.mediumImpact(); // Add subtle feedback

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleNumber'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);

    await Future.delayed(const Duration(milliseconds: 400)); // Smooth UX delay

    if (isQRScan) {
      if (data['success'] == true && data.containsKey('vehicle')) {
        setState(() {
          vehicleId = data['vehicle']['_id'];
          this.vehicleNumber = vehicleNumber;
          _scannedVehicleController.text = vehicleNumber;
          scannedStages = [];
          stages = [];
        });

        showFuturisticMessage('Vehicle Found ✔', color: Colors.greenAccent);
      } else {
        setState(() {
          vehicleId = null;
          this.vehicleNumber = vehicleNumber;
          _scannedVehicleController.text = vehicleNumber;
          scannedStages = [];
          stages = [];
        });

        showFuturisticMessage(
          'Vehicle not found. Proceeding with new entry.',
          color: Colors.amberAccent,
        );
      }
    } else {
      if (data['success'] == true && data.containsKey('vehicle')) {
        setState(() {
          searchedVehicleNumber = vehicleNumber;
          List<Map<String, dynamic>> allStages = List<Map<String, dynamic>>.from(data['vehicle']['stages']);
          allStages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          latestSearchedStages = findLatestStagesWithEvent(allStages);
        });

        showFuturisticMessage('Vehicle Loaded ✅', color: Colors.greenAccent);
      } else {
        setState(() {
          searchedVehicleNumber = vehicleNumber;
          latestSearchedStages = {};
        });

        showFuturisticMessage('Vehicle not found 🚫', color: Colors.redAccent);
      }
    }

    // Handle additional work stages
    additionalWorkStages = stages
        .where((stage) => stage['stageName'] == 'Additional Work Job Approval')
        .toList();
    additionalWorkStages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
  } catch (error) {
    print('Error fetching vehicle details: $error');

    showFuturisticMessage(
      'Error fetching details. Please try again ⚠️',
      color: Colors.deepOrange,
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

  Future<void> readyForWashing() async {
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
          'stageName': 'Ready for Washing',  // Make sure this matches exactly with backend
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle marked as Ready for Washing'),
            backgroundColor: Colors.green,
          ),
        );
        // Fetch the updated vehicle details
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to mark as Ready for Washing'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Error marking ready for washing: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error marking ready for washing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startN1Calling() async {
    if (vehicleNumber == null) return;
    setState(() {
      isLoading = true;
    });

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
          'stageName': 'N-1 Calling',
          'eventType': 'Start',
        }),
      );

      final data = json.decode(response.body);

      if (data['success'] == true) {
        setState(() {
          trackingLink = data['trackingLink'] ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('N-1 Calling initiated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchVehicleDetails(vehicleNumber!, isQRScan: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to initiate N-1 Calling'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Error initiating N-1 Calling: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error initiating N-1 Calling. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                enabled: !isCameraOpen,
                                controller: _scannedVehicleController,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle Number',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.confirmation_number, color: Colors.white70),
                                  hintText: 'Scan QR code to auto-fill',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search, color: Colors.white70),
                                    onPressed: () {
                                      String scannedVehicleNumber = _scannedVehicleController.text.trim();
                                      if (scannedVehicleNumber.isNotEmpty) {
                                        fetchVehicleDetails(scannedVehicleNumber, isQRScan: true);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter vehicle number to search')));
                                      }
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              if (isCameraOpen)
                                SizedBox(
                                  height: 250,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: MobileScanner(
                                      fit: BoxFit.cover,
                                      onDetect: (capture) {
                                        final List<Barcode> barcodes = capture.barcodes;
                                        for (final barcode in barcodes) {
                                          String? scannedText = barcode.rawValue;
                                          if (scannedText != null) {
                                            setState(() {
                                              isCameraOpen = false;
                                              fetchVehicleDetails(scannedText, isQRScan: true);
                                              _scannedVehicleController.text = scannedText;
                                            });
                                            break;
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      /// Search Vehicle By Number
                      Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.grey.shade800,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                decoration: InputDecoration(
                                  labelText: 'Enter Vehicle Number',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.confirmation_number, color: Colors.white70),
                                  hintText: 'Search for vehicle details',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.grey.shade900,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search, color: Colors.white70),
                                    onPressed: () {
                                      String searchVehicleNumber = _searchController.text.trim();
                                      if (searchVehicleNumber.isNotEmpty) {
                                        fetchVehicleDetails(searchVehicleNumber);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter vehicle number to search')));
                                      }
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      /// Stages Section
                      Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.grey.shade800,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      Icons.list_alt,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "ACTIONS",
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
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      elevation: 8,
                                    ),
                                    onPressed: (vehicleNumber != null && latestSearchedStages['Job Card Creation + Customer Approval (Start)'] == null) ? startJobCard : null,
                                    icon: const Icon(Icons.assignment, color: Colors.white),
                                    label: const Text(
                                      'START JOB CARD',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      elevation: 8,
                                    ),
                                    onPressed: vehicleNumber != null ? startAdditionalWork : null,
                                    icon: const Icon(Icons.add_task, color: Colors.white),
                                    label: const Text(
                                      'ADDITIONAL WORK',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      elevation: 8,
                                    ),
                                    onPressed: vehicleNumber != null ? readyForWashing : null,
                                    icon: const Icon(Icons.local_car_wash, color: Colors.white),
                                    label: const Text(
                                      'READY FOR WASHING',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      elevation: 8,
                                    ),
                                    onPressed: vehicleNumber != null ? startN1Calling : null,
                                    icon: const Icon(Icons.phone, color: Colors.white),
                                    label: const Text(
                                      'N-1 CALLING',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              if (trackingLink.isNotEmpty)
                                FadeInUp(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 15),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade700,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Tracking Link:",
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () async {
                                                      final Uri url = Uri.parse(trackingLink);
                                                      if (await canLaunchUrl(url)) {
                                                        await launchUrl(url);
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot launch URL")));
                                                      }
                                                    },
                                                    child: Text(
                                                      trackingLink,
                                                      style: const TextStyle(
                                                        color: Colors.lightBlueAccent,
                                                        decoration: TextDecoration.underline,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy, color: Colors.white),
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: trackingLink));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Tracking link copied to clipboard')),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      /// Vehicle Details Section
                      if (searchedVehicleNumber != null)
                        FadeInUp(
                          child: Card(
                            elevation: 10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.grey.shade800,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          Icons.info,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "LATEST VEHICLE STATUS",
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
                                  if (latestSearchedStages.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: latestSearchedStages.entries.map((entry) {
                                        final stageName = entry.value['stageName'];
                                        final eventType = entry.value['eventType'];
                                        final timestamp = convertToIST(entry.value['timestamp']);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade700,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$stageName - $eventType',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  'Timestamp: $timestamp',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  else
                                    const Center(
                                      child: Text(
                                        'No stages found for this vehicle.',
                                        style: TextStyle(color: Colors.white70, fontSize: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
