import 'package:cloud_firestore/cloud_firestore.dart';

/// A bookable one-on-one slot (e.g. personal training), admin-managed.
/// [activeRequestId] points at the adminRequests doc currently holding
/// this slot (pending or approved) — null means the slot is free. Slots
/// are single-occupancy: only one active request may hold a slot at a
/// time, enforced transactionally in AppointmentService.requestBooking.
class AppointmentSlotModel {
  final String? id;
  final String day;
  final String appointmentName;
  final String coach;
  final String time;
  final bool isActive;
  final String? activeRequestId;

  AppointmentSlotModel({
    this.id,
    required this.day,
    required this.appointmentName,
    required this.coach,
    required this.time,
    this.isActive = true,
    this.activeRequestId,
  });

  bool get isFree => activeRequestId == null;

  factory AppointmentSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentSlotModel(
      id: doc.id,
      day: data['day'] ?? '',
      appointmentName: data['appointmentName'] ?? '',
      coach: data['coach'] ?? '',
      time: data['time'] ?? '',
      isActive: data['isActive'] ?? true,
      activeRequestId: data['activeRequestId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'day': day,
        'appointmentName': appointmentName,
        'coach': coach,
        'time': time,
        'isActive': isActive,
        // activeRequestId is managed via targeted transactional updates in
        // AppointmentService — never overwritten by the admin edit form.
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
