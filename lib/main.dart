import 'package:autobus/barrel.dart';

// Initialize services at app level
late TokenService _tokenService;
late SessionAwareHttpClient _httpClient;
late ApiService _apiService;
late PaystackService _paystackService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('=== APP STARTING ===');

  // Initialize environment variables
  await AppConfig.init();
  print('✓ AppConfig initialized');

  // Don't block first frame on font CDN or StoreKit/Keychain.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.montserrat(),
    ]).timeout(const Duration(seconds: 2));
    print('✓ Google Fonts loaded');
  } catch (_) {
    print('⚠ Google Fonts timed out; using fallback');
  }

  // Initialize session handling services
  _tokenService = TokenService();
  _httpClient = SessionAwareHttpClient(
    tokenService: _tokenService,
    baseUrl: AppConfig.backendUrl,
  );
  _apiService = ApiService(httpClient: _httpClient);

  _paystackService = PaystackService();
  print('✓ Services initialized');

  // Create blocs
  final successBloc = SuccessBloc();
  final authBloc = AuthBloc(
    tokenService: _tokenService,
    successBloc: successBloc,
  );
  _httpClient.onSessionExpired = () {
    final state = authBloc.state;
    if (state is Authenticated ||
        state is TokenRefreshed ||
        state is TokenRefreshing) {
      authBloc.add(const SessionExpiredEvent());
    }
  };
  print('✓ BLoCs created');

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiService>(create: (context) => _apiService),
        RepositoryProvider<PaystackService>(
          create: (context) => _paystackService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc..add(CheckSessionEvent())),
          BlocProvider.value(value: successBloc),
          BlocProvider(create: (context) => AssistantBloc()),
          BlocProvider(create: (context) => ThemeBloc()),
        ],
        child: MyApp(httpClient: _httpClient),
      ),
    ),
  );
  if (AppleIapIds.isSupported) {
    unawaited(AppleIapService.instance.start(api: _apiService));
  }
  print('=== APP INITIALIZED ===');
}

//Getters
SessionAwareHttpClient get appHttpClient => _httpClient;
ApiService get apiService => _apiService;
TokenService get tokenService => _tokenService;
PaystackService get paystackService => _paystackService;

class MyApp extends StatelessWidget {
  final SessionAwareHttpClient httpClient;

  const MyApp({required this.httpClient, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          scaffoldMessengerKey: NavigationService.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Autobus',
          theme: state.themeData,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: AppScale.textScalerOf(context),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashWrapper(),
        );
      },
    );
  }
}
