import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:car_tracking_new/screens/helpers.dart';

class StagePerformanceScreen extends StatefulWidget {
  final List<dynamic> avgStageTimes;

  const StagePerformanceScreen({Key? key, required this.avgStageTimes}) : super(key: key);

  @override
  _StagePerformanceScreenState createState() => _StagePerformanceScreenState();
}

class _StagePerformanceScreenState extends State<StagePerformanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOutBack),
      ),
    );

    _gradientAnimation = ColorTween(
      begin: Colors.blue[900],
      end: Colors.black,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.avgStageTimes.isEmpty) {
      return Center(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 800),
          child: Text(
            "Workshop Analytics data Loading......",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _gradientAnimation.value ?? Colors.grey[900]!,
                Colors.black,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2 * _controller.value),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        turns: _controller.value * 0.05,
                        child: Icon(
                          Icons.rocket_launch,
                          color: Colors.blue[400],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[700]!,
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          "STAGE PERFORMANCE",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-0.5, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
                    )),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        "Average Completion Times",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildPerformanceTable(
                    headers: ["STAGE", "AVG TIME"],
                    rows: widget.avgStageTimes.map<List<String>>((stage) {
                      return [stage["displayName"].toString(), formatTime(stage["avgTime"])];
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPerformanceTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1, curve: Curves.easeOut),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1 * _controller.value),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Colors.grey[800]!,
                width: 1.0,
              ),
            ),
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[850]!,
                      Colors.grey[900]!,
                    ],
                  ),
                ),
                children: headers.map((header) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1 * _controller.value),
                          blurRadius: 5,
                          spreadRadius: 0.5,
                        )
                      ],
                    ),
                    child: Text(
                      header,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[300],
                        letterSpacing: 0.8,
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Data Rows
              ...rows.map((row) {
                return TableRow(
                  decoration: BoxDecoration(
                    color: rows.indexOf(row) % 2 == 0
                        ? Colors.grey[900]!
                        : Colors.grey[850]!,
                  ),
                  children: row.map((cell) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 600 + (rows.indexOf(row) * 100)),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      child: Text(
                        cell,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontWeight: row.indexOf(cell) == 0
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String formatTime(num milliseconds) {
    return Helpers.formatTime(milliseconds);
  }
}