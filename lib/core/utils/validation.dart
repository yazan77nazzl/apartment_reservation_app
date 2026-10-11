class Validation {
  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  static String? email(String? value) => value != null &&
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? null
      : 'Enter a valid email';
  static String? password(String? value) =>
      value != null && value.length >= 8 ? null : 'Use at least 8 characters';
  static String? phone(String? value) =>
      value != null && RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(value.trim())
          ? null
          : 'Enter a valid phone number';
  static String? positive(String? value) =>
      double.tryParse(value ?? '') != null && double.parse(value!) > 0
          ? null
          : 'Enter a positive number';
}
