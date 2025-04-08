import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:car_tracking_new/screens/helpers.dart';

class AllVehiclesScreen extends StatefulWidget {
  final List<dynamic> allVehicles;

  const AllVehiclesScreen({Key? key, required this.allVehicles}) : super(key: key);

  @override
  _AllVehiclesScreenState createState() => _AllVehiclesScreenState();
}

class _AllVehiclesScreenState extends State<AllVehiclesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _gradientAnimation;
  final Map<String, bool> _expandedStates = {};

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

    if (widget.allVehicles.isNotEmpty) {
      for (var vehicle in widget.allVehicles) {
        final vehicleNumber = vehicle['vehicleNumber']?.toString();
        if (vehicleNumber != null) {
          _expandedStates[vehicleNumber] = false;
        }
      }

      SchedulerBinding.instance.addPostFrameCallback((_) {
        _controller.forward();
        final firstVehicleNumber = widget.allVehicles.first['vehicleNumber']?.toString();
        if (firstVehicleNumber != null) {
          setState(() {
            _expandedStates[firstVehicleNumber] = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allVehicles.isEmpty) {
      return Center(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 800),
          child: Text(
            "No vehicles currently tracked",
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
                          Icons.directions_car_filled,
                          color: Colors.blue[400],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          "FLEET OVERVIEW",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
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
                        "Complete vehicle tracking history",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[400],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...widget.allVehicles.map((vehicle) {
                    final vehicleNumber = vehicle['vehicleNumber']?.toString() ?? 'Unknown';
                    final currentStage = vehicle['currentStage']?.toString();
                    final stageTimeline = (vehicle['stageTimeline'] as List<dynamic>?) ?? [];

                    return _buildVehicleCard(
                      vehicleNumber: vehicleNumber,
                      currentStage: currentStage,
                      stageTimeline: stageTimeline,
                      isExpanded: _expandedStates[vehicleNumber] ?? false,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedStates[vehicleNumber] = expanded;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleCard({
    required String vehicleNumber,
    required String? currentStage,
    required List<dynamic> stageTimeline,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              cardColor: Colors.grey[900],
            ),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: onExpansionChanged,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              collapsedBackgroundColor: Colors.grey[900],
              backgroundColor: Colors.grey[850],
              leading: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: Colors.blue[800]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.directions_car,
                  color: Colors.blue[400],
                ),
              ),
              title: Text(
                vehicleNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[200],
                ),
              ),
              subtitle: Text(
                currentStage != null ? "Current: $currentStage" : "Completed",
                style: TextStyle(
                  color: currentStage != null ? Colors.blue[300] : Colors.green[400],
                  fontSize: 12,
                ),
              ),
              trailing: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Colors.blue[300],
                ),
              ),
              children: stageTimeline.map<Widget>((stage) {
                final stageName = stage['stageName']?.toString() ?? 'Unknown Stage';
                final startTime = stage['startTime']?.toString();
                final endTime = stage['endTime']?.toString();
                final duration = stage['duration']?.toString() ?? '--';

                // Determine if this is a security stage
                final isSecurityIn = stageName == 'Security IN';
                final isSecurityOut = stageName == 'Security Out';
                final isSecurityStage = isSecurityIn || isSecurityOut;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, animation, child) {
                    return Transform.translate(
                      offset: Offset(50 * (1 - animation), 0),
                      child: Opacity(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isSecurityIn
                              ? Colors.amber[600]!
                              : isSecurityOut
                                  ? Colors.amber[800]!
                                  : endTime != null 
                                      ? Colors.green[400]! 
                                      : Colors.blue[400]!,
                          width: 3,
                        ),
                      ),
                      color: Colors.grey[850],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSecurityIn
                                ? Colors.amber[600]
                                : isSecurityOut
                                    ? Colors.amber[800]
                                    : endTime != null 
                                        ? Colors.green[400] 
                                        : Colors.blue[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stageName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSecurityStage 
                                      ? Colors.amber[300]
                                      : Colors.grey[200],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (startTime != null || endTime != null) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatDate(isSecurityOut ? endTime! : startTime!),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSecurityIn
                                          ? formatTimeOnly(startTime!) 
                                          : isSecurityOut
                                              ? formatTimeOnly(endTime!)
                                              : "${formatTimeOnly(startTime!)} - ${endTime != null ? formatTimeOnly(endTime) : 'Present'}",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isSecurityStage) // Only show duration for non-security stages
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              duration,
                              style: TextStyle(
                                color: Colors.blue[300],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String formatDate(String timestamp) {
    return Helpers.formatDate(timestamp);
  }

  String formatTimeOnly(String timestamp) {
    return Helpers.formatTimeOnly(timestamp);
  }
}