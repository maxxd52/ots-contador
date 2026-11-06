import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/firestore_repository.dart';
import 'firebase_options.dart';
import 'ui/viewmodels/tablero_viewmodel.dart';
import 'ui/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repository = FirestoreOtsRepository();
  final viewModel = TableroViewModel(repository: repository);
  await viewModel.inicializar();

  runApp(OtsApp(viewModel: viewModel));
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
