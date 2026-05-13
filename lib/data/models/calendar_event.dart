import 'dart:convert';
import 'package:flutter/material.dart';

/// Unified weekly family calendar event model.
///
/// The calendar is only a visibility layer. Notification scheduling remains
/// owned by each original module/service.
class CalendarEvent {
  final String id;
  final String familyId;
  final String memberId;
  final String memberName;
  final String? memberProfileType;
  final EventType eventType;
  final String title;
  final DateTime eventDate;
  final TimeOfDay? eventTime;
  final Map<String, dynamic>? eventData;
  final String? sourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.memberName,
    this.memberProfileType,
    required this.eventType,
    required this.title,
    required this.eventDate,
    this.eventTime,
    this.eventData,
    this.sourceId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> m, [String? fallbackMemberName]) {
    final rawDate = (m['event_date'] ?? m['scheduled_at'] ?? m['received_at'] ?? m['created_at']) as String?;
    final parsedDate = rawDate == null || rawDate.isEmpty
        ? DateTime.now()
        : DateTime.tryParse(rawDate) ?? DateTime.now();

    final rawTime = m['event_time'] as String?;
    final hasTimeInDate = rawDate != null &&
        (rawDate.contains('T') || RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}').hasMatch(rawDate));
    final derivedTime = rawTime != null && rawTime.isNotEmpty
        ? _parseTimeOfDay(rawTime)
        : hasTimeInDate
            ? TimeOfDay.fromDateTime(parsedDate)
            : null;

    final normalizedDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      derivedTime?.hour ?? parsedDate.hour,
      derivedTime?.minute ?? parsedDate.minute,
    );

    final rawCreated = m['created_at'] as String?;
    final rawUpdated = m['updated_at'] as String?;

    return CalendarEvent(
      id: (m['id'] ?? m['source_id'] ?? '${m['event_type']}_${parsedDate.millisecondsSinceEpoch}') as String,
      familyId: (m['family_id'] ?? '') as String,
      memberId: (m['member_id'] ?? '') as String,
      memberName: (m['member_name'] ?? fallbackMemberName ?? 'Family') as String,
      memberProfileType: m['member_profile_type'] as String? ?? m['profile_type'] as String?,
      eventType: _parseEventType((m['event_type'] ?? 'appointment') as String),
      title: (m['event_title'] ?? m['title'] ?? 'Scheduled item') as String,
      eventDate: normalizedDate,
      eventTime: derivedTime,
      eventData: _readEventData(m),
      sourceId: m['source_id'] as String? ?? m['id'] as String?,
      createdAt: rawCreated == null ? DateTime.now() : (DateTime.tryParse(rawCreated) ?? DateTime.now()),
      updatedAt: rawUpdated == null ? DateTime.now() : (DateTime.tryParse(rawUpdated) ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'member_id': memberId,
        'member_name': memberName,
        'member_profile_type': memberProfileType,
        'event_type': eventType.name,
        'event_title': title,
        'event_date': eventDate.toIso8601String(),
        'event_time': eventTime == null
            ? null
            : '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')}',
        'event_data': eventData == null ? null : jsonEncode(eventData),
        'source_id': sourceId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Map<String, dynamic>? _readEventData(Map<String, dynamic> m) {
    final raw = m['event_data'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    final details = <String, dynamic>{};
    for (final key in [
      'doctor',
      'location',
      'notes',
      'dose',
      'frequency',
      'time_of_day',
      'reminder_hour',
      'reminder_minute',
      'clinic_name',
      'received_at',
      'is_received',
    ]) {
      if (m.containsKey(key) && m[key] != null) details[key] = m[key];
    }
    return details.isEmpty ? null : details;
  }

  static EventType _parseEventType(String type) {
    switch (type) {
      case 'appointment':
        return EventType.appointment;
      case 'medicationReminder':
      case 'medication':
        return EventType.medicationReminder;
      case 'childMedication':
      case 'child_medication':
        return EventType.childMedication;
      case 'vaccinationReminder':
      case 'vaccination':
        return EventType.vaccinationReminder;
      case 'familyReminder':
      case 'family_reminder':
        return EventType.familyReminder;
      default:
        return EventType.appointment;
    }
  }

  static TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}

enum EventType {
  appointment,
  medicationReminder,
  childMedication,
  vaccinationReminder,
  familyReminder,
}

extension EventTypeX on EventType {
  String get label {
    switch (this) {
      case EventType.appointment:
        return 'Appointment';
      case EventType.medicationReminder:
        return 'Medication';
      case EventType.childMedication:
        return 'Child Medication';
      case EventType.vaccinationReminder:
        return 'Vaccination';
      case EventType.familyReminder:
        return 'Family Reminder';
    }
  }

  String get arabicLabel {
    switch (this) {
      case EventType.appointment:
        return 'موعد';
      case EventType.medicationReminder:
        return 'تذكير دواء';
      case EventType.childMedication:
        return 'دواء طفل';
      case EventType.vaccinationReminder:
        return 'تطعيم';
      case EventType.familyReminder:
        return 'تذكير عائلي';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.appointment:
        return Icons.event_available_rounded;
      case EventType.medicationReminder:
        return Icons.medication_rounded;
      case EventType.childMedication:
        return Icons.child_care_rounded;
      case EventType.vaccinationReminder:
        return Icons.vaccines_rounded;
      case EventType.familyReminder:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    switch (this) {
      case EventType.appointment:
        return const Color(0xFF1976D2);
      case EventType.medicationReminder:
        return const Color(0xFF7B1FA2);
      case EventType.childMedication:
        return const Color(0xFF00897B);
      case EventType.vaccinationReminder:
        return const Color(0xFF2E7D32);
      case EventType.familyReminder:
        return const Color(0xFFE65100);
    }
  }

  Color get softColor => color.withValues(alpha: 0.12);
}
