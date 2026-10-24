import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/app_provider.dart';
import '../../core/api/rider_api.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController name, email, phone, otp;
  bool _saving = false;
  bool _otpSent = false;
  bool _emailVerified = true;
  String? _photoUrl;
  File? _localPhoto;
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppProvider>().user;
    name = TextEditingController(text: u?.fullName ?? '');
    email = TextEditingController(text: u?.email ?? '');
    phone = TextEditingController(text: u?.phone ?? '');
    otp = TextEditingController();
    _photoUrl = u?.photoUrl;
    _originalEmail = (u?.email ?? '').trim().toLowerCase();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (file == null) return;
    setState(() => _localPhoto = File(file.path));
  }

  Future<void> _previewPhoto() async {
    final url = _localPhoto?.path ?? _photoUrl;
    if (url == null || url.isEmpty) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_localPhoto != null)
              Image.file(_localPhoto!, fit: BoxFit.cover)
            else
              Image.network(_photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 200, child: Icon(Icons.person, size: 80))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto() async {
    setState(() {
      _localPhoto = null;
      _photoUrl = null;
    });
  }

  Future<String?> _uploadPhoto() async {
    if (_localPhoto == null) return _photoUrl;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final uri = Uri.parse('${ApiClient.baseUrl}/upload');
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', _localPhoto!.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Photo upload failed');
    }
    final decoded = jsonDecode(body);
    final data = decoded is Map ? (decoded['data'] ?? decoded) : {};
    return (data['url'] ?? data['secure_url'] ?? data['path'] ?? '').toString();
  }

  Future<void> _sendEmailOtp() async {
    final mail = email.text.trim().toLowerCase();
    if (mail.isEmpty || !mail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }
    try {
      await RiderApi.sendEmailChangeOtp(mail);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _emailVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    try {
      final data = await RiderApi.verifyEmailChangeOtp(email.text.trim(), otp.text.trim());
      if (!mounted) return;
      setState(() {
        _emailVerified = true;
        _otpSent = false;
        _originalEmail = email.text.trim().toLowerCase();
      });
      if (data.isNotEmpty) {
        try {
          final user = UserModel.fromJson(Map<String, dynamic>.from(data));
          await context.read<AppProvider>().login(user);
        } catch (_) {}
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> save() async {
    final app = context.read<AppProvider>();
    final u = app.user;
    if (u == null || _saving) return;

    final newEmail = email.text.trim().toLowerCase();
    final emailChanged = newEmail.isNotEmpty && newEmail != (_originalEmail ?? '');
    if (emailChanged && !_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify the new email with OTP before saving.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? photo = _photoUrl;
      if (_localPhoto != null) {
        photo = await _uploadPhoto();
      }
      final body = <String, dynamic>{
        'fullName': name.text.trim().isEmpty ? u.fullName : name.text.trim(),
        if (photo != null) 'photoUrl': photo,
        if (photo == null && _photoUrl == null) 'photoUrl': null,
      };
      // Email already applied via verify endpoint when changed
      if (!emailChanged && newEmail.isNotEmpty) {
        body['email'] = newEmail;
      }
      final data = await RiderApi.updateMe(body);
      final user = UserModel.fromJson(Map<String, dynamic>.from(data is Map && data['id'] != null ? data : (data['user'] ?? data)));
      await app.login(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    final accent = dark ? AppColors.aquaGreen : AppColors.oceanTeal;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _previewPhoto,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: accent.withOpacity(0.15),
                    backgroundImage: _localPhoto != null
                        ? FileImage(_localPhoto!)
                        : (_photoUrl != null && _photoUrl!.isNotEmpty ? NetworkImage(_photoUrl!) as ImageProvider : null),
                    child: (_localPhoto == null && (_photoUrl == null || _photoUrl!.isEmpty))
                        ? Icon(Icons.person, size: 52, color: accent)
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'camera') _pickPhoto(source: ImageSource.camera);
                      if (v == 'gallery') _pickPhoto(source: ImageSource.gallery);
                      if (v == 'remove') _removePhoto();
                      if (v == 'preview') _previewPhoto();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'preview', child: Text('Preview')),
                      PopupMenuItem(value: 'camera', child: Text('Take photo')),
                      PopupMenuItem(value: 'gallery', child: Text('Choose from gallery')),
                      PopupMenuItem(value: 'remove', child: Text('Remove photo')),
                    ],
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: accent,
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap photo to preview · use edit to change', style: TextStyle(fontSize: 12))),
          const SizedBox(height: 24),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), helperText: 'Phone cannot be changed here'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) {
              final changed = v.trim().toLowerCase() != (_originalEmail ?? '');
              setState(() {
                _emailVerified = !changed;
                if (changed) _otpSent = false;
              });
            },
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              suffixIcon: Icon(
                _emailVerified ? Icons.verified : Icons.mark_email_unread_outlined,
                color: _emailVerified ? Colors.green : Colors.orange,
              ),
            ),
          ),
          if (!_emailVerified) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sendEmailOtp,
                    child: Text(_otpSent ? 'Resend OTP' : 'Send OTP'),
                  ),
                ),
              ],
            ),
            if (_otpSent) ...[
              const SizedBox(height: 10),
              TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Email OTP', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _verifyEmailOtp, child: const Text('Verify email')),
            ],
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}
