class IraqiIdExtractor {
  // ١. تنظيف النص من الضوضاء
  static String cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'[*\-+©|»«\\/\[\]{}]'), '') // حذف رموز الضوضاء
        .replaceAll(RegExp(r'\s{2,}'), ' ') // تقليل المسافات المتكررة
        .replaceAll(RegExp(r'[^\u0600-\u06FF\u0660-\u0669\d\s\n.,]'),
            '') // أبقِ عربي وأرقام فقط
        .trim();
  }

  // ٢. استخراج رقم الهوية (12-13 رقم)
  static String? extractIdNumber(String text) {
    // أرقام عربية
    final arabicDigits = text.replaceAllMapped(
      RegExp(r'[٠١٢٣٤٥٦٧٨٩]'),
      (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m.group(0)!).toString(),
    );

    final match = RegExp(r'\d{10,13}').firstMatch(arabicDigits);
    return match?.group(0);
  }

  // ٣. استخراج الاسم
  static String? extractName(String text) {
    // الاسم يأتي عادةً بعد كلمة "الاسم" أو "اسم"
    final match = RegExp(
      r'(?:الاسم|اسم)[:\s]+([^\n\d*]+)',
    ).firstMatch(text);

    if (match != null) {
      return match.group(1)?.trim();
    }

    // fallback: ابحث عن سطر يحتوي فقط على كلمات عربية
    final lines = text.split('\n');
    for (final line in lines) {
      final cleaned = line.trim();
      if (RegExp(r'^[\u0600-\u06FF\s]{5,30}$').hasMatch(cleaned)) {
        return cleaned;
      }
    }
    return null;
  }

  // ٤. استخراج تاريخ الميلاد
  static String? extractDOB(String text) {
    final match = RegExp(
      r'(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})',
    ).firstMatch(text);
    return match?.group(0);
  }

  // ٥. استخراج المحافظة
  static String? extractGovernorate(String text) {
    const governorates = [
      'بغداد',
      'البصرة',
      'نينوى',
      'أربيل',
      'النجف',
      'كربلاء',
      'الأنبار',
      'ديالى',
      'كركوك',
      'واسط',
      'ميسان',
      'المثنى',
      'ذي قار',
      'بابل',
      'صلاح الدين',
      'دهوك',
      'السليمانية',
      'القادسية',
    ];
    for (final gov in governorates) {
      if (text.contains(gov)) return gov;
    }
    return null;
  }

  // ٦. الدالة الرئيسية — تجمع كل شيء
  static Map<String, String?> extract(String rawOcrText) {
    final cleaned = cleanText(rawOcrText);
    return {
      'raw': rawOcrText,
      'cleaned': cleaned,
      'idNumber': extractIdNumber(rawOcrText), // نبحث في الخام للأرقام
      'name': extractName(cleaned),
      'dob': extractDOB(rawOcrText),
      'governorate': extractGovernorate(cleaned),
    };
  }
}
