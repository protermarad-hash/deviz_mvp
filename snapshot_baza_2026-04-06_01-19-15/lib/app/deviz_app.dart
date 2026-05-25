import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../ui/home_page.dart';

class DevizProApp extends StatelessWidget {
  const DevizProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DevizPro Ultra',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: FutureBuilder<AppRepository>(
        future: AppRepository.create(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomePage(repository: snapshot.data!);
        },
      ),
    );
  }
}
