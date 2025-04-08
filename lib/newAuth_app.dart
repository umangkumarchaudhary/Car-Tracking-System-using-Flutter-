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
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  runApp(MyApp(initialToken: token));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  const MyApp({Key? key, this.initialToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workshop Auth',
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
  static const String _baseUrl = "http://192.168.58.49:5000/api";
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
    "Washing"
  ];

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
  final responseBody = json.decode(response.body);
  
  if (response.statusCode == 200 && responseBody['success'] == true) {
    return responseBody;
  } else {
    // Return the error message from the backend if available
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
    // Print the request body for debugging
    print('Registering user with:');
    print('Name: $name, Mobile: $mobile, Role: $role, Email: $email');

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

      // Print the response status code and body for debugging
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('Error during registration: $e');
      return {'success': false, 'message': e.toString()}; // Return error message
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

  // Method to decode JWT token and get payload
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

        // Decode the token to get the user's role
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
        }
        
         else {
          Navigator.pushReplacementNamed(context, '/home');
        }
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
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height / 2), // Corrected line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
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

    // Only show success if both success flag is true and status code is good
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
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height / 2), // Corrected line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _authService.roles.map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    )).toList(),
                onChanged: (value) => setState(() => _selectedRole = value!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
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
  late Future<List<dynamic>> _usersFuture;
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
      }
      
      else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print("Error decoding token or fetching user data: $e");
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: FutureBuilder<List<dynamic>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user['name']),
                  subtitle: Text('${user['role']} - ${user['mobile']}'),
                );
              },
            );
          }
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'User Role: $_userRole',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await _authService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
