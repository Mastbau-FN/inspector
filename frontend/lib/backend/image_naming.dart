import 'dart:io';

import 'package:image_picker/image_picker.dart';

final RegExp _timestampImageNamePattern =
    RegExp(r'^\d{2}_\d{2}_\d{4}_\d{2}_\d{2}_\d{2}\.jpg$', caseSensitive: false);

const _knownServerImageArtifacts = <String>{
  'thumbs.db',
  'ehthumbs.db',
  'ehthumbs_vista.db',
  'desktop.ini',
  '.ds_store',
};

String _pad2(int v) => v.toString().padLeft(2, '0');

String formatTimestampImageFilename(DateTime timestamp) {
  final t = timestamp.toLocal();
  return '${_pad2(t.day)}_${_pad2(t.month)}_${t.year}_${_pad2(t.hour)}_${_pad2(t.minute)}_${_pad2(t.second)}.jpg';
}

String _basename(String raw) {
  final normalized = raw.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? raw : parts.last;
}

/// Operating-system metadata that was accidentally indexed as an image by
/// older server data. These files are not user photos and must not make an
/// otherwise complete offline inspection fail.
bool isKnownServerImageArtifactFilename(String? filename) {
  if (filename == null) return false;
  final base = _basename(filename).trim().toLowerCase();
  return _knownServerImageArtifacts.contains(base);
}

bool isTimestampImageFilename(String filename) {
  final base = _basename(filename).trim();
  return _timestampImageNamePattern.hasMatch(base);
}

DateTime? parseTimestampImageFilename(String filename) {
  final base = _basename(filename).trim();
  if (!isTimestampImageFilename(base)) return null;
  final noExt = base.substring(0, base.length - 4);
  final p = noExt.split('_');
  if (p.length != 6) return null;
  final day = int.tryParse(p[0]);
  final month = int.tryParse(p[1]);
  final year = int.tryParse(p[2]);
  final hour = int.tryParse(p[3]);
  final minute = int.tryParse(p[4]);
  final second = int.tryParse(p[5]);
  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

DateTime _bestEffortTimestampFromFile(XFile file) {
  try {
    final stat = FileStat.statSync(file.path);
    if (stat.changed.millisecondsSinceEpoch > 0) return stat.changed;
  } catch (_) {}
  return DateTime.now();
}

String canonicalTimestampFilenameForXFile(XFile file) {
  final base = _basename(file.name).trim();
  if (isTimestampImageFilename(base)) {
    final lower = base.toLowerCase();
    return lower.endsWith('.jpg')
        ? base.substring(0, base.length - 4) + '.jpg'
        : '$base.jpg';
  }

  final parsed = parseTimestampImageFilename(base);
  if (parsed != null) return formatTimestampImageFilename(parsed);

  return formatTimestampImageFilename(_bestEffortTimestampFromFile(file));
}
