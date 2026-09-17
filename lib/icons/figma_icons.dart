import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icons exported from the linked Auto-Bus Figma file (NEW DESIGNS).
///
/// Source: https://www.figma.com/design/vDEDLxCPolEKtncF1Brucp/Auto-Bus?node-id=3229-10
class FigmaIcons {
  FigmaIcons._();

  static const figmaFileUrl =
      'https://www.figma.com/design/vDEDLxCPolEKtncF1Brucp/Auto-Bus';
  static const figmaNewDesignsUrl =
      'https://www.figma.com/design/vDEDLxCPolEKtncF1Brucp/Auto-Bus?node-id=3229-10';
  static const figmaFileKey = 'vDEDLxCPolEKtncF1Brucp';


  static const back = 'assets/icons/figma/back.svg';
  static const switchBusiness = 'assets/icons/figma/switch.svg';
  static const token = 'assets/icons/figma/token.svg';
  static const tokenOutline = 'assets/icons/figma/token_outline.svg';
  static const chevronDown = 'assets/icons/figma/chevron_down.svg';
  static const profile = 'assets/icons/figma/profile.svg';
  static const notification = 'assets/icons/figma/notification.svg';
  static const notificationBing = 'assets/icons/figma/notification_bing.svg';
  static const password = 'assets/icons/figma/password.svg';
  static const info = 'assets/icons/figma/info.svg';
  static const infoHeader = 'assets/icons/figma/info_header.svg';
  static const wechat = 'assets/icons/figma/wechat.svg';
  static const marketing = 'assets/icons/figma/marketing.svg';
  static const customers = 'assets/icons/figma/customers.svg';
  static const bag = 'assets/icons/figma/bag.svg';
  static const files = 'assets/icons/figma/files.svg';
  static const website = 'assets/icons/figma/website.svg';
  static const ai = 'assets/icons/figma/ai.svg';
  static const aiFab = 'assets/icons/figma/ai_fab.svg';
  static const aiMyAi = 'assets/icons/figma/ai_my_ai.svg';
  static const aiIntelligence = 'assets/icons/figma/ai_intelligence.svg';
  static const navHome = 'assets/icons/figma/nav_home.svg';
  static const navAnalytics = 'assets/icons/figma/nav_analytics.svg';
  static const addProfile = 'assets/icons/figma/add_profile.svg';
  static const contactBook = 'assets/icons/figma/contact_book.svg';
  static const addProduct = 'assets/icons/figma/add_product.svg';
  static const archive = 'assets/icons/figma/archive.svg';
  static const danger = 'assets/icons/figma/danger.svg';
  static const pending = 'assets/icons/figma/pending.svg';
  static const clipboard = 'assets/icons/figma/clipboard.svg';
  static const documents = 'assets/icons/figma/documents.svg';
  static const socialMedia = 'assets/icons/figma/social_media.svg';
  static const link = 'assets/icons/figma/link.svg';
  static const onlineAdvertising = 'assets/icons/figma/online_advertising.svg';
  static const liveChats = 'assets/icons/figma/live_chats.svg';
  static const allChats = 'assets/icons/figma/all_chats.svg';
  static const refresh = 'assets/icons/figma/refresh.svg';
  static const filter = 'assets/icons/figma/filter.svg';
  static const revenue = 'assets/icons/figma/revenue.svg';
  static const revenueSm = 'assets/icons/figma/revenue_sm.svg';
  static const invoice = 'assets/icons/figma/invoice.svg';
  static const cardboard = 'assets/icons/figma/cardboard.svg';
  static const chat = 'assets/icons/figma/chat.svg';
  static const messageSent = 'assets/icons/figma/message_sent.svg';
  static const sentMail = 'assets/icons/figma/sent_mail.svg';
  static const at = 'assets/icons/figma/at.svg';
  static const arrowDown = 'assets/icons/figma/arrow_down.svg';
  static const instagram = 'assets/icons/figma/instagram.svg';
  static const youtube = 'assets/icons/figma/youtube.svg';
  static const facebook = 'assets/icons/figma/facebook.svg';
  static const linkedin = 'assets/icons/figma/linkedin.svg';
  static const tiktok = 'assets/icons/figma/tiktok.svg';
}

class FigmaImages {
  FigmaImages._();

  static const onboardingHero = 'assets/img/figma/onboarding_hero.png';
  static const splashLogo = 'assets/img/figma/splash_logo.png';
  static const homeBanner = 'assets/img/figma/home_banner.png';
}

class FigmaSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final bool chevronRight;
  final bool chevronUp;

  const FigmaSvgIcon(
    this.asset, {
    super.key,
    required this.size,
    this.color,
    this.chevronRight = false,
    this.chevronUp = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
    if (chevronRight) {
      icon = Transform.rotate(angle: -1.5708, child: icon);
    } else if (chevronUp) {
      icon = Transform.rotate(angle: 3.14159, child: icon);
    }
    return icon;
  }
}

class FigmaBrandIcon extends StatelessWidget {
  final String? asset;
  final FaIconData fallback;
  final double size;
  final Color color;

  const FigmaBrandIcon({
    super.key,
    required this.fallback,
    required this.size,
    required this.color,
    this.asset,
  });

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return FigmaSvgIcon(asset!, size: size, color: color);
    }
    return FaIcon(fallback, size: size, color: color);
  }
}

class FigmaChevronTrail extends StatelessWidget {
  final double size;

  const FigmaChevronTrail({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FigmaSvgIcon(
          FigmaIcons.arrowDown,
          size: size,
          color: Colors.white,
          chevronRight: true,
        ),
        FigmaSvgIcon(
          FigmaIcons.arrowDown,
          size: size,
          color: Colors.white54,
          chevronRight: true,
        ),
        FigmaSvgIcon(
          FigmaIcons.arrowDown,
          size: size,
          color: Colors.white38,
          chevronRight: true,
        ),
      ],
    );
  }
}
