import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase so authentication and Firestore are available. On
  // Android/iOS this uses the bundled google-services config; run
  // `flutterfire configure` to generate that config per environment.
  await ensureFirebaseInitialized();

  runApp(const ProviderScope(child: ShopAfrikApp()));
}
