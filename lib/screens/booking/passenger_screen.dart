import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/travel_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_service.dart';
import 'seat_selection_screen.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({
    super.key,
    required this.flight,
    required this.cabinClass,
    this.returnFlight,
    @visibleForTesting this.debugSavedPassengers,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;

  /// Round trip: the return leg, booked after seats are chosen for both legs.
  final FlightEntity? returnFlight;

  /// Screenshot tests: saved passengers to show without Firebase.
  final List<PassengerEntity>? debugSavedPassengers;

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final _form = GlobalKey<FormState>();
  late List<_PassengerFormData> forms;

  late List<PassengerEntity> savedPassengers = widget.debugSavedPassengers ?? const [];
  bool loadingSaved = true;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();

    final count = context.read<FlightProvider>().passengerCount;
    forms = List.generate(
      count,
      (i) => _PassengerFormData(index: i),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loadedOnce) return;
    _loadedOnce = true;

    Future.microtask(_loadSavedPassengers);
  }

  Future<void> _loadSavedPassengers() async {
    final user = context.read<AuthProvider>().currentUser;

    if (user == null || !FirebaseService.enabled) {
      if (mounted) {
        setState(() => loadingSaved = false);
      }
      return;
    }

    try {
      final saved = await FirebaseService.savedPassengers(user.id);

      if (!mounted) return;

      setState(() {
        savedPassengers = saved;
        loadingSaved = false;
      });

      // ถ้ายังไม่เคยบันทึกผู้โดยสารเลย ให้เติมข้อมูลพื้นฐานของบัญชี
      // ลง Passenger 1 ให้อัตโนมัติ เช่น ชื่อและอีเมล
      if (saved.isEmpty && forms.isNotEmpty) {
        final firstForm = forms.first;
        firstForm.applyAccount(
          fullName: user.name,
          emailAddress: user.email,
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingSaved = false);
      }
    }
  }

  @override
  void dispose() {
    for (final f in forms) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final passengers = forms.map((f) => f.toEntity()).toList();
    final user = context.read<AuthProvider>().currentUser;

    if (user != null && FirebaseService.enabled) {
      for (var i = 0; i < forms.length; i++) {
        if (!forms[i].saveForNextTime) continue;

        try {
          await FirebaseService.savePassenger(
            user.id,
            passengers[i],
          );
        } catch (_) {
          // การบันทึกผู้โดยสารเป็น convenience feature
          // ไม่ควรขวางขั้นตอนจองหาก Firestore มีปัญหาชั่วคราว
        }
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeatSelectionScreen(
          flight: widget.flight,
          cabinClass: widget.cabinClass,
          passengers: passengers,
          returnFlight: widget.returnFlight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(lang, 'passenger_info')),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loadingSaved)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),

            for (final f in forms)
              _PassengerForm(
                data: f,
                lang: lang,
                savedPassengers: savedPassengers,
              ),

            const SizedBox(height: 10),

            FilledButton.icon(
              onPressed: next,
              icon: const Icon(
                Icons.airline_seat_recline_normal,
              ),
              label: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  tr(lang, 'select_seat'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerFormData {
  _PassengerFormData({
    required this.index,
  });

  final int index;

  String title = 'Mr.';

  final first = TextEditingController();
  final last = TextEditingController();
  final nationality = TextEditingController(text: 'Thai');
  final passport = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();

  DateTime birth = DateTime(2000, 1, 1);
  DateTime expiry = DateTime.now().add(
    const Duration(days: 365 * 3),
  );

  bool saveForNextTime = true;
  String? selectedPassport;

  void apply(PassengerEntity passenger) {
    title = passenger.title;
    first.text = passenger.firstName;
    last.text = passenger.lastName;
    nationality.text = passenger.nationality;
    passport.text = passenger.passportNumber;
    phone.text = passenger.phone;
    email.text = passenger.email;
    birth = passenger.birthDate;
    expiry = passenger.passportExpiry;
    selectedPassport = passenger.passportNumber;
  }

  void applyAccount({
    required String fullName,
    required String emailAddress,
  }) {
    final parts = fullName.trim().split(RegExp(r'\s+'));

    if (parts.isNotEmpty) {
      first.text = parts.first;
    }

    if (parts.length > 1) {
      last.text = parts.skip(1).join(' ');
    }

    email.text = emailAddress;
  }

  void clear() {
    title = 'Mr.';
    first.clear();
    last.clear();
    nationality.text = 'Thai';
    passport.clear();
    phone.clear();
    email.clear();
    birth = DateTime(2000, 1, 1);
    expiry = DateTime.now().add(
      const Duration(days: 365 * 3),
    );
    selectedPassport = null;
  }

  void dispose() {
    first.dispose();
    last.dispose();
    nationality.dispose();
    passport.dispose();
    phone.dispose();
    email.dispose();
  }

  PassengerEntity toEntity() => PassengerEntity(
        title: title,
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        birthDate: birth,
        nationality: nationality.text.trim(),
        passportNumber: passport.text.trim(),
        passportExpiry: expiry,
        phone: phone.text.trim(),
        email: email.text.trim(),
      );
}

class _PassengerForm extends StatefulWidget {
  const _PassengerForm({
    required this.data,
    required this.lang,
    required this.savedPassengers,
  });

  final _PassengerFormData data;
  final String lang;
  final List<PassengerEntity> savedPassengers;

  @override
  State<_PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<_PassengerForm> {
  Future<DateTime?> pick(
    DateTime initial, {
    bool passportExpiry = false,
  }) {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: passportExpiry
          ? DateTime(now.year, now.month, now.day)
          : DateTime(1940),
      lastDate: passportExpiry
          ? DateTime(now.year + 15)
          : now,
    );
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty
        ? tr(widget.lang, 'required')
        : null;
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final l = widget.lang;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr(l, 'passenger')} ${d.index + 1}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),

            const SizedBox(height: 12),

            if (widget.savedPassengers.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: widget.savedPassengers.any(
                      (p) => p.passportNumber == d.selectedPassport,
                )
                    ? d.selectedPassport
                    : null,
                // isExpanded lets long names ellipsize instead of
                // overflowing the field on narrow phones.
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(l, 'use_saved_passenger'),
                  prefixIcon: const Icon(Icons.person_search_outlined),
                ),
                hint: Text(
                  tr(l, 'choose_passenger'),
                  overflow: TextOverflow.ellipsis,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: '__new__',
                    child: Text(
                      tr(l, 'new_passenger'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...widget.savedPassengers.map(
                    (passenger) => DropdownMenuItem<String>(
                      value: passenger.passportNumber,
                      child: Text(
                        '${passenger.fullName} • ${passenger.passportNumber}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  if (value == '__new__') {
                    setState(d.clear);
                    return;
                  }

                  final passenger = widget.savedPassengers.firstWhere(
                    (p) => p.passportNumber == value,
                  );

                  setState(() => d.apply(passenger));
                },
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: d.title,
              decoration: InputDecoration(
                labelText: tr(l, 'title'),
              ),
              items: const ['Mr.', 'Mrs.', 'Ms.']
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  d.title = value ?? d.title;
                });
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.first,
                    validator: requiredText,
                    decoration: InputDecoration(
                      labelText: tr(l, 'first_name'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: d.last,
                    validator: requiredText,
                    decoration: InputDecoration(
                      labelText: tr(l, 'last_name'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.nationality,
                    validator: requiredText,
                    decoration: InputDecoration(
                      labelText: tr(l, 'nationality'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: d.passport,
                    validator: requiredText,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: tr(l, 'passport_number'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(l, 'birth_date')),
              subtitle: Text(_date(d.birth)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final value = await pick(d.birth);

                if (value != null) {
                  setState(() => d.birth = value);
                }
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(l, 'passport_expiry')),
              subtitle: Text(_date(d.expiry)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final value = await pick(
                  d.expiry,
                  passportExpiry: true,
                );

                if (value != null) {
                  setState(() => d.expiry = value);
                }
              },
            ),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.phone,
                    validator: requiredText,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: tr(l, 'phone'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: d.email,
                    validator: (value) {
                      return value != null && value.contains('@')
                          ? null
                          : tr(l, 'invalid_email');
                    },
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: d.saveForNextTime,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(tr(l, 'save_passenger_next_time')),
              subtitle: Text(tr(l, 'save_passenger_next_time_sub')),
              onChanged: (value) {
                setState(() {
                  d.saveForNextTime = value ?? true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
