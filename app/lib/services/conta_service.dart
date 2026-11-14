import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import 'pacote_service.dart';

/// Erro com mensagem já pronta para mostrar ao usuário.
class ErroConta implements Exception {
  final String codigo; // sem_servidor | conexao | credenciais | duplicado | validacao | sessao
  final String? detalhe;
  const ErroConta(this.codigo, [this.detalhe]);
}

/// Contas no servidor (API /contas). Visitante: só preferências no aparelho, se autorizado.
/// O app nunca cria "contas falsas" no aparelho: sem servidor, informa que não foi possível.
class ContaService {
  static const _token = 'rd_token', _conta = 'rd_conta', _visitante = 'rd_visitante';
  String get _api => PacoteService.apiUrl;

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<(Usuario?, bool)> carregarSessao() async {
    final p = await _p;
    final c = p.getString(_conta);
    if (c != null && p.getString(_token) != null) {
      return (Usuario.fromJson(jsonDecode(c) as Map<String, dynamic>), true);
    }
    final v = p.getString(_visitante);
    if (v != null) return (Usuario.fromJson(jsonDecode(v) as Map<String, dynamic>), false);
    return (null, false);
  }

  Future<Usuario> criarConta(Usuario u, String senha) =>
      _enviar('POST', '/contas', u.paraApi(senha: senha), autenticado: false);

  Future<Usuario> entrar(String email, String senha) =>
      _enviar('POST', '/contas/entrar', {'email': email, 'senha': senha}, autenticado: false);

  Future<Usuario> salvarPerfil(Usuario u, {String? novaSenha}) => _enviar('PUT', '/contas/eu', u.paraApi(senha: novaSenha));

  Future<void> salvarVisitante(Usuario u, {required bool lembrar}) async {
    final p = await _p;
    await p.remove(_token);
    await p.remove(_conta);
    if (lembrar) {
      await p.setString(_visitante, jsonEncode(u.toJson()));
    } else {
      await p.remove(_visitante);
    }
  }

  Future<void> sair() async {
    final p = await _p;
    final t = p.getString(_token);
    if (t != null && _api.isNotEmpty) {
      try {
        await http.post(Uri.parse('$_api/contas/sair'), headers: {'Authorization': 'Bearer $t'}).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    await p.remove(_token);
    await p.remove(_conta);
  }

  /// Apaga a conta no servidor (LGPD) e os dados locais.
  Future<void> apagar() async {
    final p = await _p;
    final t = p.getString(_token);
    if (t != null) {
      if (_api.isEmpty) throw const ErroConta('sem_servidor');
      final r = await http.delete(Uri.parse('$_api/contas/eu'), headers: {'Authorization': 'Bearer $t'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 204 && r.statusCode != 401) throw ErroConta('conexao', '${r.statusCode}');
    }
    await p.remove(_token);
    await p.remove(_conta);
    await p.remove(_visitante);
  }

  Future<Usuario> _enviar(String metodo, String caminho, Map<String, dynamic> corpo, {bool autenticado = true}) async {
    if (_api.isEmpty) throw const ErroConta('sem_servidor');
    final p = await _p;
    final h = {'Content-Type': 'application/json'};
    if (autenticado) h['Authorization'] = 'Bearer ${p.getString(_token) ?? ''}';
    final uri = Uri.parse('$_api$caminho');
    http.Response r;
    try {
      r = await (metodo == 'PUT' ? http.put(uri, headers: h, body: jsonEncode(corpo)) : http.post(uri, headers: h, body: jsonEncode(corpo)))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ErroConta('conexao');
    }
    final j = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(r.bodyBytes));
    switch (r.statusCode) {
      case 200:
      case 201:
        final dados = (j['conta'] ?? j) as Map<String, dynamic>;
        final u = Usuario.daApi(dados);
        if (j['token'] != null) await p.setString(_token, j['token'] as String);
        await p.setString(_conta, jsonEncode(u.toJson()));
        await p.remove(_visitante);
        return u;
      case 401:
        throw ErroConta(autenticado ? 'sessao' : 'credenciais');
      case 409:
        throw const ErroConta('duplicado');
      case 422:
        throw ErroConta('validacao', j.toString());
      default:
        throw ErroConta('conexao', '${r.statusCode}');
    }
  }
}
