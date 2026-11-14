import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/navegacao_viewmodel.dart';
import 'tema.dart';
import 'widgets/mapa_painter.dart';

const iconesEtapa = <String, IconData>{
  'frente': Icons.straight,
  'direita': Icons.turn_right,
  'esquerda': Icons.turn_left,
  'voltar': Icons.u_turn_left,
  'elevador': Icons.elevator,
  'escada': Icons.stairs,
  'esteira': Icons.escalator,
  'rampa': Icons.accessible_forward,
  'chegada': Icons.flag,
};

class NavegacaoView extends StatefulWidget {
  const NavegacaoView({super.key});
  @override
  State<NavegacaoView> createState() => _NavegacaoViewState();
}

class _NavegacaoViewState extends State<NavegacaoView> {
  int? _andarEscolhido; // aba tocada pelo visitante; null = segue a etapa

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    final t = app.t, p = app.pacote!, tema = Theme.of(context);
    final rota = nav.rota!, etapa = nav.etapaAtual;
    final passoAPasso = app.tem('passoAPasso');
    final andar = _andarEscolhido ?? nav.andarAtual;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(header: true, child: Text(nav.destino!.nome(app.idioma), style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Chip(label: Text('${rota.distancia} ${t['total']}')),
          if (rota.semEscadas)
            Chip(avatar: const Icon(Icons.accessible, size: 18), label: Text(t['semEscadas']), backgroundColor: tema.colorScheme.secondary),
        ]),
        if (app.usa('mobilidade') && nav.rotaPadrao != null && !nav.rotaPadrao!.semEscadas)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(t['padraoUsaria'])),
        if (app.usa('sensorial')) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t['evita'])),
        const SizedBox(height: 12),

        // Etapa atual: lida pelo leitor de tela a cada mudança.
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: tema.colorScheme.primary, borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: tema.colorScheme.secondary,
                child: ExcludeSemantics(child: Icon(iconesEtapa[etapa.icone], color: Cores.tinta, size: 30)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(etapa.texto, style: TextStyle(fontSize: 20, height: 1.3, color: tema.colorScheme.onPrimary)),
                  const SizedBox(height: 6),
                  Text('${t['passo']} ${nav.indice + 1} ${t['de']} ${nav.etapas.length}',
                      style: TextStyle(fontSize: 14, color: tema.colorScheme.onPrimary.withOpacity(.8))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            setState(() => _andarEscolhido = null);
            nav.proximo();
          },
          child: Text(nav.ultimaEtapa ? t['cheguei'] : t['proximo']),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: nav.ouvir, icon: const Icon(Icons.volume_up), label: Text(t['ouvir']))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: nav.perdido, icon: const Icon(Icons.help_outline), label: Text(t['perdido']))),
        ]),
        const SizedBox(height: 12),

        // Abas de andar + mapa
        SegmentedButton<int>(
          segments: [
            for (final a in p.andares) ButtonSegment(value: a.id, label: Text(a.nome(app.idioma).split(' –').first)),
          ],
          selected: {andar},
          onSelectionChanged: (s) => setState(() => _andarEscolhido = s.first),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: t['mapa'],
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: CustomPaint(
                painter: MapaPainter(
                  pacote: p,
                  rota: rota,
                  rotaPadrao: nav.rotaPadrao,
                  destino: nav.destino!,
                  andar: andar,
                  posicao: nav.posicaoNaRota,
                  idioma: app.idioma,
                  altoContraste: app.tem('altoContraste'),
                  planta: app.planta(andar),
                  paleta: PaletaMapa.de(app.tema, altoContraste: app.tem('altoContraste')),
                ),
              ),
            ),
          ),
        ),

        // Lista completa (oculta para quem prefere um passo de cada vez)
        if (!passoAPasso) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < nav.etapas.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 13, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text(
                nav.etapas[i].texto,
                style: TextStyle(
                  fontWeight: i == nav.indice ? FontWeight.w700 : FontWeight.w400,
                  decoration: i < nav.indice ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
        TextButton(onPressed: () => nav.voltarAoMapa(), child: Text(t['cancelarRota'])),
      ],
    );
  }
}
