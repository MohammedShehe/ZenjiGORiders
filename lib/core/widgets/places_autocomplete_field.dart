import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places;

/// Shared Tanzania-scoped Places autocomplete field.
/// Shows friendly names (primary + secondary), never raw Plus Codes in the field.
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool enabled;
  final ValueChanged<PlaceSelection>? onSelected;
  final VoidCallback? onUseCurrentLocation;
  final String? apiKey;

  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon = Icons.location_on_outlined,
    this.enabled = true,
    this.onSelected,
    this.onUseCurrentLocation,
    this.apiKey,
  });

  static const String defaultKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBX93zeEULXrhxlvkNefmoFcYDGizvvSpU',
  );

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class PlaceSelection {
  final String placeId;
  final String displayName;
  final String? secondary;
  final double lat;
  final double lng;
  final String? fullAddress;

  const PlaceSelection({
    required this.placeId,
    required this.displayName,
    required this.lat,
    required this.lng,
    this.secondary,
    this.fullAddress,
  });
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  late final places.FlutterGooglePlacesSdk _client;
  final _focus = FocusNode();
  List<Map<String, String>> _suggestions = [];
  bool _loading = false;
  int _req = 0;
  Timer? _debounce;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    final key = (widget.apiKey != null && widget.apiKey!.isNotEmpty)
        ? widget.apiKey!
        : PlacesAutocompleteField.defaultKey;
    _client = places.FlutterGooglePlacesSdk(key, useNewApi: true);
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    if (_suppressSearch) return;
    _debounce?.cancel();
    final q = widget.controller.text.trim();
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_req;
    setState(() => _loading = true);
    try {
      final response = await _client.findAutocompletePredictions(
        q,
        countries: const ['tz'],
      );
      if (!mounted || id != _req) return;
      final list = <Map<String, String>>[];
      for (final p in response.predictions) {
        if (p.placeId.isEmpty) continue;
        final main = (p.primaryText.isNotEmpty ? p.primaryText : p.fullText).trim();
        final secondary = p.secondaryText.trim();
        list.add({
          'place_id': p.placeId,
          'main': main,
          'secondary': secondary,
          'full': p.fullText,
        });
      }
      setState(() => _suggestions = list);
    } catch (e) {
      if (mounted && id == _req) {
        setState(() => _suggestions = []);
        final raw = e.toString();
        final msg = (raw.contains('403') || raw.contains('permission'))
            ? 'Places API unavailable. Enable Places API (New) for this key.'
            : 'Location search failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted && id == _req) setState(() => _loading = false);
    }
  }

  /// Prefer human-readable name; skip Plus Codes like R73F+P2J.
  static String friendlyName(String? primary, String? secondary, String? fallback) {
    String clean(String? s) {
      if (s == null) return '';
      final t = s.trim();
      // Plus Code pattern: 4+ chars, +, 2+ chars
      if (RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}').hasMatch(t.split(',').first.trim())) {
        return '';
      }
      return t;
    }

    final p = clean(primary);
    final sec = clean(secondary);
    if (p.isNotEmpty && sec.isNotEmpty) {
      // "Fuoni Kibondeni, Zanzibar" style — take main + first part of secondary
      final secShort = sec.split(',').first.trim();
      if (secShort.isNotEmpty && !p.contains(secShort)) return '$p, $secShort';
      return p;
    }
    if (p.isNotEmpty) return p;
    if (sec.isNotEmpty) return sec.split(',').take(2).join(', ');
    final f = clean(fallback);
    if (f.isNotEmpty) return f.split(',').take(2).join(', ');
    return fallback?.trim() ?? '';
  }

  Future<void> _pick(Map<String, String> item) async {
    setState(() {
      _loading = true;
      _suggestions = [];
    });
    try {
      final response = await _client.fetchPlace(
        item['place_id']!,
        fields: const [
          places.PlaceField.Id,
          places.PlaceField.Address,
          places.PlaceField.Location,
          places.PlaceField.Name,
        ],
      );
      final place = response.place;
      final loc = place?.latLng;
      if (place == null || loc == null) {
        throw Exception('Could not resolve this place.');
      }
      final display = friendlyName(
        item['main'] ?? place.name,
        item['secondary'],
        place.name ?? place.address ?? item['full'],
      );
      _suppressSearch = true;
      widget.controller.text = display;
      _suppressSearch = false;
      widget.onSelected?.call(PlaceSelection(
        placeId: item['place_id']!,
        displayName: display,
        secondary: item['secondary'],
        lat: loc.lat,
        lng: loc.lng,
        fullAddress: place.address,
      ));
      _focus.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (widget.onUseCurrentLocation != null
                    ? IconButton(
                        tooltip: 'Use current location',
                        icon: const Icon(Icons.my_location),
                        onPressed: widget.onUseCurrentLocation,
                      )
                    : null),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height < 700 ? 160 : 220,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(
                    s['main'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: (s['secondary'] ?? '').isEmpty
                      ? null
                      : Text(s['secondary'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  onTap: () => _pick(s),
                );
              },
            ),
          ),
      ],
    );
  }
}
