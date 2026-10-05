import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';

class ThemeBloc extends Cubit<ThemeState> {
  ThemeBloc() : super(ThemeState(_defaultTheme()));

  static ThemeData _defaultTheme() {
    final poppins = GoogleFonts.poppins();
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7F03B9),
        brightness: Brightness.light,
      ),
      fontFamily: poppins.fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(),
      scaffoldBackgroundColor: LightScreenTheme.background,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        systemOverlayStyle: AppSystemUi.light,
      ),
    );
  }

  void changeFontFamily(String fontFamily) {
    emit(ThemeState(_defaultTheme()));
  }
}
