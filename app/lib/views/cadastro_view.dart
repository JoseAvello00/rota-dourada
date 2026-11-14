import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../viewmodels/app_viewmodel.dart';
import 'widgets/barra.dart';

enum ModoCadastro { criar, editar, visitante, visitanteEditar }

/// Aviso de erro geral (lido pelo leitor de tela).
class AvisoErro extends StatelessWidget {
  final String texto;
  const AvisoErro(this.texto, {super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: cs.error, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Botão principal que mostra "carregando" com texto (não só um ícone girando).
class BotaoOcupado extends StatelessWidget {
  final bool ocupado;
  final String texto, textoOcupado;
  final VoidCallback aoTocar;
  const BotaoOcupado({super.key, required this.ocupado, required this.texto, required this.textoOcupado, required this.aoTocar});
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: ocupado ? null : aoTocar,
        child: ocupado
            ? Semantics(
                liveRegion: true,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(textoOcupado),
                ]),
              )
            : Text(texto),
      );
}

/// Criar conta, editar perfil e preferências de visitante.
/// Campos obrigatórios indicados no rótulo; várias necessidades podem ser marcadas.
class CadastroView extends StatefulWidget {
  final ModoCadastro modo;
  const CadastroView({super.key, required this.modo});
  @override
  State<CadastroView> createState() => _CadastroViewState();
}

class _CadastroViewState extends State<CadastroView> {
  final Map<String, String?> _erros = {};
  String? _erroGeral;
  bool _ver = false;

  bool get _visitante => widget.modo == ModoCadastro.visitante || widget.modo == ModoCadastro.visitanteEditar;
  bool get _editar => widget.modo == ModoCadastro.editar || widget.modo == ModoCadastro.visitanteEditar;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppViewModel>();
    if (_editar) {
      app.rascunho.preencher(app.usuario);
      app.rascunho.lembrar = true;
    }
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _salvar(AppViewModel app) async {
    final t = app.t, r = app.rascunho;
    final tel = _digitos(r.telefone.text), email = r.email.text.trim().toLowerCase();
    _erros.clear();
    if (!_visitante) {
      if (r.nome.text.trim().isEmpty) _erros['nome'] = t['eNome2'];
      if (tel.length != 10 && tel.length != 11) _erros['tel'] = t['eTel'];
      if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) _erros['email'] = t['eEmail2'];
      if ((!_editar || r.senha.text.isNotEmpty) && r.senha.text.length < 8) _erros['senha'] = t['eSenha'];
    }
    if (r.possui == null) {
      _erros['possui'] = t['ePossui2'];
    } else if (r.possui! && r.tipos.isEmpty) {
      _erros['tipos'] = t['eTipos2'];
    } else if (r.possui! && !_visitante && !r.consentimento) {
      _erros['consent'] = t['eConsent2'];
    }
    setState(() => _erroGeral = _erros.isEmpty ? null : t['corrija']);
    if (_erros.isNotEmpty) {
      SemanticsService.announce('${t['corrija']} ${_erros.values.join(' ')}', TextDirection.ltr);
      return;
    }
    final u = Usuario(
      nome: _visitante ? '' : r.nome.text.trim(),
      email: _visitante ? null : email,
      telefone: _visitante ? null : tel,
      possuiDeficiencia: r.possui!,
      tipos: r.possui! ? (r.tipos.toList()..sort()) : const [],
      consentimento: r.possui! && (_visitante ? r.lembrar : r.consentimento),
      idioma: app.idioma,
      criadoEm: app.usuario?.criadoEm ?? DateTime.now().toUtc().toIso8601String(),
      idRemoto: app.usuario?.idRemoto,
    );
    String? erro;
    if (_visitante) {
      await app.entrarComoVisitante(u, lembrar: r.lembrar);
    } else if (_editar) {
      erro = await app.salvarPerfil(u, novaSenha: r.senha.text.isEmpty ? null : r.senha.text);
    } else {
      erro = await app.criarConta(u, r.senha.text);
    }
    if (!mounted) return;
    if (erro != null) {
      setState(() => _erroGeral = t['err_$erro']);
      SemanticsService.announce(_erroGeral!, TextDirection.ltr);
      return;
    }
    r.senha.clear();
    final msg = _visitante ? t['prefsSalvas'] : (_editar ? t['perfilSalvo'] : t['contaCriada']);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (_editar) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final t = app.t, r = app.rascunho, tema = Theme.of(context);
    final titulo = _visitante ? t['visTitulo'] : (_editar ? t['editarTitulo'] : t['criarTitulo']);
    final ui = r.possui == true ? tiposDeficiencia.where((x) => r.tipos.contains(x.id)).expand((x) => x.ui).toSet() : <String>{};
    final cs = tema.colorScheme;

