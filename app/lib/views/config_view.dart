import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../viewmodels/app_viewmodel.dart';
import 'cadastro_view.dart';
import 'widgets/barra.dart';

Future<bool> confirmarAcessivel(BuildContext context, String titulo, String texto, String sim, String nao) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Semantics(header: true, child: Text(titulo)),
      content: Text(texto),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(c).pop(false), child: Text(nao)),
        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(sim)),
      ],
    ),
  );
  return r ?? false;
}

/// Configurações: tema (claro, escuro, Sexta-feira 13), idioma e perfil.
class ConfigView extends StatelessWidget {
  const ConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, tema = Theme.of(context), u = app.usuario;
    final necessidades = (u != null && u.possuiDeficiencia && u.tipos.isNotEmpty)
        ? u.tipos.map((id) => tiposDeficiencia.firstWhere((x) => x.id == id).rotulo[app.idioma]).join('; ')
        : t['nenhuma'];

    return Scaffold(
      appBar: BarraRotaDourada(anterior: t['telaMapa'], mostrarAcoes: false),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Semantics(header: true, child: Text(t['config'], style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Text(t['tema'], style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final (id, nome, fundo, frente) in [
            ('claro', t['temaClaro'], const Color(0xFFEEF3EE), const Color(0xFF1F3B2D)),
            ('escuro', t['temaEscuro'], const Color(0xFF121614), const Color(0xFFE3A92B)),
            ('terror', t['temaTerror'], const Color(0xFF0E0809), const Color(0xFFF0A04B)),
          ])
            RadioListTile<String>(
              value: id,
              groupValue: app.tema,
              onChanged: (v) => v == null ? null : app.trocarTema(v),
              title: Row(children: [
                Container(
                  width: 44,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black26)),
                  child: ExcludeSemantics(child: Text('Aa', style: TextStyle(color: frente, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Text(nome),
              ]),
            ),
          if (app.tem('altoContraste')) Text(t['notaContraste']),
          const SizedBox(height: 12),
          Row(children: [
            Text('${t['idioma']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            DropdownButton<String>(
              value: app.idioma,
              items: const [
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
              onChanged: (v) => v == null ? null : app.trocarIdioma(v),
            ),
          ]),
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(t['perfil'], style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(height: 6),
          Text(app.ehConta ? '${t['modoConta']}: ${u?.email ?? ''}' : t['modoVisitante']),
          Text('${t['necessidades']}: $necessidades'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CadastroView(modo: app.ehConta ? ModoCadastro.editar : ModoCadastro.visitanteEditar))),
            child: Text(t['editarPerfil']),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              if (!await confirmarAcessivel(context, t['sairT'], t['sairD'], t['sair'], t['cancelar'])) return;
              await app.sair();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: Text(t['sair']),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: tema.colorScheme.error),
            onPressed: () async {
              if (!await confirmarAcessivel(context, t['apagarT'], t['apagarD'], t['apagar'], t['cancelar'])) return;
              final erro = await app.apagarDados();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro == null ? t['apagado'] : t['err_$erro'])));
              if (erro == null) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: Text(t['apagar']),
          ),
        ]),
      ),
    );
  }
}
