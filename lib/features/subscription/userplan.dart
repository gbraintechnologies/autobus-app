// Unused named args are kept so Credits Top up / Renew callers still compile.
// ignore_for_file: unused_element

import 'package:autobus/features/subscription/buy_credits.dart';
import 'package:flutter/material.dart';

/// Legacy plan picker. Autobus now sells consumable credits.
class SelectPlan extends StatelessWidget {
  final String userEmail;
  final String? successPopUntilRouteName;

  const SelectPlan({
    required this.userEmail,
    bool upgradeFromActivePlan = false,
    double? minExclusivePlanPrice,
    this.successPopUntilRouteName,
    bool topUpStyle = false,
    bool renewStyle = false,
    String? remainingCreditsLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BuyCreditsPage(
      userEmail: userEmail,
      successPopUntilRouteName: successPopUntilRouteName,
    );
  }
}
