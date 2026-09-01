import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/subscription/buy_credits.dart';

const String kManageSubscriptionRouteName = 'ManageSubscription';

class ManageSubscriptionPage extends StatefulWidget {
  const ManageSubscriptionPage({super.key});

  @override
  State<ManageSubscriptionPage> createState() => _ManageSubscriptionPageState();
}

class _ManageSubscriptionPageState extends State<ManageSubscriptionPage> {
  String _userEmail = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final user = await context.read<ApiService>().getUserProfile();
      _userEmail = (user['email'] ?? user['user_email'] ?? '').toString();
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 244, 244, 244),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return BuyCreditsPage(userEmail: _userEmail);
  }
}
