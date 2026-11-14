import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/app_viewmodel.dart';
import '../config_view.dart';
import '../conversa_view.dart';

/// Barra superior padrão. Em telas secundárias mostra "Voltar" sempre no mesmo lugar
/// (canto esquerdo), com rótulo para leitores de tela ("Voltar para <tela anterior>").
class BarraRotaDourada extends StatelessWidget implements PreferredSizeWidget {
  final String? anterior; // nome da tela anterior; null = tela principal (sem Voltar)
  final VoidCallback? aoVoltar;
  final bool mostrarAcoes;
  const BarraRotaDourada({super.key, this.anterior, this.aoVoltar, this.mostrarAcoes = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t;
    final fg = Theme.of(context).appBarTheme.foregroundColor;
    final podeVoltar = anterior != null;
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: podeVoltar ? 112 : 0,
      leading: podeVoltar
          ? Semantics(
              button: true,
              label: '${t['voltarPara']} $anterior',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: fg,
                    side: BorderSide(color: fg ?? Colors.white, width: 1.5),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: Text(t['voltar']),
                  onPressed: aoVoltar ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      title: Text('Rota Dourada', style: const TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        if (mostrarAcoes && app.logado && app.podeConversar)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversaView())),
              child: Text(t['conversar']),
            ),
          ),
        if (mostrarAcoes && app.logado)
          IconButton(
            tooltip: t['config'],
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigView())),
          ),
      ],
    );
  }
}
