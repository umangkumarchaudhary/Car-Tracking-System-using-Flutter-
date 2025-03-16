import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_app.dart';
import 'screens/security_guard_dashboard.dart';
import 'screens/ActiveReceptionDashboard.dart'; 
import 'screens/ServiceAdvisorDashboard.dart';
import 'screens/JobControllerDashboard.dart';
import 'screens/FinalInspectionDashboard.dart';
import 'screens/WashingDashboard.dart';
import 'screens/BayTechnicianDashboard.dart';
import 'screens/AdminDashboard.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? token;
  String? role;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedToken = prefs.getString('token');
    String? savedRole = prefs.getString('role'); // Store role

    setState(() {
      token = savedToken;
      role = savedRole;
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear token & role

    setState(() {
      token = null;
      role = null;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()), // Navigate to login
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Tracking System',
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (token == null) {
      return AuthScreen();
    }

    if (role == "Security Guard") {
      return SecurityGuardDashboard(token: token!, onLogout: _logout);
    }

    if (role == "Active Reception Technician") { 
      return ActiveReceptionDashboard(token: token!, onLogout: _logout);
    }

    if (role == "Service Advisor") {
      return ServiceAdvisorDashboard(token: token!, onLogout: _logout);
    }

    if(role == "Job Controller"){
      return JobControllerDashboard(token: token!, onLogout: _logout);
    }

    if(role == "Final Inspection Technician"){
      return FinalInspectionDashboard(token: token!, onLogout: _logout);
    }

    if(role == "Washing Boy"){
      return WashingDashboard(token: token!, onLogout: _logout);
    }

    if(role == "Bay Technician"){
      return BayTechnicianDashboard(token: token!, onLogout: _logout);
    }

    if(role == "Admin"){
      return AdminDashboard(token: token!, onLogout: _logout);
    }

    return AuthScreen();
  }
}
