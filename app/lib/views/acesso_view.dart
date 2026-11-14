import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import 'cadastro_view.dart';
import 'entrar_view.dart';
import 'widgets/barra.dart';

/// Tela de acesso: três opções claramente diferenciadas.
class AcessoView extends StatelessWidget {
  const AcessoView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, tema = Theme.of(context);

    Widget opcao(IconData icone, String titulo, String descricao, Widget destino) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: tema.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: tema.colorScheme.onSurface.withOpacity(.25), width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: tema.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icone, color: tema.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(descricao, style: TextStyle(color: tema.colorScheme.onSurface.withOpacity(.8))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: const BarraRotaDourada(mostrarAcoes: false),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Semantics(
            header: true,
            child: Text(t['boasVindas'], style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(t['boasVindasSub']),
          const SizedBox(height: 12),
          Row(children: [
            Text('${t['idioma']}: '),
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
          const SizedBox(height: 12),
          opcao(Icons.person_outline, t['opVisitante'], t['opVisitanteD'], const CadastroView(modo: ModoCadastro.visitante)),
          opcao(Icons.mail_outline, t['opEntrar'], t['opEntrarD'], const EntrarView()),
          opcao(Icons.person_add_alt, t['opCriar'], t['opCriarD'], const CadastroView(modo: ModoCadastro.criar)),
        ]),
      ),
    );
  }
}
