import 'package:flutter/material.dart';

/// Unified calendar event model for appointments, vaccines, and prenatal tests
class CalendarEvent {
  final String id;
  final String familyId;
  final String memberId;
  final String memberName;
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
    required this.eventType,
    required this.title,
    required this.eventDate,
    this.eventTime,
    this.eventData,
    this.sourceId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a calendar event from appointment data
  factory CalendarEvent.fromAppointment({
    required String id,
    required String familyId,
    required String memberId,
    required String memberName,
    required String title,
    required String? doctor,
    required String? location,
    required DateTime scheduledAt,
    required String? notes,
  }) {
    return CalendarEvent(
      id: id,
      familyId: familyId,
      memberId: memberId,
      memberName: memberName,
      eventType: EventType.appointment,
      title: title,
      eventDate: scheduledAt,
      eventTime: TimeOfDay.fromDateTime(scheduledAt),
      eventData: {
        'doctor': doctor,
        'location': location,
        'notes': notes,
      },
      sourceId: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a calendar event from vaccination due date
  factory CalendarEvent.fromVaccineDue({
    required String id,
    required String familyId,
    required String memberId,
    required String memberName,
    required String vaccineName,
    required DateTime dueDate,
    required bool isReceived,
    required String? clinicName,
  }) {
    return CalendarEvent(
      id: 'vaccine_${id}_${dueDate.millisecondsSinceEpoch}',
      familyId: familyId,
      memberId: memberId,
      memberName: memberName,
      eventType: EventType.vaccination,
      title: 'Vaccine: $vaccineName',
      eventDate: dueDate,
      eventData: {
        'vaccine_name': vaccineName,
        'is_received': isReceived,
        'clinic_name': clinicName,
      },
      sourceId: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a calendar event from prenatal test due date
  factory CalendarEvent.fromPrenatalTest({
    required String id,
    required String familyId,
    required String memberId,
    required String memberName,
    required String testName,
    required int trimester,
    required DateTime dueDate,
    required bool isCompleted,
  }) {
    return CalendarEvent(
      id: 'prenatal_${id}_$trimester',
      familyId: familyId,
      memberId: memberId,
      memberName: memberName,
      eventType: EventType.prenatalTest,
      title: 'Prenatal Test (T$trimester): $testName',
      eventDate: dueDate,
      eventData: {
        'test_name': testName,
        'trimester': trimester,
        'is_completed': isCompleted,
      },
      sourceId: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() => {
    'id': id,
    'family_id': familyId,
    'member_id': memberId,
    'event_type': eventType.toString().split('.').last,
    'event_title': title,
    'event_date': eventDate.toIso8601String(),
    'event_time': eventTime != null ? '${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')}' : null,
    'event_data': eventData != null ? _encodeJson(eventData!) : null,
    'source_id': sourceId,
  };

  /// Create from database map
  factory CalendarEvent.fromMap(Map<String, dynamic> m, String memberName) {
    return CalendarEvent(
      id: m['id'] as String,
      familyId: m['family_id'] as String,
      memberId: m['member_id'] as String,
      memberName: memberName,
      eventType: _parseEventType(m['event_type'] as String),
      title: m['event_title'] as String,
      eventDate: DateTime.parse(m['event_date'] as String),
      eventTime: m['event_time'] != null ? _parseTimeOfDay(m['event_time'] as String) : null,
      eventData: m['event_data'] != null ? _decodeJson(m['event_data'] as String) : null,
      sourceId: m['source_id'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  static String _encodeJson(Map<String, dynamic> data) {
    // Simple JSON encoding - in production, use json.encode()
    return data.toString();
  }

  static Map<String, dynamic> _decodeJson(String data) {
    // Simple JSON decoding - in production, use json.decode()
    return {};
  }

  static EventType _parseEventType(String type) {
    switch (type) {
      case 'appointment':
        return EventType.appointment;
      case 'vaccination':
        return EventType.vaccination;
      case 'prenatalTest':
        return EventType.prenatalTest;
      default:
        return EventType.appointment;
    }
  }

  static TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

enum EventType {
  appointment,    // Doctor visit
  vaccination,    // Vaccine due / received
  prenatalTest,   // Prenatal screening
}

extension EventTypeX on EventType {
  String get label {
    switch (this) {
      case EventType.appointment:
        return 'Appointment';
      case EventType.vaccination:
        return 'Vaccination';
      case EventType.prenatalTest:
        return 'Prenatal Test';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.appointment:
        return Icons.calendar_today;
      case EventType.vaccination:
        return Icons.vaccines;
      case EventType.prenatalTest:
        return Icons.pregnant_woman;
    }
  }

  Color get color {
    switch (this) {
      case EventType.appointment:
        return const Color(0xFF1976D2); // Blue
      case EventType.vaccination:
        return const Color(0xFF388E3C); // Green
      case EventType.prenatalTest:
        return const Color(0xFFC2185B); // Pink
    }
  }
}
