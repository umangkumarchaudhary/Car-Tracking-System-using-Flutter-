import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Constants
const String baseUrl = 'https://final-mb-cts.onrender.com/api';
const Duration apiTimeout = Duration(seconds: 15);
const Duration scanLockDuration = Duration(seconds: 2);

class ActiveReceptionDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ActiveReceptionDashboard({
    Key? key,
    required this.token,
    required this.onLogout,
  }) : super(key: key);

  @override
  _ActiveReceptionDashboardState createState() => _ActiveReceptionDashboardState();
}

class _ActiveReceptionDashboardState extends State<ActiveReceptionDashboard> {
  // State variables
  bool _isLoading = false;
  bool _isProfileLoading = false;
  bool _isReceptionActive = false;
  bool _isCameraOpen = false;
  bool _isScanning = false;
  bool _isStartButtonPressed = false;

  List<Map<String, dynamic>> _inProgressVehicles = [];
  List<Map<String, dynamic>> _finishedVehicles = [];
  final TextEditingController _vehicleNumberController = TextEditingController();
  String? _vehicleId;
  Map<String, dynamic> _userProfile = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (await _checkInternetConnection()) {
      await _fetchAllVehicles();
    }
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
      return false;
    }
    return true;
  }

  String _convertToIST(String? utcTimestamp) {
    if (utcTimestamp == null || utcTimestamp.isEmpty) return 'N/A';
    
    try {
      final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
      final utcTime = dateFormat.parseUTC(utcTimestamp);
      final istTime = utcTime.add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd-MM-yyyy hh:mm a').format(istTime);
    } catch (e) {
      debugPrint('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  Future<void> _handleQRCode(String code) async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _vehicleNumberController.text = code;
      _isCameraOpen = false;
    });

    try {
      await _checkVehicleInteractiveBayStatus(code);
    } finally {
      Future.delayed(scanLockDuration, () {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!await _checkInternetConnection()) return;

    setState(() => _isProfileLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: _buildHeaders(),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['profile'] is Map) {
          setState(() => _userProfile = data['profile']);
        } else {
          _showErrorSnackbar('Invalid profile data format');
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _fetchAllVehicles() async {
    if (!await _checkInternetConnection()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles'),
        headers: _buildHeaders(),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['vehicles'] is List) {
          _processVehicleData(data['vehicles']);
        } else {
          _showErrorSnackbar('Invalid vehicles data format');
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processVehicleData(List<dynamic> vehicles) {
    final List<Map<String, dynamic>> inProgress = [];
    final List<Map<String, dynamic>> finished = [];

    for (final vehicle in vehicles) {
      try {
        final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'Unknown';
        final stages = (vehicle['stages'] as List?) ?? [];

        final interactiveStages = stages
            .where((stage) => stage is Map && stage['stageName'] == 'Interactive Bay')
            .toList();

        if (interactiveStages.isNotEmpty) {
          final lastEvent = interactiveStages.last;
          final lastEventType = lastEvent['eventType']?.toString() ?? 'Unknown';

          final startTime = _convertToIST(interactiveStages.first['timestamp']?.toString());
          final endTime = interactiveStages.length > 1 
              ? _convertToIST(interactiveStages.last['timestamp']?.toString())
              : null;

          final startUserName = _extractUserName(interactiveStages.first);
          final endUserName = interactiveStages.length > 1 
              ? _extractUserName(interactiveStages.last)
              : null;

          if (lastEventType == 'Start') {
            inProgress.add(_buildVehicleMap(
              vehicleNumber, startTime, null, startUserName, null,
            ));
          } else if (lastEventType == 'End') {
            finished.add(_buildVehicleMap(
              vehicleNumber, startTime, endTime, startUserName, endUserName,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error processing vehicle: $e');
      }
    }

    if (mounted) {
      setState(() {
        _inProgressVehicles = inProgress;
        _finishedVehicles = finished;
      });
    }
  }

  String? _extractUserName(Map<String, dynamic> stage) {
    try {
      return stage['performedBy']?['userName']?.toString();
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _buildVehicleMap(
    String vehicleNumber,
    String startTime,
    String? endTime,
    String? startUserName,
    String? endUserName,
  ) {
    return {
      'vehicleNumber': vehicleNumber,
      'startTime': startTime,
      'endTime': endTime,
      'startUserName': startUserName ?? 'Unknown',
      'endUserName': endUserName ?? 'Unknown',
    };
  }

  Future<void> _startReception() async {
    if (_vehicleNumberController.text.isEmpty) {
      _showErrorSnackbar('Please scan a vehicle QR code first');
      return;
    }

    if (!await _checkInternetConnection()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Active Reception Technician',
          'stageName': 'Interactive Bay',
          'eventType': 'Start',
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _vehicleId = data['vehicle']?['_id']?.toString();
          setState(() {
            _isStartButtonPressed = true;
            _isReceptionActive = true;
          });
          _showSuccessSnackbar('Active Reception started');
          await _fetchAllVehicles();
        } else {
          _handleReceptionError(data);
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endReceptionForVehicle(String vehicleNumber) async {
    if (!await _checkInternetConnection()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'vehicleNumber': vehicleNumber,
          'role': 'Active Reception Technician',
          'stageName': 'Interactive Bay',
          'eventType': 'End',
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessSnackbar('Active Reception completed for $vehicleNumber');
          await _fetchAllVehicles();
          setState(() {
            _isReceptionActive = false;
            _isStartButtonPressed = false;
            _vehicleNumberController.clear();
          });
        } else {
          _handleReceptionError(data);
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkVehicleInteractiveBayStatus(String vehicleNumber) async {
    if (!await _checkInternetConnection()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles'),
        headers: _buildHeaders(),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['vehicles'] is List) {
          _processVehicleStatus(data['vehicles'], vehicleNumber);
        } else {
          _showErrorSnackbar('Invalid vehicle status data');
        }
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processVehicleStatus(List<dynamic> vehicles, String vehicleNumber) {
    bool foundVehicle = false;

    for (final vehicle in vehicles) {
      if (vehicle['vehicleNumber'] == vehicleNumber) {
        foundVehicle = true;
        final stages = (vehicle['stages'] as List?) ?? [];
        
        final interactiveStages = stages
            .where((stage) => stage is Map && stage['stageName'] == 'Interactive Bay')
            .toList();

        if (interactiveStages.isNotEmpty) {
          final lastEvent = interactiveStages.last;
          final lastEventType = lastEvent['eventType']?.toString();

          if (lastEventType == 'Start') {
            setState(() {
              _isStartButtonPressed = true;
              _isReceptionActive = true;
            });
            return;
          }
        }
        break;
      }
    }

    setState(() {
      _isStartButtonPressed = false;
      _isReceptionActive = false;
    });

    if (!foundVehicle) {
      _showErrorSnackbar('Vehicle not found');
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Bearer ${widget.token}',
      'Content-Type': 'application/json',
    };
  }

  void _handleReceptionError(Map<String, dynamic> data) {
    final message = data['message']?.toString() ?? 'Reception operation failed';
    if (message.contains('already started')) {
      _fetchVehicleDetails(_vehicleNumberController.text);
      setState(() => _isReceptionActive = true);
    } else {
      _showErrorSnackbar(message);
    }
  }

  Future<void> _fetchVehicleDetails(String vehicleNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/$vehicleNumber'),
        headers: _buildHeaders(),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() => _vehicleId = data['vehicle']?['_id']?.toString());
        }
      }
    } catch (e) {
      debugPrint('Error fetching vehicle details: $e');
    }
  }

  void _handleApiError(http.Response response) {
    final statusCode = response.statusCode;
    final message = 'API Error: $statusCode';
    _showErrorSnackbar(message);
  }

  void _handleNetworkError(Object error) {
    debugPrint('Network error: $error');
    _showErrorSnackbar('Network error occurred');
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Interactive Bay Reception",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'MercedesBenz',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAllVehicles,
            tooltip: 'Refresh Vehicle Data',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: _showProfileDialog,
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScannerSection(),
              const SizedBox(height: 20),
              _buildReceptionButton(),
              const SizedBox(height: 30),
              _buildVehicleLists(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: Icon(
              _isCameraOpen ? Icons.camera_alt : Icons.qr_code_scanner,
              size: 20,
            ),
            label: Text(
              _isCameraOpen ? 'Close Scanner' : 'Scan Vehicle QR',
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCameraOpen ? Colors.red[700] : Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => setState(() => _isCameraOpen = !_isCameraOpen),
          ),
          const SizedBox(height: 10),
          if (_isCameraOpen)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: MobileScanner(
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _handleQRCode(barcodes.first.rawValue!);
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _vehicleNumberController,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Scanned Vehicle No',
              labelStyle: TextStyle(color: Colors.grey[400]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceptionButton() {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              if (!_isStartButtonPressed) {
                await _startReception();
              } else {
                await _endReceptionForVehicle(_vehicleNumberController.text);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isStartButtonPressed ? Colors.red[700] : Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : Text(_isStartButtonPressed ? 'End Interactive Bay' : 'Start Interactive Bay'),
    );
  }

  Widget _buildVehicleLists() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVehicleListSection(
          title: 'Vehicles in Interactive Bay',
          vehicles: _inProgressVehicles,
          emptyText: 'No vehicles currently in Interactive Bay',
          icon: Icons.directions_car,
          iconColor: Colors.blue[300]!,
        ),
        const SizedBox(height: 20),
        _buildVehicleListSection(
          title: 'Completed Vehicles',
          vehicles: _finishedVehicles,
          emptyText: 'No vehicles have completed Interactive Bay',
          icon: Icons.check_circle,
          iconColor: Colors.green[300]!,
        ),
      ],
    );
  }

  Widget _buildVehicleListSection({
    required String title,
    required List<Map<String, dynamic>> vehicles,
    required String emptyText,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'MercedesBenz',
          ),
        ),
        const SizedBox(height: 10),
        vehicles.isEmpty
            ? Text(emptyText, style: TextStyle(color: Colors.grey[400]))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vehicles.length,
                itemBuilder: (context, index) => _buildVehicleListItem(
                  vehicles[index],
                  icon,
                  iconColor,
                ),
              ),
      ],
    );
  }

  Widget _buildVehicleListItem(
    Map<String, dynamic> vehicle,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          vehicle['vehicleNumber']?.toString() ?? 'Unknown',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Time: ${vehicle['startTime']}',
              style: TextStyle(color: Colors.grey[400]),
            ),
            Text(
              'Started By: ${vehicle['startUserName']}',
              style: TextStyle(color: Colors.grey[400]),
            ),
            if (vehicle['endTime'] != null) ...[
              Text(
                'End: ${vehicle['endTime']}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                'Ended By: ${vehicle['endUserName']}',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'User Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'MercedesBenz',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: _isProfileLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileItem(Icons.person, 'Name', _userProfile['name']),
                  _buildProfileItem(Icons.email, 'Email', _userProfile['email']),
                  _buildProfileItem(Icons.phone, 'Mobile', _userProfile['mobile']),
                  _buildProfileItem(Icons.work, 'Role', _userProfile['role']),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, dynamic value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: TextStyle(color: Colors.grey)),
      subtitle: Text(
        value?.toString() ?? 'Not available',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }
}