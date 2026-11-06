import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/ots_repository.dart';
import 'ui/viewmodels/tablero_viewmodel.dart';
import 'ui/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalOtsRepository();
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
