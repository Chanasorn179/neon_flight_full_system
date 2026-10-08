import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_localizations.dart';
import '../core/theme.dart';
import '../models/app_notice.dart';
import '../providers/booking_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/booking/ticket_screen.dart';
import 'app_widgets.dart';

/// App-bar bell with an unseen count; opens the list of booking notices.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.watch<LanguageProvider>().languageCode;
    final bookings = context.watch<BookingProvider>();
    final enabled = context.watch<SettingsProvider>().notifications;
    final unseen = enabled ? bookings.unseenCount : 0;

    return IconButton(
      tooltip: unseen == 0
          ? tr(lang, 'notifications')
          : '${tr(lang, 'notifications')} ($unseen)',
      onPressed: () => _open(context),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        foregroundColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .6),
        ),
      ),
      icon: Badge(
        isLabelVisible: unseen > 0,
        label: Text(unseen > 9 ? '9+' : '$unseen'),
        child: Icon(
          unseen > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final provider = context.read<BookingProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _NoticeSheet(),
    );
    await provider.markNoticesSeen();
  }
}

class _NoticeSheet extends StatelessWidget {
  const _NoticeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<BookingProvider>();
    final enabled = context.watch<SettingsProvider>().notifications;
    final notices = provider.notices;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(tr(lang, 'notifications'), style: theme.textTheme.titleLarge),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr(lang, 'notifications_off_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (notices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 44,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(tr(lang, 'no_notifications')),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: notices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) => _NoticeTile(
                  notice: notices[i],
                  unseen: !provider.seenNotices.contains(notices[i].id),
                  lang: lang,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.notice,
    required this.unseen,
    required this.lang,
  });

  final AppNotice notice;
  final bool unseen;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final b = notice.booking;
    final f = b.flight;
    final route = '${f.departure.code} → ${f.arrival.code}';

    final (IconData icon, Color fg, Color bg, String title) = switch (notice.kind) {
      NoticeKind.departingSoon => (
          Icons.flight_takeoff_rounded,
          colors.primary,
          colors.primaryContainer,
          tr(lang, 'notice_soon'),
        ),
      NoticeKind.paymentPending => (
          Icons.hourglass_top_rounded,
          AppTheme.pendingForeground(theme.brightness),
          AppTheme.pendingBackground(theme.brightness),
          tr(lang, 'notice_pending'),
        ),
      NoticeKind.paid => (
          Icons.verified_rounded,
          theme.brightness == Brightness.dark
              ? const Color(0xFF7AD49A)
              : const Color(0xFF137A3A),
          theme.brightness == Brightness.dark
              ? const Color(0xFF15301F)
              : const Color(0xFFE5F5EA),
          tr(lang, 'notice_paid'),
        ),
      NoticeKind.cancelled => (
          Icons.block_rounded,
          colors.error,
          colors.errorContainer,
          tr(lang, 'notice_cancelled'),
        ),
    };

    final body = notice.kind == NoticeKind.paymentPending
        ? trArgs(lang, 'notice_pending_body', {'id': b.id, 'amount': money(b.fare.total)})
        : trArgs(lang, 'notice_route_body', {
            'route': route,
            'flight': f.flightNumber,
            'date': dateOf(f.departureTime),
            'time': timeOf(f.departureTime),
          });

    return Material(
      color: unseen ? colors.primaryContainer.withValues(alpha: .25) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        minTileHeight: 64,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: bg,
          child: Icon(icon, color: fg, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: unseen ? FontWeight.w800 : FontWeight.w600),
        ),
        subtitle: Text(body),
        trailing: unseen
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TicketScreen(booking: b)),
          );
        },
      ),
    );
  }
}
