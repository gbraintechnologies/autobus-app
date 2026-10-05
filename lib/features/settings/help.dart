import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@starfoods.com',
      query: 'subject=Help Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://starfoods.com/help');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Help & Support',
      creditCategory: CreditCategory.server,
      body: SingleChildScrollView(
        padding: LightScreenTheme.listPagePadding(scale),
        child: LightListCard(
          scale: scale,
          padding: EdgeInsets.symmetric(vertical: 4 * scale),
          child: Column(
            children: [
              ListTile(
                onTap: _launchEmail,
                contentPadding: EdgeInsets.symmetric(horizontal: 8 * scale),
                leading: HomeSfIcon(
                  icon: HomeFigmaIcons.inbox,
                  color: Colors.black87,
                  size: 22 * scale,
                ),
                title: Text('Email Support', style: LightScreenTheme.listTitle(scale)),
                subtitle: Text(
                  'support@useautobus.com',
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
              ListTile(
                onTap: _launchWebsite,
                contentPadding: EdgeInsets.symmetric(horizontal: 8 * scale),
                leading: HomeSfIcon(
                  icon: HomeFigmaIcons.website,
                  color: Colors.black87,
                  size: 22 * scale,
                ),
                title: Text('Our Website', style: LightScreenTheme.listTitle(scale)),
                subtitle: Text(
                  'www.useautobus.com',
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
