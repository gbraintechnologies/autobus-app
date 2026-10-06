import 'package:autobus/barrel.dart';

/// After session loss, skip the welcome/login form when this device already
/// has a remembered account. Explicit sign-out clears that and shows sign-in.
/// The marketing splash is not on this path, so it cannot be opened again.
class LoggedOutGate extends StatefulWidget {
  const LoggedOutGate({super.key});

  @override
  State<LoggedOutGate> createState() => _LoggedOutGateState();
}

class _LoggedOutGateState extends State<LoggedOutGate> {
  LastLoginIdentity? _identity;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final cached = LastLoginStore.peekIdentity();
    if (cached != null) {
      _identity = cached;
      _ready = true;
      LastLoginStore.readIdentity().then((id) {
        if (!mounted || id == null) return;
        if (id.displayName != _identity?.displayName) {
          setState(() => _identity = id);
        }
      });
      return;
    }
    LastLoginStore.readIdentity().then((id) {
      if (!mounted) return;
      setState(() {
        _identity = id;
        _ready = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: AutobusLoadingIndicator()),
      );
    }
    final identity = _identity;
    if (identity != null && identity.identifier.isNotEmpty) {
      return PinUnlockPage(
        identifier: identity.identifier,
        displayName: identity.displayName,
        onUseAnotherAccount: () {
          setState(() => _identity = null);
        },
      );
    }
    return const Signin();
  }
}
