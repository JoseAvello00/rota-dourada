import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/navegacao_viewmodel.dart';
import 'excecoes_view.dart';
import 'navegacao_view.dart';
import 'widgets/barra.dart';

/// Página aberta ao tocar em "Iniciar navegação". Agrupa o passo a passo e as
/// etapas derivadas (posição incerta, sem rota, chegada) com o mesmo "Voltar":
/// - em "posição incerta" volta para a rota;
/// - nas demais volta ao mapa preservando destino e seleção.
/// Quando a jornada volta à fase "explorar" (por qualquer botão), a página se fecha.
class NavegacaoPage extends StatefulWidget {
  const NavegacaoPage({super.key});
  @override
  State<NavegacaoPage> createState() => _NavegacaoPageState();
}

class _NavegacaoPageState extends State<NavegacaoPage> {
  bool _fechando = false;

  void _voltar(NavegacaoViewModel nav) {
    if (nav.fase == Fase.incerto) {
      nav.voltarParaRota();
    } else {
      nav.voltarAoMapa(limpar: nav.fase == Fase.chegou);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    final t = app.t;

    if (nav.fase == Fase.explorar && !_fechando) {
      _fechando = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    final corpo = switch (nav.fase) {
      Fase.incerto => const IncertoView(),
      Fase.semRota => const SemRotaView(),
      Fase.chegou => const ChegadaView(),
      _ => const NavegacaoView(),
    };

    return PopScope(
      canPop: nav.fase == Fase.explorar,
      onPopInvoked: (saiu) {
        if (!saiu) _voltar(nav);
      },
      child: Scaffold(
        appBar: BarraRotaDourada(
          anterior: nav.fase == Fase.incerto ? t['telaNavegacao'] : t['telaMapa'],
          aoVoltar: () => _voltar(nav),
        ),
        body: SafeArea(child: corpo),
      ),
    );
  }
}
