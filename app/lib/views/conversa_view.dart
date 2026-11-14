import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../services/feedback_service.dart';
import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/navegacao_viewmodel.dart';
import '../services/central_service.dart';
import 'config_view.dart';
import 'sos_view.dart';
import 'tema.dart';
import 'widgets/barra.dart';

/// Conversa face a face (exclusiva para surdez e/ou deficiência na fala): tela dividida,
/// metade de cima girada para o atendente, e botão "SOS — Preciso de ajuda".
/// O visitante escolhe frases no idioma dele; o atendente lê em português e
/// responde com frases prontas que aparecem traduzidas para o visitante.
/// Funciona offline e sem depender de voz ou sons.
class ConversaView extends StatefulWidget {
  final Map<String, String>? fraseInicial;
  const ConversaView({super.key, this.fraseInicial});
  @override
  State<ConversaView> createState() => _ConversaViewState();
}

class _ConversaViewState extends State<ConversaView> {
  Map<String, String>? _msg;
  bool _doAtendente = false;
  final _campoVisitante = TextEditingController();
  final _campoAtendente = TextEditingController();
  final _voz = FeedbackService();

  @override
  void initState() {
    super.initState();
    final nav = context.read<NavegacaoViewModel>();
    final idioma = context.read<AppViewModel>().idioma;
    if (widget.fraseInicial != null) {
      _msg = widget.fraseInicial;
    } else if (nav.destino != null) {
      _msg = {
        'pt': 'Estou procurando: ${nav.destino!.nome('pt')}.',
        'en': "I'm looking for: ${nav.destino!.nome(idioma)}.",
        'es': 'Estoy buscando: ${nav.destino!.nome(idioma)}.',
      };
    } else {
      final tipos = context.read<AppViewModel>().usuario?.tipos ?? const [];
      _msg = frasesVisitante[tipos.contains('auditiva') ? 0 : 1];
    }
  }

  void _visitante(Map<String, String> m) => setState(() {
        _msg = m;
        _doAtendente = false;
      });

  void _atendente(Map<String, String> m, AppViewModel app, String idioma) {
    setState(() {
      _msg = m;
      _doAtendente = true;
    });
    if (app.tem('vibracao')) _voz.vibrar('chegada');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, idioma = app.idioma;
    final paraAtendente = _msg == null ? '—' : _msg!['pt']!;
    final paraVisitante = _msg == null ? '—' : (_msg![idioma] ?? _msg!['pt']!);
    const grande = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2);

    Widget botao(String texto, VoidCallback onTap) => OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: onTap,
          child: Text(texto, textAlign: TextAlign.left),
        );

    if (!app.podeConversar) {
      return Scaffold(appBar: BarraRotaDourada(anterior: t['telaMapa'], mostrarAcoes: false), body: const SizedBox.shrink());
    }

    Future<void> sos() async {
      if (!await confirmarAcessivel(context, t['sosConfT'], t['sosConfD'], t['sosConfSim'], t['cancelar'])) return;
      // Só envia se houver integração real com a central; caso contrário, nada é enviado.
      final status = app.central.disponivel
          ? await app.central.enviarPedidoDeAjuda(local: _local(app), necessidades: app.usuario?.tipos ?? const [])
          : StatusEnvio.naoEnviado;
      if (!context.mounted) return;
      if (app.tem('vibracao')) _voz.vibrar('chegada');
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: true,
        transitionDuration: Duration.zero, // sem animação nem piscar
        pageBuilder: (_, __, ___) => SosView(status: status, local: _local(app)),
      ));
    }

    return Scaffold(
      appBar: BarraRotaDourada(anterior: t['telaMapa'], mostrarAcoes: false),
      body: SafeArea(
        child: Column(children: [
          // Metade do atendente (girada 180°)
          Expanded(
            child: RotatedBox(
              quarterTurns: 2,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: ListView(children: [
                  const Text('Para o atendente: leia a mensagem do visitante',
                      style: TextStyle(fontSize: 13, color: Cores.tinta)),
                  const SizedBox(height: 6),
                  Text(paraAtendente, style: grande.copyWith(color: Cores.tinta)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final r in respostasAtendente) botao(r['pt']!, () => _atendente(r, app, idioma)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _campoAtendente,
                    decoration: const InputDecoration(hintText: 'Escreva sua resposta', border: OutlineInputBorder()),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      _atendente({'pt': v.trim()}, app, idioma);
                      _campoAtendente.clear();
                    },
                  ),
                ]),
              ),
            ),
          ),
          Container(height: 3, color: Cores.capim),
          // Metade do visitante
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Semantics(
                button: true,
                label: t['sos'],
                excludeSemantics: true,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Cores.sos,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(60),
                    side: const BorderSide(color: Colors.white, width: 3),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 30),
                  label: Text(t['sos']),
                  onPressed: sos,
                ),
              ),
              const SizedBox(height: 12),
              Text(t['vireTela'], style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Semantics(liveRegion: true, child: Text(paraVisitante, style: grande)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in frasesVisitante) botao(f[idioma]!, () => _visitante(f)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _campoVisitante,
                decoration: InputDecoration(hintText: t['escreva'], border: const OutlineInputBorder()),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  _visitante({'pt': v.trim(), 'en': v.trim(), 'es': v.trim()});
                  _campoVisitante.clear();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _local(AppViewModel app) {
    final nav = context.read<NavegacaoViewModel>();
    final p = app.pacote!;
    final n = nav.posicao == null ? null : p.nos[nav.posicao!.no];
    if (n == null) return '';
    return '${n.referencia('pt') ?? n.nome('pt') ?? ''} – ${p.andar(n.andar).nome('pt').split(' –').first}';
  }

  @override
  void dispose() {
    _campoVisitante.dispose();
    _campoAtendente.dispose();
    _voz.parar();
    super.dispose();
  }
}
