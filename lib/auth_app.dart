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

const String BASE_URL = "http://192.168.108.49:5000/api";

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
  String? token;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  void _checkLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedToken = prefs.getString('token');
    if (savedToken != null) {
      setState(() {
        token = savedToken;
      });
    }
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    setState(() {
      token = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return token != null
        ? HomeScreen(token: token!, logout: _logout)
        : isLogin
            ? LoginScreen(switchMode: () => setState(() => isLogin = false))
            : RegisterScreen(switchMode: () => setState(() => isLogin = true));
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback switchMode;
  LoginScreen({required this.switchMode});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController mobileController = TextEditingController();
  String selectedRole = "Security Guard";
  bool isLoading = false;

  void _login() async {
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
          .timeout(Duration(seconds: 10));

      setState(() => isLoading = false);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);

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
        _showSnackBar(data["message"]);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Login failed! Check internet & server.");
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
                "Diagnosis Engineer",
                "Washing",
              ].map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role, style: TextStyle(color: Colors.grey[400])),
                );
              }).toList(),
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
                    onPressed: _login, // Call the existing login method here
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
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = "Security Guard";
  bool isLoading = false;

  void _register() async {
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
              "password": passwordController.text,
              "role": selectedRole,
            }),
          )
          .timeout(Duration(seconds: 10));

      print("Response Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      setState(() => isLoading = false);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _showSnackBar("Registration successful! Please login.");
        widget.switchMode();
      } else {
        _showSnackBar(data["message"]);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Registration failed! Check internet & server.");
      print("Error: $e");
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
              "Join us today",
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
            // Password Input
            TextField(
              controller: passwordController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
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
                "Diagnosis Engineer",
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
                    onPressed: _register, // Call the existing register method here
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