    Widget erroDe(String k) => _erros[k] == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_erros[k]!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
          );

    return Scaffold(
      appBar: BarraRotaDourada(anterior: _editar ? t['config'] : t['telaAcesso'], mostrarAcoes: false),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Semantics(header: true, child: Text(titulo, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            Text(_visitante ? t['visSub'] : t['obrigSub']),
            const SizedBox(height: 14),
            if (_erroGeral != null) AvisoErro(_erroGeral!),
            if (!_visitante) ...[
              TextField(
                controller: r.nome,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: '${t['nomeCampo']} ${t['obrig']}', errorText: _erros['nome']),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: r.telefone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(labelText: '${t['telefone']} ${t['obrig']}', hintText: '(63) 99999-0000', errorText: _erros['tel']),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: r.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: '${t['emailCampo']} ${t['obrig']}', errorText: _erros['email']),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: r.senha,
                obscureText: !_ver,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: _editar ? '${t['senhaTroca']} ${t['opcional']}' : '${t['senhaNova']} ${t['obrig']}',
                  errorText: _erros['senha'],
                  suffixIcon: IconButton(
                    tooltip: t['mostrarSenha'],
                    icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ver = !_ver),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('${t['perguntaDef']} ${t['obrig']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: [ButtonSegment(value: true, label: Text(t['sim'])), ButtonSegment(value: false, label: Text(t['nao']))],
              selected: r.possui == null ? <bool>{} : {r.possui!},
              onSelectionChanged: (s) => setState(() => r.possui = s.isEmpty ? null : s.first),
            ),
            erroDe('possui'),
            if (r.possui == true) ...[
              const SizedBox(height: 14),
              Text(t['quais'], style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final tipo in tiposDeficiencia)
                CheckboxListTile(
                  value: r.tipos.contains(tipo.id),
                  title: Text(tipo.rotulo[app.idioma] ?? tipo.rotulo['pt']!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => v == true ? r.tipos.add(tipo.id) : r.tipos.remove(tipo.id)),
                ),
              erroDe('tipos'),
              if (!_visitante)
                CheckboxListTile(
                  value: r.consentimento,
                  title: Text('${t['consent']} ${t['obrig']}', style: const TextStyle(fontSize: 15)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => r.consentimento = v ?? false),
                ),
              erroDe('consent'),
            ],
            if (_visitante)
              CheckboxListTile(
                value: r.lembrar,
                title: Text(t['lembrar']),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => r.lembrar = v ?? false),
              ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['adaptaT'], style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  for (final k in (ui.isEmpty ? {'nenhum'} : ui)) Text('• ${t['ad_$k']}', style: TextStyle(color: cs.onPrimary)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            BotaoOcupado(
              ocupado: app.ocupado,
              texto: _visitante ? t['continuar'] : (_editar ? t['salvarAlt'] : t['criarConta']),
              textoOcupado: _editar ? t['salvando'] : t['criando'],
              aoTocar: () => _salvar(app),
            ),
          ]),
        ),
      ),
    );
  }
}
