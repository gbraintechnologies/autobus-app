import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/settings/delete_account.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class Security extends StatelessWidget {
  const Security({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    final List<SecurityMenuItem> menuItems = [
      SecurityMenuItem("Change Password", HomeFigmaIcons.lock, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecoverAccount()),
        );
      }),
      SecurityMenuItem("2FA", HomeFigmaIcons.twoFactor, () {}),
      SecurityMenuItem("Delete Account", HomeFigmaIcons.delete, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
        );
      }),
    ];

    return LightScreenScaffold(
      title: 'Password & Security',
      creditCategory: CreditCategory.server,
      body: SingleChildScrollView(
        padding: LightScreenTheme.listPagePadding(scale),
        child: LightListCard(
          scale: scale,
          padding: EdgeInsets.symmetric(vertical: 4 * scale),
          child: Column(
            children: menuItems
                .map(
                  (item) => _SecurityMenuTile(scale: scale, item: item),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _SecurityMenuTile extends StatelessWidget {
  final double scale;
  final SecurityMenuItem item;

  const _SecurityMenuTile({required this.scale, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 8 * scale),
      leading: HomeSfIcon(
        icon: item.icon,
        color: Colors.black87,
        size: 22 * scale,
      ),
      title: Text(item.title, style: LightScreenTheme.listTitle(scale)),
      trailing: HomeSfIcon(
        icon: HomeFigmaIcons.chevronRight,
        color: LightScreenTheme.muted,
        size: 20 * scale,
      ),
    );
  }
}

class SecurityMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  SecurityMenuItem(this.title, this.icon, this.onTap);
}
