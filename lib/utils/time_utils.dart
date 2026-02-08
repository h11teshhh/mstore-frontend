class TimeUtils {
  /// Converts ISO string (UTC from backend) to local device time (IST)
  /// Forces UTC recognition to ensure proper offset calculation.
  static DateTime toLocalTime(String isoString) {
    try {
      // We parse, force UTC, then convert to Local (IST)
      return DateTime.parse(isoString).toUtc().toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Returns formatted date like: 05-02-2026
  static String formatDate(dynamic isoString) {
    if (isoString == null || isoString.toString().isEmpty) return "--";
    try {
      final dt = DateTime.parse(isoString.toString()).toUtc().toLocal();
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year}";
    } catch (e) {
      return isoString.toString();
    }
  }

  /// Returns formatted date + time: 05-02-2026 03:15 PM
  static String formatDateTime(dynamic isoString) {
    if (isoString == null || isoString.toString().isEmpty) return "--";
    try {
      // The key change: .toUtc().toLocal()
      final dt = DateTime.parse(isoString.toString()).toUtc().toLocal();

      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? "PM" : "AM";

      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year} "
          "${hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} $amPm";
    } catch (e) {
      return isoString.toString();
    }
  }
}
