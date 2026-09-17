import 'package:autobus/barrel.dart';

import 'package:autobus/common_design/light_screen_theme.dart';

import 'package:autobus/common_design/widgets/app_bottom_nav.dart';

import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

import 'package:autobus/icons/home_figma_icons.dart';



enum _MarketingType { pictures, videos, text }



class DigitalMarketingSelection extends StatefulWidget {

  const DigitalMarketingSelection({super.key});



  @override

  State<DigitalMarketingSelection> createState() =>

      _DigitalMarketingSelectionState();

}



class _DigitalMarketingSelectionState extends State<DigitalMarketingSelection> {

  final Set<_MarketingType> _selected = <_MarketingType>{};



  static const _green = Color(0xFF22C55E);



  MarketingContentType _mapType(_MarketingType type) {

    switch (type) {

      case _MarketingType.pictures:

        return MarketingContentType.pictures;

      case _MarketingType.videos:

        return MarketingContentType.videos;

      case _MarketingType.text:

        return MarketingContentType.text;

    }

  }



  void _toggle(_MarketingType type) {

    setState(() {

      if (_selected.contains(type)) {

        _selected.remove(type);

      } else {

        _selected.add(type);

      }

    });

  }



  void _onGetStarted() {

    if (_selected.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Please select a content type',

            style: GoogleFonts.poppins(),

          ),

        ),

      );

      return;

    }



    Navigator.of(context).push<void>(

      MaterialPageRoute<void>(

        builder: (_) => DigitalMarketingPage(

          initialSelected: _selected.map(_mapType).toSet(),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;



    return LightScreenScaffold(

      title: 'Digital Marketing',

      creditCategory: CreditCategory.imageGen,

      body: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Expanded(

            child: SingleChildScrollView(

              padding: EdgeInsets.fromLTRB(

                20 * scale,

                20 * scale,

                20 * scale,

                16 * scale,

              ),

              child: Column(

                children: [

                  Text(

                    'What are you creating?',

                    textAlign: TextAlign.center,

                    style: LightScreenTheme.hubTitle(scale).copyWith(

                      fontSize: 18,

                    ),

                  ),

                  SizedBox(height: 8 * scale),

                  Text(

                    'Tap one or more content types to include in this campaign.',

                    textAlign: TextAlign.center,

                    style: LightScreenTheme.hubBody(scale).copyWith(

                      fontSize: 13,

                      color: LightScreenTheme.muted,

                    ),

                  ),

                  SizedBox(height: 28 * scale),

                  _ContentTypeCard(

                    scale: scale,

                    label: 'Pictures',

                    hint: 'Stills & carousels',

                    icon: HomeFigmaIcons.marketingPictures,

                    iconGradient: HomeFigmaIcons.marketingPicturesGradient,

                    selected: _selected.contains(_MarketingType.pictures),

                    onTap: () => _toggle(_MarketingType.pictures),

                  ),

                  SizedBox(height: 12 * scale),

                  _ContentTypeCard(

                    scale: scale,

                    label: 'Videos',

                    hint: 'Clips & reels',

                    icon: HomeFigmaIcons.marketingVideos,

                    iconGradient: HomeFigmaIcons.marketingVideosGradient,

                    selected: _selected.contains(_MarketingType.videos),

                    onTap: () => _toggle(_MarketingType.videos),

                  ),

                  SizedBox(height: 12 * scale),

                  _ContentTypeCard(

                    scale: scale,

                    label: 'Text',

                    hint: 'Captions & copy',

                    icon: HomeFigmaIcons.marketingText,

                    iconGradient: HomeFigmaIcons.marketingTextGradient,

                    selected: _selected.contains(_MarketingType.text),

                    onTap: () => _toggle(_MarketingType.text),

                  ),

                  if (_selected.isNotEmpty) ...[

                    SizedBox(height: 24 * scale),

                    Wrap(

                      spacing: 8 * scale,

                      runSpacing: 8 * scale,

                      alignment: WrapAlignment.center,

                      children: [

                        for (final t in _MarketingType.values)

                          if (_selected.contains(t))

                            Container(

                              padding: EdgeInsets.symmetric(

                                horizontal: 12 * scale,

                                vertical: 6 * scale,

                              ),

                              decoration: BoxDecoration(

                                color: _green.withValues(alpha: 0.12),

                                borderRadius: BorderRadius.circular(20 * scale),

                                border: Border.all(

                                  color: _green.withValues(alpha: 0.55),

                                ),

                              ),

                              child: Row(

                                mainAxisSize: MainAxisSize.min,

                                children: [

                                  HomeSfIcon(

                                    icon: t == _MarketingType.pictures

                                        ? HomeFigmaIcons.marketingPictures

                                        : t == _MarketingType.videos

                                            ? HomeFigmaIcons.marketingVideos

                                            : HomeFigmaIcons.marketingText,

                                    size: 14 * scale.clamp(0.9, 1.05),

                                    color: _green,

                                  ),

                                  SizedBox(width: 6 * scale),

                                  Text(

                                    t == _MarketingType.pictures

                                        ? 'Pictures'

                                        : t == _MarketingType.videos

                                            ? 'Videos'

                                            : 'Text',

                                    style: GoogleFonts.poppins(

                                      color: _green,

                                      fontSize: 11,

                                      fontWeight: FontWeight.w600,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                      ],

                    ),

                  ],

                ],

              ),

            ),

          ),

          Padding(

            padding: EdgeInsets.fromLTRB(

              35 * scale,

              0,

              35 * scale,

              24 * scale + bottomInset,

            ),

            child: SizedBox(

              height: 56 * scale.clamp(0.9, 1.05),

              child: FilledButton(

                onPressed: _onGetStarted,

                style: FilledButton.styleFrom(

                  backgroundColor: LightScreenTheme.button,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(30 * scale),

                  ),

                ),

                child: Row(

                  mainAxisAlignment: MainAxisAlignment.center,

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      'Continue',

                      style: GoogleFonts.poppins(

                        color: Colors.white,

                        fontSize: 16,

                        fontWeight: FontWeight.w500,

                      ),

                    ),

                    SizedBox(width: 10 * scale),

                    HomeSfIcon(

                      icon: HomeFigmaIcons.arrowForward,

                      color: Colors.white,

                      size: 18 * scale.clamp(0.9, 1.05),

                    ),

                  ],

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class _ContentTypeCard extends StatelessWidget {

  final double scale;

  final String label;

  final String hint;

  final IconData icon;

  final Gradient iconGradient;

  final bool selected;

  final VoidCallback onTap;



  static const _green = Color(0xFF22C55E);



  const _ContentTypeCard({

    required this.scale,

    required this.label,

    required this.hint,

    required this.icon,

    required this.iconGradient,

    required this.selected,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Material(

      color: LightScreenTheme.surface,

      borderRadius: BorderRadius.circular(20 * scale),

      clipBehavior: Clip.antiAlias,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20 * scale),

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 180),

          curve: Curves.easeOut,

          padding: EdgeInsets.all(16 * scale),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(20 * scale),

            border: Border.all(

              color: selected ? _green : LightScreenTheme.border,

              width: selected ? 2 : 1,

            ),

          ),

          child: Row(

            children: [

              Container(

                width: 48 * scale,

                height: 48 * scale,

                decoration: BoxDecoration(

                  gradient: iconGradient,

                  borderRadius: BorderRadius.circular(14 * scale),

                ),

                alignment: Alignment.center,

                child: HomeSfIcon(

                  icon: icon,

                  size: 22 * scale.clamp(0.9, 1.05),

                  color: Colors.white,

                ),

              ),

              SizedBox(width: 14 * scale),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(label, style: LightScreenTheme.listTitle(scale)),

                    SizedBox(height: 4 * scale),

                    Text(hint, style: LightScreenTheme.listSubtitle(scale)),

                  ],

                ),

              ),

              AnimatedOpacity(

                duration: const Duration(milliseconds: 180),

                opacity: selected ? 1 : 0,

                child: HomeSfIcon(

                  icon: HomeFigmaIcons.check,

                  color: _green,

                  size: 24 * scale.clamp(0.9, 1.05),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


