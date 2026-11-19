import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

/// Asks for when-in-use location and returns a fix.
///
/// The system permission sheet is shown when iOS or Android will still ask.
/// If location is switched off, or the app was denied for good, a Turn On
/// dialog opens the relevant Settings page.
Future<Position?> requestPickupPosition(BuildContext context) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (!context.mounted) return null;

  final servicesOn = await Geolocator.isLocationServiceEnabled();
  final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  if (granted && servicesOn) {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
  if (!context.mounted) return null;
  if (permission == LocationPermission.denied && servicesOn) return null;

  final app = context.read<AppProvider>();
  final openSettings = servicesOn ? Geolocator.openAppSettings : Geolocator.openLocationSettings;
  final turnOn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(app.t('Turn on location', 'Washa eneo')),
      content: Text(app.t(
        'ZenjiGO needs your location to set your pickup.',
        'ZenjiGO inahitaji eneo lako ili kuweka mahali unapoanza safari.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(app.t('Not now', 'Sio sasa')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(app.t('Turn on', 'Washa')),
        ),
      ],
    ),
  );
  if (turnOn == true) await openSettings();
  return null;
}
