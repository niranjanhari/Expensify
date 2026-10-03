import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpensifyApp());
}

class ExpensifyApp extends StatelessWidget {
  const ExpensifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Expensify',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}

