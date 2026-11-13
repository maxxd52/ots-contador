import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/firestore_repository.dart';
import 'data/repositories/ots_repository.dart';
import 'firebase_options.dart';
import 'ui/viewmodels/tablero_viewmodel.dart';
import 'ui/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  OtsRepository repository;
  bool isOffline = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    repository = FirestoreOtsRepository();
  } catch (error) {
    debugPrint(
      'Firebase initialization failed or unsupported ($error). '
      'Operating in offline mode with LocalOtsRepository.',
    );
    repository = LocalOtsRepository();
    isOffline = true;
  }

  final viewModel = TableroViewModel(
    repository: repository,
    isOffline: isOffline,
  );

  runApp(OtsApp(viewModel: viewModel));

  unawaited(viewModel.inicializar());
}

class OtsApp extends StatelessWidget {
  final TableroViewModel viewModel;

  const OtsApp({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTS 120 Días',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomeScreen(viewModel: viewModel),
    );
  }
}
