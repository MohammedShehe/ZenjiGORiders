import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/api/rider_api.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController name, email, phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppProvider>().user;
    name = TextEditingController(text: u?.fullName ?? '');
    email = TextEditingController(text: u?.email ?? '');
    phone = TextEditingController(text: u?.phone ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final app = context.read<AppProvider>();
    final u = app.user;
    if (u == null || _saving) return;
    setState(() => _saving = true);
    try {
      final data = await RiderApi.updateMe({
        'fullName': name.text.trim().isEmpty ? u.fullName : name.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'phone': phone.text.trim(),
      });
      final updated = data.isNotEmpty ? data : await RiderApi.me();
      app.updateUser(u.copyWith(
        fullName: (updated['fullName'] ?? name.text.trim()).toString(),
        email: (updated['email'] ?? email.text.trim()).toString(),
        phone: (updated['phone'] ?? phone.text.trim()).toString(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('Profile updated successfully.', 'Wasifu umesasishwa kwa mafanikio.'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Edit Profile', 'Hariri Wasifu'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: app.t('Full name', 'Jina kamili'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: app.t('Phone number', 'Namba ya simu'),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: app.t('Email', 'Barua pepe'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 26),
          ElevatedButton.icon(
            onPressed: _saving ? null : save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_saving ? app.t('Saving…', 'Inahifadhi…') : app.t('Save Changes', 'Hifadhi Mabadiliko')),
          ),
        ],
      ),
    );
  }
}
