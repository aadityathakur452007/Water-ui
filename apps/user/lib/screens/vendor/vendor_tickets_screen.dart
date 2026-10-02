import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_ticket_detail_screen.dart';

/// Support tickets list (Slice 1). Live mode fetches
/// `GET /api/vendor/tickets` with loading skeleton / empty / error-retry
/// per States.md; 401 routes to login via [AuthService.handleUnauthorized].
/// Demo mode is honest: tickets live on the server, so the screen shows
/// the static care contact instead of fake rows.
class VendorTicketsScreen extends StatefulWidget {
  const VendorTicketsScreen({super.key, this.service = const VendorService()});

  final VendorService service;

  @override
  State<VendorTicketsScreen> createState() => _VendorTicketsScreenState();
}

Color _ticketStatusColor(String status) {
  switch (status) {
    case 'open':
      return const Color(0xFF1B7BD6);
    case 'closed':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF6E6E73);
  }
}

class _VendorTicketsScreenState extends State<VendorTicketsScreen> {
  static bool get _live => !AppConfig.demoMode;

  Future<List<VendorTicket>>? _future;

  @override
  void initState() {
    super.initState();
    if (_live) _future = widget.service.fetchTickets();
  }

  void _refresh() {
    if (!_live) return;
    setState(() => _future = widget.service.fetchTickets());
  }

  Future<void> _openDetail(VendorTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorTicketDetailScreen(
          service: widget.service,
          ticket: ticket,
          ticketId: ticket.id,
        ),
      ),
    );
    if (mounted && _live) _refresh();
  }

  void _openNewTicketSheet() {
    final subject = TextEditingController();
    final message = TextEditingController();
    var saving = false;
    String? error;
    String? subjectError;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheet).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Open a support ticket',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Tell us what broke and what you expected. We reply within 1 business day.',
                style: TextStyle(color: Color(0xFF6E6E73)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subject,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Payout missing for 20 Sept',
                  errorText: subjectError,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: message,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText: 'Order IDs, slot, what you saw…',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(color: Color(0xFFD32F2F))),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final s = subject.text.trim();
                          final m = message.text.trim();
                          if (s.isEmpty || m.isEmpty) {
                            setSheet(() {
                              subjectError =
                                  s.isEmpty ? 'Enter a subject.' : null;
                              error = m.isEmpty
                                  ? 'Describe what happened.'
                                  : null;
                            });
                            return;
                          }
                          setSheet(() {
                            saving = true;
                            error = null;
                            subjectError = null;
                          });
                          try {
                            final created =
                                await widget.service.openTicket(
                              subject: s,
                              message: m,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            _refresh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Ticket opened.')),
                            );
                            _openDetail(created);
                          } on AppException catch (e) {
                            if (!mounted) return;
                            if (e.code == 'UNAUTHENTICATED' ||
                                e.status == 401) {
                              await const AuthService()
                                  .handleUnauthorized();
                              if (!mounted) return;
                              Navigator.pop(context);
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                logInScreenRoute,
                                (_) => false,
                              );
                              return;
                            }
                            setSheet(() {
                              saving = false;
                              error =
                                  '${e.message} Nothing was sent — try again.';
                            });
                          } catch (e) {
                            if (!sheet.mounted) return;
                            setSheet(() {
                              saving = false;
                              error = '$e Nothing was sent — try again.';
                            });
                          }
                        },
                  child: Text(saving ? 'Sending\u2026' : 'Open ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      subject.dispose();
      message.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support tickets')),
      floatingActionButton: _live
          ? FloatingActionButton.extended(
              onPressed: _openNewTicketSheet,
              icon: const Icon(Icons.add),
              label: const Text('New ticket'),
            )
          : null,
      body: !_live
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.support_agent,
                        color: Color(0xFF1B7BD6)),
                    title: Text('Shodasha Mineral Waters'),
                    subtitle: Text(
                        'Care: 1800-000-000 \u2022 care@shodasha.local'),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ticket tracking lives on the server — you are in demo mode, so there is nothing to list yet. The care contact above works now.',
                  style: TextStyle(color: Color(0xFF6E6E73)),
                ),
              ],
            )
          : FutureBuilder<List<VendorTicket>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _TicketSkeleton(),
                      SizedBox(height: 8),
                      _TicketSkeleton(),
                      SizedBox(height: 8),
                      _TicketSkeleton(),
                    ],
                  );
                }
                if (snap.hasError) {
                  final err = snap.error;
                  final expired = err is AppException &&
                      (err.code == 'UNAUTHENTICATED' ||
                          err.status == 401);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(expired
                              ? 'Session expired.'
                              : 'Could not load tickets.'),
                          const SizedBox(height: 4),
                          Text(
                            expired
                                ? 'Please log in again.'
                                : '$err',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF6E6E73)),
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
                final tickets = snap.data ?? const <VendorTicket>[];
                if (tickets.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      _refresh();
                      await _future;
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.support_agent,
                                color: Color(0xFF1B7BD6)),
                            title: Text('Shodasha Mineral Waters'),
                            subtitle: Text(
                                'Care: 1800-000-000 \u2022 care@shodasha.local'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('No support tickets yet.'),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Open one with the button below — we reply within 1 business day.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Color(0xFF6E6E73)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _openNewTicketSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Open your first ticket'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = tickets[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                            t.subject.isEmpty ? '(No subject)' : t.subject,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '#${t.id}${t.createdAt.isNotEmpty ? ' \u00B7 ${t.createdAt}' : ''}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _ticketStatusColor(t.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.status.isEmpty ? 'open' : t.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ticketStatusColor(t.status),
                              ),
                            ),
                          ),
                          onTap: () => _openDetail(t),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(width: 200),
            SizedBox(height: 8),
            _Bar(width: 120),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
