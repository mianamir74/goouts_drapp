import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Challenge 25 check at the door, for orders with alcohol (13 Nov 2026).
//
//  Shown by ActiveDeliveryScreen before the delivery photo when the order has
//  hasAlcohol. Returns the check as a map for completeFoodDelivery:
//    {appearedDrunk, lookedUnder25, idChecked, idType, result}
//  result "refused" = the alcohol goes back to the restaurant, the food is
//  still handed over. Returns null if the driver backs out.
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF2F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0392CA);
  static const navy = Color(0xFF0D1B3E);
  static const body = Color(0xFF475569);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFDECEC);
  static const success = Color(0xFF16A34A);
}

class AlcoholCheckScreen extends StatefulWidget {
  const AlcoholCheckScreen({super.key});

  @override
  State<AlcoholCheckScreen> createState() => _AlcoholCheckScreenState();
}

class _AlcoholCheckScreenState extends State<AlcoholCheckScreen> {
  // Steps: 0 drunk?, 1 looks under 25?, 2 ID check, 3 refused
  int _step = 0;
  bool _drunk = false;
  bool _under25 = false;
  String _idType = '';

  void _finish({required String result, bool idChecked = false}) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'appearedDrunk': _drunk,
      'lookedUnder25': _under25,
      'idChecked': idChecked,
      'idType': idChecked ? _idType : '',
      'result': result,
    });
  }

  Widget _question(String title, String text, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: _C.navy)),
        const SizedBox(height: 10),
        Text(text,
            style: const TextStyle(fontSize: 15, height: 1.5, color: _C.body)),
        const SizedBox(height: 24),
        ...buttons,
      ],
    );
  }

  Widget _btn(String label, VoidCallback? onTap, {bool primary = true, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 54,
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color ?? _C.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color ?? _C.navy,
                  side: BorderSide(color: color ?? _C.navy),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _question(
          'This order has alcohol',
          'Before handing it over: does the customer appear drunk?',
          [
            _btn('No', () => setState(() => _step = 1)),
            _btn('Yes, they appear drunk', () => setState(() {
                  _drunk = true;
                  _step = 3;
                }), primary: false, color: _C.danger),
          ],
        );
      case 1:
        return _question(
          'Challenge 25',
          'Does the customer look under 25?',
          [
            _btn('No, they look 25 or over',
                () => _finish(result: 'handed_over')),
            _btn('Yes, they look under 25', () => setState(() {
                  _under25 = true;
                  _step = 2;
                }), primary: false),
          ],
        );
      case 2:
        return _question(
          'Check photo ID',
          'Ask for a passport, a photo driving licence or a PASS card. '
              'Check the photo matches and the date of birth shows they are 18 or over.',
          [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const [
                  ['passport', 'Passport'],
                  ['driving_licence', 'Driving licence'],
                  ['pass_card', 'PASS card'],
                  ['other', 'Other photo ID'],
                ])
                  ChoiceChip(
                    label: Text(t[1]),
                    selected: _idType == t[0],
                    onSelected: (_) => setState(() => _idType = t[0]),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _btn('ID checked: 18 or over',
                _idType.isEmpty ? null : () => _finish(result: 'handed_over', idChecked: true),
                color: _C.success),
            _btn('No ID, or under 18', () => setState(() => _step = 3),
                primary: false, color: _C.danger),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _C.dangerBg, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Do not hand over the alcohol.\n\n'
                'Hand over the food only. Take the alcohol back to the '
                'restaurant. GoOuts will refund the customer for it.',
                style: TextStyle(
                    fontSize: 16, height: 1.5, fontWeight: FontWeight.w700, color: _C.danger),
              ),
            ),
            const SizedBox(height: 24),
            _btn('OK, continue with the food only',
                () => _finish(result: 'refused', idChecked: false),
                color: _C.danger),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        foregroundColor: _C.navy,
        elevation: 0,
        title: const Text('Alcohol check'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _body(),
        ),
      ),
    );
  }
}
