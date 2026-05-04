String dedupeAddress(String address) {
  final parts = address.split(' ').where((s) => s.isNotEmpty).toList();
  final result = <String>[];
  for (final part in parts) {
    if (result.isEmpty || result.last != part) result.add(part);
  }
  return result.join(' ');
}
