import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;

  const AppLogo({
    super.key,
    this.size = 60,
    this.showText = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = isDark || theme.brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CustomPaint(
            painter: LogoPainter(),
            size: Size(size, size),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'MarketHub',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: size * 0.4,
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

// Custom Painter to draw the logo
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    
    // Draw shopping bag icon
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw bag body (rounded rectangle)
    final Rect bagRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.7,
      height: size.height * 0.75,
    );
    
    final RRect bagRRect = RRect.fromRectAndRadius(
      bagRect,
      Radius.circular(size.width * 0.08),
    );
    
    canvas.drawRRect(bagRRect, paint);

    // Draw bag handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    // Left handle
    final leftHandlePath = Path()
      ..moveTo(
        center.dx - size.width * 0.25,
        center.dy - size.height * 0.35,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.3,
        center.dy - size.height * 0.5,
        center.dx - size.width * 0.1,
        center.dy - size.height * 0.45,
      );
    canvas.drawPath(leftHandlePath, handlePaint);

    // Right handle
    final rightHandlePath = Path()
      ..moveTo(
        center.dx + size.width * 0.25,
        center.dy - size.height * 0.35,
      )
      ..quadraticBezierTo(
        center.dx + size.width * 0.3,
        center.dy - size.height * 0.5,
        center.dx + size.width * 0.1,
        center.dy - size.height * 0.45,
      );
    canvas.drawPath(rightHandlePath, handlePaint);

    // Draw "M" letter inside the bag
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'M',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    // Draw sparkle dots
    final sparklePaint = Paint()..color = Colors.white.withOpacity(0.3);
    
    // Top right sparkle
    canvas.drawCircle(
      Offset(
        size.width * 0.85,
        size.height * 0.15,
      ),
      size.width * 0.04,
      sparklePaint,
    );
    
    // Bottom left sparkle
    canvas.drawCircle(
      Offset(
        size.width * 0.15,
        size.height * 0.85,
      ),
      size.width * 0.03,
      sparklePaint,
    );
    
    // Small sparkle
    canvas.drawCircle(
      Offset(
        size.width * 0.75,
        size.height * 0.8,
      ),
      size.width * 0.025,
      sparklePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}