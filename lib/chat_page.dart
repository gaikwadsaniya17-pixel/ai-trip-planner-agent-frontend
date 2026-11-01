import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

const _starters = [
  ('🏖️', '5 days in Goa on a budget'),
  ('🗼', 'Foodie trip to Tokyo, 7 days'),
  ('🏔️', 'Weekend trek in the Himalayas'),
  ('💙', 'Romantic week in Paris'),
];

const _followUps = [
  'Where should I stay?',
  'Make this trip cheaper',
  'What local food should I try?',
  'Add two more days to this trip',
];

class _Section {
  final String? title; // null = intro text before the first "## "
  final String body;
  _Section(this.title, this.body);
}

/// Splits the AI's markdown on "## " headings so each day can become a ticket.
List<_Section> _split(String md) {
  final out = <_Section>[];
  String? title;
  final buf = StringBuffer();
  void flush() {
    final b = buf.toString().trim();
    if (title != null || b.isNotEmpty) out.add(_Section(title, b));
    buf.clear();
  }

  for (final line in md.split('\n')) {
    if (line.startsWith('## ')) {
      flush();
      title = line.substring(3).replaceAll(RegExp(r'[*_`#]'), '').trim();
    } else {
      buf.writeln(line);
    }
  }
  flush();
  return out;
}

final _dayRe = RegExp(r'^day\s*(\d+)\s*[:\-–—.]?\s*(.*)$', caseSensitive: false);

IconData _iconFor(String t) {
  final s = t.toLowerCase();
  if (s.contains('budget') || s.contains('cost')) return Icons.account_balance_wallet_outlined;
  if (s.contains('tip')) return Icons.tips_and_updates_outlined;
  if (s.contains('stay') || s.contains('hotel')) return Icons.hotel_outlined;
  return Icons.explore_outlined;
}

