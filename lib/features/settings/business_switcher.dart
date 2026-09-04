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
                            : () {
                                final bloc = context.read<AuthBloc>();
                                final name = businessDisplayName(item);
                                Navigator.pop(context);
                                bloc.add(
                                  SwitchBusinessEvent(
                                    userId: id,
                                    displayName: name,
                                  ),
                                );
                              },
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

class BusinessSwitchScrim extends StatelessWidget {
  const BusinessSwitchScrim({super.key, this.displayName = ''});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim();
    return AbsorbPointer(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AutobusLoadingIndicator(size: 56),
                const SizedBox(height: 18),
                Text(
                  'Switching business',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.isEmpty ? 'Loading this account…' : 'Opening $name',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
