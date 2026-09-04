import 'package:autobus/barrel.dart';

String businessDisplayName(Map<String, dynamic> item) {
  for (final key in ['company', 'fullname', 'email']) {
    final v = item[key]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return 'Business';
}

Map<String, dynamic> businessAsMap(dynamic item) {
  if (item is Map<String, dynamic>) return item;
  if (item is Map) return Map<String, dynamic>.from(item);
  return <String, dynamic>{};
}

void showBusinessSwitcher(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const BusinessSwitcherSheet(),
  );
}

class BusinessSwitcherSheet extends StatelessWidget {
  const BusinessSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError &&
                (state.source == 'switch_business' ||
                    state.source == 'create_business')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userFacingError(state.message)),
                  backgroundColor: Colors.red,
                ),
              );
            }
            if (state is Authenticated && state.lastBusinessOp == 'switched') {
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            final authed = state is Authenticated ? state : null;
            final items = authed?.businesses ?? const [];
            final activeId = authed?.activeBusinessId;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your businesses',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch without signing out. Each business keeps its own data.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = businessAsMap(items[index]);
                      final id = item['id']?.toString() ?? '';
                      final isActive = id.isNotEmpty && id == activeId;
                      final isManager = item['is_manager'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: CustColors.mainCol.withValues(alpha: 0.12),
                          child: Text(
                            businessDisplayName(item).substring(0, 1).toUpperCase(),
                            style: GoogleFonts.montserrat(
                              color: CustColors.mainCol,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          businessDisplayName(item),
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          [
                            item['email']?.toString() ?? '',
                            if (isManager) 'Primary login',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: GoogleFonts.montserrat(fontSize: 12),
                        ),
                        trailing: isActive
                            ? Icon(Icons.check_circle, color: CustColors.mainCol)
                            : const Icon(Icons.chevron_right, color: Colors.black38),
                        onTap: isActive || id.isEmpty
                            ? null
                            : () => context.read<AuthBloc>().add(
                                SwitchBusinessEvent(userId: id),
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: CustColors.mainCol,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                  title: Text(
                    'Add a business',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Create another account attached to this login',
                    style: GoogleFonts.montserrat(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateBusinessPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3F3F3),
                    child: Icon(Icons.settings_outlined, color: Colors.black54),
                  ),
                  title: Text(
                    'Manage businesses',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageBusinessesPage(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
