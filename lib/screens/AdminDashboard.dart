import 'package:flutter/material.dart';
import 'package:car_tracking_new/screens/stage_performance.dart';
import 'package:car_tracking_new/screens/vehicle_count.dart';
import 'package:car_tracking_new/screens/all_vehicles.dart';
import 'package:car_tracking_new/screens/filters.dart';
import 'package:car_tracking_new/screens/section_buttons.dart';
import 'package:car_tracking_new/screens/api_service.dart';
import 'package:car_tracking_new/screens/helpers.dart';
import 'package:car_tracking_new/screens/UserDashboard.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';
import 'dart:math';


class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  AdminDashboard({required this.token, required this.onLogout});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  List<dynamic> avgStageTimes = [];
  List<dynamic> vehicleCountPerStage = [];
  List<dynamic> allVehicles = [];
  int selectedSection = 0;
  String selectedValue = "all";
  bool isLoading = true;
  late AnimationController _animationController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ApiService _apiService = ApiService();

  final List<String> stageOrder = [
    "Interactive Bay",
    "Job Card Creation + Customer Approval",
    "Bay Allocation Started",
    "Bay Work: PM",
    "Additional Work Job Approval",
    "Final Inspection",
    "Washing"
  ];

  final List<String> vehicleStageOrder = [
    "Security Gate",
    "Interactive Bay",
    "Job Card Creation + Customer Approval",
    "Bay Allocation Started",
    "Bay Work: PM",
    "Additional Work Job Approval",
    "Final Inspection",
    "Washing"
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    // Set preferred orientation to landscape for tablet/desktop
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    
    // Set system UI overlay style for immersive experience
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F1620),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    fetchDashboardData();
    
    // Start animation controller
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> fetchDashboardData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final stageData = await _apiService.fetchStagePerformance(selectedValue);
      final vehicleCountData = await _apiService.fetchVehicleCountPerStage(selectedValue);
      final allVehicleData = await _apiService.fetchAllVehicles();

      stageData.sort((a, b) => stageOrder.indexOf(a["stageName"]).compareTo(stageOrder.indexOf(b["stageName"])));
      vehicleCountData.sort(
          (a, b) => vehicleStageOrder.indexOf(a["stageName"]).compareTo(vehicleStageOrder.indexOf(b["stageName"])));

      setState(() {
        avgStageTimes = stageData;
        vehicleCountPerStage = vehicleCountData;
        allVehicles = allVehicleData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar("Error fetching dashboard data");
      print("❌ Error fetching dashboard data: $e");
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: fetchDashboardData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isTabletOrDesktop = size.width > 600;
    
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Color(0xFF0F1620),
      appBar: _buildAppBar(isTabletOrDesktop),
      drawer: isTabletOrDesktop ? null : _buildDrawer(),
      body: Stack(
        children: [
          // Background elements
          ..._buildBackgroundElements(),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                if (isTabletOrDesktop) 
                  _buildHeaderSection(),
                
                Expanded(
                  child: isLoading 
                    ? _buildLoadingView() 
                    : _buildMainContent(isTabletOrDesktop),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildBackgroundElements() {
    return [
      // Background gradient
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F1620),
              Color(0xFF1A2536),
              Color(0xFF0A0F17),
            ],
          ),
        ),
      ),
      
      // Mercedes logo watermark
      Positioned(
  bottom: -100,
  right: -100,
  child: Opacity(
    opacity: 0.04,
    child: Image.asset(
      'assets/mercedes_logo.jpg',
      width: 400,
      height: 400,
    ),
  ),
),

      
      // Animated particles or lines (simplified)
      Positioned.fill(
        child: CustomPaint(
          painter: NetworkLinesPainter(
            animationValue: _animationController.value,
          ),
        ),
      ),
    ];
  }

  PreferredSizeWidget _buildAppBar(bool isTabletOrDesktop) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Image.asset(
            'assets/mercedes_logo.jpg',
            height: 30,
          ),
          SizedBox(width: 10),
          Text(
            "ADMIN",
            style: GoogleFonts.montserrat(
              fontSize: isTabletOrDesktop ? 8 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        _buildRefreshButton(),
        _buildUserDashboardButton(),
        _buildLogoutButton(),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: GlassmorphicContainer(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
        blur: 20,
        alignment: Alignment.center,
        border: 0,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2536).withOpacity(0.7),
            Color(0xFF0F1620).withOpacity(0.9),
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/mercedes_logo.jpg',
                    width: 70,
                    height: 70,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Mercedes-Benz',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Workshop Analytics',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerTile(
              icon: Icons.insights,
              title: 'Stage Performance',
              isSelected: selectedSection == 0,
              onTap: () {
                setState(() => selectedSection = 0);
                Navigator.pop(context);
              },
            ),
            _buildDrawerTile(
              icon: Icons.bar_chart,
              title: 'Vehicle Count',
              isSelected: selectedSection == 1,
              onTap: () {
                setState(() => selectedSection = 1);
                Navigator.pop(context);
              },
            ),
            _buildDrawerTile(
              icon: Icons.directions_car,
              title: 'All Vehicles',
              isSelected: selectedSection == 2,
              onTap: () {
                setState(() => selectedSection = 2);
                Navigator.pop(context);
              },
            ),
            Divider(color: Colors.white24),
            _buildDrawerTile(
              icon: Icons.switch_account,
              title: 'User Dashboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, animation, __) => FadeTransition(
                      opacity: animation,
                      child: UserDashboard(
                        token: widget.token,
                        onLogout: widget.onLogout,
                      ),
                    ),
                    transitionDuration: Duration(milliseconds: 500),
                  ),
                );
              },
            ),
            _buildDrawerTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.lightBlue.shade200 : Colors.white70,
      ),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: isSelected ? Colors.lightBlue.shade200 : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
  
  Widget _buildRefreshButton() {
  return IconButton(
    icon: Icon(Icons.refresh, color: Colors.white),
    tooltip: 'Refresh Data',
    onPressed: () {
      _playButtonAnimation(); // ✅ Call animation inside onPressed
      fetchDashboardData();
      _showAnimatedToast('Refreshing data...');
    },
  );
}

  
Widget _buildUserDashboardButton() {
  return IconButton(
    icon: Icon(Icons.switch_account, color: Colors.white),
    tooltip: 'Go to User Dashboard',
    onPressed: () {
      _playButtonAnimation(); // ✅ Call animation inside onPressed

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: UserDashboard(
              token: widget.token,
              onLogout: widget.onLogout,
            ),
          ),
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    },
  );
}

  
 Widget _buildLogoutButton() {
  return IconButton(
    icon: Icon(Icons.logout, color: Colors.white),
    tooltip: 'Logout',
    onPressed: () {
      _playButtonAnimation(); // ✅ Call animation first
      _showLogoutConfirmation(); // ✅ Then show confirmation dialog
    },
  );
}

  
  void _playButtonAnimation() {
    return;
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Flexible(
            child: SectionButtons(
              onSectionSelected: (index) {
                setState(() => selectedSection = index);
              },
            ).animate().fade(duration: 400.ms).slideX(begin: -0.1, end: 0),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: double.infinity,
            child: Filters(
              selectedValue: selectedValue,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedValue = value;
                    fetchDashboardData();
                  });
                }
              },
            ).animate().fade(duration: 400.ms).slideX(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/Animation.json',
  width: 150,
  height: 150,
),
          SizedBox(height: 20),
          Text(
            'Loading Vehicle Tracking Dashboard',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent(bool isTabletOrDesktop) {
    return Column(
      children: [
        if (!isTabletOrDesktop)
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                SectionButtons(
                  onSectionSelected: (index) {
                    setState(() => selectedSection = index);
                  },
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
          
        Expanded(
          child: _buildContentSection(isTabletOrDesktop),
        ),
      ],
    );
  }
  
  Widget _buildContentSection(bool isTabletOrDesktop) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 20,
      blur: 15,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      ),
      margin: EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildSelectedSection(),
      ),
    );
  }
  
  Widget _buildSelectedSection() {
    Widget contentWidget;
    
    if (selectedSection == 0) {
      contentWidget = StagePerformanceScreen(avgStageTimes: avgStageTimes);
    } else if (selectedSection == 1) {
      contentWidget = VehicleCountScreen(vehicleCountPerStage: vehicleCountPerStage);
    } else {
      contentWidget = AllVehiclesScreen(allVehicles: allVehicles);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: contentWidget,
    );
  }
  
  void _showAnimatedToast(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 50,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: GlassmorphicContainer(
              width: 200,
              height: 50,
              borderRadius: 12,
              blur: 10,
              alignment: Alignment.center,
              border: 1,
              linearGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.lightBlue.withOpacity(0.2),
                  Colors.lightBlue.withOpacity(0.1),
                ],
              ),
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              child: Center(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
  
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassmorphicContainer(
            width: 350,
            height: 200,
            borderRadius: 20,
            blur: 20,
            alignment: Alignment.center,
            border: 1,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A2536).withOpacity(0.9),
                Color(0xFF0F1620).withOpacity(0.9),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/mercedes_logo.jpg',
                  width: 60,
                  height: 60,
                ),
                SizedBox(height: 15),
                Text(
                  'Confirm Logout',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Are you sure you want to log out?',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDialogButton(
                      'Cancel',
                      Colors.white24,
                      () => Navigator.pop(context),
                    ),
                    SizedBox(width: 16),
                    _buildDialogButton(
                      'Logout',
                      Colors.redAccent.withOpacity(0.7),
                      () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
 Widget _buildDialogButton(String text, Color color, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: () {
      _playButtonAnimation(); // ✅ Call animation first
      onPressed(); // ✅ Then execute the actual button action
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: Text(
      text,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
    ),
  );
}

}

// Custom painter for network lines effect
class NetworkLinesPainter extends CustomPainter {
  final double animationValue;
  
  NetworkLinesPainter({required this.animationValue});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
      
    final int linesCount = 10;
    final double spacing = size.height / linesCount;
    
    for (int i = 0; i < linesCount; i++) {
      final path = Path();
      final startY = i * spacing;
      
      path.moveTo(0, startY);
      
      for (int x = 0; x < size.width; x += 20) {
        final waveHeight = 10.0 * sin((x / 50) + (animationValue * 2) + i);
        path.lineTo(x.toDouble(), startY + waveHeight);
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(NetworkLinesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}