import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rota_dourada/models/pacote.dart';
import 'package:rota_dourada/services/posicao/fontes.dart';
import 'package:rota_dourada/services/posicao/motor_posicao.dart';
import 'package:rota_dourada/services/rota_service.dart';

void main() {
  late Pacote pacote;
  late List<Beacon> virtuais;
  setUpAll(() {
    pacote = Pacote.fromJson(
        jsonDecode(File('assets/pacote_capim_dourado.json').readAsStringSync()) as Map<String, dynamic>);
    virtuais = beaconsVirtuais(pacote);
  });

  int rssi(Beacon b, math.Point<double> p) =>
      (b.rssi1m - 10 * b.expoente * math.log(math.max(.5, p.distanceTo(math.Point(b.x, b.y)))) / math.ln10).round();

  test('trilateração com beacons próximos fica dentro da área de circulação e com erro baixo', () {
    final m = MotorPosicao(pacote, extras: virtuais);
    final no = pacote.nos['t_sw2']!;
    final real = math.Point(no.x, no.y);
    final t0 = DateTime(2026, 11, 14, 10);
    for (var i = 0; i < 4; i++) {
      for (final b in virtuais.where((b) => b.andar == 0 && b.x.isFinite)) {
        if (real.distanceTo(math.Point(b.x, b.y)) < 14) m.leituraBle(b.chave, rssi(b, real), t0.add(Duration(milliseconds: 200 * i)));
      }
    }
    final p = m.processar(t0.add(const Duration(seconds: 1)));
    expect(p.estado, EstadoPosicao.ok);
    expect(p.ponto.distanceTo(real), lessThan(3));
    expect(pacote.andar(0).grade!.livre(p.x, p.y), isTrue);
  });

  test('perda de sinal: sem beacon há 6 s = semSinal; há 21 s = indisponível (nunca "ok")', () {
    final m = MotorPosicao(pacote, extras: virtuais);
    final no = pacote.nos['t_sw2']!;
    final t0 = DateTime(2026, 11, 14, 10);
    m.definirInicial(0, no.x, no.y, t0);
    expect(m.processar(t0.add(const Duration(seconds: 6))).estado, EstadoPosicao.semSinal);
    expect(m.processar(t0.add(const Duration(seconds: 21))).estado, EstadoPosicao.indisponivel);
  });

  test('Bluetooth desligado sem posição anterior = indisponível com motivo', () {
    final m = MotorPosicao(pacote)..equipamentoIndisponivel('Bluetooth desligado');
    final p = m.processar(DateTime(2026));
    expect(p.estado, EstadoPosicao.indisponivel);
    expect(p.motivo, 'Bluetooth desligado');
  });

  test('passos não atravessam parede: posição continua na área de circulação', () {
    final m = MotorPosicao(pacote);
    final no = pacote.nos['t_sw2']!;
    final t0 = DateTime(2026, 11, 14, 10);
    m.definirInicial(0, no.x, no.y, t0);
    for (var i = 0; i < 60; i++) {
      m.passo(t0.add(Duration(milliseconds: 500 * i)), 0); // 42 m para o norte, rumo fixo
    }
    final p = m.processar(t0.add(const Duration(seconds: 2)));
    expect(pacote.andar(0).grade!.livre(p.x, p.y), isTrue);
  });

  test('rota a partir de um ponto termina na entrada cadastrada e segue só pela circulação', () {
    final s = RotaService(pacote);
    final no = pacote.nos['t_sw2']!;
    final destino = pacote.pois.firstWhere((p) => p.entrada != null && p.andar == 0 && p.id != 'poi_renner');
    final r = s.calcularDoPonto(pacote.perfis['padrao']!, 0, math.Point(no.x, no.y), destino)!;
    expect([r.rota.nos.last], anyOf(contains(pacote.arestas.firstWhere((a) => a.id == destino.entrada!.aresta).de),
        contains(pacote.arestas.firstWhere((a) => a.id == destino.entrada!.aresta).para)));
    final g = pacote.andar(0).grade!;
    final linha = s.polilinha(r.rota, 0);
    for (var i = 1; i < linha.length; i++) {
      expect(g.segmentoLivre(linha[i - 1], linha[i]), isTrue, reason: 'segmento $i');
    }
  });

  test('anúncio iBeacon vira uuid:major:minor', () {
    final dados = [0x02, 0x15, ...List.generate(16, (i) => i), 0x00, 0x01, 0x00, 0x2A, 0xC5];
    expect(chaveIBeacon(dados), '00010203-0405-0607-0809-0a0b0c0d0e0f:1:42');
    expect(chaveIBeacon([0x01, 0x02]), isNull);
  });
}
