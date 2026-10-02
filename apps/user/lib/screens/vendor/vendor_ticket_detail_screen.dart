import 'package:flutter/material.dart';

import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';

/// Ticket detail + reply box (Slice 1). Shows the ticket subject/status
/// plus the reply thread; the reply field is disabled while empty or
/// sending, and failures toast honestly with the typed text preserved.
class VendorTicketDetailScreen extends StatefulWidget {
  const VendorTicketDetailScreen({
    super.key,
    this.service = const VendorService(),
    this.ticket,
    this.ticketId,
  });

  final VendorService service;

  /// Seed for instant paint (from the list); refreshed from the server.
  final VendorTicket? ticket;
  final String? ticketId;

  @override
  State<VendorTicketDetailScreen> createState() =>
      _VendorTicketDetailScreenState();
}

class _VendorTicketDetailScreenState
    extends State<VendorTicketDetailScreen> {
  late Future<VendorTicket> _future;
  final _reply = TextEditingController();
  bool _sending = false;
  bool _canSend = false;

  String get _id =>
      widget.ticketId ?? widget.ticket?.id ?? '';

  @override
  void initState() {
    super.initState();
    _reply.addListener(
        () => setState(() => _canSend = _reply.text.trim().isNotEmpty));
    _future = widget.ticket != null && widget.ticket!.replies.isNotEmpty
        ? Future.value(widget.ticket)
        : widget.service.fetchTicket(_id);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = widget.service.fetchTicket(_id));

  Future<void> _send(VendorTicket current) async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final reply = await widget.service.addReply(current.id, text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reply.clear();
      });
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reply.body.isEmpty
              ? 'Reply sent.'
              : 'Reply sent.'),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e.code == 'UNAUTHENTICATED' || e.status == 401) {
        await const AuthService().handleUnauthorized();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          logInScreenRoute,
          (_) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${e.message} Your reply is kept.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e Your reply is kept.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<VendorTicket>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  height: 24,
                  width: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            );
          }
          if (snap.hasError) {
            final err = snap.error;
            final expired = err is AppException &&
                (err.code == 'UNAUTHENTICATED' || err.status == 401);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(expired
                        ? 'Session expired.'
                        : 'Could not load this ticket.'),
                    const SizedBox(height: 4),
                    Text(
                      expired ? 'Please log in again.' : '$err',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Color(0xFF6E6E73)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: expired
                          ? () async {
                              await const AuthService()
                                  .handleUnauthorized();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  logInScreenRoute,
                                  (_) => false,
                                );
                              }
                            }
                          : _refresh,
                      child: Text(expired ? 'Log in' : 'Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final ticket = snap.data!;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        ticket.subject.isEmpty
                            ? '(No subject)'
                            : ticket.subject,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${ticket.id}${ticket.createdAt.isNotEmpty ? ' \u00B7 ${ticket.createdAt}' : ''} \u00B7 ${ticket.status.isEmpty ? 'open' : ticket.status}',
                        style: const TextStyle(
                            color: Color(0xFF6E6E73)),
                      ),
                      const SizedBox(height: 16),
                      if (ticket.replies.isEmpty)
                        const Text(
                          'No replies yet — we reply within 1 business day.',
                          style: TextStyle(
                              color: Color(0xFF6E6E73)),
                        ),
                      for (final r in ticket.replies) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.author.isEmpty
                                      ? 'Support'
                                      : r.author,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(r.body),
                                if (r.createdAt.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    r.createdAt,
                                    style: const TextStyle(
                                      color: Color(0xFF6E6E73),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Write a reply',
                            hintText: 'Add more detail…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send reply',
                        onPressed: (!_canSend || _sending)
                            ? null
                            : () => _send(ticket),
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
