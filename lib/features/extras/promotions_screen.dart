import 'package:flutter/material.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AppProvider>().promos();
      if (!mounted) return;
      setState(() {
        _offers = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _value(Map<String, dynamic> offer, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = offer[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  Future<void> _apply(Map<String, dynamic> offer) async {
    final code = _value(offer, ['code', 'promoCode', 'id']);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This offer has no code from the server.')));
      return;
    }
    try {
      await context.read<AppProvider>().applyPromo(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo validated by the server.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions & Offers'), actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _offers.isEmpty
                      ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No promotions are currently available.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _offers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final offer = _offers[index];
                            return Card(child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
                              title: Text(_value(offer, ['code', 'promoCode', 'name', 'title'], 'Promotion'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(_value(offer, ['description', 'details', 'discountDescription'])),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _apply(offer),
                            ));
                          },
                        ),
                ),
    );
  }
}
