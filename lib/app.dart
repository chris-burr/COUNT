import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'state/providers.dart';
import 'ui/mac/mac_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/session_list_screen.dart';

class CountApp extends ConsumerWidget {
  const CountApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return MaterialApp(
      title: 'COUNT',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: isMac
          ? const MacShell()
          : appState.isLoading
              ? const _SplashScreen()
              : appState.isOnboarded
                  ? const SessionListScreen()
                  : const OnboardingScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
