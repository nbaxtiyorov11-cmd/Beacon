import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import 'trip_service.dart';

class FamilyContact {
  const FamilyContact({
    required this.id,
    required this.name,
    required this.email,
    this.relation = 'Member',
    this.isOrganizer = false,
    this.locationShareEnabled = true,
    this.lastSeen,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.emergencyActive = false,
    this.emergencyLatitude,
    this.emergencyLongitude,
    this.emergencyStartedAt,
    this.emergencyUpdatedAt,
    this.emergencyExpiresAt,
  });

  final String id;
  final String name;
  final String email;
  final String relation;
  final bool isOrganizer;
  final bool locationShareEnabled;
  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final bool emergencyActive;
  final double? emergencyLatitude;
  final double? emergencyLongitude;
  final DateTime? emergencyStartedAt;
  final DateTime? emergencyUpdatedAt;
  final DateTime? emergencyExpiresAt;

  factory FamilyContact.fromMap(String id, Map<String, dynamic> map) {
    return FamilyContact(
      id: id,
      name: (map['name'] as String?) ?? 'Family member',
      email: (map['email'] as String?) ?? '',
      relation: (map['relation'] as String?) ?? 'Member',
      isOrganizer: map['isOrganizer'] as bool? ?? false,
      locationShareEnabled: map['locationShareEnabled'] as bool? ?? true,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'relation': relation,
        'isOrganizer': isOrganizer,
        'locationShareEnabled': locationShareEnabled,
        'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      };
}

class PublicUserProfile {
  const PublicUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
}

class PublicActivityStats {
  const PublicActivityStats({
    this.tripCount = 0,
    this.distanceMeters = 0,
    this.movingMinutes = 0,
  });

  final int tripCount;
  final double distanceMeters;
  final int movingMinutes;

  factory PublicActivityStats.fromMap(Map<String, dynamic>? data) {
    return PublicActivityStats(
      tripCount: (data?['tripCount'] as num?)?.toInt() ?? 0,
      distanceMeters: (data?['distanceMeters'] as num?)?.toDouble() ?? 0,
      movingMinutes: (data?['movingMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participantUids,
    required this.participantProfiles,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.lastMessageAt,
    required this.lastReadAt,
  });

  final String id;
  final List<String> participantUids;
  final Map<String, Map<String, dynamic>> participantProfiles;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime? lastMessageAt;
  final Map<String, DateTime?> lastReadAt;

  Map<String, dynamic> otherProfile(String currentUid) =>
      participantProfiles.entries
          .firstWhere((entry) => entry.key != currentUid)
          .value;

  bool hasUnreadFor(String uid) {
    if (lastSenderUid.isEmpty ||
        lastSenderUid == uid ||
        lastMessageAt == null) {
      return false;
    }
    final readAt = lastReadAt[uid];
    return readAt == null || readAt.isBefore(lastMessageAt!);
  }

  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    final rawProfiles = data['participantProfiles'] as Map? ?? const {};
    final rawReadAt = data['lastReadAt'] as Map? ?? const {};
    return ChatConversation(
      id: id,
      participantUids: (data['participantUids'] as List? ?? const [])
          .map((uid) => uid.toString())
          .toList(),
      participantProfiles: rawProfiles.map(
        (key, value) => MapEntry(
          key.toString(),
          Map<String, dynamic>.from(value as Map),
        ),
      ),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderUid: data['lastSenderUid'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastReadAt: rawReadAt.map((key, value) => MapEntry(
            key.toString(),
            (value as Timestamp?)?.toDate(),
          )),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
    required this.reactions,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderUid,
  });

  final String id;
  final String senderUid;
  final String text;
  final DateTime? createdAt;
  final Map<String, String> reactions;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderUid;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final rawReactions = data['reactions'] as Map? ?? const {};
    return ChatMessage(
      id: id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderUid: data['replyToSenderUid'] as String?,
      reactions: rawReactions.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}

enum FamilyInviteResult {
  sent,
  accountNotFound,
  selfInvite,
  alreadyPending,
  alreadyConnected
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromEmail,
    required this.toUid,
    required this.toName,
    required this.toEmail,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String fromEmail;
  final String toUid;
  final String toName;
  final String toEmail;

  factory FamilyInvitation.fromMap(String id, Map<String, dynamic> map) {
    return FamilyInvitation(
      id: id,
      fromUid: map['fromUid'] as String? ?? '',
      fromName: map['fromName'] as String? ?? 'Beacon user',
      fromEmail: map['fromEmail'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      toName: map['toName'] as String? ?? 'Beacon user',
      toEmail: map['toEmail'] as String? ?? '',
    );
  }
}

class UserSettings {
  const UserSettings({
    this.trackingEnabled = false,
    this.approximateLocation = false,
    this.familySharing = false,
    this.notifications = true,
  });

  final bool trackingEnabled;
  final bool approximateLocation;
  final bool familySharing;
  final bool notifications;

  factory UserSettings.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return UserSettings(
      trackingEnabled: map['trackingEnabled'] as bool? ?? false,
      approximateLocation: map['approximateLocation'] as bool? ?? false,
      familySharing: map['familySharing'] as bool? ?? false,
      notifications: map['notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'trackingEnabled': trackingEnabled,
        'approximateLocation': approximateLocation,
        'familySharing': familySharing,
        'notifications': notifications,
      };
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? _firestore;
  final ValueNotifier<String> status = ValueNotifier('Firestore idle');

  @visibleForTesting
  static Map<String, dynamic> userProfileUpdateData(AuthUser user) => {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoUrl ?? '',
        'emailVerified': user.emailVerified,
        'provider': user.provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  FirebaseFirestore? _ensureReady() {
    if (_firestore != null) {
      return _firestore;
    }

    try {
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } on FirebaseException catch (error) {
      debugPrint('Firestore initialize error: $error');
      return null;
    } on PlatformException catch (error) {
      debugPrint('Firestore platform error: $error');
      return null;
    }
  }

  Future<T> _retryUnavailable<T>(Future<T> Function() action) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (error) {
        final retryable =
            error.code == 'unavailable' || error.code == 'deadline-exceeded';
        if (!retryable || attempt >= 2) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 400 * (1 << attempt)),
        );
      }
    }
  }

  Future<void> saveUserProfile(AuthUser user,
      {UserSettings settings = const UserSettings()}) async {
    try {
      status.value = 'Saving profile...';
      final firestore = _ensureReady();
      if (firestore == null) {
        status.value = 'Profile not saved: Firestore not initialized';
        debugPrint('Firestore not initialized; skipping user profile save.');
        return;
      }

      final doc = firestore.collection('users').doc(user.uid);
      final snapshot = await doc.get();
      final payload = userProfileUpdateData(user);

      if (!snapshot.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['settings'] = settings.toMap();
      }

      await doc.set(payload, SetOptions(merge: true));

      final normalizedEmail = user.email.trim().toLowerCase();
      if (normalizedEmail.isNotEmpty) {
        await firestore.collection('publicProfiles').doc(normalizedEmail).set({
          'uid': user.uid,
          'email': normalizedEmail,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoUrl ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      status.value = 'Profile saved to Firestore';
      debugPrint('Saved user profile for ${user.uid}');
    } on FirebaseException catch (error) {
      status.value = 'Profile save failed: $error';
      debugPrint('Failed to save user profile: $error');
    } on PlatformException catch (error) {
      status.value = 'Profile save failed: $error';
      debugPrint('Failed to save user profile (platform): $error');
    }
  }

  Future<UserSettings> fetchUserSettings(String uid) async {
    try {
      final firestore = _ensureReady();
      if (firestore == null) {
        return const UserSettings();
      }

      final snapshot = await firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        return const UserSettings();
      }

      final payload = snapshot.data();
      final settings = payload?['settings'];
      if (settings is Map) {
        return UserSettings.fromMap(Map<String, dynamic>.from(settings));
      }
      return UserSettings.fromMap(payload);
    } on FirebaseException catch (error) {
      debugPrint('Failed to fetch user settings: $error');
      return const UserSettings();
    } on PlatformException catch (error) {
      debugPrint('Failed to fetch user settings (platform): $error');
      return const UserSettings();
    }
  }

  Future<void> saveUserSettings(String uid, UserSettings settings) async {
    try {
      status.value = 'Saving settings...';
      final firestore = _ensureReady();
      if (firestore == null) {
        status.value = 'Settings not saved: Firestore not initialized';
        return;
      }

      await firestore.collection('users').doc(uid).set({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      status.value = 'Settings saved to Firestore';
      debugPrint('Saved settings for $uid');
    } on FirebaseException catch (error) {
      status.value = 'Settings save failed: $error';
      debugPrint('Failed to save settings: $error');
    } on PlatformException catch (error) {
      status.value = 'Settings save failed: $error';
      debugPrint('Failed to save settings (platform): $error');
    }
  }

  Future<List<FamilyContact>> fetchFamilyContacts(String uid) async {
    try {
      final firestore = _ensureReady();
      if (firestore == null) {
        return const [];
      }

      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('family')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => FamilyContact.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (error) {
      debugPrint('Failed to fetch family contacts: $error');
      return const [];
    } on PlatformException catch (error) {
      debugPrint('Failed to fetch family contacts (platform): $error');
      return const [];
    }
  }

  Future<void> saveFamilyContacts(
      String uid, List<FamilyContact> contacts) async {
    try {
      status.value = 'Saving family circle...';
      final firestore = _ensureReady();
      if (firestore == null) {
        status.value = 'Family circle not saved: Firestore not initialized';
        return;
      }

      final batch = firestore.batch();
      final collection =
          firestore.collection('users').doc(uid).collection('family');
      final current = await collection.get();
      for (final doc in current.docs) {
        batch.delete(doc.reference);
      }

      for (final contact in contacts) {
        final id = contact.id.isEmpty
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : contact.id;
        batch.set(
            collection.doc(id),
            {
              ...contact.toMap(),
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }

      await batch.commit();
      status.value = 'Family circle saved to Firestore';
      debugPrint('Saved family contacts for $uid');
    } on FirebaseException catch (error) {
      status.value = 'Family circle save failed: $error';
      debugPrint('Failed to save family contacts: $error');
    } on PlatformException catch (error) {
      status.value = 'Family circle save failed: $error';
      debugPrint('Failed to save family contacts (platform): $error');
    }
  }

  Future<FamilyInviteResult> sendFamilyInvitation({
    required AuthUser sender,
    required String targetEmail,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final normalizedEmail = targetEmail.trim().toLowerCase();
    final profileSnapshot = await _retryUnavailable(
      () => firestore.collection('publicProfiles').doc(normalizedEmail).get(),
    );
    if (!profileSnapshot.exists) return FamilyInviteResult.accountNotFound;

    final profileData = profileSnapshot.data()!;
    final recipient = PublicUserProfile(
      uid: profileData['uid'] as String? ?? '',
      email: profileData['email'] as String? ?? normalizedEmail,
      displayName: profileData['displayName'] as String? ?? '',
      photoUrl: profileData['photoURL'] as String? ?? '',
    );
    if (recipient.uid.isEmpty) return FamilyInviteResult.accountNotFound;
    if (recipient.uid == sender.uid) return FamilyInviteResult.selfInvite;

    final connectionId = _connectionId(sender.uid, recipient.uid);
    final connection =
        firestore.collection('familyConnections').doc(connectionId);
    if ((await _retryUnavailable(connection.get)).exists) {
      return FamilyInviteResult.alreadyConnected;
    }

    final invitationId = '${sender.uid}__${recipient.uid}';
    final invitation =
        firestore.collection('familyInvitations').doc(invitationId);
    final previous = await _retryUnavailable(invitation.get);
    if (previous.data()?['status'] == 'pending') {
      return FamilyInviteResult.alreadyPending;
    }
    if (previous.exists) {
      final previousStatus = previous.data()?['status'];
      if (previousStatus == 'accepted' || previousStatus == 'rejected') {
        await _retryUnavailable(invitation.delete);
      } else {
        throw StateError('This family request cannot be resent yet.');
      }
    }

    await _retryUnavailable(
      () => invitation.set({
        'fromUid': sender.uid,
        'fromName': sender.displayName?.trim().isNotEmpty == true
            ? sender.displayName!.trim()
            : sender.email,
        'fromEmail': sender.email.trim(),
        'toUid': recipient.uid,
        'toName': recipient.displayName,
        'toEmail': recipient.email.trim().toLowerCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      }),
    );
    return FamilyInviteResult.sent;
  }

  Stream<List<FamilyContact>> watchFamilyContacts(String uid) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('familyConnections')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final members = (doc.data()['members'] as List? ?? const [])
                  .whereType<Map>()
                  .map((member) => Map<String, dynamic>.from(member))
                  .toList();
              final other = members.cast<Map<String, dynamic>?>().firstWhere(
                    (member) => member?['uid'] != uid,
                    orElse: () => null,
                  );
              if (other == null) return null;
              final otherUid = other['uid'] as String? ?? doc.id;
              final locations = doc.data()['locations'] as Map? ?? const {};
              final location = locations[otherUid] as Map?;
              final alerts = doc.data()['alerts'] as Map? ?? const {};
              final alert = alerts[otherUid] as Map?;
              final alertExpiresAt =
                  (alert?['expiresAt'] as Timestamp?)?.toDate();
              return FamilyContact(
                id: otherUid,
                name: other['displayName'] as String? ?? 'Family member',
                email: other['email'] as String? ?? '',
                relation: 'Connected',
                latitude: (location?['latitude'] as num?)?.toDouble(),
                longitude: (location?['longitude'] as num?)?.toDouble(),
                locationUpdatedAt:
                    (location?['updatedAt'] as Timestamp?)?.toDate(),
                emergencyActive: (alert?['active'] as bool? ?? false) &&
                    (alertExpiresAt == null ||
                        alertExpiresAt.isAfter(DateTime.now())),
                emergencyLatitude: (alert?['latitude'] as num?)?.toDouble(),
                emergencyLongitude: (alert?['longitude'] as num?)?.toDouble(),
                emergencyStartedAt:
                    (alert?['startedAt'] as Timestamp?)?.toDate(),
                emergencyUpdatedAt:
                    (alert?['updatedAt'] as Timestamp?)?.toDate(),
                emergencyExpiresAt: alertExpiresAt,
              );
            })
            .whereType<FamilyContact>()
            .toList());
  }

  Future<void> updateFamilyLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Location coordinates are out of range.');
    }
    await _updateConnections(userId, {
      'locations.$userId': {
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> clearFamilyLocation(String userId) async {
    await _updateConnections(
        userId, {'locations.$userId': FieldValue.delete()});
  }

  Future<int> updateEmergencyAlert({
    required String userId,
    required double? latitude,
    required double? longitude,
  }) async {
    return _updateConnections(userId, {
      'alerts.$userId': {
        'active': true,
        'latitude': latitude,
        'longitude': longitude,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      },
    });
  }

  Future<void> clearEmergencyAlert(String userId) async {
    await _updateConnections(userId, {'alerts.$userId': FieldValue.delete()});
  }

  Future<int> _updateConnections(
    String userId,
    Map<String, dynamic> update,
  ) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final snapshot = await _retryUnavailable(
      () => firestore
          .collection('familyConnections')
          .where('memberUids', arrayContains: userId)
          .get(),
    );
    if (snapshot.docs.isEmpty) return 0;

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, update);
    }
    await _retryUnavailable(batch.commit);
    return snapshot.docs.length;
  }

  Future<Map<String, String>> fetchEmergencyContact(String userId) async {
    final firestore = _ensureReady();
    if (firestore == null) return const {};
    final snapshot = await _retryUnavailable(
      () => firestore.collection('users').doc(userId).get(),
    );
    final data = snapshot.data()?['emergencyContact'];
    if (data is! Map) return const {};
    return {
      'name': data['name'] as String? ?? '',
      'phone': data['phone'] as String? ?? '',
    };
  }

  Future<void> saveEmergencyContact({
    required String userId,
    required String name,
    required String phone,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    await _retryUnavailable(
      () => firestore.collection('users').doc(userId).set({
        'emergencyContact': {'name': name.trim(), 'phone': phone.trim()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Stream<List<FamilyInvitation>> watchIncomingFamilyInvitations(String uid) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('familyInvitations')
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .map((doc) => FamilyInvitation.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<SafePlace>> watchSafePlaces(String uid) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('users')
        .doc(uid)
        .collection('safePlaces')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              final data = document.data();
              return SafePlace(
                id: document.id,
                name: data['name'] as String? ?? 'Safe place',
                latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
                longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
                radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 150,
                totalVisitSeconds:
                    (data['totalVisitSeconds'] as num?)?.toInt() ?? 0,
                lastVisitSeconds:
                    (data['lastVisitSeconds'] as num?)?.toInt() ?? 0,
                lastVisitedAt: (data['lastVisitedAt'] as Timestamp?)?.toDate(),
              );
            }).toList());
  }

  Future<void> saveSafePlace(String uid, SafePlace place) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    await _retryUnavailable(
      () => firestore
          .collection('users')
          .doc(uid)
          .collection('safePlaces')
          .doc(place.id)
          .set({
        'name': place.name.trim(),
        'latitude': place.latitude,
        'longitude': place.longitude,
        'radiusMeters': place.radiusMeters,
        'totalVisitSeconds': place.totalVisitSeconds,
        'lastVisitSeconds': place.lastVisitSeconds,
        'lastVisitedAt': place.lastVisitedAt == null
            ? null
            : Timestamp.fromDate(place.lastVisitedAt!),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Future<void> recordSafePlaceVisit({
    required String userId,
    required String placeId,
    required int visitSeconds,
    required DateTime visitedAt,
  }) async {
    if (visitSeconds <= 0) return;
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    await _retryUnavailable(
      () => firestore
          .collection('users')
          .doc(userId)
          .collection('safePlaces')
          .doc(placeId)
          .update({
        'totalVisitSeconds': FieldValue.increment(visitSeconds),
        'lastVisitSeconds': visitSeconds,
        'lastVisitedAt': Timestamp.fromDate(visitedAt),
      }),
    );
  }

  Future<void> deleteSafePlace({
    required String userId,
    required String placeId,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    await _retryUnavailable(
      () => firestore
          .collection('users')
          .doc(userId)
          .collection('safePlaces')
          .doc(placeId)
          .delete(),
    );
  }

  Future<void> saveMessagingToken({
    required String userId,
    required String token,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    await _retryUnavailable(
      () => firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(token)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Future<void> removeMessagingToken({
    required String userId,
    required String token,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) return;
    await _retryUnavailable(
      () => firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(token)
          .delete(),
    );
  }

  Future<void> removeFamilyConnection({
    required String userId,
    required String targetUid,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final snapshot = await _retryUnavailable(
      () => firestore
          .collection('familyConnections')
          .where('memberUids', arrayContains: userId)
          .get(),
    );

    final matches = snapshot.docs.where((doc) {
      final memberUids = (doc.data()['memberUids'] as List? ?? const [])
          .map((uid) => uid.toString())
          .toList();
      return memberUids.contains(targetUid);
    }).toList();

    if (matches.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in matches) {
      batch.delete(doc.reference);
    }
    await _retryUnavailable(() => batch.commit());
  }

  Future<void> respondToFamilyInvitation({
    required String userId,
    required FamilyInvitation invitation,
    required bool accept,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final invitationRef =
        firestore.collection('familyInvitations').doc(invitation.id);
    await firestore.runTransaction((transaction) async {
      final invitationSnapshot = await transaction.get(invitationRef);
      final data = invitationSnapshot.data();
      if (data == null ||
          data['toUid'] != userId ||
          data['status'] != 'pending') {
        throw StateError('This family request is no longer pending.');
      }

      if (!accept) {
        transaction.update(invitationRef, {
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      transaction.update(invitationRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      final fromUid = data['fromUid'] as String;
      final toUid = data['toUid'] as String;
      final connectionRef = firestore
          .collection('familyConnections')
          .doc(_connectionId(fromUid, toUid));
      transaction.set(connectionRef, {
        'memberUids': [fromUid, toUid],
        'members': [
          {
            'uid': fromUid,
            'displayName': data['fromName'] as String,
            'email': data['fromEmail'] as String,
          },
          {
            'uid': toUid,
            'displayName': data['toName'] as String,
            'email': data['toEmail'] as String,
          },
        ],
        'locations': <String, dynamic>{},
        'alerts': <String, dynamic>{},
        'invitationId': invitation.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await _retryUnavailable(invitationRef.delete);
  }

  static String _connectionId(String firstUid, String secondUid) {
    final uids = [firstUid, secondUid]..sort();
    return '${uids.first}__${uids.last}';
  }

  Future<PublicUserProfile?> findPublicProfileByEmail(String email) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final normalizedEmail = email.trim().toLowerCase();
    final snapshot = await _retryUnavailable(
      () => firestore.collection('publicProfiles').doc(normalizedEmail).get(),
    );
    final data = snapshot.data();
    if (data == null) return null;
    final uid = data['uid'] as String? ?? '';
    if (uid.isEmpty) return null;

    return PublicUserProfile(
      uid: uid,
      email: data['email'] as String? ?? normalizedEmail,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoURL'] as String? ?? '',
    );
  }

  Future<PublicActivityStats> fetchPublicActivityStats(String uid) async {
    final firestore = _ensureReady();
    if (firestore == null) return const PublicActivityStats();

    try {
      final snapshot = await _retryUnavailable(
        () => firestore.collection('activityStats').doc(uid).get(),
      );
      return PublicActivityStats.fromMap(snapshot.data());
    } on FirebaseException catch (error) {
      debugPrint('Failed to fetch public activity stats: $error');
      return const PublicActivityStats();
    }
  }

  Future<void> syncPublicActivityStats(
      String uid, List<TripEntry> trips) async {
    final firestore = _ensureReady();
    if (firestore == null) return;

    final distanceMeters = trips.fold<double>(
      0,
      (total, trip) => total + trip.distanceMeters,
    );
    final movingMinutes = trips.fold<int>(
      0,
      (total, trip) => total + trip.totalMinutes.round(),
    );
    await _retryUnavailable(
        () => firestore.collection('activityStats').doc(uid).set({
              'tripCount': trips.length,
              'distanceMeters': distanceMeters,
              'movingMinutes': movingMinutes,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)));
  }

  Stream<List<ChatConversation>> watchChatConversations(String uid) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('chatThreads')
        .where('participantUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final conversations = snapshot.docs
          .map((doc) => ChatConversation.fromMap(doc.id, doc.data()))
          .toList();
      conversations.sort((first, second) {
        return (second.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
                first.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return conversations;
    });
  }

  Future<String> openOrCreateChat({
    required AuthUser currentUser,
    required PublicUserProfile otherUser,
  }) async {
    if (currentUser.uid == otherUser.uid) {
      throw StateError('You cannot start a chat with yourself.');
    }
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final participantUids = [currentUser.uid, otherUser.uid]..sort();
    final chatId = participantUids.join('__');
    final chatRef = firestore.collection('chatThreads').doc(chatId);
    final participants = {
      currentUser.uid: {
        'uid': currentUser.uid,
        'displayName': currentUser.displayName?.trim().isNotEmpty == true
            ? currentUser.displayName!.trim()
            : currentUser.email,
        'email': currentUser.email,
        'photoURL': currentUser.photoUrl ?? '',
      },
      otherUser.uid: {
        'uid': otherUser.uid,
        'displayName': otherUser.displayName.isNotEmpty
            ? otherUser.displayName
            : otherUser.email,
        'email': otherUser.email,
        'photoURL': otherUser.photoUrl,
      },
    };

    await _retryUnavailable(() => firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(chatRef);
          if (!snapshot.exists) {
            final now = Timestamp.now();
            transaction.set(chatRef, {
              'participantUids': participantUids,
              'participantProfiles': participants,
              'lastMessage': '',
              'lastSenderUid': '',
              'lastMessageAt': now,
              'lastReadAt': {currentUser.uid: now, otherUser.uid: now},
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            final storedUids =
                (snapshot.data()?['participantUids'] as List? ?? const [])
                    .map((uid) => uid.toString())
                    .toSet();
            if (!storedUids.contains(currentUser.uid) ||
                !storedUids.contains(otherUser.uid)) {
              throw StateError('This conversation is not available.');
            }
          }
        }));
    return chatId;
  }

  Stream<List<ChatMessage>> watchChatMessages(String chatId) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('chatThreads')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<ChatConversation?> watchChatConversation(String chatId) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(null);

    return firestore.collection('chatThreads').doc(chatId).snapshots().map(
          (snapshot) => snapshot.data() == null
              ? null
              : ChatConversation.fromMap(snapshot.id, snapshot.data()!),
        );
  }

  Future<void> sendChatMessage({
    required String chatId,
    required String senderUid,
    required String text,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderUid,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > 4000) return;
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    final threadRef = firestore.collection('chatThreads').doc(chatId);
    final messageRef = threadRef.collection('messages').doc();
    final batch = firestore.batch();
    batch.set(messageRef, {
      'senderUid': senderUid,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderUid != null) 'replyToSenderUid': replyToSenderUid,
    });
    batch.update(threadRef, {
      'lastMessage': cleanText,
      'lastSenderUid': senderUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastReadAt.$senderUid': FieldValue.serverTimestamp(),
    });
    await _retryUnavailable(batch.commit);
  }

  Future<void> markChatRead({
    required String chatId,
    required String readerUid,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');

    await _retryUnavailable(() => firestore
        .collection('chatThreads')
        .doc(chatId)
        .update({'lastReadAt.$readerUid': FieldValue.serverTimestamp()}));
  }

  Future<void> setChatMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final firestore = _ensureReady();
    if (firestore == null) throw StateError('Firestore is not initialized.');
    final messageRef = firestore
        .collection('chatThreads')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final message = await _retryUnavailable(messageRef.get);
    if (!message.exists) return;
    final current = (message.data()?['reactions'] as Map? ?? const {})[userId];
    await _retryUnavailable(() => messageRef.update({
          'reactions.$userId': current == emoji ? FieldValue.delete() : emoji,
        }));
  }

  Future<List<TripEntry>> fetchTrips(String uid) async {
    try {
      final firestore = _ensureReady();
      if (firestore == null) {
        return const [];
      }

      final snapshot = await firestore
          .collection('trips')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final startedAt =
            (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final endedAt =
            (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final points =
            (data['points'] as List? ?? const []).asMap().entries.map((entry) {
          final point = entry.value as Map;
          return TripLocation(
            latitude: (point['lat'] as num).toDouble(),
            longitude: (point['lng'] as num).toDouble(),
            segmentStart: point['segmentStart'] as bool? ?? entry.key == 0,
          );
        }).toList();

        return TripEntry(
          id: doc.id,
          startedAt: startedAt,
          endedAt: endedAt,
          points: points,
          distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
          averageSpeedKmh: (data['averageSpeedKmh'] as num?)?.toDouble() ?? 0,
          name: data['name'] as String?,
          movingSeconds: (data['movingSeconds'] as num?)?.toDouble(),
        );
      }).toList();
    } on FirebaseException catch (error) {
      debugPrint('Failed to fetch trips: $error');
      return const [];
    } on PlatformException catch (error) {
      debugPrint('Failed to fetch trips (platform): $error');
      return const [];
    }
  }

  Stream<List<TripEntry>> watchTrips(String uid) {
    final firestore = _ensureReady();
    if (firestore == null) return Stream.value(const []);

    return firestore
        .collection('trips')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final startedAt =
                  (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final endedAt =
                  (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final points = (data['points'] as List? ?? const [])
                  .asMap()
                  .entries
                  .map((entry) {
                final point = entry.value as Map;
                return TripLocation(
                  latitude: (point['lat'] as num).toDouble(),
                  longitude: (point['lng'] as num).toDouble(),
                  segmentStart:
                      point['segmentStart'] as bool? ?? entry.key == 0,
                );
              }).toList();

              return TripEntry(
                id: doc.id,
                startedAt: startedAt,
                endedAt: endedAt,
                points: points,
                distanceMeters:
                    (data['distanceMeters'] as num?)?.toDouble() ?? 0,
                averageSpeedKmh:
                    (data['averageSpeedKmh'] as num?)?.toDouble() ?? 0,
                name: data['name'] as String?,
                movingSeconds: (data['movingSeconds'] as num?)?.toDouble(),
              );
            }).toList());
  }

  Future<void> saveTrip(String uid, TripEntry trip) async {
    try {
      status.value = 'Saving trip...';
      final firestore = _ensureReady();
      if (firestore == null) {
        status.value = 'Trip not saved: Firestore not initialized';
        debugPrint('Firestore not initialized; skipping trip save.');
        return;
      }

      final batch = firestore.batch();
      final tripRef = firestore.collection('trips').doc();
      batch.set(tripRef, {
        'uid': uid,
        'startedAt': Timestamp.fromDate(trip.startedAt),
        'endedAt': Timestamp.fromDate(trip.endedAt),
        'distanceMeters': trip.distanceMeters,
        'averageSpeedKmh': trip.averageSpeedKmh,
        'name': trip.name,
        'movingSeconds': trip.movingSeconds,
        'points': trip.points
            .map(
              (point) => {
                'lat': point.latitude,
                'lng': point.longitude,
                'segmentStart': point.segmentStart,
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(
          firestore.collection('activityStats').doc(uid),
          {
            'tripCount': FieldValue.increment(1),
            'distanceMeters': FieldValue.increment(trip.distanceMeters),
            'movingMinutes': FieldValue.increment(trip.totalMinutes.round()),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      await _retryUnavailable(batch.commit);

      status.value = 'Trip saved to Firestore';
      debugPrint('Saved trip for $uid');
    } on FirebaseException catch (error) {
      status.value = 'Trip save failed: $error';
      debugPrint('Failed to save trip: $error');
    } on PlatformException catch (error) {
      status.value = 'Trip save failed: $error';
      debugPrint('Failed to save trip (platform): $error');
    }
  }
}
