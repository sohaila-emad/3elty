/// Input validation utilities for the app
class Validators {
  // Member validation
  static String? validateMemberName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final age = int.tryParse(value.trim());
    if (age == null) {
      return 'Age must be a number';
    }
    if (age < 0 || age > 150) {
      return 'Age must be between 0 and 150';
    }
    return null;
  }

  // Auth validation
  static String? validateAdminName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Admin name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phone = value.trim();
    if (phone.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (phone.length > 15) {
      return 'Phone number must be less than 15 digits';
    }
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(phone)) {
      return 'Phone number contains invalid characters';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateMedicationName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Medication name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateDose(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Dose is required (e.g., 500mg, 2 tablets)';
    }
    if (value.trim().length < 2) {
      return 'Dose format too short';
    }
    return null;
  }

  static String? validateFrequency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Frequency is required (e.g., 3x daily)';
    }
    return null;
  }

  static String? validateAppointmentTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Appointment title is required';
    }
    if (value.trim().length < 3) {
      return 'Title must be at least 3 characters';
    }
    return null;
  }

  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null) {
      return '$fieldName must be a valid number';
    }
    if (num <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }
}
