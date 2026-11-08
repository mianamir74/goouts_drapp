// GoOuts Help Assistant chat (8 Nov 2026).
// Instant answers from the GoOuts FAQs via the supportAsk Cloud Function, with
// a "Talk to a person" button that files a support ticket with the chat.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class HelpAssistantScreen extends StatefulWidget {
  /// consumer, driver or business
  final String app;

  /// Optional: opens the user's ticket list after a hand off.
  final VoidCallback? onOpenTickets;

  const HelpAssistantScreen({super.key, required this.app, this.onOpenTickets});

  @override
  State<HelpAssistantScreen> createState() => _HelpAssistantScreenState();
}

class _Msg {
  final bool fromUser;
  final String text;
  final List<String> related;
  final bool handoff;
  _Msg(this.fromUser, this.text, {this.related = const [], this.handoff = false});
}

class _HelpAssistantScreenState extends State<HelpAssistantScreen> {
  static const _blue = Color(0xFF0392CA);
  static const _navy = Color(0xFF0D1B3E);
  static const _bg = Color(0xFFF4F8FB);

  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _busy = false;
  bool _handingOff = false;
  String? _ticketNumber;

  List<String> get _starters => widget.app == 'consumer'
      ? const [
          'How do cashback rewards work?',
          'What is the welcome bonus?',
          'How does refer a friend work?',
          'Can I share my cashback?',
        ]
      : const [
          'How do I go online?',
          'How is my payment calculated?',
          'What is residual income?',
          'How do I introduce a business?',
        ];

  @override
  void initState() {
    super.initState();
    _msgs.add(_Msg(false,
        "Hello, I'm the GoOuts Help Assistant. Ask me a question, or tap one below."));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _ask(String q) async {
    final text = q.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    _toBottom();
    try {
      final r = await _fn.httpsCallable('supportAsk').call({'question': text, 'app': widget.app});
      final d = Map<String, dynamic>.from(r.data as Map);
      final related = ((d['related'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false, (d['answer'] ?? '').toString(),
          related: related, handoff: d['handoff'] == true)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false,
          "Sorry, I couldn't connect just now. Please try again, or tap Talk to a person.",
          handoff: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  Future<void> _handoff() async {
    if (_handingOff) return;
    setState(() => _handingOff = true);
    try {
      final transcript = _msgs
          .skip(1)
          .map((m) => {'from': m.fromUser ? 'user' : 'assistant', 'text': m.text})
          .toList();
      final r = await _fn
          .httpsCallable('supportHandoff')
          .call({'app': widget.app, 'transcript': transcript});
      final d = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        _ticketNumber = (d['ticketNumber'] ?? '').toString();
        _msgs.add(_Msg(false,
            'Done. Your request $_ticketNumber has gone to our support team with this chat attached. '
            "We'll reply in the app, in your support tickets."));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reach support. Please try again.')));
    } finally {
      if (mounted) setState(() => _handingOff = false);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.support_agent_rounded, color: _blue, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GoOuts Help',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
              Text('Instant answers, 24/7',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF60717D))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: _handingOff || _ticketNumber != null ? null : _handoff,
            child: const Text('Talk to a person',
                style: TextStyle(fontWeight: FontWeight.w700, color: _blue)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              children: [
                for (var i = 0; i < _msgs.length; i++) _bubble(_msgs[i], i == _msgs.length - 1),
                if (_msgs.length == 1) _chips(_starters),
                if (_busy) _typing(),
              ],
            ),
          ),
          _composer(),
        ]),
      ),
    );
  }

  Widget _bubble(_Msg m, bool last) {
    final user = m.fromUser;
    return Column(
      crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: user ? _blue : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(user ? 16 : 4),
              bottomRight: Radius.circular(user ? 4 : 16),
            ),
            boxShadow: user
                ? null
                : [BoxShadow(color: _navy.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(m.text,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: user ? Colors.white : _navy)),
        ),
        if (!user && m.related.isNotEmpty) _chips(m.related, label: 'Related questions'),
        if (!user && m.handoff && last && _ticketNumber == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _handingOff ? null : _handoff,
              icon: _handingOff
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_rounded, size: 18),
              label: const Text('Talk to a person'),
            ),
          ),
        if (!user && _ticketNumber != null && last && widget.onOpenTickets != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(onPressed: widget.onOpenTickets, child: const Text('Open my tickets')),
          ),
      ],
    );
  }

  Widget _chips(List<String> items, {String? label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A99A6))),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in items)
            ActionChip(
              label: Text(q, style: const TextStyle(fontSize: 13, color: _blue)),
              backgroundColor: Colors.white,
              side: BorderSide(color: _blue.withValues(alpha: 0.35)),
              onPressed: _busy ? null : () => _ask(q),
            ),
        ]),
      ]),
    );
  }

  Widget _typing() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
        ),
      );

  Widget _composer() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        color: Colors.white,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Type your question',
                filled: true,
                fillColor: _bg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: _blue),
            onPressed: _busy ? null : () => _ask(_input.text),
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ]),
      );
}
