import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class ManageOrders extends StatelessWidget {
  const ManageOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage Orders',
      creditCategory: CreditCategory.server,
      body: SingleChildScrollView(
        padding: LightScreenTheme.hubPagePadding(scale),
        child: Column(
          children: [
            Text(
              'Welcome to Orders',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubTitle(scale),
            ),
            SizedBox(height: LightScreenTheme.hubTitleGap * scale),
            Text(
              'Track pending work, completed orders, and your full order history.',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubBody(scale).copyWith(
                color: const Color(0xFF4E4E4E),
              ),
            ),
            SizedBox(height: LightScreenTheme.hubToCards * scale),
            LightHubGrid(
              scale: scale,
              children: [
                LightHubCard(
                  scale: scale,
                  title: 'Pending Orders',
                  subtitle: 'Start creating',
                  icon: HomeFigmaIcons.pendingOrders,
                  iconGradient: HomeFigmaIcons.pendingOrdersGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ActiveQueries(),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'Completed Orders',
                  subtitle: 'Connect socials',
                  icon: HomeFigmaIcons.completedOrders,
                  iconGradient: HomeFigmaIcons.completedOrdersGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AllOrdersHistory(
                          orderStatus: 'completed',
                          title: 'Completed Orders',
                          emptyMessage: 'No completed orders',
                        ),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'All orders',
                  subtitle: 'View campaigns',
                  icon: HomeFigmaIcons.allOrders,
                  iconGradient: HomeFigmaIcons.allOrdersGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AllOrdersHistory(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
