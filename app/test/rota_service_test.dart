import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rota_dourada/models/pacote.dart';
import 'package:rota_dourada/models/rota.dart';
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

    test('mobilidade: chega ao 2º piso pelo elevador atrás da Renner', () {
      final r = rotas.calcular(pacote.perfis['mobilidade']!, 't_p1', 'p_c')!;
      expect(r.tipos, contains('elevador'));
      expect(r.semEscadas, isTrue);
      expect(r.nos, containsAll(['t_rp', 't_elev', 'p_elev']));
    });



    test('visual prefere escada fixa a escada rolante', () {
      final r = rotas.calcular(pacote.perfis['visual']!, 't_p1', 'p_c')!;
      expect(r.tipos, contains('escada'));
      expect(r.tipos, isNot(contains('escada_rolante')));
    });

    test('trecho não confirmado nunca entra em rota acessível', () {
      final base = rotas.calcular(pacote.perfis['mobilidade']!, 't_p1', 't_rn')!;
      final alvo = base.trechos[1].id;
      final j = jsonDecode(File('assets/pacote_capim_dourado.json').readAsStringSync()) as Map<String, dynamic>;
      (j['arestas'] as List).firstWhere((a) => a['id'] == alvo)['a_validar'] = true;
      final p2 = Pacote.fromJson(j);
      final r = RotaService(p2).calcular(p2.perfis['mobilidade']!, 't_p1', 't_rn');
      expect(r == null || !r.trechos.any((t) => t.id == alvo), isTrue);
    });


    test('sem rota compatível retorna null (sem escadas rolantes nem escada)', () {
      final semEscadas = RotaService(pacote, tiposIndisponiveis: {'escada', 'escada_rolante'});
      expect(semEscadas.calcular(pacote.perfis['padrao']!, 't_p1', 'p_c'), isNull);
    });


    test('sensorial reduz o trecho em áreas de estímulo alto', () {
      double alto(Rota r) => r.trechos.where((t) => t.estimulo == 'alto').fold(0.0, (s, t) => s + t.distancia);
      final pad = rotas.calcular(pacote.perfis['padrao']!, 't_p1', 't_rn')!;
      final sen = rotas.calcular(pacote.perfis['sensorial']!, 't_p1', 't_rn')!;
      expect(alto(sen), lessThan(alto(pad)));
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

    test('EN: escada rolante no perfil padrão', () {
      final r = rotas.calcular(pacote.perfis['padrao']!, 't_p1', 'p_c')!;
      final e = InstrucaoService(pacote).gerar(r, poi('poi_praca_alim'), 'en', nomeEntrada: 'Main entrance P1');
      expect(e.any((x) => x.texto.contains('Take the escalator up to the 2nd floor')), isTrue);
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
