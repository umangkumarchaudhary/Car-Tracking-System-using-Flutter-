import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_tracking_new/screens/security_guard_dashboard.dart';
import 'package:car_tracking_new/screens/ActiveReceptionDashboard.dart';
import 'package:car_tracking_new/screens/ServiceAdvisorDashboard.dart';
import 'package:car_tracking_new/screens/JobControllerDashboard.dart';
import 'package:car_tracking_new/screens/FinalInspectionDashboard.dart';
import 'package:car_tracking_new/screens/WashingDashboard.dart';
import 'package:car_tracking_new/screens/BayTechnicianDashboard.dart';
import 'package:car_tracking_new/screens/AdminDashboard.dart';

const String BASE_URL = "https://mercedes-benz-car-tracking-system.onrender.com/api";
// Token refresh interval (4 hours in milliseconds)
const int TOKEN_REFRESH_INTERVAL = 4 * 60 * 60 * 1000;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'User Authentication',
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = true; // Added loading state for initial check
  String? token;
  String? userRole;
  Timer? _tokenRefreshTimer;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  void _checkLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedToken = prefs.getString('token');
    String? savedRole = prefs.getString('role');
    bool? isApproved = prefs.getBool('isApproved');
    
    if (savedToken != null && savedRole != null && (isApproved == true || savedRole == "Admin")) {
      // Verify token validity with the server before proceeding
      try {
        final response = await http.get(
          Uri.parse("$BASE_URL/verify-token"),
          headers: {"Authorization": "Bearer $savedToken"},
        ).timeout(Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          setState(() {
            token = savedToken;
            userRole = savedRole;
          });
          
          // Setup token refresh timer
          _setupTokenRefreshTimer();
          
          // Navigate to the appropriate dashboard
          _navigateToDashboard(savedToken, savedRole);
        } else {
          // Token is invalid, refresh it
          _refreshToken(savedToken);
        }
      } catch (e) {
        // If server is unreachable, use cached token anyway (offline access)
        setState(() {
          token = savedToken;
          userRole = savedRole;
          isLoading = false;
        });
        
        // Navigate using cached credentials
        _navigateToDashboard(savedToken, savedRole);
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _refreshToken(String oldToken) async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/refresh-token"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $oldToken"
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String newToken = data["token"];
        
        // Save the new token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', newToken);
        
        String? savedRole = prefs.getString('role');
        
        setState(() {
          token = newToken;
          userRole = savedRole;
          isLoading = false;
        });
        
        // Navigate to the appropriate dashboard
        if (savedRole != null) {
          _navigateToDashboard(newToken, savedRole);
        }
        
        // Setup new refresh timer
        _setupTokenRefreshTimer();
      } else {
        // If token refresh fails, logout user
        _logout();
      }
    } catch (e) {
      // On error, just proceed with the old token for now
      setState(() {
        isLoading = false;
      });
    }
  }
  
  void _setupTokenRefreshTimer() {
    // Cancel existing timer if any
    _tokenRefreshTimer?.cancel();
    
    // Set new timer to refresh token every 4 hours
    _tokenRefreshTimer = Timer.periodic(Duration(milliseconds: TOKEN_REFRESH_INTERVAL), (timer) {
      if (token != null) {
        _refreshToken(token!);
      }
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('isApproved');
    
    // Cancel token refresh timer
    _tokenRefreshTimer?.cancel();
    
    setState(() {
      token = null;
      userRole = null;
      isLoading = false;
    });
  }
  
  void _navigateToDashboard(String token, String role) {
    // Function to get logout handler for each dashboard
    VoidCallback getLogoutHandler() {
      return () async {
        _logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
        );
      };
    }
    
    Future.delayed(Duration.zero, () {
      switch (role) {
        case "Security Guard":
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (context) => SecurityGuardDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Active Reception Technician":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveReceptionDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Service Advisor":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceAdvisorDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Job Controller":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => JobControllerDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Final Inspection Technician":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FinalInspectionDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Washing":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WashingDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Bay Technician":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BayTechnicianDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        case "Admin":
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                token: token,
                onLogout: getLogoutHandler(),
              ),
            ),
          );
          break;
        default:
          // Handle unknown role
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid role. Please login again.")),
          );
          _logout();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/mercedes_logo.jpg',
                height: 100,
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Loading...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return token != null
        ? HomeScreen(token: token!, logout: _logout)
        : isLogin
            ? LoginScreen(
                switchMode: () => setState(() => isLogin = false),
                onLoginSuccess: (newToken, role) {
                  setState(() {
                    token = newToken;
                    userRole = role;
                  });
                  _setupTokenRefreshTimer();
                },
              )
            : RegisterScreen(switchMode: () => setState(() => isLogin = true));
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback switchMode;
  final Function(String token, String role) onLoginSuccess;
  
  LoginScreen({required this.switchMode, required this.onLoginSuccess});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController mobileController = TextEditingController();
  String selectedRole = "Security Guard";
  bool isLoading = false;
  bool rememberMe = true; // Default to true for better UX

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedMobile = prefs.getString('lastMobile');
    String? savedRole = prefs.getString('lastRole');
    
    if (savedMobile != null) {
      setState(() {
        mobileController.text = savedMobile;
      });
    }
    
    if (savedRole != null) {
      setState(() {
        selectedRole = savedRole;
      });
    }
  }

  void _login() async {
    if (mobileController.text.isEmpty) {
      _showSnackBar("Please enter mobile number");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse("$BASE_URL/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "mobile": mobileController.text,
              "role": selectedRole,
            }),
          )
          .timeout(Duration(seconds: 15)); // Increased timeout for slower networks

      setState(() => isLoading = false);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save credentials if "Remember Me" is checked
        if (rememberMe) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("lastMobile", mobileController.text);
          await prefs.setString("lastRole", selectedRole);
        }
        
        // Store user token, role and approval status
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("role", selectedRole);
        await prefs.setBool("isApproved", data["user"]["isApproved"] ?? false);
        
        // Notify the parent widget about successful login
        widget.onLoginSuccess(data["token"], selectedRole);
        
        // Navigate based on role
        switch (selectedRole) {
          case "Security Guard":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SecurityGuardDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Active Reception Technician":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ActiveReceptionDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Service Advisor":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceAdvisorDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Job Controller":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => JobControllerDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Final Inspection Technician":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FinalInspectionDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Washing":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WashingDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Bay Technician":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BayTechnicianDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          case "Admin":
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboard(
                  token: data["token"],
                  onLogout: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('role');
                    await prefs.remove('isApproved');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AuthScreen()),
                    );
                  },
                ),
              ),
            );
            break;

          default:
            _showSnackBar("Invalid role selected.");
            break;
        }
      } else {
        _showSnackBar(data["message"] ?? "Login failed. Please try again.");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Login failed! Check internet connection and try again.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 50),
            // Mercedes-Benz Logo
            Image.asset(
              'assets/mercedes_logo.jpg',
              height: 100,
            ),
            SizedBox(height: 20),
            // Welcome Text
            Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Login to continue",
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            SizedBox(height: 40),
            // Mobile Number Input
            TextField(
              controller: mobileController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Mobile Number",
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Role Dropdown
            DropdownButton<String>(
              dropdownColor: Colors.grey[900],
              value: selectedRole,
              onChanged: (newValue) => setState(() => selectedRole = newValue!),
              items: [
                "Admin",
                "Security Guard",
                "Active Reception Technician",
                "Service Advisor",
                "Job Controller",
                "Bay Technician",
                "Final Inspection Technician",
                "Washing",
              ].map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role, style: TextStyle(color: Colors.grey[400])),
                );
              }).toList(),
            ),
            SizedBox(height: 10),
            // Remember Me Checkbox
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? true;
                    });
                  },
                  checkColor: Colors.black,
                  fillColor: MaterialStateProperty.resolveWith(
                      (states) => Colors.grey[400]),
                ),
                Text(
                  "Remember Me",
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Login Button
            isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding:
                          EdgeInsets.symmetric(vertical: 15, horizontal: 80),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _login,
                    child: Text(
                      "Login",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
            SizedBox(height: 10),
            TextButton(
              onPressed: widget.switchMode,
              child: Text(
                "No account? Register here",
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final VoidCallback switchMode;
  RegisterScreen({required this.switchMode});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String selectedRole = "Security Guard";
  bool isLoading = false;

  void _register() async {
    // Validate inputs
    if (nameController.text.isEmpty) {
      _showSnackBar("Name is required");
      return;
    }
    
    if (mobileController.text.isEmpty) {
      _showSnackBar("Mobile number is required");
      return;
    }
    
    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse("$BASE_URL/register"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "name": nameController.text,
              "mobile": mobileController.text,
              "email": emailController.text,
              "role": selectedRole,
            }),
          )
          .timeout(Duration(seconds: 15));

      setState(() => isLoading = false);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (selectedRole == "Admin") {
          _showSnackBar("Admin registered successfully! You can login immediately.");
        } else {
          _showSnackBar("Registration successful! Please wait for admin approval before logging in.");
        }
        widget.switchMode();
      } else {
        _showSnackBar(data["message"] ?? "Registration failed. Please try again.");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Registration failed! Check internet connection and try again.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 50),
            // Mercedes-Benz Logo
            Image.asset(
              'assets/mercedes_logo.jpg',
              height: 100,
            ),
            SizedBox(height: 20),
            // Welcome Text
            Text(
              "Create an Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              selectedRole == "Admin" 
                ? "Create an Admin account"
                : "Account will require admin approval",
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            SizedBox(height: 40),
            // Name Input
            TextField(
              controller: nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Mobile Number Input
            TextField(
              controller: mobileController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Mobile Number",
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Email Input
            TextField(
              controller: emailController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email (optional)",
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),
            // Role Dropdown
            DropdownButton<String>(
              dropdownColor: Colors.grey[900],
              value: selectedRole,
              onChanged: (newValue) => setState(() => selectedRole = newValue!),
              items: [
                "Admin",
                "Security Guard",
                "Active Reception Technician",
                "Service Advisor",
                "Job Controller",
                "Bay Technician",
                "Final Inspection Technician",
                "Washing",
              ].map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role, style: TextStyle(color: Colors.grey[400])),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            // Register Button
            isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding:
                          EdgeInsets.symmetric(vertical: 15, horizontal: 80),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _register,
                    child: Text(
                      "Register",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
            SizedBox(height: 10),
            TextButton(
              onPressed: widget.switchMode,
              child: Text(
                "Already have an account? Login",
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String token;
  final VoidCallback logout;
  HomeScreen({required this.token, required this.logout});

  void _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('isApproved');
    logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Text("Welcome to the Workshop Tracking System"),
      ),
    );
  }
}