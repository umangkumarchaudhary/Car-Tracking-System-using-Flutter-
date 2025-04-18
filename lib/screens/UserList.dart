import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class UserList extends StatefulWidget {
  final String authToken;

  const UserList({Key? key, required this.authToken}) : super(key: key);

  @override
  _UserListState createState() => _UserListState();
}

class _UserListState extends State<UserList> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allUsers = [];
  List<dynamic> _pendingUsers = [];
  List<dynamic> _filteredAllUsers = [];
  List<dynamic> _filteredPendingUsers = [];
  bool _isLoading = true;
  bool _isApproving = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterUsers);
    _fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
  if (widget.authToken.isEmpty) {
    debugPrint("❌ authToken is empty");
    return;
  }

  setState(() => _isLoading = true);
  debugPrint("🔐 Sent token: ${widget.authToken}");

  try {
    final allUsersResponse = await http.get(
      Uri.parse('http://final-mb-cts.onrender.com/api/users'),
      headers: {
        'Authorization': 'Bearer ${widget.authToken}',
        'Content-Type': 'application/json',
      },
    );

    final pendingUsersResponse = await http.get(
      Uri.parse('http://final-mb-cts.onrender.com/api/admin/pending-approvals'),
      headers: {
        'Authorization': 'Bearer ${widget.authToken}',
        'Content-Type': 'application/json',
      },
    );

    debugPrint("📦 All Users: ${allUsersResponse.statusCode} => ${allUsersResponse.body}");
    debugPrint("📦 Pending: ${pendingUsersResponse.statusCode} => ${pendingUsersResponse.body}");

    if (allUsersResponse.statusCode == 200 && pendingUsersResponse.statusCode == 200) {
      final allDecoded = json.decode(allUsersResponse.body);
      final pendingDecoded = json.decode(pendingUsersResponse.body);

      setState(() {
        _allUsers = allDecoded['users'] ?? [];
        _pendingUsers = pendingDecoded['users'] ?? [];
        _filteredAllUsers = _allUsers;
        _filteredPendingUsers = _pendingUsers;
        _isLoading = false;
      });
    } else {
      throw Exception('Failed to load users');
    }
  } catch (e) {
    debugPrint("❌ Error: $e");
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching users: $e')),
    );
  }
}


  Future<void> _approveUser(String userId) async {
    setState(() => _isApproving = true);

    try {
      final response = await http.post(
        Uri.parse('http://final-mb-cts.onrender.com/api/admin/approve-user/$userId'),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ User approved successfully')),
        );
        await _fetchUsers();
      } else {
        throw Exception("Failed to approve user");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isApproving = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAllUsers = _allUsers.where((user) {
        return user['name'].toLowerCase().contains(query) ||
               user['mobile'].toLowerCase().contains(query) ||
               user['role'].toLowerCase().contains(query);
      }).toList();

      _filteredPendingUsers = _pendingUsers.where((user) {
        return user['name'].toLowerCase().contains(query) ||
               user['mobile'].toLowerCase().contains(query) ||
               user['role'].toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All Users (${_allUsers.length})'),
            Tab(text: 'Pending (${_pendingUsers.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_filteredAllUsers, false),
                _buildUserList(_filteredPendingUsers, true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchUsers,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildUserList(List<dynamic> users, bool isPendingTab) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          isPendingTab ? 'No pending approvals' : 'No users found',
          style: const TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(user['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mobile: ${user['mobile']}'),
                  Text('Role: ${user['role']}'),
                  Text('Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(user['createdAt']))}'),
                ],
              ),
              trailing: isPendingTab
                  ? (_isApproving
                      ? const CircularProgressIndicator()
                      : IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _approveUser(user['_id']),
                        ))
                  : Icon(
                      user['isApproved'] ? Icons.verified : Icons.pending,
                      color: user['isApproved'] ? Colors.green : Colors.orange,
                    ),
            ),
          );
        },
      ),
    );
  }
}
