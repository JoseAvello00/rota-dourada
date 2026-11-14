import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/feedback_service.dart';
import 'services/pacote_service.dart';
import 'services/conta_service.dart';
import 'services/preferencias_service.dart';
import 'viewmodels/app_viewmodel.dart';
import 'viewmodels/navegacao_viewmodel.dart';
import 'views/home_view.dart';
import 'views/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppViewModel(PacoteService(), ContaService(), PreferenciasService())..iniciar();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider(create: (_) => NavegacaoViewModel(app, FeedbackService())),
      ],
      child: const RotaDouradaApp(),
    ),
  );
}

class RotaDouradaApp extends StatelessWidget {
  const RotaDouradaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    return MaterialApp(
      title: 'Rota Dourada',
      debugShowCheckedModeBanner: false,
      theme: temaPara(app.tema, app.pacote == null || !app.logado ? const <String>{} : app.perfilUsuario.ui),
      home: const HomeView(),
    );
  }
}
