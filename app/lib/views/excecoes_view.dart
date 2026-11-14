import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/navegacao_viewmodel.dart';
import 'explorar_view.dart';

Widget _alerta(BuildContext context, String titulo, String texto) => Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(left: BorderSide(color: Theme.of(context).colorScheme.error, width: 5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(texto),
        ]),
      ),
    );

/// Posição incerta: não apresenta estimativa como exata; pede um ponto conhecido.
class IncertoView extends StatelessWidget {
  const IncertoView({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    final t = app.t, tema = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _alerta(context, t['incertoT'], t['incertoD']),
      const SizedBox(height: 10),
      for (final n in nav.pontosConhecidos(nav.andarAtual))
        ListTile(
          title: Text(rotuloPonto(n, app.idioma)),
          onTap: () => nav.recomecarDe(n.id),
          shape: Border(bottom: BorderSide(color: tema.dividerColor)),
        ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: nav.voltarParaRota, child: Text(t['voltarRota'])),
    ]);
  }
}

/// Sem rota compatível: preserva as restrições, nunca apresenta escada como acessível
/// e oferece só alternativas que existem na planta.
class SemRotaView extends StatelessWidget {
  const SemRotaView({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (nav.destino != null)
        Semantics(
          header: true,
          child: Text(nav.destino!.nome(app.idioma),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
      const SizedBox(height: 8),
      SemRotaAcessivel(nav: nav, app: app),
    ]);
  }
}

class ChegadaView extends StatelessWidget {
  const ChegadaView({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.read<NavegacaoViewModel>();
    final t = app.t, tema = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Semantics(
        header: true,
        liveRegion: true,
        child: Text(t['chegou'], style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 8),
      Text(nav.etapas.last.texto, style: tema.textTheme.titleMedium),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => nav.voltarAoMapa(limpar: true), child: Text(t['nova'])),
    ]);
  }
}
