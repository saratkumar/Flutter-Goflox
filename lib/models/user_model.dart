import 'package:cloud_firestore/cloud_firestore.dart';

/// An admin-granted credit award — tracked on its own field, deliberately
/// kept separate from [MembershipEntry]/memberships. It isn't a real
/// purchased plan, so it shouldn't be forced through the same
/// plan-name-matching machinery: whether it unlocks unrestricted class
/// access is an explicit flag here ([unlocksAnyClass]), not an implicit
/// behavior baked into a magic plan name. If that policy ever needs to
/// change (e.g. admin credits should stop bypassing the Personal Training
/// gate), it's a one-place change here rather than a rewrite of how
/// memberships/plans are matched.
class AdminCreditGrant {
  final int credits;
  final DateTime expiryDate;
  final DateTime grantedAt;
  final bool unlocksAnyClass;

  const AdminCreditGrant({
    required this.credits,
    required this.expiryDate,
    required this.grantedAt,
    this.unlocksAnyClass = true,
  });

  bool get isActive => expiryDate.isAfter(DateTime.now());

  factory AdminCreditGrant.fromMap(Map<String, dynamic> map) {
    return AdminCreditGrant(
      credits: map['credits'] ?? 0,
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      grantedAt: (map['grantedAt'] as Timestamp).toDate(),
      unlocksAnyClass: map['unlocksAnyClass'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'credits': credits,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'grantedAt': Timestamp.fromDate(grantedAt),
        'unlocksAnyClass': unlocksAnyClass,
      };
}

class MembershipEntry {
  final String planName;
  final int credits;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime purchasedAt;

  MembershipEntry({
    required this.planName,
    required this.credits,
    required this.startDate,
    required this.endDate,
    required this.purchasedAt,
  });

  factory MembershipEntry.fromMap(Map<String, dynamic> map) {
    return MembershipEntry(
      planName: map['planName'] ?? '',
      credits: map['credits'] ?? 0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      purchasedAt: (map['purchasedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'planName': planName,
        'credits': credits,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'purchasedAt': Timestamp.fromDate(purchasedAt),
      };

  bool get isActive => endDate.isAfter(DateTime.now());
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? phone;
  final String role; // 'client', 'trainer', 'admin'
  final String? adminLevel; // 'super_admin', 'admin' — only for admin role
  final List<String> adminPermissions;
  final int credits;
  final List<MembershipEntry> memberships;
  final AdminCreditGrant? adminCreditGrant;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.phone,
    this.role = 'client',
    this.adminLevel,
    this.adminPermissions = const [],
    this.credits = 0,
    this.memberships = const [],
    this.adminCreditGrant,
  });

  bool get isClient => role == 'client';
  bool get isTrainer => role == 'trainer';
  bool get isAdmin => role == 'admin';
  bool get isSuperAdmin => role == 'admin' && adminLevel == 'super_admin';

  bool hasPermission(String permission) {
    if (isSuperAdmin) return true;
    return adminPermissions.contains(permission);
  }

  // The active membership is the one with the latest end date that hasn't expired.
  MembershipEntry? get activeMembership {
    final active = memberships.where((m) => m.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.endDate.compareTo(a.endDate));
    return active.first;
  }

  /// The active admin-granted credit award, if any.
  AdminCreditGrant? get activeAdminGrant =>
      (adminCreditGrant != null && adminCreditGrant!.isActive)
          ? adminCreditGrant
          : null;

  /// True while an unexpired admin-granted credit award that's flagged to
  /// unlock unrestricted access exists — bypasses the Personal Training
  /// gate regardless of the user's actual plan(s).
  bool get hasUnrestrictedAccess =>
      activeAdminGrant?.unlocksAnyClass ?? false;

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    final rawMemberships = data['memberships'] as List<dynamic>? ?? [];
    final rawGrant = data['adminCreditGrant'] as Map<String, dynamic>?;
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      phone: data['phone'],
      role: data['role'] ?? 'client',
      adminLevel: data['adminLevel'],
      adminPermissions: List<String>.from(data['adminPermissions'] ?? []),
      credits: data['credits'] ?? 0,
      memberships: rawMemberships
          .map((e) => MembershipEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      adminCreditGrant:
          rawGrant != null ? AdminCreditGrant.fromMap(rawGrant) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'role': role,
        if (adminLevel != null) 'adminLevel': adminLevel,
        'adminPermissions': adminPermissions,
        'credits': credits,
        'memberships': memberships.map((m) => m.toMap()).toList(),
        if (adminCreditGrant != null)
          'adminCreditGrant': adminCreditGrant!.toMap(),
      };
}
