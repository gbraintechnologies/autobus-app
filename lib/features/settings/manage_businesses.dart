import 'package:autobus/barrel.dart';

class ManageBusinessesPage extends StatefulWidget {
  const ManageBusinessesPage({super.key});

  @override
  State<ManageBusinessesPage> createState() => _ManageBusinessesPageState();
}

class _ManageBusinessesPageState extends State<ManageBusinessesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(const LoadBusinessesEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError &&
            (state.source == 'switch_business' ||
                state.source == 'create_business' ||
                state.source == 'detach_business')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingError(state.message)),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state is Authenticated && state.lastBusinessOp == 'detached') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business detached. It can now be signed into separately.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthPageHeader(
                  title: 'Businesses',
                  fontWeight: FontWeight.w300,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                Text(
                  'One login can manage several businesses. Detach a business by setting a password for its email — then it can be signed into on its own.',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final authed = state is Authenticated ? state : null;
                      final items = authed?.businesses ?? const [];
                      final activeId = authed?.activeBusinessId;
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'No businesses loaded yet.',
                            style: GoogleFonts.montserrat(color: Colors.black54),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = businessAsMap(items[index]);
                          final id = item['id']?.toString() ?? '';
                          final isActive = id == activeId;
                          final isManager = item['is_manager'] == true;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
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
                                if (isActive) 'Current',
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: GoogleFonts.montserrat(fontSize: 12),
                            ),
                            trailing: isManager
                                ? null
                                : TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetachBusinessPage(
                                            businessId: id,
                                            email: item['email']?.toString() ?? '',
                                            name: businessDisplayName(item),
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Detach'),
                                  ),
                            onTap: isActive || id.isEmpty
                                ? null
                                : () {
                                    final bloc = context.read<AuthBloc>();
                                    final name = businessDisplayName(item);
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).popUntil((route) => route.isFirst);
                                    bloc.add(
                                      SwitchBusinessEvent(
                                        userId: id,
                                        displayName: name,
                                      ),
                                    );
                                  },
                          );
                        },
                      );
                    },
                  ),
                ),
                Center(
                  child: AppButton(
                    buttonText: 'Add a business',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateBusinessPage(),
                        ),
                      );
                    },
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
