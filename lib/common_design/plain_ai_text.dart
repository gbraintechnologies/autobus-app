/// Strip markdown markers from LLM copy so it can be shown and published as
/// plain text (Instagram, WhatsApp, SMS, and in-app Text widgets).
String stripAiMarkdown(String? text) {
  if (text == null || text.isEmpty) return '';

  var response = text;
  response = response.replaceAllMapped(
    RegExp(r'```(?:\w+)?\s*\n?(.*?)```', dotAll: true),
    (m) => m.group(1) ?? '',
  );
  response = response.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (m) => m.group(1) ?? '',
  );
  response = response.replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) {
    final inner = m.group(1) ?? '';
    if (inner.startsWith(' ') || inner.endsWith(' ')) return '*$inner*';
    return inner;
  });
  response = response.replaceAllMapped(
    RegExp(r'^#{1,6}\s+', multiLine: true),
    (_) => '',
  );
  response = response.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (m) => m.group(1) ?? '',
  );
  response = response.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (m) => m.group(1) ?? '',
  );
  return response.replaceAll('**', '').trim();
}
