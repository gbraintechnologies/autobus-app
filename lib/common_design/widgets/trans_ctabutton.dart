import 'package:autobus/barrel.dart';

class TransparentCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const TransparentCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: 51,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Expanded(
              child: AppFitText(
                label,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 18),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }
}
