import 'package:flutter/material.dart';
import 'package:car_tracking_new/screens/stage_performance.dart';
import 'package:car_tracking_new/screens/vehicle_count.dart';
import 'package:car_tracking_new/screens/all_vehicles.dart';
import 'package:car_tracking_new/screens/filters.dart';
import 'package:car_tracking_new/screens/section_buttons.dart';
import 'package:car_tracking_new/screens/api_service.dart';
import 'package:car_tracking_new/screens/helpers.dart';
import 'package:car_tracking_new/screens/UserDashboard.dart';

class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  AdminDashboard({required this.token, required this.onLogout});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> avgStageTimes = [];
  List<dynamic> vehicleCountPerStage = [];
  List<dynamic> allVehicles = [];
  int selectedSection = 0;
  String selectedValue = "all";
  bool isLoading = false;

  // Mapping of original stage names to display names
  final Map<String, String> stageNameMapping = {
    "Security Gate": "Security IN",  // Maps old name to new display name
    "Security IN": "Security IN",    // Maps new name consistently
    "Security Out": "Security Out",
    "Interactive Bay": "Interactive Bay",
    "Job Card Creation + Customer Approval": "Job Card Creation + Cust. App.",
    "Bay Allocation Started": "Bay Allocation",
    "Bay Work: PM": "Bay Work: PM",
    "Bay Work: GR": "Bay Work: GR",
    "Additional Work Job Approval": "Add. Work Appr.",
    "Final Inspection": "Final Inspection",
    "Washing": "Washing",
  };

  // Function to get display name from mapping
  String getStageDisplayName(String stageName) {
    return stageNameMapping[stageName] ?? stageName; // If not found, return original
  }

  final ApiService _apiService = ApiService();

  final List<String> stageOrder = [
    "Interactive Bay",
    "Job Card Creation + Customer Approval", // Original name
    "Bay Allocation Started", // Original name
    "Bay Work: PM", // Original name
    "Bay Work: GR", // Original name
    "Additional Work Job Approval", // Original name
    "Final Inspection", // Original name
    "Washing" // Original name
  ];

  final List<String> vehicleStageOrder = [
    "Security Gate",
    "Interactive Bay",
    "Job Card Creation + Customer Approval",
    "Bay Allocation Started",
    "Bay Work: PM",
    "Bay Work: GR",
    "Additional Work Job Approval",
    "Final Inspection",
    "Washing"
  ];

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);

    try {
      final stageData = await _apiService.fetchStagePerformance(selectedValue);
      final vehicleCountData = await _apiService.fetchVehicleCountPerStage(selectedValue);
      final allVehicleData = await _apiService.fetchAllVehicles();

      if (stageData != null) {
        stageData.removeWhere((stage) => stage["stageName"] == "Security Gate");
        

        // Filter to keep only known stage names
        final filteredStageData = stageData.where((stage) => stageOrder.contains(stage["stageName"])).toList();

        // Sort the filtered data based on the predefined order
        filteredStageData.sort((a, b) {
          int indexA = stageOrder.indexOf(a["stageName"]);
          int indexB = stageOrder.indexOf(b["stageName"]);
          return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
        });

        avgStageTimes = filteredStageData.map((stage) {
          return {
            ...stage,
            'displayName': getStageDisplayName(stage['stageName']), // Use mapping for display names
          };
        }).toList();
      }

      if (vehicleCountData != null) {
        // Filter to keep only known vehicle stage names
        final filteredVehicleData = vehicleCountData.where((stage) => vehicleStageOrder.contains(stage["stageName"])).toList();

        // Sort the filtered data based on the predefined order
        filteredVehicleData.sort((a, b) {
          int indexA = vehicleStageOrder.indexOf(a["stageName"]);
          int indexB = vehicleStageOrder.indexOf(b["stageName"]);
          return (indexA == -1 ? 999 : indexA).compareTo(indexB == -1 ? 999 : indexB);
        });
        vehicleCountPerStage = filteredVehicleData.map((stage) {
          return {
            ...stage,
            'displayName': getStageDisplayName(stage['stageName']), // Use mapping for display names
          };
        }).toList();
      }

      setState(() {
        allVehicles = allVehicleData ?? [];
        isLoading = false;
      });

    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar("Error fetching dashboard data");
      print("❌ Error fetching dashboard data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate screen width to determine button width
    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = (screenWidth - 40) / 3; // Equal width accounting for padding
    
    // Define fixed button styles for each button
    ButtonStyle blueButtonStyle = ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.blueAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      elevation: 8,
      shadowColor: Colors.blueAccent.withOpacity(0.5),
      fixedSize: Size(buttonWidth, 50), // Fixed size for all buttons
    );
    
    ButtonStyle greenButtonStyle = ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      elevation: 8,
      shadowColor: Colors.greenAccent.withOpacity(0.5),
      fixedSize: Size(buttonWidth, 50), // Fixed size for all buttons
    );
    
    ButtonStyle orangeButtonStyle = ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.orangeAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      elevation: 8,
      shadowColor: Colors.orangeAccent.withOpacity(0.5),
      fixedSize: Size(buttonWidth, 50), // Fixed size for all buttons
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_account),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDashboard(
                    token: widget.token,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            tooltip: "Go to User Dashboard",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchDashboardData,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Place the Buttons in a Row with equal spacing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Changed to spaceBetween for equal gaps
                    children: [
                      // Stage Performance button
                      ElevatedButton(
                        style: blueButtonStyle,
                        onPressed: () {
                          setState(() => selectedSection = 0);
                        },
                        child: Container(
                          width: buttonWidth - 16, // Account for button padding
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Stage Performance",
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      
                      // Vehicle Count button
                      ElevatedButton(
                        style: greenButtonStyle,
                        onPressed: () {
                          setState(() => selectedSection = 1);
                        },
                        child: Container(
                          width: buttonWidth - 16, // Account for button padding
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Vehicle Count",
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      
                      // All Vehicles button
                      ElevatedButton(
                        style: orangeButtonStyle,
                        onPressed: () {
                          setState(() => selectedSection = 2);
                        },
                        child: Container(
                          width: buttonWidth - 16, // Account for button padding
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "All Vehicles",
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Filters(
                    selectedValue: selectedValue,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedValue = value;
                          fetchDashboardData();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(10),
              child: Builder(builder: (context) {
                if (selectedSection == 0) {
                  return StagePerformanceScreen(avgStageTimes: avgStageTimes);
                } else if (selectedSection == 1) {
                  return VehicleCountScreen(vehicleCountPerStage: vehicleCountPerStage);
                } else {
                  return AllVehiclesScreen(allVehicles: allVehicles);
                }
              }),
            ),
          ),
        ],
      ),
    );
  }
}