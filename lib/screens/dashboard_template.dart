import 'package:flutter/material.dart';

class DashboardTemplate extends StatelessWidget {
  final String title;

  DashboardTemplate({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text(
          "Hi, welcome to $title!",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
