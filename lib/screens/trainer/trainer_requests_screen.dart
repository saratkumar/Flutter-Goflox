import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class TrainerRequestsScreen extends StatelessWidget {
  const TrainerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('adminRequests')
            .where('requestedBy', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 14),
                  Text('No requests yet',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  SizedBox(height: 6),
                  Text(
                    'Slot increase and credit requests\nwill appear here.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final type = data['type'] ?? '';
              final status = data['status'] ?? 'pending';
              final statusColor = status == 'approved'
                  ? const Color(0xFF00D4AA)
                  : status == 'rejected'
                      ? AppColors.error
                      : const Color(0xFFFFAB40);

              final createdAt = data['createdAt'];
              String dateStr = '';
              if (createdAt is Timestamp) {
                final d = createdAt.toDate();
                const months = ['Jan','Feb','Mar','Apr','May','Jun',
                                 'Jul','Aug','Sep','Oct','Nov','Dec'];
                dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    // Type icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        type == 'credit_request'
                            ? Icons.toll_outlined
                            : Icons.add_box_outlined,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'credit_request'
                                ? 'Credit Request — ${data['targetUserName'] ?? ''}'
                                : 'Slot Increase — ${data['className'] ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '+${data['amount']} '
                            '${type == 'credit_request' ? 'credits' : 'slots'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ],
                          if ((data['note'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(data['note'],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