final _sheet = MarkdownStyleSheet(
  p: body(15, color: Colors.white.withValues(alpha: .88), h: 1.55),
  strong: body(15, w: FontWeight.w700, color: C.amber, h: 1.55),
  em: body(15, color: Colors.white70, h: 1.55).copyWith(fontStyle: FontStyle.italic),
  listBullet: body(15, color: C.lagoon),
  a: body(15, color: C.lagoon).copyWith(decoration: TextDecoration.underline),
  h1: display(22),
  h2: display(20),
  h3: display(17),
  blockSpacing: 10,
  listIndent: 16,
);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _api = WayfarerApi();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMsg>[];
  String _sid = '';
  bool _loading = true;
  bool _sending = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    var sid = prefs.getString('sid');
    if (sid == null) {
      sid = const Uuid().v4();
      await prefs.setString('sid', sid);
    }
    _sid = sid;
    try {
      _messages.addAll(await _api.history(sid)); // also wakes the Render server
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    _jumpDown();
  }

  void _jumpDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  bool get _nearBottom =>
      !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 260;

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    _input.clear();

    final reply = ChatMsg('assistant', '');
    setState(() {
      _messages..add(ChatMsg('user', text))..add(reply);
      _sending = true;
      _status = null;
    });
    _jumpDown();

    final wakeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && reply.text.isEmpty) {
        setState(() => _status = 'Waking up the server. The first reply can take up to a minute.');
      }
    });

    try {
      await for (final chunk in _api.chat(_sid, text)) {
        final stick = _nearBottom;
        reply.text += chunk;
        if (mounted) setState(() => _status = null);
        if (stick) _jumpDown();
      }
      if (reply.text.isEmpty) reply.text = 'I got an empty reply. Send your message again.';
    } on ApiException catch (e) {
      reply.text = '⚠️ ${e.message}';
    } catch (_) {
      final msg = 'I lost the connection to the server. Check your internet and send it again.';
      reply.text = reply.text.isEmpty ? '⚠️ $msg' : '${reply.text}\n\n⚠️ $msg';
    } finally {
      wakeTimer.cancel();
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: C.dusk,
        title: Text('Start a new trip?', style: display(20)),
        content: Text('This deletes the current conversation.', style: body(14.5, color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep chatting')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete it')),
        ],
      ),
    );
    if (ok != true) return;
    await _api.clear(_sid);
    if (mounted) setState(_messages.clear);
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final showFollowUps = !_sending && _messages.isNotEmpty && !_messages.last.isUser && _messages.last.text.isNotEmpty;
    return Scaffold(
      body: Stack(children: [
        const Aurora(),
        SafeArea(
          child: Column(children: [
            _header(),
            Expanded(child: _loading ? _bootView() : (_messages.isEmpty ? _welcome() : _list())),
            if (showFollowUps) _followUpBar(),
            _composer(),
          ]),
        ),
      ]),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(gradient: C.sunset, shape: BoxShape.circle),
            child: const Icon(Icons.flight_takeoff_rounded, color: C.ink, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wayfarer', style: display(23)),
              Text('Your AI trip planner', style: body(12, color: Colors.white54)),
            ]),
          ),
          IconButton(
            tooltip: 'New trip',
            onPressed: (_messages.isEmpty || _sending) ? null : _confirmClear,
            icon: const Icon(Icons.add_road_rounded),
          ),
        ]),
      );

  Widget _bootView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const TypingDots(),
          const SizedBox(height: 14),
          Text('Getting your trips ready', style: body(14, color: Colors.white60)),
        ]),
      );

  Widget _welcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(gradient: C.sunset, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.public_rounded, color: C.ink, size: 34),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -4, end: 4, duration: 2200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 26),
          Text('Where to next?', style: display(46, w: FontWeight.w700))
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: .15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
          Text(
            'Tell me where you want to go, for how long and what you like. I\'ll plan it day by day.',
            style: body(16, color: Colors.white70, h: 1.5),
          ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
          const SizedBox(height: 28),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < _starters.length; i++)
              _pill('${_starters[i].$1}  ${_starters[i].$2}', () => _send(_starters[i].$2))
                  .animate(delay: (450 + i * 90).ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: .3, end: 0, curve: Curves.easeOutCubic),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white.withValues(alpha: .06),
              border: Border.all(color: Colors.white.withValues(alpha: .2)),
            ),
            child: Text(label, style: body(14, w: FontWeight.w500)),
          ),
        ),
      );

  Widget _list() => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final m = _messages[i];
          return m.isUser ? _userBubble(m) : _assistant(m);
        },
      );

  Widget _userBubble(ChatMsg m) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: C.sunset,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(m.text, style: body(15, color: C.ink, w: FontWeight.w600)),
        ),
      );

  Widget _assistant(ChatMsg m) {
    if (m.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Glass(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const TypingDots(),
              if (_status != null) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(_status!, style: body(12.5, color: Colors.white60)),
                ),
              ],
            ]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in _split(m.text)) Padding(padding: const EdgeInsets.only(bottom: 12), child: _section(s)),
      ]),
    );
  }

  Widget _section(_Section s) {
    final md = MarkdownBody(data: s.body, styleSheet: _sheet);
    if (s.title == null) return Glass(radius: 22, child: md);
    final day = _dayRe.firstMatch(s.title!);
    if (day != null) {
      final n = day.group(1)!;
      final theme = day.group(2)!.trim();
      return TicketCard(badge: DayBadge(n), title: theme.isEmpty ? 'Day $n' : theme, body: md);
    }
    return TicketCard(badge: IconBadge(_iconFor(s.title!)), title: s.title!, body: md);
  }

  Widget _followUpBar() => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _followUps.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Center(child: _pill(_followUps[i], () => _send(_followUps[i]))),
        ),
      );

  Widget _composer() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Glass(
          radius: 30,
          opacity: .09,
          padding: const EdgeInsets.fromLTRB(20, 4, 6, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                style: body(15.5),
                cursorColor: C.amber,
                decoration: InputDecoration(
                  hintText: 'Plan a trip to…',
                  hintStyle: body(15.5, color: Colors.white38),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            GestureDetector(
              onTap: _sending ? null : () => _send(_input.text),
              child: AnimatedContainer(
                duration: 250.ms,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _sending ? null : C.sunset,
                  color: _sending ? Colors.white12 : null,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: C.ink),
              ),
            ),
          ]),
        ),
      );
}
