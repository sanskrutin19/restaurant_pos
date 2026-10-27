import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'providers.dart';
import 'core/pos_theme.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/guest_menu_screen.dart';
import 'screens/license_activation_screen.dart';
import 'services/printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cross-platform Hive initialization
  await Hive.initFlutter();
  
  await Hive.openBox('settings');
  await Hive.openBox('menu_cache');
  await Hive.openBox('pending_orders');

  runApp(
    const ProviderScope(
      child: RestaurantPOSApp(),
    ),
  );
}

class RestaurantPOSApp extends ConsumerWidget {
  const RestaurantPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider);
    final license = ref.watch(licenseProvider);

    // Initialize services with ApiClient
    PrinterService().init(ref.read(apiClientProvider));

    return MaterialApp(
      title: 'Servezy',
      debugShowCheckedModeBanner: false,
      theme: POSTheme.light(),
      darkTheme: POSTheme.dark(),
      themeMode: ThemeMode.light,
      home: license.when(
        data: (status) {
          if (status['is_active'] == true) {
            return authUser == null ? const LoginScreen() : const AppShell();
          } else {
            return LicenseActivationScreen(machineId: status['machine_id'] ?? 'Unknown');
          }
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Cannot connect to local server.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => ref.read(licenseProvider.notifier).checkLicense(),
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/guest-order')) {
          final uri = Uri.parse(settings.name!);
          final tableId = int.tryParse(uri.queryParameters['table'] ?? '1') ?? 1;
          return MaterialPageRoute(
            builder: (_) => GuestMenuScreen(tableId: tableId),
          );
        }
        return null;
      },
    );
  }
}