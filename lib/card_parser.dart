/// Turns raw OCR text (from the card photo) into structured card details.
///
/// This uses simple, well-commented heuristics — pattern matching plus the
/// Luhn checksum — rather than any paid/cloud service, so it works fully
/// offline and free of charge. It won't be 100% perfect on every card design,
/// but it works well on most plastic cards with embossed/printed digits.
class CardParser {
  /// Looks for a run of 13-19 digits (allowing spaces/dashes between them,
  /// the way card numbers are usually printed) and returns the cleaned
  /// digits-only string, preferring a 16-digit match that passes the Luhn
  /// checksum used by real card numbers.

  static List<String> cards = [];

  /// Looks for a standalone number with no spaces or dashes inside it,
  /// 8 to 13 digits long — e.g. a separate "account number" some banks
  /// print on the front or back of a card, distinct from the 16-digit card
  /// number. Returns null if no such number is found.
  static String? extractAccountNumber(String text) {
    final matches = RegExp(r'\b\d{8,13}\b').allMatches(text);

    final candidates = matches.map((m) => m.group(0)!).toSet().toList();

    if (candidates.isEmpty) return null;

    // Prefer the longest match found — closer to 13 digits is usually the
    // actual account number rather than a shorter stray digit run.
    candidates.sort((a, b) => b.length.compareTo(a.length));

    return candidates.first;
  }

  static String? extractCardNumber(String text) {
    final matches = RegExp(r'(?:\d[ -]?){13,19}').allMatches(text);

    final candidates = matches
        .map((m) => m.group(0)!.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((d) => d.length >= 13 && d.length <= 19)
        .toSet() // de-duplicate
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      int score(String d) {
        var s = 0;
        if (d.length != 16) s += 1; // prefer exactly 16 digits
        if (!_passesLuhn(d)) s += 2; // prefer a valid checksum
        return s;
      }

      return score(a).compareTo(score(b));
    });

    return candidates.first;
  }

  /// Formats a digits-only string into groups of 4, e.g. "4111 1111 1111 1111".
  static String formatCardNumber(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i + 1) % 4 == 0 && i != digits.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  /// Looks for an MM/YY (or MM YY) pattern, the standard expiry format.
  static String? extractExpiryDate(String text) {
    final match = RegExp(r'(0[1-9]|1[0-2])\s?/\s?(\d{2})\b').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}/${match.group(2)}';
  }

  /// Best-effort guess at the cardholder name: the longest all-letter line
  /// that isn't a digit, isn't the issuer/network name, and isn't a known
  /// label like "VALID THRU". This is a heuristic and may occasionally miss
  /// or misfire — it's meant as a convenience, not a guarantee.
  static String? extractCardHolderName(String text) {
    const blacklist = [
      'VISA',
      'MASTERCARD',
      'MAESTRO',
      'AMERICAN EXPRESS',
      'EXPRESS',
      'DEBIT',
      'CREDIT',
      'BANK',
      'VALID',
      'THRU',
      'EXPIRES',
      'EXP',
      'PLATINUM',
      'GOLD',
      'CLASSIC',
      'SIGNATURE',
      'WORLD',
      'BUSINESS',
      'MEMBER',
      'SINCE',
    ];

    String? best;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.length < 4) continue;
      if (RegExp(r'\d').hasMatch(line)) continue;
      if (!RegExp(r'^[A-Za-z .,\-]+$').hasMatch(line)) continue;

      final upper = line.toUpperCase();
      if (blacklist.any((word) => upper.contains(word))) continue;

      if (best == null || line.length > best.length) best = upper;
    }
    return best;
  }

  static bool _passesLuhn(String number) {
    var sum = 0;
    var alternate = false;
    for (var i = number.length - 1; i >= 0; i--) {
      var n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}
