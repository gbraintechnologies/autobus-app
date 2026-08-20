import 'package:autobus/barrel.dart';
import 'package:autobus/features/integrations/webview_url_resolver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens Postiz or Chatwoot using credentials returned by the Autobus API,
/// then navigates to [PlatformEmbedSession.authorizationUrl] to link channels.
class EmbeddedPlatformWebView extends StatefulWidget {
  final String title;
  final PlatformEmbedSession session;

  const EmbeddedPlatformWebView({
    super.key,
    required this.title,
    required this.session,
  });

  @override
  State<EmbeddedPlatformWebView> createState() => _EmbeddedPlatformWebViewState();
}

class _EmbeddedPlatformWebViewState extends State<EmbeddedPlatformWebView> {
  late final WebViewController _controller;
  var _loading = true;
  var _loginStepDone = false;
  String? _error;

  PlatformEmbedSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _loading = false);
            if (_loginStepDone) return;
            if (_session.isChatwoot) {
              await _tryChatwootFormSubmit();
            } else if (_session.isPostiz) {
              await _tryPostizApiLogin();
            }
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = err.description;
            });
          },
        ),
      );
    _startLoginFlow();
  }

  Future<void> _startLoginFlow() async {
    final auth = resolveEmbeddedPlatformUrl(_session.authorizationUrl.trim());
    if (auth.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing authorization URL from server.';
      });
      return;
    }

    // Direct provider OAuth (e.g. Facebook via Postiz Public API) — skip Postiz UI.
    if (_session.directOauth) {
      await _controller.loadRequest(Uri.parse(auth));
      _loginStepDone = true;
      return;
    }

    if (_session.isPostiz) {
      final pageUrl = resolveEmbeddedPlatformUrl(
        _session.postizLoginPageUrl!.trim(),
      );
      await _controller.loadRequest(Uri.parse(pageUrl));
      return;
    }

    if (_session.isChatwoot) {
      final pageUrl = resolveEmbeddedPlatformUrl(
        _session.chatwootLoginPageUrl!.trim(),
      );
      await _controller.loadRequest(Uri.parse(pageUrl));
      return;
    }

    await _controller.loadRequest(Uri.parse(auth));
    _loginStepDone = true;
  }

  Future<void> _tryPostizApiLogin() async {
    final body = _session.postizLoginBody;
    if (body == null) {
      _loginStepDone = true;
      await _openAuthorizationPage();
      return;
    }
    final email = (body['email'] ?? '').toString();
    final password = (body['password'] ?? '').toString();
    final provider = (body['provider'] ?? 'LOCAL').toString();
    final providerToken = (body['providerToken'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) {
      _loginStepDone = true;
      await _openAuthorizationPage();
      return;
    }

    // Kick off login; poll a window flag because async JS promises are not
    // reliably returned from runJavaScriptReturningResult.
    final startScript =
        '''
window.__postizLoginDone = false;
window.__postizLoginResult = null;
fetch('/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({
    email: ${jsonEncode(email)},
    password: ${jsonEncode(password)},
    provider: ${jsonEncode(provider)},
    providerToken: ${jsonEncode(providerToken)}
  })
}).then(function(res) {
  window.__postizLoginResult = res.ok ? 'ok' : ('fail:' + res.status);
}).catch(function() {
  window.__postizLoginResult = 'error';
}).finally(function() {
  window.__postizLoginDone = true;
});
''';
    try {
      await _controller.runJavaScript(startScript);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final done = await _controller.runJavaScriptReturningResult(
          'window.__postizLoginDone === true',
        );
        if (done.toString().contains('true')) break;
      }
    } catch (_) {
      // Fall through to authorization URL even if login script fails.
    }
    _loginStepDone = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _openAuthorizationPage();
  }

  Future<void> _tryChatwootFormSubmit() async {
    final body = _session.chatwootLoginBody;
    if (body == null) return;
    final email = (body['email'] ?? '').toString();
    final password = (body['password'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) return;

    final script =
        '''
(function() {
  var email = ${jsonEncode(email)};
  var password = ${jsonEncode(password)};
  var emailInput = document.querySelector('input[type="email"], input[name="email"], #email');
  var passInput = document.querySelector('input[type="password"], input[name="password"], #password');
  if (!emailInput || !passInput) return 'no_form';
  emailInput.value = email;
  emailInput.dispatchEvent(new Event('input', { bubbles: true }));
  passInput.value = password;
  passInput.dispatchEvent(new Event('input', { bubbles: true }));
  var form = emailInput.closest('form');
  if (form) { form.submit(); return 'submitted'; }
  var btn = document.querySelector('button[type="submit"], input[type="submit"]');
  if (btn) { btn.click(); return 'clicked'; }
  return 'no_submit';
})();
''';
    try {
      final result = await _controller.runJavaScriptReturningResult(script);
      final s = result.toString();
      if (s.contains('submitted') || s.contains('clicked')) {
        _loginStepDone = true;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final auth = resolveEmbeddedPlatformUrl(
          _session.authorizationUrl.trim(),
        );
        if (auth.isNotEmpty) {
          await _controller.loadRequest(Uri.parse(auth));
        }
      }
    } catch (_) {}
  }

  Future<void> _openAuthorizationPage() async {
    final auth = resolveEmbeddedPlatformUrl(_session.authorizationUrl.trim());
    if (auth.isNotEmpty) {
      await _controller.loadRequest(Uri.parse(auth));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _openAuthorizationPage,
            child: Text(
              'Continue',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: AutobusLoadingIndicator(size: 32)),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: GoogleFonts.montserrat(
                      color: Colors.red.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens provider OAuth / Meta signup in the device browser.
/// In-app WebViews are blocked by Facebook, Instagram, TikTok, and Google.
Future<void> openPlatformConnectInBrowser(
  BuildContext context, {
  required String label,
  required Future<PlatformEmbedSession> Function() fetchSession,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final session = await fetchSession();
    if (!context.mounted) return;
    final raw = session.authorizationUrl.trim().isNotEmpty
        ? session.authorizationUrl.trim()
        : (session.postizLoginPageUrl ?? '').trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Server did not return a valid $label link.'),
        ),
      );
      return;
    }
    var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the $label signup page.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Finish $label signup in your browser. We will return you to the app when it completes.',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

/// Fetches a Postiz or Chatwoot embed session and opens the WebView.
Future<void> openEmbeddedPlatformSession(
  BuildContext context, {
  required String title,
  required Future<PlatformEmbedSession> Function() fetchSession,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final session = await fetchSession();
    if (!context.mounted) return;
    if (session.authorizationUrl.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Server did not return a link URL.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmbeddedPlatformWebView(title: title, session: session),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}
