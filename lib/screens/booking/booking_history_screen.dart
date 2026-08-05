import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/app_widgets.dart';
import 'ticket_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  BookingStatus selected = BookingStatus.upcoming;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) context.read<BookingProvider>().load(user.id);
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) await context.read<BookingProvider>().load(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<BookingProvider>();
    final items = provider.bookings.where((b) => b.status == selected).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'my_bookings'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<BookingStatus>(
              segments: [
                ButtonSegment(value: BookingStatus.upcoming, label: Text(tr(lang, 'upcoming'))),
                ButtonSegment(value: BookingStatus.completed, label: Text(tr(lang, 'completed'))),
                ButtonSegment(value: BookingStatus.cancelled, label: Text(tr(lang, 'cancelled'))),
              ],
              selected: {selected},
              onSelectionChanged: (v) => setState(() => selected = v.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 160),
                            EmptyState(
                              icon: Icons.airplane_ticket_outlined,
                              title: tr(lang, 'no_booking'),
                              subtitle: tr(lang, 'no_booking_sub'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final booking = items[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: const CircleAvatar(child: Icon(Icons.flight)),
                                title: Text(
                                  '${booking.flight.departure.code} → ${booking.flight.arrival.code}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  '${dateOf(booking.flight.departureTime)}\nBooking ID: ${booking.id}',
                                ),
                                isThreeLine: true,
                                trailing: FilledButton.tonal(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => TicketScreen(booking: booking)),
                                  ),
                                  child: Text(tr(lang, 'view_ticket')),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
