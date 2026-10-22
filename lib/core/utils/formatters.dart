import 'package:intl/intl.dart';

class Formatters {
  static String formatCurrency(double? amount, {String symbol = 'đ'}) {
    if (amount == null) return '0 $symbol';
    return NumberFormat.currency(locale: 'vi_VN', symbol: symbol).format(amount);
  }

  static String formatDistance(double km) {
    if (km == km.roundToDouble()) {
      return '${km.toInt()}km';
    }
    return '${km.toStringAsFixed(1)}km';
  }
}
