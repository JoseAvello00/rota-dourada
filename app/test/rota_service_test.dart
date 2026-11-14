import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rota_dourada/models/pacote.dart';
import 'package:rota_dourada/services/instrucao_service.dart';
import 'package:rota_dourada/services/rota_service.dart';

void main() {
  late Pacote pacote;
  late RotaService rotas;
  Poi poi(String id) => pacote.pois.firstWhere((p) => p.id == id);

  setUpAll(() {
    final bruto = File('assets/pacote_capim_dourado.json').readAsStringSync();
    pacote = Pacote.fromJson(jsonDecode(bruto) as Map<String, dynamic>);
    rotas = RotaService(pacote);
  });

  group('RotaService (rede traçada sobre a Planta Mix)', () {
    test('padrão sobe pela escada rolante', () {
      final pad = rotas.calcular(pacote.perfis['padrao']!, 't_p1', 'p_c')!;
      expect(pad.tipos, contains('escada_rolante'));
      expect(pad.distancia, inInclusiveRange(100, 160));
    });

    test('mobilidade: sem rota confirmada por dentro; pelo acesso oeste usa elevador', () {
      final mob = pacote.perfis['mobilidade']!;
      expect(rotas.calcular(mob, 't_p1', 'p_c'), isNull);
      final r = rotas.calcular(mob, 't_po', 'p_c')!;
      expect(r.tipos, contains('elevador'));
      expect(r.tipos.intersection({'escada', 'escada_rolante', 'esteira'}), isEmpty);
      expect(rotas.entradasComRota(mob, 'p_c').map((x) => x.$1.id).toList(), ['t_po']);
    });

    test('visual prefere escada fixa a escada rolante', () {
      final r = rotas.calcular(pacote.perfis['visual']!, 't_p1', 'p_c')!;
      expect(r.tipos, contains('escada'));
      expect(r.tipos, isNot(contains('escada_rolante')));
    });

    test('trecho não confirmado nunca entra em rota acessível', () {
      final j = jsonDecode(File('assets/pacote_capim_dourado.json').readAsStringSync()) as Map<String, dynamic>;
      (j['arestas'] as List).firstWhere((a) => a['id'] == 'v_elevador')['a_validar'] = true;
      final p2 = Pacote.fromJson(j);
      final s2 = RotaService(p2);
      expect(s2.calcular(p2.perfis['mobilidade']!, 't_po', 'p_c'), isNull);
      expect(s2.calcular(p2.perfis['padrao']!, 't_po', 'p_c'), isNotNull);
    });

    test('sem rota compatível retorna null (elevador indisponível)', () {
      final semElevador = RotaService(pacote, tiposIndisponiveis: {'elevador'});
      expect(semElevador.calcular(pacote.perfis['mobilidade']!, 't_po', 'p_c'), isNull);
    });

    test('sensorial desvia da Praça de Eventos central (paridade com JS e Python)', () {
      final r = rotas.calcular(pacote.perfis['sensorial']!, 't_p1', 'p_c')!;
      expect(r.nos, ['t_p1', 't_s0', 't_sw1', 't_swa', 't_sw2', 't_sw3', 't_esc', 'p_esc', 'p_e', 'p_c']);
      expect(rotas.calcular(pacote.perfis['sensorial']!, 't_p1', 't_rn')!.nos, isNot(contains('t_praca')));
    });
  });

  group('InstrucaoService', () {
    test('PT: entrada P1 → escada rolante → praça de alimentação', () {
      final r = rotas.calcular(pacote.perfis['padrao']!, 't_p1', 'p_c')!;
      final e = InstrucaoService(pacote).gerar(r, poi('poi_praca_alim'), 'pt', nomeEntrada: 'Entrada principal P1');
      expect(e.first.texto, startsWith('Saindo de Entrada principal P1'));
      expect(e.any((x) => x.texto.contains('Pegue a escada rolante e suba até o 2º Piso')), isTrue);
      expect(e.last.icone, 'chegada');
    });

    test('EN: elevador no modo mobilidade', () {
      final r = rotas.calcular(pacote.perfis['mobilidade']!, 't_po', 'p_c')!;
      final e = InstrucaoService(pacote).gerar(r, poi('poi_praca_alim'), 'en', nomeEntrada: 'West access');
      expect(e.any((x) => x.texto.contains('Take the elevator to the 2nd floor')), isTrue);
    });

    test('origem por referência e retas longas divididas', () {
      final r = rotas.calcular(pacote.perfis['padrao']!, 't_rs', 't_sanw2')!;
      final e = InstrucaoService(pacote).gerar(r, poi('poi_pne_oeste'), 'pt');
      expect(e.first.texto, startsWith('Você está na Praça de Eventos central'));
      final longa = rotas.calcular(pacote.perfis['padrao']!, 't_p3', 't_a7')!;
      expect(InstrucaoService(pacote).gerar(longa, poi('poi_cinemark'), 'pt').every((x) => x.distancia <= 90), isTrue);
    });
  });
}
