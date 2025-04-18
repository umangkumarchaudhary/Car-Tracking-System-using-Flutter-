import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://final-mb-cts.onrender.com/api';

class BayTechnicianDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const BayTechnicianDashboard({Key? key, required this.token, required this.onLogout}) : super(key: key);

  @override
  State<BayTechnicianDashboard> createState() => _BayTechnicianDashboardState();
}

class _BayTechnicianDashboardState extends State<BayTechnicianDashboard> {
  final TextEditingController _vehicleNumberController = TextEditingController();
  bool _isLoading = false;
  bool _isCameraOpen = false;
  MobileScannerController? _scannerController;
  final List<String> _workTypes = [
    'PM', 'GR', 'Body and Paint', 'Diagnosis', 'PMGR', 'PMGR + Body&Paint', 'GR+ Body & Paint', 'PM+ Body and Paint'
  ];
  final List<String> _bayNumbers = List.generate(15, (index) => (index + 1).toString());
  String? _selectedWorkType;
  String? _selectedBayNumber;

  List<dynamic> _workInProgress = [];
  List<dynamic> _workPaused = [];
  List<dynamic> _workEnded = [];

  String _selectedFilter = 'In Progress';

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _fetchWorkData();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkData() async {
    setState(() => _isLoading = true);
    try {
      print('Fetching work data...'); // Debug: Indicate data fetching start
      final response = await http.get(
        Uri.parse('$baseUrl/bay-work-status'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
        print('Response Status Code: ${response.statusCode}'); // Debug: Print status code
      if (response.statusCode == 200) {
        print('Decoding response body...'); // Debug: Indicate decoding start
        final data = json.decode(response.body);
          print('Decoded data: $data'); // Debug: Print decoded data

        setState(() {
          _workInProgress = data['inProgress'] ?? [];
          // Sort _workInProgress to have the latest items at the top
          _workInProgress.sort((a, b) => 0); // No actual sorting, keeps the original order. If you have a timestamp, sort based on that.

          _workPaused = data['paused'] ?? [];
          _workEnded = data['ended'] ?? [];
        });
        // Debugging: Print the data after setting state
        print('In Progress: $_workInProgress');
        print('Paused: $_workPaused');
        print('Ended: $_workEnded');
      } else {
        print('Failed to fetch work data: ${response.statusCode}'); // Debug: Print failure message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch work data: ${response.statusCode}')),
        );
      }
    } catch (error) {
        print('Error fetching work data: $error'); // Debug: Print error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching work data: $error')),
      );
    } finally {
      setState(() => _isLoading = false);
        print('Fetching complete, isLoading: $_isLoading'); // Debug: Print loading state
    }
  }

  void _handleQRCode(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrValue = barcodes.first.rawValue!;
      setState(() {
        _vehicleNumberController.text = qrValue;
        _isCameraOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned vehicle: $qrValue')),
      );
    }
  }

  Future<void> _startWork() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please scan vehicle QR code')));
      return;
    }
    if (_selectedWorkType == null || _selectedBayNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select work type and bay number')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: json.encode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Bay Technician',
          'stageName': 'Bay Work: $_selectedWorkType',
          'eventType': 'Start',
          'workType': _selectedWorkType,
          'bayNumber': _selectedBayNumber,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work started successfully')));
        _fetchWorkData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to start work')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error starting work')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endWork() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No vehicle selected')));
      return;
    }
    if (_selectedWorkType == null || _selectedBayNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select work type and bay number')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: json.encode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Bay Technician',
          'stageName': 'Bay Work: $_selectedWorkType',
          'eventType': 'End',
          'workType': _selectedWorkType,
          'bayNumber': _selectedBayNumber,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work completed successfully')));
        _fetchWorkData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to end work')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error ending work')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pauseWork() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No vehicle selected')));
      return;
    }
    if (_selectedWorkType == null || _selectedBayNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select work type and bay number')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: json.encode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Bay Technician',
          'stageName': 'Bay Work: $_selectedWorkType',
          'eventType': 'Pause',
          'workType': _selectedWorkType,
          'bayNumber': _selectedBayNumber,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work paused')));
        _fetchWorkData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to pause work')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error pausing work')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resumeWork() async {
    if (_vehicleNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No vehicle selected')));
      return;
    }
    if (_selectedWorkType == null || _selectedBayNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select work type and bay number')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicle-check'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: json.encode({
          'vehicleNumber': _vehicleNumberController.text,
          'role': 'Bay Technician',
          'stageName': 'Bay Work: $_selectedWorkType',
          'eventType': 'Resume',
          'workType': _selectedWorkType,
          'bayNumber': _selectedBayNumber,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work resumed')));
        _fetchWorkData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to resume work')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error resuming work')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredWorkList {
      // Debugging: Print the selected filter
      print('Selected Filter: $_selectedFilter');
    switch (_selectedFilter) {
      case 'In Progress':
          print('Returning In Progress: $_workInProgress');
        return _workInProgress;
      case 'Paused':
          print('Returning Paused: $_workPaused');
        return _workPaused;
      case 'Ended':
          print('Returning Ended: $_workEnded');
        return _workEnded;
      default:
          print('Returning Default (In Progress): $_workInProgress');
        return _workInProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bay Technician Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() => _isCameraOpen = !_isCameraOpen);
              },
              child: Text(_isCameraOpen ? 'Close Scanner' : 'Open QR Scanner'),
            ),
            const SizedBox(height: 10),
            if (_isCameraOpen)
              SizedBox(
                height: 200,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleQRCode,
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _vehicleNumberController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.qr_code_scanner),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedWorkType,
              decoration: const InputDecoration(
                labelText: 'Work Type',
                border: OutlineInputBorder(),
              ),
              items: _workTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedWorkType = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBayNumber,
              decoration: const InputDecoration(
                labelText: 'Bay Number',
                border: OutlineInputBorder(),
              ),
              items: _bayNumbers.map((number) {
                return DropdownMenuItem(
                  value: number,
                  child: Text('Bay $number'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedBayNumber = value);
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                    ),
                    child: const Text('START WORK', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _endWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                    ),
                    child: const Text('END WORK', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _pauseWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                    ),
                    child: const Text('PAUSE WORK', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resumeWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                    ),
                    child: const Text('RESUME WORK', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('In Progress'),
                  selected: _selectedFilter == 'In Progress',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = 'In Progress');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Paused'),
                  selected: _selectedFilter == 'Paused',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = 'Paused');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Ended'),
                  selected: _selectedFilter == 'Ended',
                  onSelected: (selected) {
                    setState(() => _selectedFilter = 'Ended');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredWorkList.isEmpty
                      ? const Center(child: Text('No work found for selected filter.'))
                      : ListView.builder(
                          itemCount: _filteredWorkList.length,
                          itemBuilder: (context, index) {
                            final work = _filteredWorkList[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                title: Text('Vehicle: ${work['vehicleNumber'] ?? ''}'),
                                subtitle: Text('Work Type: ${work['workType'] ?? ''}\nBay: ${work['bayNumber'] ?? ''}'),
                                trailing: Text(_selectedFilter),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
