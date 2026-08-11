import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/firebase_service.dart';
import '../../services/ticket_qr_service.dart';

class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  bool handled = false;
  bool checking = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (handled || checking) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() {
      handled = true;
      checking = true;
    });

    final localResult = TicketQrService.verify(raw);

    if (!localResult.valid || localResult.data == null) {
      if (!mounted) return;

      setState(() => checking = false);

      await _showResult(
        valid: false,
        title: 'ตั๋วไม่ถูกต้อง',
        message: localResult.message,
      );
      return;
    }

    if (!FirebaseService.enabled) {
      if (!mounted) return;

      setState(() => checking = false);

      await _showResult(
        valid: false,
        title: 'ตรวจสอบออนไลน์ไม่ได้',
        message: 'Firebase ยังไม่พร้อมใช้งาน',
      );
      return;
    }

    final bookingId = localResult.data!['bookingId']?.toString() ?? '';

    try {
      final booking = await FirebaseService.bookingById(bookingId);

      if (!mounted) return;

      if (booking == null) {
        setState(() => checking = false);

        await _showResult(
          valid: false,
          title: 'ไม่พบตั๋วในระบบ',
          message: 'Booking ID $bookingId ไม่มีอยู่ใน Firestore',
        );
        return;
      }

      final status = booking['status']?.toString().toLowerCase() ?? '';

      if (status == 'cancelled') {
        setState(() => checking = false);

        await _showResult(
          valid: false,
          title: 'ตั๋วถูกยกเลิก',
          message: 'Booking ID $bookingId ถูกยกเลิกแล้ว',
          booking: booking,
        );
        return;
      }

      setState(() => checking = false);

      await _showResult(
        valid: true,
        title: 'ตั๋วถูกต้อง',
        message: 'ตรวจสอบ QR และข้อมูลใน Firestore สำเร็จ',
        booking: booking,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => checking = false);

      await _showResult(
        valid: false,
        title: 'ตรวจสอบตั๋วไม่สำเร็จ',
        message: error.toString(),
      );
    }
  }

  Future<void> _showResult({
    required bool valid,
    required String title,
    required String message,
    Map<String, dynamic>? booking,
  }) async {
    final flight = booking?['flight'];
    final flightMap = flight is Map
        ? Map<String, dynamic>.from(flight)
        : const <String, dynamic>{};

    final departure = flightMap['departure'];
    final arrival = flightMap['arrival'];

    final departureMap = departure is Map
        ? Map<String, dynamic>.from(departure)
        : const <String, dynamic>{};

    final arrivalMap = arrival is Map
        ? Map<String, dynamic>.from(arrival)
        : const <String, dynamic>{};

    final passengersRaw = booking?['passengers'];
    final passengers = passengersRaw is List ? passengersRaw : const [];

    String passengerName = '-';

    if (passengers.isNotEmpty && passengers.first is Map) {
      final p = Map<String, dynamic>.from(passengers.first as Map);
      passengerName = [
        p['title'],
        p['firstName'],
        p['lastName'],
      ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    }

    final seatsRaw = booking?['seats'];
    final seats = seatsRaw is List
        ? seatsRaw.map((e) => e.toString()).join(', ')
        : '-';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          valid
              ? Icons.verified_rounded
              : Icons.error_outline_rounded,
          color: valid ? Colors.green : Colors.red,
          size: 46,
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),

              if (booking != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                _line(
                  'Booking ID',
                  booking['id']?.toString() ?? '-',
                ),
                _line(
                  'เที่ยวบิน',
                  flightMap['flightNumber']?.toString() ?? '-',
                ),
                _line(
                  'เส้นทาง',
                  '${departureMap['code'] ?? '-'} → ${arrivalMap['code'] ?? '-'}',
                ),
                _line(
                  'ผู้โดยสาร',
                  passengerName,
                ),
                _line(
                  'ที่นั่ง',
                  seats,
                ),
                _line(
                  'ชั้นโดยสาร',
                  booking['cabinClass']?.toString() ?? '-',
                ),
                _line(
                  'สถานะ',
                  booking['status']?.toString() ?? '-',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('สแกนอีกครั้ง'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        handled = false;
        checking = false;
      });
    }
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('สแกน E-Ticket'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              onDetect: _onDetect,
            ),

            IgnorePointer(
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: checking
                          ? Colors.amber
                          : Colors.white,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),

            if (checking)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('กำลังตรวจสอบกับ Firestore...'),
                      ],
                    ),
                  ),
                ),
              ),

            const Positioned(
              left: 24,
              right: 24,
              bottom: 36,
              child: Text(
                'เล็งกล้องไปที่ QR บนตั๋ว NEON FLIGHT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
