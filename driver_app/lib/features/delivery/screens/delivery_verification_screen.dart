import 'package:flutter/material.dart';

/// Called from ActiveDeliveryScreen when the driver taps "Mark Delivered".
/// The driver takes a photo of the package at the door, or enters a PIN.
class DeliveryVerificationScreen extends StatefulWidget {
  final String orderId;
  const DeliveryVerificationScreen({super.key, required this.orderId});

  @override
  State<DeliveryVerificationScreen> createState() =>
      _DeliveryVerificationScreenState();
}

class _DeliveryVerificationScreenState
    extends State<DeliveryVerificationScreen> {
  bool _photoTaken = false;
  bool _showPin = false;
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _capturePhoto() {
    // In production: use camera_awesome or image_picker
    setState(() => _photoTaken = true);
  }

  void _confirm() {
    Navigator.pop(context, true); // signal delivery confirmed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Photo Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF0392ca).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: Row(
              children: const [
                Icon(Icons.verified_user,
                    color: Color(0xFF0392ca), size: 14),
                SizedBox(width: 4),
                Text('REQUIRED',
                    style: TextStyle(
                        color: Color(0xFF0392ca),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Instruction card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF0b1a3d),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color:
                            const Color(0xFF0392ca).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.door_front_door_outlined,
                        color: Color(0xFF0392ca)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confirm Delivery Spot',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        SizedBox(height: 4),
                        Text(
                          'Take a clear photo of the package at the customer\'s '
                          'door. Ensure the apartment number is visible if possible.',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Camera viewfinder ─────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF0b1a3d),
                    border: Border.all(
                        color: _photoTaken
                            ? const Color(0xFF10b981)
                            : Colors.white10,
                        width: _photoTaken ? 2 : 1),
                  ),
                  child: Stack(
                    children: [
                      // Grid painter for camera effect
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: _CameraGridPainter(),
                          size: Size.infinite,
                        ),
                      ),
                      // Corner brackets
                      ..._corners(),
                      // Status badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: const [
                              Icon(Icons.wb_sunny_outlined,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Good Lighting',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      // Center badge
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                              color: _photoTaken
                                  ? const Color(0xFF10b981)
                                      .withOpacity(0.9)
                                  : const Color(0xFF0392ca)
                                      .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _photoTaken
                                    ? Icons.check_circle
                                    : Icons.camera_alt_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _photoTaken
                                    ? 'PHOTO CAPTURED'
                                    : 'TAP TO CAPTURE',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Shutter controls ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundBtn(Icons.image_outlined),
                _shutterBtn(),
                _roundBtn(Icons.flash_on),
              ],
            ),

            const SizedBox(height: 24),

            const Text('OR',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ── PIN entry alternative ─────────────────────────────────
            if (!_showPin)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPin = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.pin_outlined),
                      SizedBox(width: 12),
                      Text('Enter Customer PIN',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0b1a3d),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8),
                        decoration: const InputDecoration(
                          hintText: '• • • •',
                          hintStyle: TextStyle(
                              color: Colors.white24, fontSize: 22),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0392ca),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Confirm',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),

            if (!_showPin)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Required for high-value orders if photo fails',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ),

            const SizedBox(height: 16),

            if (_photoTaken)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10b981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check),
                      SizedBox(width: 8),
                      Text('Confirm Delivery',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: const [
                Icon(Icons.info_outline,
                    color: Color(0xFF0392ca), size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy note: Photos are only stored temporarily to confirm delivery success.',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const c = Color(0xFF0392ca);
    const t = 18.0;
    const w = 3.0;
    Widget corner(Alignment a, bool top, bool left) => Positioned(
          top: a == Alignment.topLeft || a == Alignment.topRight ? 16 : null,
          bottom:
              a == Alignment.bottomLeft || a == Alignment.bottomRight ? 16 : null,
          left:
              a == Alignment.topLeft || a == Alignment.bottomLeft ? 16 : null,
          right:
              a == Alignment.topRight || a == Alignment.bottomRight ? 16 : null,
          child: SizedBox(
            width: t,
            height: t,
            child: CustomPaint(
              painter: _CornerPainter(c, w, top, left),
            ),
          ),
        );
    return [
      corner(Alignment.topLeft, true, true),
      corner(Alignment.topRight, true, false),
      corner(Alignment.bottomLeft, false, true),
      corner(Alignment.bottomRight, false, false),
    ];
  }

  Widget _roundBtn(IconData icon) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: const Color(0xFF0b1a3d), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      );

  Widget _shutterBtn() => GestureDetector(
        onTap: _capturePhoto,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(
                color: Color(0xFF0392ca), shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt,
                color: Colors.white, size: 32),
          ),
        ),
      );
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    // Rule-of-thirds grid
    canvas.drawLine(Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height), p);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), p);
    canvas.drawLine(Offset(0, size.height / 3),
        Offset(size.width, size.height / 3), p);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isTop;
  final bool isLeft;

  const _CornerPainter(
      this.color, this.strokeWidth, this.isTop, this.isLeft);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;

    canvas.drawLine(Offset(x, y),
        Offset(isLeft ? size.width : 0.0, y), p);
    canvas.drawLine(Offset(x, y),
        Offset(x, isTop ? size.height : 0.0), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
