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
  var _closing = false;
  String? _error;

  PlatformEmbedSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (isPlatformConnectReturnUrl(request.url)) {
              _closeSheet();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _loading = true);
            if (isPlatformConnectReturnUrl(url)) {
              _closeSheet();
            }
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _loading = false);
            if (isPlatformConnectReturnUrl(url)) {
              _closeSheet();
              return;
            }
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

  void _closeSheet() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.4,
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: _closeSheet,
            icon: const Icon(Icons.close, size: 26),
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
                    style: GoogleFonts.poppins(
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

bool isPlatformConnectReturnUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'autobus' || scheme == 'intent';
}

Future<void> _pushConnectWebView(
  BuildContext context, {
  required String title,
  required PlatformEmbedSession session,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EmbeddedPlatformWebView(title: title, session: session),
    ),
  );
}

/// Opens provider OAuth in a lightweight in-app browser (Safari View /
/// Chrome Custom Tabs) with an X close button — not Chrome/Safari itself.
///
/// Returns `true` when the user has already closed the connect UI (our
/// sheet). Returns `false` when a system in-app browser is still open and
/// the caller should refresh on app resume.
Future<bool> openPlatformConnectInBrowser(
  BuildContext context, {
  required String label,
  required Future<PlatformEmbedSession> Function() fetchSession,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final session = await fetchSession();
    if (!context.mounted) return true;
    final raw = session.authorizationUrl.trim().isNotEmpty
        ? session.authorizationUrl.trim()
        : (session.postizLoginPageUrl ?? '').trim();
    final resolved = resolveEmbeddedPlatformUrl(raw);
    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Server did not return a valid $label link.'),
        ),
      );
      return true;
    }

    // Chatwoot / Postiz login need JS in our sheet. OAuth providers go through
    // Safari View / Custom Tabs so Facebook, Instagram, Google, and TikTok
    // do not block the session.
    if (session.isChatwoot || session.isPostiz) {
      await _pushConnectWebView(context, title: label, session: session);
      return true;
    }

    var ok = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
      browserConfiguration: const BrowserConfiguration(showTitle: true),
    );
    if (!ok) {
      ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
    if (!ok && context.mounted) {
      await _pushConnectWebView(context, title: label, session: session);
      return true;
    }
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the $label signup page.')),
      );
      return true;
    }
    return false;
  } catch (e) {
    if (!context.mounted) return true;
    messenger.showSnackBar(
      SnackBar(content: Text(userFacingError(e))),
    );
    return true;
  }
}

/// Fetches a Postiz or Chatwoot embed session and opens the in-app sheet.
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
    await _pushConnectWebView(context, title: title, session: session);
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(userFacingError(e))),
    );
  }
}
