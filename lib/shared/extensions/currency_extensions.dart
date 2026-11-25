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

  /// "฿2,000" — what a feed card prints beside "/คน". The sign sits against
  /// the figure; the space the card used to put there read as two fields.
  String get asBaht => '฿$_grouped';
}
