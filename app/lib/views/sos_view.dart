import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../services/central_service.dart';
import '../viewmodels/app_viewmodel.dart';
import 'tema.dart';

/// Pedido de ajuda em tela cheia para mostrar a quem está perto.
/// Estático (sem piscar, sem som). Informa o status REAL do envio à central:
/// sem integração, diz claramente que nada foi enviado.
class SosView extends StatelessWidget {
  final StatusEnvio status;
  final String local;
  const SosView({super.key, required this.status, required this.local});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, tipos = app.usuario?.tipos ?? const <String>[];
    const branco = Colors.white;
    final linhas = <String>[
      if (tipos.contains('auditiva')) sosLinhas['surdo']!,
      if (tipos.contains('fala')) sosLinhas['fala']!,
      sosLinhas['chame']!,
      if (local.isNotEmpty) '${sosLinhas['perto']} $local.',
    ];
    final textoStatus = switch (status) {
      StatusEnvio.enviado => t['sosEnviado'],
      StatusEnvio.falhou => t['sosFalhou'],
      StatusEnvio.naoEnviado => t['sosSemEnvio'],
    };
    return Scaffold(
      backgroundColor: Cores.sos,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(sosLinhas['titulo']!,
                      style: const TextStyle(color: branco, fontSize: 44, height: 1.05, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                for (final l in linhas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l, style: const TextStyle(color: branco, fontSize: 24, height: 1.3)),
                  ),
                if (app.idioma != 'pt')
                  Text(sosOutroIdioma[app.idioma] ?? '',
                      style: const TextStyle(color: branco, fontSize: 18)),
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                    child: Text(textoStatus, style: const TextStyle(color: branco, fontSize: 16)),
                  ),
                ),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: branco,
                foregroundColor: const Color(0xFF4A000B),
                minimumSize: const Size.fromHeight(58),
                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t['sosFechar']),
            ),
          ]),
        ),
      ),
    );
  }
}

const sosOutroIdioma = {
  'en': 'Please call mall security or the first aid team.',
  'es': 'Por favor, llame a seguridad o a primeros auxilios del shopping.',
};
