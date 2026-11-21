import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/rider_api.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';

/// "Book for a friend": collects who will be riding. Returns the passenger, or null if dismissed.
/// Passing [current] pre-fills the form; the sheet pops with [_ClearPassenger] semantics via `clear`.
class BookForFriendSheet extends StatefulWidget {
  final PassengerInfo? current;
  final bool isDark;
  final String Function(String en, String sw) t;
  const BookForFriendSheet({super.key, this.current, required this.isDark, required this.t});

  /// Returns: a [PassengerInfo] when saved, `false` when the rider chose to ride themselves, null if dismissed.
  static Future<Object?> show(BuildContext context, {PassengerInfo? current, required bool isDark, required String Function(String, String) t}) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookForFriendSheet(current: current, isDark: isDark, t: t),
    );
  }

  @override
  State<BookForFriendSheet> createState() => _BookForFriendSheetState();
}

class _BookForFriendSheetState extends State<BookForFriendSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _saved = [];

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    if (c != null) {
      _name.text = c.name;
      _phone.text = c.phone;
      _note.text = c.note ?? '';
    }
    RiderApi.savedPassengers().then((l) {
      if (mounted) setState(() => _saved = l.take(6).toList());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final note = _note.text.trim();
    Navigator.pop(
      context,
      PassengerInfo(name: _name.text.trim(), phone: _phone.text.trim(), note: note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final dark = widget.isDark;
    final bg = dark ? const Color(0xFF0E3446) : Colors.white;
    final fg = dark ? AppColors.offWhite : AppColors.deepNavy;
    final muted = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    const accent = AppColors.brightGreen;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    InputDecoration deco(String label, IconData icon, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.group_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Book for a friend', 'Omba safari kwa rafiki'), style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text(t('They ride. You book, pay and can cancel.', 'Yeye anasafiri. Wewe unaomba, unalipa na unaweza kughairi.'),
                        style: TextStyle(color: muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              if (_saved.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t('Recent', 'Wa hivi karibuni'), style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _saved
                      .map((p) => ActionChip(
                            avatar: Icon(Icons.person_rounded, size: 16, color: accent),
                            label: Text((p['name'] ?? '').toString()),
                            onPressed: () => setState(() {
                              _name.text = (p['name'] ?? '').toString();
                              _phone.text = (p['phone'] ?? '').toString();
                            }),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                style: TextStyle(color: fg),
                decoration: deco(t('Their name', 'Jina lake'), Icons.person_outline_rounded).copyWith(counterText: ''),
                validator: (v) => (v ?? '').trim().length < 2 ? t('Enter their name', 'Weka jina lake') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(20)],
                style: TextStyle(color: fg),
                decoration: deco(t('Their phone number', 'Namba yake ya simu'), Icons.phone_outlined, hint: '0712 345 678'),
                validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 9
                    ? t('Enter a valid phone number so the driver can reach them', 'Weka namba sahihi ili dereva amfikie')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 160,
                style: TextStyle(color: fg),
                decoration: deco(t('Note for the driver (optional)', 'Ujumbe kwa dereva (si lazima)'), Icons.edit_note_rounded, hint: t('Blue gate, red shirt…', 'Geti la buluu, shati jekundu…'))
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.sms_outlined, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('We text them the driver details and trip PIN, and the driver calls them, not you. Set the pickup to where they are.',
                          'Tunamtumia dereva na PIN ya safari kwa SMS, na dereva atampigia yeye, si wewe. Weka eneo alipo.'),
                      style: TextStyle(color: fg, fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(t('Save', 'Hifadhi'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              if (widget.current != null)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t('Ride myself instead', 'Nitasafiri mwenyewe')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
