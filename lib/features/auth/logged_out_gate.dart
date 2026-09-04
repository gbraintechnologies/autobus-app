import 'package:autobus/barrel.dart';

/// After logout, skip the welcome screen when we already know who signed in.
class LoggedOutGate extends StatefulWidget {
  const LoggedOutGate({super.key});

  @override
  State<LoggedOutGate> createState() => _LoggedOutGateState();
}

class _LoggedOutGateState extends State<LoggedOutGate> {
  String? _identifier;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final cached = LastLoginStore.peek();
    if (cached != null) {
      _identifier = cached;
      _ready = true;
      return;
    }
    LastLoginStore.read().then((id) {
      if (!mounted) return;
      setState(() {
        _identifier = id;
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
    if (_identifier != null && _identifier!.isNotEmpty) {
      return Signin(initialIdentifier: _identifier);
    }
    return const LogorSign();
  }
}
