import 'package:flutter/material.dart';

import '../core/app_localizations.dart';
import '../models/travel_models.dart';

/// From/To selector: two full-width rows showing code and city, with a swap
/// button. Tapping a row opens a searchable airport sheet.
class RouteSelector extends StatelessWidget {
  const RouteSelector({
    super.key,
    required this.from,
    required this.to,
    required this.airports,
    required this.lang,
    required this.onChanged,
  });

  final String from;
  final String to;
  final List<AirportEntity> airports;
  final String lang;

  /// Called with the new (from, to) pair.
  final void Function(String from, String to) onChanged;

  AirportEntity? _find(String code) {
    for (final a in airports) {
      if (a.code == code) return a;
    }
    return null;
  }

  Future<void> _pick(BuildContext context, {required bool isFrom}) async {
    final picked = await showAirportPicker(
      context,
      airports: airports,
      lang: lang,
      selected: isFrom ? from : to,
    );
    if (picked == null) return;
    final other = isFrom ? to : from;
    if (picked == other) {
      onChanged(to, from); // picking the other end means "swap"
    } else {
      onChanged(isFrom ? picked : from, isFrom ? to : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .75),
        ),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              _AirportRow(
                label: tr(lang, 'from'),
                icon: Icons.flight_takeoff_rounded,
                airport: _find(from),
                code: from,
                lang: lang,
                onTap: () => _pick(context, isFrom: true),
              ),
              Divider(
                height: 1,
                indent: 52,
                endIndent: 64,
                color: theme.colorScheme.outlineVariant,
              ),
              _AirportRow(
                label: tr(lang, 'to'),
                icon: Icons.flight_land_rounded,
                airport: _find(to),
                code: to,
                lang: lang,
                onTap: () => _pick(context, isFrom: false),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: tr(lang, 'swap'),
              onPressed: () => onChanged(to, from),
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirportRow extends StatelessWidget {
  const _AirportRow({
    required this.label,
    required this.icon,
    required this.airport,
    required this.code,
    required this.lang,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AirportEntity? airport;
  final String code;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final city = airport == null
        ? ''
        : cityName(lang, code, cityTh: airport!.cityTh, cityEn: airport!.cityEn);
    return Semantics(
      button: true,
      label: '$label $code $city',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 72, 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            code,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Searchable bottom sheet of airports. Returns the chosen IATA code.
Future<String?> showAirportPicker(
  BuildContext context, {
  required List<AirportEntity> airports,
  required String lang,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AirportSheet(
      airports: airports,
      lang: lang,
      selected: selected,
    ),
  );
}

class _AirportSheet extends StatefulWidget {
  const _AirportSheet({
    required this.airports,
    required this.lang,
    required this.selected,
  });

  final List<AirportEntity> airports;
  final String lang;
  final String? selected;

  @override
  State<_AirportSheet> createState() => _AirportSheetState();
}

class _AirportSheetState extends State<_AirportSheet> {
  String query = '';

  bool _matches(AirportEntity a) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [a.code, a.cityEn, a.cityTh, a.nameEn, a.nameTh]
        .any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = widget.lang;
    final matches = widget.airports.where(_matches).toList();
    final domestic = matches.where((a) => a.isDomestic).toList();
    final international = matches.where((a) => !a.isDomestic).toList();

    Widget tile(AirportEntity a) {
      final isSelected = a.code == widget.selected;
      return ListTile(
        minTileHeight: 60,
        leading: Container(
          width: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            a.code,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(cityName(lang, a.code, cityTh: a.cityTh, cityEn: a.cityEn)),
        subtitle: Text(lang == 'th' ? a.nameTh : a.nameEn),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).pop(a.code),
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'select_airport'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: tr(lang, 'search_airport'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (domestic.isNotEmpty) header(tr(lang, 'domestic')),
                ...domestic.map(tile),
                if (international.isNotEmpty) header(tr(lang, 'international')),
                ...international.map(tile),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(tr(lang, 'no_flights'))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
