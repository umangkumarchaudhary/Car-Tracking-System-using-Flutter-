import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class LiveStatusScreen extends StatefulWidget {
  final String token;
  const LiveStatusScreen({required this.token, Key? key}) : super(key: key);

  @override
  _LiveStatusScreenState createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic> dashboardData = {};
  String selectedTimePeriod = 'today';
  late TabController _tabController;
  final List<String> _timePeriods = ['today', 'thisWeek', 'thisMonth', 'lastMonth'];
  final List<String> _timePeriodsDisplay = ['Today', 'This Week', 'This Month', 'Last Month'];
  
  // Define Indian Standard Time offset (UTC+5:30)
  final Duration istOffset = const Duration(hours: 5, minutes: 30);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://final-mb-cts.onrender.com/api/dashboard/metrics?metricType=all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'  },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          dashboardData = responseData['data'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error fetching dashboard data: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Method to convert UTC to IST
  DateTime _convertToIST(DateTime utcTime) {
    return utcTime.add(istOffset);
  }

  // Format date and time for display with IST conversion
  String _formatDateTime(String dateTimeString) {
    final utcTime = DateTime.parse(dateTimeString);
    final istTime = _convertToIST(utcTime);
    return DateFormat('HH:mm, MMM d').format(istTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Text(
              'Silver Star',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchDashboardData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stages'),
            Tab(text: 'Service Advisor'),
            Tab(text: 'Job Controller'),
            Tab(text: 'Bay Work'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildTimePeriodSelector(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStageAveragesTab(),
                      _buildSpecialStageAveragesTab(),
                      _buildJobCardReceivedTab(),
                      _buildBayWorkTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _timePeriods.length,
          itemBuilder: (context, index) {
            final isSelected = _timePeriods[index] == selectedTimePeriod;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(_timePeriodsDisplay[index]),
                selected: isSelected,
                selectedColor: Colors.white.withOpacity(0.2),
                backgroundColor: Colors.grey[900],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      selectedTimePeriod = _timePeriods[index];
                    });
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageAveragesTab() {
    if (dashboardData['stageAverages'] == null) {
      return const Center(child: Text('No stage data available', style: TextStyle(color: Colors.white)));
    }

    final stageData = dashboardData['stageAverages'][selectedTimePeriod] as Map<String, dynamic>? ?? {};
    
    return stageData.isEmpty
        ? const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white)))
        : ListView(
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle('Stage Processing Times'),
              const SizedBox(height: 8),
              _buildStageAveragesChart(stageData),
              const SizedBox(height: 24),
              _buildStageAveragesList(stageData),
            ],
          );
  }

  Widget _buildStageAveragesChart(Map<String, dynamic> stageData) {
    final stages = stageData.keys.toList();
    final averageValues = stages.map((stage) {
      final avgTime = stageData[stage]['average'] as String;
      final timeParts = avgTime.split(':').map(int.parse).toList();
      // Convert to minutes for better visualization
      return timeParts[0] * 60 + timeParts[1] + (timeParts[2] / 60);
    }).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: averageValues.reduce((curr, next) => curr > next ? curr : next) * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.grey[800]!,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final stage = stages[groupIndex];
                final avgTime = stageData[stage]['average'] as String;
                return BarTooltipItem(
                  '$stage\n$avgTime',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < stages.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${value.toInt() + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()} min',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            stages.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: averageValues[index],
                  color: _getStageColor(index),
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStageColor(int index) {
    final colors = [
      const Color(0xFF00AEFF), // Light blue
      const Color(0xFF8A2BE2), // Blue violet
      const Color(0xFF00CED1), // Dark turquoise
      const Color(0xFFFF6347), // Tomato
      const Color(0xFF7FFF00), // Chartreuse
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFFD700), // Gold
      const Color(0xFF00FF7F), // Spring green
      const Color(0xFFFF4500), // Orange red
    ];
    return colors[index % colors.length];
  }

  Widget _buildStageAveragesList(Map<String, dynamic> stageData) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stageData.length,
      itemBuilder: (context, index) {
        final stage = stageData.keys.elementAt(index);
        final data = stageData[stage];
        
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text(
              stage,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.timer, size: 14, color: _getStageColor(index)),
                const SizedBox(width: 4),
                Text(
                  'Avg: ${data['average']}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.format_list_numbered, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Count: ${data['count']}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            children: [
              _buildStageDetailsTable(data['details']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStageDetailsTable(List<dynamic> details) {
  if (details.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text('No details available', style: TextStyle(color: Colors.white)),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: details.take(5).length,
    itemBuilder: (context, index) {
      final detail = details[index];
      final startTime = _formatDateTime(detail['startTime']);
      final endTime = _formatDateTime(detail['endTime']);
      
      return Card(
        color: Colors.grey[900],
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Vehicle + Duration (same row)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    detail['vehicleNumber'] ?? 'N/A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    detail['duration'],
                    style: TextStyle(
                      color: _getStageColor(index),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Start + End (formatted)
              _buildTimeRow("Start", startTime),
              SizedBox(height: 4),
              _buildTimeRow("End", endTime),
            ],
          ),
        ),
      );
    },
  );
}

// Helper widget for consistent time rows
Widget _buildTimeRow(String label, String time) {
  return Row(
    children: [
      Text("$label: ", style: TextStyle(color: Colors.white70, fontSize: 12)),
      Text(time, style: TextStyle(color: Colors.white, fontSize: 12)),
    ],
  );
}

  Widget _buildSpecialStageAveragesTab() {
    if (dashboardData['specialStageAverages'] == null) {
      return const Center(child: Text('No special stage data available', style: TextStyle(color: Colors.white)));
    }

    final specialData = dashboardData['specialStageAverages'][selectedTimePeriod] as Map<String, dynamic>? ?? {};
    
    return specialData.isEmpty
        ? const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white)))
        : ListView(
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle('Service Advisor Performance'),
              const SizedBox(height: 16),
              _buildSpecialStageCards(specialData),
            ],
          );
  }

  Widget _buildSpecialStageCards(Map<String, dynamic> specialData) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: specialData.length,
      itemBuilder: (context, index) {
        final stage = specialData.keys.elementAt(index);
        final data = specialData[stage];
        
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCard('Average', data['average'], Icons.timer),
                    _buildMetricCard('Total', data['totalDuration'], Icons.access_time),
                    _buildMetricCard('Count', data['count'].toString(), Icons.format_list_numbered),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recent Records',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStageDetailsTable(data['details']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobCardReceivedTab() {
    if (dashboardData['jobCardReceivedMetrics'] == null) {
      return const Center(child: Text('No job card data available', style: TextStyle(color: Colors.white)));
    }

    final jobCardData = dashboardData['jobCardReceivedMetrics'][selectedTimePeriod] as Map<String, dynamic>? ?? {};
    
    return jobCardData.isEmpty
        ? const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white)))
        : ListView(
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle('Job Card Processing Metrics'),
              const SizedBox(height: 16),
              _buildJobCardTimeline(jobCardData),
              const SizedBox(height: 24),
              ...jobCardData.entries.map((entry) => _buildJobCardMetricCard(entry.key, entry.value)),
            ],
          );
  }

  Widget _buildJobCardTimeline(Map<String, dynamic> jobCardData) {
    final List<Map<String, dynamic>> timelineData = [];
    
    jobCardData.forEach((key, value) {
      // Convert average time to minutes for visualization
      final avg = value['average'] as String;
      final timeParts = avg.split(':').map(int.parse).toList();
      final minutes = timeParts[0] * 60 + timeParts[1] + (timeParts[2] / 60);
      
      timelineData.add({
        'name': key,
        'minutes': minutes,
        'display': avg,
        'count': value['count'],
      });
    });

    // Sort by name to ensure consistent order
    timelineData.sort((a, b) => a['name'].compareTo(b['name']));

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          timelineData.length,
          (index) {
            final data = timelineData[index];
            final minutes = data['minutes'] as double;
            
            return Expanded(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 16,
                          height: (minutes > 0 ? minutes / timelineData.map((d) => d['minutes'] as double).reduce((a, b) => a > b ? a : b) : 0) * 100,
                          decoration: BoxDecoration(
                            color: _getStageColor(index),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              data['display'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatJobCardMetricName(data['name']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '(${data['count']})',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatJobCardMetricName(String name) {
    switch (name) {
      case 'jobCardReceivedBayAllocation':
        return 'JC Received + Bay Allocation';
      case 'jobCardReceivedByTechnician':
        return 'JC Received by Technician';
      case 'jobCardReceivedByFI':
        return 'JC Received by FI';
      default:
        return name;
    }
  }

  Widget _buildJobCardMetricCard(String metric, dynamic data) {
    final formattedName = _formatJobCardMetricName(metric);
    
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          formattedName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.timer, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Avg: ${data['average']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.format_list_numbered, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Count: ${data['count']}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        children: [
          _buildStageDetailsTable(data['details']),
        ],
      ),
    );
  }

  Widget _buildBayWorkTab() {
    if (dashboardData['bayWorkMetrics'] == null) {
      return const Center(child: Text('No bay work data available', style: TextStyle(color: Colors.white)));
    }

    final bayWorkData = dashboardData['bayWorkMetrics'][selectedTimePeriod] as Map<String, dynamic>? ?? {};
    
    if (bayWorkData.isEmpty) {
      return const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white)));
    }
    
    final overallData = bayWorkData['overall'] as Map<String, dynamic>? ?? {};
    final workTypeData = bayWorkData['byWorkType'] as Map<String, dynamic>? ?? {};

    return ListView(
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle('Bay Work Performance'),
        const SizedBox(height: 16),
        _buildOverallBayWorkCard(overallData),
        const SizedBox(height: 24),
        _buildWorkTypeDistributionChart(workTypeData),
        const SizedBox(height: 24),
        _buildSectionTitle('Work Type Breakdown'),
        const SizedBox(height: 8),
        ...workTypeData.entries.map((entry) => _buildWorkTypeCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildOverallBayWorkCard(Map<String, dynamic> overallData) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Bay Performance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCard('Average', overallData['average'], Icons.timer),
                _buildMetricCard('Active', overallData['activeDuration'], Icons.play_arrow),
                _buildMetricCard('Paused', overallData['pausedDuration'], Icons.pause),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMetricCard('Total', overallData['totalDuration'], Icons.access_time),
                const SizedBox(width: 16),
                _buildMetricCard('Jobs', overallData['count'].toString(), Icons.car_repair),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTypeDistributionChart(Map<String, dynamic> workTypeData) {
    if (workTypeData.isEmpty) {
      return const SizedBox();
    }

    final workTypes = workTypeData.keys.toList();
    final counts = workTypes.map((type) => workTypeData[type]['count'] as int).toList();
    final totalCount = counts.reduce((a, b) => a + b);

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Work Type Distribution',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 25,
                    sections: List.generate(
                      workTypes.length,
                      (index) {
                        final percent = counts[index] / totalCount * 100;
                        return PieChartSectionData(
                          color: _getStageColor(index),
                          value: counts[index].toDouble(),
                          title: '${percent.toStringAsFixed(1)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  workTypes.length,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStageColor(index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _shortenWorkType(workTypes[index]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortenWorkType(String workType) {
    if (workType.length > 12) {
      return '${workType.substring(0, 10)}...';
    }
    return workType;
  }

  Widget _buildWorkTypeCard(String workType, dynamic data) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          workType,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.timer, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Avg: ${data['average']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.format_list_numbered, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Count: ${data['count']}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCard('Active', data['activeDuration'], Icons.play_arrow),
                    _buildMetricCard('Paused', data['pausedDuration'], Icons.pause),
                    _buildMetricCard('Total', data['totalDuration'], Icons.access_time),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStageDetailsTable(data['details']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}