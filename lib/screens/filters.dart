import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class Filters extends StatefulWidget {
  final String selectedValue;
  final ValueChanged<String?> onChanged;

  const Filters({Key? key, required this.selectedValue, required this.onChanged}) : super(key: key);

  @override
  State<Filters> createState() => _FiltersState();
}

class _FiltersState extends State<Filters> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: math.pi,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isExpanded = true;
        });
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1F38),
                Color(_isHovered ? 0xFF343B65 : 0xFF2D3250),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: _isHovered ? 20 : 15,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Color(0xFF6C63FF).withOpacity(_isHovered ? 0.35 : 0.2),
                blurRadius: _isHovered ? 25 : 20,
                offset: const Offset(0, 2),
                spreadRadius: _isHovered ? 1 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Frosted glass effect
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                            width: 1,
                          ),
                          left: BorderSide(
                            color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Animated background particles
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: Particle(),
                ),

                // Animated glow accents
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        // Top right glow
                        Positioned(
                          top: -15,
                          right: -15,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: _isHovered ? 35 : 30,
                            width: _isHovered ? 35 : 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF6C63FF).withOpacity(_glowAnimation.value),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF6C63FF).withOpacity(_glowAnimation.value),
                                  blurRadius: _isHovered ? 35 : 25,
                                  spreadRadius: _isHovered ? 12 : 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom left subtle glow
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 25,
                            width: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF41C9FF).withOpacity(_glowAnimation.value * 0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF41C9FF).withOpacity(_glowAnimation.value * 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Holographic effect overlay
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isHovered ? 0.12 : 0.05,
                    child: CustomPaint(
                      painter: HolographicPainter(),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      // Animated icon
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _isHovered ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: value * 0.1,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.all(_isHovered ? 6 : 4),
                              decoration: BoxDecoration(
                                color: Color(0xFF6C63FF).withOpacity(_isHovered ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.access_time_rounded,
                                color: const Color(0xFF6C63FF),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: const Color(0xFF1A1F38),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: widget.selectedValue,
                              isExpanded: true,
                              icon: AnimatedBuilder(
                                animation: _rotationAnimation,
                                builder: (context, child) {
                                  return InkWell(
                                    onTap: () {
                                      if (_isExpanded) {
                                        _animationController.reverse();
                                      } else {
                                        _animationController.forward();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6C63FF).withOpacity(_isHovered ? 0.25 : 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _isHovered
                                            ? [
                                                BoxShadow(
                                                  color: Color(0xFF6C63FF).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Transform.rotate(
                                        angle: _rotationAnimation.value,
                                        child: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF6C63FF),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                letterSpacing: 0.3,
                              ),
                              dropdownColor: const Color(0xFF252A43),
                              menuMaxHeight: 300,
                              elevation: 12,
                              items: const [
                                DropdownMenuItem(
                                  value: "1",
                                  child: Text(
                                    "Last 24 Hours",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "7",
                                  child: Text(
                                    "Last 7 Days",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "30",
                                  child: Text(
                                    "Last 30 Days",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "all",
                                  child: Text(
                                    "All Time",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                widget.onChanged(value);
                                _animationController.reverse();
                              },
                              onTap: () {
                                if (_isExpanded) {
                                  _animationController.reverse();
                                } else {
                                  _animationController.forward();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Animated selection highlight
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: _isHovered ? 0 : -3,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF41C9FF).withOpacity(0.0),
                          Color(0xFF41C9FF).withOpacity(0.7),
                          Color(0xFF6C63FF).withOpacity(0.7),
                          Color(0xFF6C63FF).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom particle effect
class Particle extends StatefulWidget {
  @override
  State<Particle> createState() => _ParticleState();
}

class _ParticleState extends State<Particle> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double animationValue;
  List<ParticleModel> particles = [];
  final int numberOfParticles = 25;

  ParticlePainter(this.animationValue) {
    if (particles.isEmpty) {
      for (int i = 0; i < numberOfParticles; i++) {
        particles.add(ParticleModel(
          x: math.Random().nextDouble(),
          y: math.Random().nextDouble(),
          speed: math.Random().nextDouble() * 2,
          direction: math.Random().nextDouble() * 2 * math.pi,
        ));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final particle in particles) {
      final x = (particle.x + animationValue * 0.2) % 1;
      final y = (particle.y + animationValue * particle.speed * 0.1) % 1;

      final particleSize = particle.speed * 3;

      final Offset offset = Offset(x * size.width, y * size.height);
      canvas.drawCircle(offset, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ParticleModel {
  double x;
  double y;
  double speed;
  double direction;

  ParticleModel({
    required this.x,
    required this.y,
    required this.speed,
    required this.direction,
  });

  void move() {
    double dx = speed * math.cos(direction);
    double dy = speed * math.sin(direction);
    x += dx;
    y += dy;
  }
}

// Custom holographic effect painter
class HolographicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 12;
    for (double i = 0; i < size.width + size.height; i += step) {
      final start = Offset(math.max(0, i - size.height), math.min(i, size.height));
      final end = Offset(math.min(i, size.width), math.max(0, i - size.width));
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
