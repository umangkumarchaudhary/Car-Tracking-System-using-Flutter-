import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final String token;
  final VoidCallback logout;

  HomeScreen({required this.token, required this.logout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: logout,
          )
        ],
      ),
      body: Center(child: Text("Welcome to the Workshop Tracking System!")),
    );
  }
}
