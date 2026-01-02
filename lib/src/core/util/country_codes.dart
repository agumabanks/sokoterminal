// Country code data for phone input
import 'package:flutter/material.dart';

class CountryCode {
  const CountryCode({
    required this.code,
    required this.name,
    required this.flag,
    required this.digitCode,
  });

  /// Display code like "+256"
  final String code;
  /// Country name
  final String name;
  /// Flag emoji
  final String flag;
  /// Just the digits, e.g. "256"
  final String digitCode;

  String get displayShort => '$flag $code';
  String get displayFull => '$flag $name ($code)';
}

/// Pre-defined list of East African country codes
const List<CountryCode> eastAfricanCountryCodes = [
  CountryCode(code: '+256', name: 'Uganda', flag: '🇺🇬', digitCode: '256'),
  CountryCode(code: '+254', name: 'Kenya', flag: '🇰🇪', digitCode: '254'),
  CountryCode(code: '+255', name: 'Tanzania', flag: '🇹🇿', digitCode: '255'),
  CountryCode(code: '+250', name: 'Rwanda', flag: '🇷🇼', digitCode: '250'),
  CountryCode(code: '+257', name: 'Burundi', flag: '🇧🇮', digitCode: '257'),
  CountryCode(code: '+211', name: 'South Sudan', flag: '🇸🇸', digitCode: '211'),
  CountryCode(code: '+243', name: 'DR Congo', flag: '🇨🇩', digitCode: '243'),
];

/// Default country code (Uganda)
const CountryCode defaultCountryCode = CountryCode(
  code: '+256',
  name: 'Uganda',
  flag: '🇺🇬',
  digitCode: '256',
);

/// Normalizes a phone number with the given country code.
/// - Strips leading zeros from the local number
/// - Returns format: countryDigits + localNumber (e.g., "256706272481")
String normalizePhoneWithCountry(String input, CountryCode country) {
  var raw = input.trim();
  if (raw.isEmpty) return '';

  // Remove any non-digit characters
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';

  // If already starts with country digit code, return as is
  if (digits.startsWith(country.digitCode)) {
    return digits;
  }

  // Strip leading zero(s)
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.isEmpty) return '';

  return '${country.digitCode}$digits';
}

/// Formats phone for display with + prefix (e.g., "+256706272481")
String formatPhoneForDisplay(String normalizedPhone) {
  if (normalizedPhone.isEmpty) return '';
  if (normalizedPhone.startsWith('+')) return normalizedPhone;
  return '+$normalizedPhone';
}

/// Shows a polished bottom sheet for country selection
Future<CountryCode?> showCountryPickerBottomSheet(BuildContext context, CountryCode current) async {
  return showModalBottomSheet<CountryCode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'Select Country',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: eastAfricanCountryCodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final country = eastAfricanCountryCodes[index];
                final isSelected = country.code == current.code;
                return Material(
                  color: isSelected ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, country),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  country.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  country.code,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
