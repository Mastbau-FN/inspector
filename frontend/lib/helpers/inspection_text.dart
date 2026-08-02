/// Normalizes user-visible inspection labels for tolerant comparisons.
///
/// In particular, `&`, `&amp;`, `und`, and a missing connector are treated
/// equally. Older app versions removed `&` while saving a selected template,
/// so this keeps those existing categories connected to their predefined
/// checkpoints.
String normalizeInspectionLabel(String? value) {
  var normalized = (value ?? '').trim().toLowerCase();
  normalized = normalized.replaceAll(
    RegExp(r'&amp;', caseSensitive: false),
    ' ',
  );
  normalized = normalized.replaceAll(RegExp(r'\s+(und)\s+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[&+]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9äöüß]+'), ' ');
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}
