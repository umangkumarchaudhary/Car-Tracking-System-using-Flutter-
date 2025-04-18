import 'package:flutter/material.dart';
import 'InteractiveDashboardScreen.dart';
import 'WashingDashboardScreen.dart';
import 'FinalInspectionDashboardScreen.dart';
import 'PartsEstimateDashboardScreen.dart';
import 'BayWorkDashboardScreen.dart';
import 'JobCardCreationDashboardScreen.dart';

class StageDashboard extends StatelessWidget {
  final String authToken;

  const StageDashboard({super.key, required this.authToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Stage Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Interactive Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InteractiveDashboardScreen(authToken: authToken),
                  ),
                );
              },
              child: const Text(
                'Interactive',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Job Card Creation Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobCardCreationDashboardScreen(
                      authToken: authToken,
                      dashboardTitle: 'Job Card Creation Dashboard',
                    ),
                  ),
                );
              },
              child: const Text(
                'Job Card Creation',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Washing Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WashingDashboardScreen(
                      authToken: authToken,
                      dashboardTitle: 'Washing Dashboard',
                    ),
                  ),
                );
              },
              child: const Text(
                'Washing',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Final Inspection Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FinalInspectionDashboardScreen(
                      authToken: authToken,
                      dashboardTitle: 'Final Inspection Dashboard',
                    ),
                  ),
                );
              },
              child: const Text(
                'Final Inspection',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Parts Estimate Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PartsEstimateDashboardScreen(
                      authToken: authToken,
                      dashboardTitle: 'Parts Estimate Dashboard',
                    ),
                  ),
                );
              },
              child: const Text(
                'Parts Estimate',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Bay Work Dashboard Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BayWorkDashboardScreen(
                      authToken: authToken,
                      dashboardTitle: 'Bay Work Dashboard',
                    ),
                  ),
                );
              },
              child: const Text(
                'Bay Work',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
