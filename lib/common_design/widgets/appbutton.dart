import 'package:autobus/barrel.dart';

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String buttonText;

  const AppButton({required this.buttonText, super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: CustColors.mainCol,
        minimumSize: Size(
          (MediaQuery.sizeOf(context).width * 0.72).clamp(200.0, 270.0),
          50,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
        ),
      ),
      onPressed: onPressed,
      child: AppFitText(
        buttonText,
        style: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
