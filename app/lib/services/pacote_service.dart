import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/pacote.dart';

enum OrigemPacote { local, atualizado, embutido }

class ResultadoPacote {
  final Pacote pacote;
  final OrigemPacote origem;
  const ResultadoPacote(this.pacote, this.origem);
}

/// Mantém o pacote salvo no aparelho e atualiza pela API quando houver conexão.
/// A navegação nunca depende da rede depois do primeiro pacote salvo.
class PacoteService {
  static const pacoteId = 'capim-dourado-piloto';

  /// Ex.: flutter run --dart-define=API_URL=https://rota-dourada-api.onrender.com
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  Future<File> _arquivo() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$pacoteId.json');
  }

  Future<ResultadoPacote> carregar() async {
    final arq = await _arquivo();
    Pacote? local;
    if (await arq.exists()) {
      try {
        local = Pacote.fromJson(jsonDecode(await arq.readAsString()) as Map<String, dynamic>);
      } catch (_) {
        local = null; // arquivo corrompido: tenta de novo abaixo
      }
    }

    final novo = await _tentarAtualizar(local?.versao);
    if (novo != null) {
      await arq.writeAsString(novo.$2);
      return ResultadoPacote(novo.$1, OrigemPacote.atualizado);
    }
    if (local != null) return ResultadoPacote(local, OrigemPacote.local);

    // Primeira execução sem conexão: usa o pacote embutido no app (piloto).
    final bruto = await rootBundle.loadString('assets/$pacoteId.json');
    await arq.writeAsString(bruto);
    return ResultadoPacote(
        Pacote.fromJson(jsonDecode(bruto) as Map<String, dynamic>), OrigemPacote.embutido);
  }

  /// Consulta a versão (chamada leve) e só baixa o pacote se mudou.
  Future<(Pacote, String)?> _tentarAtualizar(String? versaoLocal) async {
    if (apiUrl.isEmpty) return null;
    try {
      final v = await http
          .get(Uri.parse('$apiUrl/pacotes/$pacoteId/versao'))
          .timeout(const Duration(seconds: 4));
      if (v.statusCode != 200) return null;
      final versao = (jsonDecode(v.body) as Map<String, dynamic>)['versao'] as String;
      if (versao == versaoLocal) return null;
      final r = await http
          .get(Uri.parse('$apiUrl/pacotes/$pacoteId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final corpo = utf8.decode(r.bodyBytes);
      return (Pacote.fromJson(jsonDecode(corpo) as Map<String, dynamic>), corpo);
    } catch (_) {
      return null; // sem conexão: segue com o pacote local
    }
  }
}
