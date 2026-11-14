import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rota_dourada/models/pacote.dart';
import 'package:rota_dourada/models/usuario.dart';
import 'package:rota_dourada/services/rota_service.dart';

Usuario usuario(List<String> tipos, {bool possui = true}) => Usuario(
      nome: 'Ana',
      possuiDeficiencia: possui,
      tipos: tipos,
      consentimento: true,
      criadoEm: '2026-11-13T00:00:00Z',
    );

void main() {
  late Pacote pacote;
  setUpAll(() {
    pacote = Pacote.fromJson(
        jsonDecode(File('assets/pacote_capim_dourado.json').readAsStringSync()) as Map<String, dynamic>);
  });

  test('cadeirante + cegueira: soma restrições, maior penalidade e ajustes de tela', () {
    final p = PerfilUsuario.de(pacote, usuario(['cadeirante', 'cegueira']));
    expect(p.perfis, ['mobilidade', 'visual']);
    expect(p.rota.proibidos, containsAll(['escada', 'escada_rolante', 'esteira']));
    expect(p.rota.penalidadeCurva, pacote.perfis['visual']!.penalidadeCurva);
    expect(p.ui, containsAll(['semEscadas', 'altoContraste', 'audioAuto', 'listaPrimeiro']));
    expect(p.rota.exigirConfirmado, isTrue);
    expect(RotaService(pacote).calcular(p.rota, 't_p1', 'p_c'), isNull);
    final r = RotaService(pacote).calcular(p.rota, 't_po', 'p_c')!;
    expect(r.tipos, contains('elevador'));
  });

  test('"não" ignora tipos e usa o perfil padrão', () {
    final p = PerfilUsuario.de(pacote, usuario(['cadeirante'], possui: false));
    expect(p.perfis, ['padrao']);
    expect(p.rota.proibidos, isEmpty);
    expect(PerfilUsuario.de(pacote, null).ui, isEmpty);
  });

  test('usuário serializa e volta igual (armazenamento local)', () {
    final u = usuario(['auditiva', 'tea']);
    final v = Usuario.fromJson(jsonDecode(jsonEncode(u.toJson())) as Map<String, dynamic>);
    expect(v.tipos, u.tipos);
    expect(v.consentimento, isTrue);
  });

  test('fala e auditiva liberam Conversar; outras não', () {
    bool conversa(List<String> t) => PerfilUsuario.de(pacote, usuario(t)).ui.contains('conversar');
    expect(conversa(['fala']) && conversa(['auditiva']) && conversa(['cegueira', 'fala']), isTrue);
    expect(conversa(['cadeirante']) || conversa(['cegueira']), isFalse);
    expect(PerfilUsuario.de(pacote, null).ui.contains('conversar'), isFalse);
    expect(PerfilUsuario.de(pacote, usuario(['fala'])).perfis, ['padrao']);
  });

  test('cadeirante: todo o térreo tem rota sem escada; o 2º piso só pelo acesso oeste', () {
    final p = PerfilUsuario.de(pacote, usuario(['cadeirante']));
    final s = RotaService(pacote);
    for (final poi in pacote.pois) {
      final origem = poi.andar == 0 ? 't_rs' : 't_po';
      expect(s.calcular(p.rota, origem, poi.no), isNotNull, reason: poi.id);
    }
  });
}
