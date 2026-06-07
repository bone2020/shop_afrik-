import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is wired up but not initialized here yet: the generated
  // `firebase_options.dart` is created per-environment by `flutterfire
  // configure` (see lib/services/firebase_bootstrap.dart) and is not
  // committed. Enable the call below once that file exists.
  //
  // await ensureFirebaseInitialized();

  runApp(const ProviderScope(child: ShopAfrikApp()));
}
