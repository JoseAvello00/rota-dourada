import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_viewmodel.dart';
import 'cadastro_view.dart';
import 'widgets/barra.dart';

/// Entrar com e-mail e senha em uma conta existente.
class EntrarView extends StatefulWidget {
  const EntrarView({super.key});
  @override
  State<EntrarView> createState() => _EntrarViewState();
}

class _EntrarViewState extends State<EntrarView> {
  String? _erroEmail, _erroSenha, _erroGeral;
  bool _ver = false;

  Future<void> _entrar(AppViewModel app) async {
    final t = app.t, r = app.rascunho;
    final email = r.email.text.trim().toLowerCase(), senha = r.senha.text;
    setState(() {
      _erroEmail = RegExp(r'^\S+@\S+\.\S+$').hasMatch(email) ? null : t['eEmail2'];
      _erroSenha = senha.isEmpty ? t['eSenhaVazia'] : null;
      _erroGeral = null;
    });
    if (_erroEmail != null || _erroSenha != null) {
      SemanticsService.announce(t['corrija'], TextDirection.ltr);
      return;
    }
    final erro = await app.entrar(email, senha);
    if (!mounted) return;
    if (erro != null) {
      setState(() => _erroGeral = t['err_$erro']);
      SemanticsService.announce(_erroGeral!, TextDirection.ltr);
      return;
    }
    r.senha.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['bemVindoDeVolta'])));
    Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, r = app.rascunho, tema = Theme.of(context);
    return Scaffold(
      appBar: BarraRotaDourada(anterior: t['telaAcesso'], mostrarAcoes: false),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Semantics(header: true, child: Text(t['entTitulo'], style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            if (_erroGeral != null) AvisoErro(_erroGeral!),
            TextField(
              controller: r.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: '${t['emailCampo']} ${t['obrig']}', errorText: _erroEmail),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: r.senha,
              obscureText: !_ver,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: '${t['senha']} ${t['obrig']}',
                errorText: _erroSenha,
                suffixIcon: IconButton(
                  tooltip: t['mostrarSenha'],
                  icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ver = !_ver),
                ),
              ),
              onSubmitted: (_) => _entrar(app),
            ),
            const SizedBox(height: 16),
            BotaoOcupado(ocupado: app.ocupado, texto: t['entrar'], textoOcupado: t['entrando'], aoTocar: () => _entrar(app)),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CadastroView(modo: ModoCadastro.criar))),
              child: Text(t['naoTemConta']),
            ),
          ]),
        ),
      ),
    );
  }
}
