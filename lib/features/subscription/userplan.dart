import 'package:autobus/features/subscription/buy_credits.dart';
import 'package:flutter/material.dart';

/// Legacy plan picker. Autobus now sells consumable credits.
class SelectPlan extends StatelessWidget {
  final String userEmail;
  final bool upgradeFromActivePlan;
  final double? minExclusivePlanPrice;
  final String? successPopUntilRouteName;

  const SelectPlan({
    required this.userEmail,
    this.upgradeFromActivePlan = false,
    this.minExclusivePlanPrice,
    this.successPopUntilRouteName,
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
