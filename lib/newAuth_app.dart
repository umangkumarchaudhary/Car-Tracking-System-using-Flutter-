import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_tracking_new/screens/security_guard_dashboard.dart';
import 'package:car_tracking_new/screens/ActiveReceptionDashboard.dart';
import 'package:car_tracking_new/screens/ServiceAdvisorDashboard.dart';
import 'package:car_tracking_new/screens/JobControllerDashboard.dart';
import 'package:car_tracking_new/screens/BayTechnicianDashboard.dart';
import 'package:car_tracking_new/screens/FinalInspectionDashboard.dart';
import 'package:car_tracking_new/screens/WashingDashboard.dart';
import 'package:car_tracking_new/screens/PartsTeamDashboard.dart';
import 'package:car_tracking_new/screens/AdminDashboard.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  runApp(MyApp(initialToken: token));
}

// Define theme constants
class AppTheme {
  static const Color primaryColor = Colors.black;
  static const Color accentColor = Colors.white;
  static const Color backgroundColor = Colors.black;
  static const Color cardColor = Color(0xFF212121);
  static const Color textColor = Colors.white;
  static const Color errorColor = Color(0xFFE57373);
  
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      background: backgroundColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    appBarTheme: AppBarTheme(
      color: primaryColor,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accentColor, width: 1.0),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: primaryColor,
        backgroundColor: accentColor,
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  const MyApp({Key? key, this.initialToken}) : super(key: key);

  @override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'Workshop Auth',
    debugShowCheckedModeBanner: false, // 👈 Add this line
    theme: AppTheme.theme,
    initialRoute: initialToken == null ? '/login' : '/home',
    routes: {
      '/login': (context) => const AuthScreen(),
      '/register': (context) => const RegistrationScreen(),
      '/home': (context) => const HomeScreen(),
    },
  );
}

}

class AuthService {
  static const String _baseUrl = "https://final-mb-cts.onrender.com/api";
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final List<String> roles = [
  "Admin",
  "Workshop Manager",
  "Security Guard",
  "Active Reception Technician",
  "Service Advisor",
  "Job Controller",
  "Bay Technician",
  "Final Inspection Technician",
  "Washing",
  "Parts Team"  // Add this line
];

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final responseBody = json.decode(response.body);
    
    if (response.statusCode == 200 && responseBody['success'] == true) {
      return responseBody;
    } else {
      return {
        'success': false,
        'message': responseBody['message'] ?? 
                 'Failed with status ${response.statusCode}'
      };
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String mobile,
    required String password,
    required String role,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'mobile': mobile,
          'password': password,
          'role': role,
          'email': email
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginUser(String mobile, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mobile': mobile, 'password': password}),
    );
    return _handleResponse(response);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<List<dynamic>> getUsers(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return json.decode(response.body)['users'];
  }

  Map<String, dynamic> decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');

    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }

    return utf8.decode(base64Decode(output));
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await _authService.loginUser(
        _mobileController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response['success'] == true) {
        await _authService.saveToken(response['token']);

        final token = response['token'];
        final decodedToken = _authService.decodeToken(token);
        final userRole = decodedToken['role'];

        // Navigate based on user role
        if (userRole == 'Security Guard') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SecurityGuardDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Active Reception Technician') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveReceptionDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Service Advisor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceAdvisorDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Job Controller') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => JobControllerDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Bay Technician') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BayTechnicianDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Final Inspection Technician') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FinalInspectionDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Washing') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WashingDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                token: token,
                onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          );
        } else if (userRole == 'Parts Team') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => PartsTeamDashboard(
        token: token,
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
    ),
  );
}

         else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _showSnackBar(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height / 2, 
            left: 20, 
            right: 20),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  
  return Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF000913),
            Color(0xFF0A1A2A),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo Container
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: Color(0xFF9CA3AF).withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00A3E0).withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.star, // Replace with Mercedes logo if available
                            size: 60,
                            color: Color(0xFFCFD7E2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Brand Text
                      Text(
                        'SILVER STAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Login to Continue',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 60),
                      
                      // Login Form Card
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF0E1621).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF9CA3AF).withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mobile Number Field
                              _buildTextField(
                                controller: _mobileController,
                                label: 'Mobile Number',
                                icon: Icons.phone_android,
                                keyboardType: TextInputType.phone,
                                validator: (value) => value!.isEmpty ? 'Mobile number is required' : null,
                              ),
                              SizedBox(height: 24),
                              
                              // Password Field
                              _buildPasswordField(),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00A3E0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: Color(0xFF00A3E0).withOpacity(0.5),
                          ),
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Create Account Button
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CREATE NEW ACCOUNT',
                              style: TextStyle(
                                color: Color(0xFFCFD7E2),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Color(0xFF00A3E0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Custom text field builder method
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Color(0xFFAEB9C7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3A4A5A),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            prefixIcon: Icon(
              icon,
              color: Color(0xFF00A3E0),
              size: 20,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 40),
          ),
        ),
      ),
    ],
  );
}

