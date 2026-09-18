class StorageSizeFormatter {
  const StorageSizeFormatter._();

  static const int _kb = 1000;
  static const int _mb = _kb * 1000;
  static const int _gb = _mb * 1000;
  static const int _tb = _gb * 1000;

  static String formatBytes(num bytes) {
    final value = bytes < 0 ? 0.0 : bytes.toDouble();
    if (value >= _tb) return '${_format(value / _tb)} TB';
    if (value >= _gb) return '${_format(value / _gb)} GB';
    if (value >= _mb) return '${_format(value / _mb)} MB';
    if (value >= _kb) return '${_format(value / _kb)} KB';
    return '${value.round()} B';
  }

  static String formatMebibytes(num mebibytes) {
    final value = mebibytes < 0 ? 0.0 : mebibytes.toDouble();
    if (value >= 1024 * 1024) return '${_format(value / (1024 * 1024))} TB';
    if (value >= 1024) return '${_format(value / 1024)} GB';
    return '${_format(value)} MB';
  }

  static String _format(double value) {
    final decimals = value >= 100 ? 0 : 1;
    return value
        .toStringAsFixed(decimals)
        .replaceFirst('.', ',');
  }
}
