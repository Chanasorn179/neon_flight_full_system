import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import 'seat_selection_screen.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key, required this.flight, required this.cabinClass});
  final FlightEntity flight;
  final CabinClass cabinClass;

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final _form = GlobalKey<FormState>();
  late List<_PassengerFormData> forms;

  @override
  void initState() {
    super.initState();
    final count = context.read<FlightProvider>().passengerCount;
    forms = List.generate(count, (i) => _PassengerFormData(index: i));
  }

  @override
  void dispose() {
    for (final f in forms) {
      f.dispose();
    }
    super.dispose();
  }

  void next() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final passengers = forms.map((f) => f.toEntity()).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeatSelectionScreen(
          flight: widget.flight,
          cabinClass: widget.cabinClass,
          passengers: passengers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'passenger_info'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final f in forms) _PassengerForm(data: f, lang: lang),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: next,
              icon: const Icon(Icons.airline_seat_recline_normal),
              label: Padding(padding: const EdgeInsets.all(14), child: Text(tr(lang, 'select_seat'))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerFormData {
  _PassengerFormData({required this.index});
  final int index;
  String title = 'Mr.';
  final first = TextEditingController();
  final last = TextEditingController();
  final nationality = TextEditingController(text: 'Thai');
  final passport = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  DateTime birth = DateTime(2000, 1, 1);
  DateTime expiry = DateTime.now().add(const Duration(days: 365 * 3));

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
  const _PassengerForm({required this.data, required this.lang});
  final _PassengerFormData data;
  final String lang;

  @override
  State<_PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<_PassengerForm> {
  Future<DateTime?> pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1940),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  String? requiredText(String? v) => (v == null || v.trim().isEmpty) ? tr(widget.lang, 'required') : null;

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
            Text('${tr(l, 'passenger')} ${d.index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: d.title,
              decoration: InputDecoration(labelText: tr(l, 'title')),
              items: const ['Mr.', 'Mrs.', 'Ms.'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => d.title = v ?? d.title,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: d.first, validator: requiredText, decoration: InputDecoration(labelText: tr(l, 'first_name')))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: d.last, validator: requiredText, decoration: InputDecoration(labelText: tr(l, 'last_name')))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: d.nationality, validator: requiredText, decoration: InputDecoration(labelText: tr(l, 'nationality')))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: d.passport, validator: requiredText, decoration: InputDecoration(labelText: tr(l, 'passport_number')))),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(l, 'birth_date')),
              subtitle: Text('${d.birth.day}/${d.birth.month}/${d.birth.year}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final v = await pick(d.birth);
                if (v != null) setState(() => d.birth = v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(l, 'passport_expiry')),
              subtitle: Text('${d.expiry.day}/${d.expiry.month}/${d.expiry.year}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final v = await pick(d.expiry);
                if (v != null) setState(() => d.expiry = v);
              },
            ),
            Row(
              children: [
                Expanded(child: TextFormField(controller: d.phone, validator: requiredText, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr(l, 'phone')))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: d.email,
                    validator: (v) => v != null && v.contains('@') ? null : tr(l, 'invalid_email'),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
