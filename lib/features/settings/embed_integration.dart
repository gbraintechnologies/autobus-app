import 'package:autobus/barrel.dart';
import 'package:flutter/services.dart';

class EmbedIntegrationPage extends StatefulWidget {
  const EmbedIntegrationPage({super.key});

  @override
  State<EmbedIntegrationPage> createState() => _EmbedIntegrationPageState();
}

class _EmbedIntegrationPageState extends State<EmbedIntegrationPage> {
  final _webhook = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _handoff = true;
  String _catalogMode = 'managed';
  String _keyPrefix = '';
  String _webhookSecret = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _webhook.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().getEmbedSettings();
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _handoff = data['handoff_enabled'] != false;
        _catalogMode = (data['catalog_mode'] ?? 'managed').toString();
        _keyPrefix = (data['api_key_prefix'] ?? '').toString();
        _webhookSecret = (data['webhook_secret'] ?? '').toString();
        _webhook.text = (data['webhook_url'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e.toString()))),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = await context.read<ApiService>().saveEmbedSettings({
        'enabled': _enabled,
        'webhook_url': _webhook.text.trim(),
        'catalog_mode': _catalogMode,
        'handoff_enabled': _handoff,
      });
      if (!mounted) return;
      setState(() {
        _webhookSecret = (data['webhook_secret'] ?? _webhookSecret).toString();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Embedded chat settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e.toString()))),
      );
    }
  }

  Future<void> _rotateKey() async {
    try {
      final data = await context.read<ApiService>().rotateEmbedKey();
      final key = (data['api_key'] ?? '').toString();
      if (!mounted) return;
      setState(() => _keyPrefix = (data['api_key_prefix'] ?? '').toString());
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API key'),
          content: SelectableText(key.isEmpty ? 'No key returned' : key),
          actions: [
            TextButton(
              onPressed: key.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: key));
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text('Embedded chat', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Let another application send customer messages to this business. Autobus replies from the catalog and places the order.',
                  style: GoogleFonts.montserrat(fontSize: 13, height: 1.4, color: Colors.black54),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accept embedded messages'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow handoff to a person'),
                  value: _handoff,
                  onChanged: (v) => setState(() => _handoff = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _catalogMode,
                  decoration: const InputDecoration(labelText: 'Catalog'),
                  items: const [
                    DropdownMenuItem(value: 'managed', child: Text('Managed in Autobus')),
                    DropdownMenuItem(value: 'synced', child: Text('Synced from their software')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _catalogMode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _webhook,
                  decoration: const InputDecoration(
                    labelText: 'Webhook URL',
                    hintText: 'https://example.com/autobus/events',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _keyPrefix.isEmpty ? 'No API key yet' : 'Key prefix $_keyPrefix',
                  style: GoogleFonts.montserrat(fontSize: 13),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _rotateKey, child: const Text('Issue API key')),
                if (_webhookSecret.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Webhook secret', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SelectableText(_webhookSecret, style: GoogleFonts.montserrat(fontSize: 12)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
    );
  }
}
