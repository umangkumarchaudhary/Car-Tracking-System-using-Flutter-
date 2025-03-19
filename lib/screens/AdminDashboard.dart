import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  AdminDashboard({required this.token, required this.onLogout});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> allUsers = [];
  List<dynamic> pendingUsers = [];
  bool isLoading = true;
  bool isApproving = false;
  bool isDeleting = false;
  final String baseUrl = "http://192.168.108.49:5000/api";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch all users
      final allUsersResponse = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      // Fetch pending users
      final pendingUsersResponse = await http.get(
        Uri.parse('$baseUrl/users/pending'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (allUsersResponse.statusCode == 200 && pendingUsersResponse.statusCode == 200) {
        final allUsersData = json.decode(allUsersResponse.body);
        final pendingUsersData = json.decode(pendingUsersResponse.body);

        setState(() {
          allUsers = allUsersData['users'];
          pendingUsers = pendingUsersData['pendingUsers'];
          isLoading = false;
        });
      } else {
        _showSnackBar("Failed to load users. Please try again.");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _approveUser(String userId) async {
    setState(() {
      isApproving = true;
    });

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar("User approved successfully!");
        _loadUsers(); // Refresh user lists
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? "Failed to approve user.");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() {
        isApproving = false;
      });
    }
  }

  Future<void> _deleteUser(String userId) async {
    setState(() {
      isDeleting = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar("User deleted successfully!");
        _loadUsers(); // Refresh user lists
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? "Failed to delete user.");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() {
        isDeleting = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildUserList(List<dynamic> users, bool isPendingList) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          isPendingList ? "No pending approvals" : "No users found",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final bool isApproved = user['isApproved'] ?? false;
          
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  user['name'][0].toUpperCase(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user['name'] ?? "Unknown"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Mobile: ${user['mobile'] ?? 'N/A'}"),
                  Text("Role: ${user['role'] ?? 'N/A'}"),
                  Text("Status: ${isApproved ? 'Approved' : 'Pending'}"),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isApproved)
                    IconButton(
                      icon: Icon(Icons.check_circle, color: Colors.green),
                      onPressed: isApproving 
                          ? null 
                          : () => _showApproveConfirmation(user['_id']),
                    ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: isDeleting 
                        ? null 
                        : () => _showDeleteConfirmation(user['_id']),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  void _showApproveConfirmation(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Approve User"),
        content: Text("Are you sure you want to approve this user?"),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Approve"),
            onPressed: () {
              Navigator.pop(context);
              _approveUser(userId);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete User"),
        content: Text("Are you sure you want to delete this user? This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "All Users"),
            Tab(text: "Pending Approvals"),
          ],
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.blueAccent,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(allUsers, false),
          _buildUserList(pendingUsers, true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.refresh),
        onPressed: _loadUsers,
        tooltip: 'Refresh Users',
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}