String normalizeUgPhone(String input) {
  var raw = input.trim();
  if (raw.isEmpty) return '';

  if (raw.startsWith('+')) raw = raw.substring(1);
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';

  if (digits.startsWith('256')) return digits;

  if (digits.startsWith('0') && digits.length >= 10) {
    return '256${digits.substring(1)}';
  }

  if (digits.length == 9 || digits.length == 10) {
    return '256$digits';
  }

  return digits;
}

bool looksLikeUgPhone(String input) {
  final normalized = normalizeUgPhone(input);
  return normalized.startsWith('256') && normalized.length == 12;
}
