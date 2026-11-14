import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;

import '../l10n/textos.dart';
import '../models/pacote.dart';
import '../models/usuario.dart';
import '../services/central_service.dart';
import '../services/conta_service.dart';
import '../services/pacote_service.dart';
import '../services/planta_service.dart';
import '../services/preferencias_service.dart';

enum EstadoPacote { carregando, pronto, indisponivel }

/// Rascunho do formulário: sobrevive a "Voltar" e reabertura da tela.
class RascunhoCadastro {
  final nome = TextEditingController();
  final telefone = TextEditingController();
  final email = TextEditingController();
  final senha = TextEditingController();
  bool? possui;
  final Set<String> tipos = {};
  bool consentimento = false;
  bool lembrar = false;

  void preencher(Usuario? u) {
    nome.text = u?.nome ?? '';
    telefone.text = u?.telefone ?? '';
    email.text = u?.email ?? '';
    senha.clear();
    possui = u == null ? null : u.possuiDeficiencia;
    tipos
      ..clear()
      ..addAll(u?.tipos ?? const []);
    consentimento = u?.consentimento ?? false;
  }
}

/// Estado global: pacote, plantas, sessão (visitante ou conta), tema e idioma.
class AppViewModel extends ChangeNotifier {
  final PacoteService _pacotes;
  final ContaService contas;
  final PreferenciasService _prefs;
  final CentralAtendimento central;
  AppViewModel(this._pacotes, this.contas, this._prefs, {this.central = const SemCentral()});

  EstadoPacote estado = EstadoPacote.carregando;
  Pacote? pacote;
  Map<int, Map<String, ui.Image>> plantas = {};
  String idioma = 'pt';
  String tema = 'claro';

  Usuario? usuario;
  bool ehConta = false;
  bool ocupado = false; // carregando (criar conta, entrar, salvar)
  final rascunho = RascunhoCadastro();
  PerfilUsuario? _perfil;

  Textos get t => Textos.de(idioma);
  bool get logado => usuario != null;
  PerfilUsuario get perfilUsuario => _perfil ??= PerfilUsuario.de(pacote!, usuario);
  Perfil get perfil => perfilUsuario.rota;
  bool tem(String flag) => pacote != null && logado && perfilUsuario.tem(flag);
  bool usa(String p) => pacote != null && perfilUsuario.usa(p);

  /// Conversar é exclusivo para surdez e/ou deficiência na fala.
  bool get podeConversar => tem('conversar');

  /// Tema efetivo do mapa (alto contraste do perfil usa a planta escura).
  String get temaMapa => tem('altoContraste') ? 'escuro' : tema;
  ui.Image? planta(int andar) => plantas[andar]?[temaMapa] ?? plantas[andar]?['claro'];

  Future<void> iniciar() async {
    final (tm, id) = await _prefs.carregar();
    tema = tm;
    if (id != null) idioma = id;
    try {
      final r = await _pacotes.carregar();
      pacote = r.pacote;
      plantas = await PlantaService().carregar(r.pacote);
      estado = EstadoPacote.pronto;
    } catch (_) {
      estado = EstadoPacote.indisponivel;
    }
    final (u, conta) = await contas.carregarSessao();
    usuario = u;
    ehConta = conta;
    _perfil = null;
    notifyListeners();
  }

  void _definir(Usuario? u, bool conta) {
    usuario = u;
    ehConta = conta;
    _perfil = null;
    notifyListeners();
  }

  Future<void> entrarComoVisitante(Usuario u, {required bool lembrar}) async {
    await contas.salvarVisitante(u, lembrar: lembrar);
    _definir(u, false);
  }

  /// Executa uma operação de conta mostrando "carregando"; devolve o código de erro ou null.
  Future<String?> _operacao(Future<Usuario> Function() f) async {
    ocupado = true;
    notifyListeners();
    try {
      final u = await f();
      _definir(u, true);
      return null;
    } on ErroConta catch (e) {
      return e.codigo;
    } catch (_) {
      return 'conexao';
    } finally {
      ocupado = false;
      notifyListeners();
    }
  }

  Future<String?> criarConta(Usuario u, String senha) => _operacao(() => contas.criarConta(u, senha));
  Future<String?> entrar(String email, String senha) => _operacao(() => contas.entrar(email, senha));
  Future<String?> salvarPerfil(Usuario u, {String? novaSenha}) =>
      _operacao(() => contas.salvarPerfil(u, novaSenha: novaSenha));

  Future<void> sair() async {
    await contas.sair();
    rascunho.preencher(null);
    _definir(null, false);
  }

  Future<String?> apagarDados() async {
    try {
      await contas.apagar();
    } on ErroConta catch (e) {
      return e.codigo;
    }
    rascunho.preencher(null);
    _definir(null, false);
    return null;
  }

  Future<void> trocarTema(String t) async {
    tema = t;
    notifyListeners();
    await _prefs.salvarTema(t);
  }

  Future<void> trocarIdioma(String i) async {
    idioma = i;
    notifyListeners();
    await _prefs.salvarIdioma(i);
  }
}
