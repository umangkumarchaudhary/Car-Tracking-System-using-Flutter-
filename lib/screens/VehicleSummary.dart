import 'package:flutter/material.dart';

class VehicleSummary extends StatelessWidget {
  final List<dynamic> vehiclesInside;
  final Map<String, dynamic> stats;
  final String avgTimeSpent;
  final Map<String, dynamic>? longestActive;

  const VehicleSummary({
    super.key,
    required this.vehiclesInside,
    required this.stats,
    required this.avgTimeSpent,
    required this.longestActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Vehicle Stats"),
          _buildStatsGrid(),

          const SizedBox(height: 24),
          _buildSectionTitle("Vehicles Inside"),
          ...vehiclesInside.map((v) => _buildVehicleCard(v)).toList(),

          const SizedBox(height: 24),
          _buildSectionTitle("Avg Time Spent"),
          _buildInfoCard(avgTimeSpent),

          if (longestActive != null) ...[
            const SizedBox(height: 24),
            _buildSectionTitle("Longest Active Vehicle"),
            _buildLongestActive(longestActive!),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatsGrid() {
    final entries = [
      ["Entered Today", stats['enteredToday']],
      ["Entered This Week", stats['enteredThisWeek']],
      ["Entered This Month", stats['enteredThisMonth']],
      ["Exited Today", stats['exitedToday']],
      ["Exited This Week", stats['exitedThisWeek']],
      ["Exited This Month", stats['exitedThisMonth']],
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: entries
          .map((e) => _buildInfoCard("${e[0]}: ${e[1]}", centered: false))
          .toList(),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          v['vehicleNumber'] ?? "Unknown Vehicle",
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Entry: ${v['entryIST']}", style: const TextStyle(color: Colors.white70)),
            Text("Duration: ${v['liveDuration']}", style: const TextStyle(color: Colors.white70)),
            Text("Stage: ${v['lastStage']}", style: const TextStyle(color: Colors.white70)),
            if (v['lastStageScannedAt'] != null)
              Text("Scanned At: ${v['lastStageScannedAt']}", style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, {bool centered = true}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: centered ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildLongestActive(Map<String, dynamic> data) {
    final vehicle = data['vehicle'];
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        title: Text(vehicle['registrationNumber'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Since: ${data['since']}", style: const TextStyle(color: Colors.white70)),
            Text("Duration: ${data['duration']}", style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