// Password field with show/hide functionality
Widget _buildPasswordField() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Password',
        style: TextStyle(
          color: Color(0xFFAEB9C7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3A4A5A),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: _passwordController,
          style: TextStyle(color: Colors.white),
          obscureText: _obscurePassword,
          validator: (value) => value!.isEmpty ? 'Password is required' : null,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Color(0xFF00A3E0),
              size: 20,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 40),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Color(0xFF00A3E0),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ),
    ],
  );
}
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Security Guard';
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await _authService.registerUser(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        email: _emailController.text.trim(),
      );

      if (response['success'] == true) {
        Navigator.pop(context);
        _showSnackBar('Registration successful! Please login');
      } else {
        _showSnackBar(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showSnackBar('Error during registration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: message.contains('successful') 
            ? Colors.green 
            : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height / 2,
            left: 20,
            right: 20),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  
  return Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.accentColor),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF000913),
            Color(0xFF0A1A2A),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    // Mercedes Star Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: Color(0xFF9CA3AF).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.star,  // Replace with Mercedes logo if available
                          size: 50,
                          color: Color(0xFFCFD7E2),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Welcome Text
                    Text(
                      'WELCOME',
                      style: TextStyle(
                        color: Color(0xFFCFD7E2),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create Your Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 40),
                    
                    // Form Fields in a Card
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF0E1621).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF9CA3AF).withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name Field
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (value) => value!.isEmpty ? 'Name is required' : null,
                            ),
                            SizedBox(height: 20),
                            
                            // Role Dropdown
                            _buildDropdown(),
                            SizedBox(height: 20),
                            
                            // Mobile Field
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number',
                              icon: Icons.phone_android,
                              keyboardType: TextInputType.phone,
                              validator: (value) => value!.isEmpty ? 'Mobile number is required' : null,
                            ),
                            SizedBox(height: 20),
                            
                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email (optional)',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: 20),
                            
                            // Password Field
                            _buildPasswordField(),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00A3E0), 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: Color(0xFF00A3E0).withOpacity(0.5),
                        ),
                        onPressed: _isLoading ? null : _submitForm,
                        child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'REGISTER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Custom text field builder method
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Color(0xFFAEB9C7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3A4A5A),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            prefixIcon: Icon(
              icon,
              color: Color(0xFF00A3E0),
              size: 20,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 40),
          ),
        ),
      ),
    ],
  );
}

// Password field with show/hide functionality
Widget _buildPasswordField() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Password',
        style: TextStyle(
          color: Color(0xFFAEB9C7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3A4A5A),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: _passwordController,
          style: TextStyle(color: Colors.white),
          obscureText: _obscurePassword,
          validator: (value) => value!.isEmpty ? 'Password is required' : null,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Color(0xFF00A3E0),
              size: 20,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 40),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Color(0xFF00A3E0),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ),
    ],
  );
}

// Custom dropdown builder
Widget _buildDropdown() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Role',
        style: TextStyle(
          color: Color(0xFFAEB9C7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3A4A5A),
            width: 1,
          ),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedRole,
          icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF00A3E0)),
          dropdownColor: Color(0xFF1A2533),
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.work_outline,
              color: Color(0xFF00A3E0),
              size: 20,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 40),
          ),
          items: _authService.roles.map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              )).toList(),
          onChanged: (value) => setState(() => _selectedRole = value!),
        ),
      ),
    ],
  );
}
}

class HomeScreen extends StatefulWidget {
  final String? initialToken;
  const HomeScreen({Key? key, this.initialToken}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final token = widget.initialToken ?? await _authService.getToken();
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final decodedToken = _authService.decodeToken(token);
      final userRole = decodedToken['role'];

      if (userRole == 'Security Guard') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SecurityGuardDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Active Reception Technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveReceptionDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Service Advisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceAdvisorDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Job Controller') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JobControllerDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Bay Technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BayTechnicianDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Final Inspection Technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FinalInspectionDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Washing') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WashingDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else if (userRole == 'Parts Team') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => PartsTeamDashboard(
        token: token,
        onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
    ),
  );
}
      else if (userRole == 'Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboard(
              token: token,
              onLogout: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        );
      } else {
        setState(() => _userRole = userRole);
      }
    } catch (e) {
      print("Error decoding token or fetching user data: $e");
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HOME'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _userRole ?? 'Loading...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 40),
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 40),
            Text(
              'You are logged in',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}