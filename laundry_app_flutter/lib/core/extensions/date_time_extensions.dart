import 'package:intl/intl.dart';

extension IndonesianDateTimeFormat on DateTime {
  String toIndonesianDate() => DateFormat('d MMMM y', 'id_ID').format(this);

  String toIndonesianTime() => DateFormat('HH.mm', 'id_ID').format(this);
}
