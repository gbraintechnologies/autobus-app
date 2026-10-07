import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class ManageMarketing extends StatelessWidget {
  const ManageMarketing({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage Marketing',
      creditCategory: CreditCategory.imageGen,
      body: SingleChildScrollView(
        padding: LightScreenTheme.hubPagePadding(scale),
        child: Column(
          children: [
            Text(
              'Welcome to Marketing',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubTitle(scale),
            ),
            SizedBox(height: LightScreenTheme.hubTitleGap * scale),
            Text(
              'Create campaigns, link your outlets, and publish marketing content from Autobus.',
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
                  title: 'Create campaigns',
                  subtitle: 'Start creating',
                  icon: HomeFigmaIcons.createCampaign,
                  iconGradient: HomeFigmaIcons.liveChatsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const DigitalMarketingPage(),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'Link Social Media',
                  subtitle: 'Connect socials',
                  icon: HomeFigmaIcons.linkSocial,
                  iconGradient: HomeFigmaIcons.linkChannelGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ManageOutlets(),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'Recent Campaigns',
                  subtitle: 'View campaigns',
                  icon: HomeFigmaIcons.recentCampaigns,
                  iconGradient: HomeFigmaIcons.allChatsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const RecentCampaignsPage(),
                      ),
                    );
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'Recent posts',
                  subtitle: 'Published posts',
                  icon: HomeFigmaIcons.recentCampaigns,
                  iconGradient: HomeFigmaIcons.liveChatsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const RecentPostsPage(),
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
