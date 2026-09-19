import 'package:autobus/barrel.dart';

/// Shared back-button + title row for login / sign-up screens.
class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.fontWeight = FontWeight.w400,
  });

  final String title;
  final VoidCallback onBack;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              height: 35,
              width: 35,
              decoration: BoxDecoration(
                color: CustColors.mainCol,
                shape: BoxShape.circle,
                border: Border.all(color: CustColors.mainCol, width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 17.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: AppFitText(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 26,
                fontWeight: fontWeight,
              ),
            ),
          ),
          const SizedBox(width: 35),
        ],
      ),
    );
  }
}
