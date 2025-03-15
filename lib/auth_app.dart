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

        case "Service Advisor": // ✅ Added Navigation for Service Advisor
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

          
        case "Job Controller": // ✅ Added Navigation for Service Advisor
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

          case "Washing Boy":
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
      appBar: AppBar(title: Text("Login")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: mobileController,
              decoration: InputDecoration(labelText: "Mobile Number"),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
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
  "Washing Boy",
].map((role) {
  return DropdownMenuItem(value: role, child: Text(role));
}).toList(),

            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text("Login"),
                  ),
            SizedBox(height: 10),
            TextButton(
              onPressed: widget.switchMode,
              child: Text("No account? Register here"),
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
      appBar: AppBar(title: Text("Register")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Name"),
            ),
            SizedBox(height: 20),
            TextField(
              controller: mobileController,
              decoration: InputDecoration(labelText: "Mobile Number"),
            ),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email (optional)"),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
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
  "Washing Boy",
].map((role) {
  return DropdownMenuItem(value: role, child: Text(role));
}).toList(),

            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: Text("Register"),
                  ),
            SizedBox(height: 10),
            TextButton(
              onPressed: widget.switchMode,
              child: Text("Already have an account? Login"),
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