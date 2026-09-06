import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class GooutsApp extends StatelessWidget {
  const GooutsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Goouts',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}