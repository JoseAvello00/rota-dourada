import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import 'acesso_view.dart';
import 'explorar_view.dart';
import 'widgets/barra.dart';

/// Raiz: carregamento do mapa → tela de acesso (visitante / entrar / criar conta)
/// → mapa "Aonde você quer ir?". A navegação passo a passo, a conversa e as
/// configurações abrem como páginas por cima, sempre com "Voltar".
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t;

    if (app.estado != EstadoPacote.pronto) {
      final msg = app.estado == EstadoPacote.carregando ? t['carregando'] : t['semPacote'];
      return Scaffold(
        appBar: const BarraRotaDourada(mostrarAcoes: false),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Semantics(liveRegion: true, child: Text(msg, textAlign: TextAlign.center))),
        ),
      );
    }
    if (!app.logado) return const AcessoView();

    return Scaffold(
      appBar: const BarraRotaDourada(),
      body: const SafeArea(child: ExplorarView()),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            '${t['pacoteOk']} · v${app.pacote!.versao} · ${app.pacote!.atualizadoEm} · ${t['offline']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
