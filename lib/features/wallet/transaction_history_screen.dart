import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tx = app.transactions;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Transaction History', 'Historia ya Miamala'))),
      body: tx.isEmpty
          ? Center(child: Text(app.t('No transactions yet.', 'Hakuna miamala bado.')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tx.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final t = tx[i];
                final credit = t.amount >= 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: credit
                        ? AppColors.brightGreen.withOpacity(0.15)
                        : AppColors.error.withOpacity(0.12),
                    child: Icon(
                      t.type == 'topup'
                          ? Icons.add
                          : t.type == 'tip'
                              ? Icons.volunteer_activism
                              : Icons.directions_car,
                      color: credit ? AppColors.brightGreen : AppColors.error,
                    ),
                  ),
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.createdAt.toLocal().toString().split('.').first}${t.paymentMethod != null ? ' · ${t.paymentMethod}' : ''}',
                  ),
                  trailing: Text(
                    '${credit ? '+' : ''}TZS ${t.amount.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: credit ? AppColors.brightGreen : AppColors.error,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
