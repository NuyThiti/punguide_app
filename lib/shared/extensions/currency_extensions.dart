extension BudgetFormat on double {
  String get _grouped {
    final whole = round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String get asBudget => '\$$_grouped';

  String get asBaht => '฿$_grouped';
}
