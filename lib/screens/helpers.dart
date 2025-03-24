import 'package:intl/intl.dart';

class Helpers {
  static DateTime? toIST(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      DateTime utcDate = DateTime.parse(timestamp).toUtc();
      return utcDate.add(Duration(hours: 5, minutes: 30)); // Convert to IST
    } catch (e) {
      print("❌ Error parsing timestamp: $timestamp, Exception: $e");
      return null;
    }
  }

  static String formatDate(String? timestamp) {
    DateTime? date = toIST(timestamp);
    return date != null ? DateFormat('dd-MM-yyyy').format(date) : "Invalid Date";
  }

  static String formatTimeOnly(String? timestamp) {
    DateTime? date = toIST(timestamp);
    return date != null ? DateFormat('hh:mm a').format(date) : "Invalid Time";
  }

  static String formatTime(num? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return "N/A";
    final int seconds = (milliseconds / 1000).floor();
    final int minutes = (seconds / 60).floor();
    final int hours = (minutes / 60).floor();
    return "${hours}h ${minutes % 60}m ${seconds % 60}s";
  }
}
