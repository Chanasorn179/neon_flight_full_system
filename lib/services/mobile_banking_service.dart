import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/payment_catalog.dart';

/// Opens the chosen bank's app. If it isn't installed, opens its store page.
/// Returns false when nothing could be opened.
Future<bool> openBankApp(BankOption bank) async {
  if (Platform.isAndroid) {
    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: bank.androidPackage,
        flags: [0x10000000], // FLAG_ACTIVITY_NEW_TASK
      ).launch();
      return true;
    } catch (_) {
      // Not installed (or not visible): fall through to the store page.
    }
    return launchUrl(
      Uri.parse(
        'https://play.google.com/store/apps/details?id=${bank.androidPackage}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
  return launchUrl(
    Uri.parse(
      'https://apps.apple.com/th/search?term=${Uri.encodeComponent(bank.app)}',
    ),
    mode: LaunchMode.externalApplication,
  );
}

/// The payment QR as a PNG on white, with a quiet zone, so banking apps can
/// read it from the photo gallery ("scan from image").
Future<Uint8List> qrPng(String data, {double size = 720}) async {
  const margin = 48.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final full = size + margin * 2;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, full, full),
    Paint()..color = Colors.white,
  );
  canvas.translate(margin, margin);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  ).paint(canvas, Size(size, size));
  final image = await recorder.endRecording().toImage(
    full.toInt(),
    full.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Saves the payment QR to the gallery. Returns false if access was refused.
Future<bool> saveQrToGallery(String data, String name) async {
  if (!await Gal.hasAccess(toAlbum: true)) {
    if (!await Gal.requestAccess(toAlbum: true)) return false;
  }
  await Gal.putImageBytes(await qrPng(data), album: 'NEON FLIGHT', name: name);
  return true;
}
