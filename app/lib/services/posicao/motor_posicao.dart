import 'dart:math' as math;

import '../../models/pacote.dart';

/// ok: posição atual confiável · imprecisa: erro > 5 m · semSinal: sem beacon há > 5 s (só passos)
/// indisponivel: sem dados confiáveis (erro > 10 m, > 20 s sem beacon ou equipamento desligado).
enum EstadoPosicao { aguardando, ok, imprecisa, semSinal, indisponivel }

class PosicaoAtual {
  final int andar;
  final double x, y, erro; // metros; erro = raio de ~1 desvio-padrão
  final EstadoPosicao estado;
  final String fonte; // ble | passos | manual | simulacao
  final String? motivo;
  const PosicaoAtual(this.andar, this.x, this.y, this.erro, this.estado, this.fonte, [this.motivo]);
  math.Point<double> get ponto => math.Point(x, y);
  bool get confiavel => estado == EstadoPosicao.ok || estado == EstadoPosicao.imprecisa;
}

/// Fusão local (no aparelho, offline) de RSSI de beacons BLE + passos (PDR) com map matching
/// na grade de circulação. Puro Dart: recebe leituras com o horário, não acessa sensores.
class MotorPosicao {
  final Pacote pacote;
  final Map<String, Beacon> _porChave;
  /// [extras]: beacons virtuais do modo simulação (nunca usados com sensores reais).
  MotorPosicao(this.pacote, {List<Beacon> extras = const []})
      : _porChave = {for (final b in [...pacote.beacons.where((b) => b.instalado), ...extras]) b.chave: b};

  Iterable<Beacon> get beacons => _porChave.values;

  static const janela = Duration(seconds: 3), semSinalApos = Duration(seconds: 5), perdidoApos = Duration(seconds: 20);
  static const alcanceMax = 15.0, histereseAndar = 3, erroImpreciso = 5.0, erroMaximo = 10.0;

  double? _x, _y;
  double _var = 0; // variância (m²)
  int? _andar;
  String _fonte = 'ble';
  DateTime? _ultimoFix;
  String? _equipamento; // motivo de indisponibilidade do hardware
  final _rssi = <String, List<(DateTime, int)>>{};
  int? _andarCandidato;
  int _votos = 0, _outliers = 0;
  double offsetRumo = 0; // ajuste de bússola aprendido (interferência magnética local)
  double declinacao = 0; // declinação magnética do local (graus, configurável)

  bool get temBeacons => _porChave.isNotEmpty;

  void equipamentoIndisponivel(String? motivo) => _equipamento = motivo;

  /// Ponto conhecido escolhido pelo visitante (toque no mapa / QR): ancora a posição.
  void definirInicial(int andar, double x, double y, DateTime t, {double erro = 1.5, String fonte = 'manual'}) {
    _andar = andar;
    _x = x;
    _y = y;
    _var = erro * erro;
    _ultimoFix = t;
    _fonte = fonte;
    _outliers = 0;
  }

  void leituraBle(String chave, int rssi, DateTime t) {
    if (!_porChave.containsKey(chave) || rssi >= 0 || rssi < -105) return;
    (_rssi[chave] ??= []).add((t, rssi));
  }

  /// Distância pelo modelo log-distância, com RSSI mediano da janela (corta picos de multipercurso).
  List<(Beacon, double)> _alcances(DateTime agora) {
    final out = <(Beacon, double)>[];
    _rssi.forEach((k, l) {
      l.removeWhere((e) => agora.difference(e.$1) > janela);
      if (l.length < 2) return; // um único pacote não basta
      final v = l.map((e) => e.$2).toList()..sort();
      final med = v[v.length ~/ 2];
      final b = _porChave[k]!;
      final d = math.pow(10, (b.rssi1m - med) / (10 * b.expoente)).toDouble();
      if (d <= alcanceMax) out.add((b, d));
    });
    out.sort((a, b) => a.$2.compareTo(b.$2));
    return out;
  }

  /// Andar por voto ponderado (1/d) com histerese: só troca após [histereseAndar] ciclos seguidos.
  int? _decidirAndar(List<(Beacon, double)> al) {
    final peso = <int, double>{};
    for (final (b, d) in al) {
      peso[b.andar] = (peso[b.andar] ?? 0) + 1 / math.max(d, .5);
    }
    if (peso.isEmpty) return _andar;
    final melhor = peso.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    if (_andar == null) return melhor;
    if (melhor == _andar) {
      _votos = 0;
      return _andar;
    }
    _votos = _andarCandidato == melhor ? _votos + 1 : 1;
    _andarCandidato = melhor;
    return _votos >= histereseAndar ? melhor : _andar;
  }

  /// Trilateração por mínimos quadrados ponderados (Gauss-Newton) a partir do centroide.
  (double, double, double)? _fix(List<(Beacon, double)> al) {
    if (al.isEmpty) return null;
    final usados = al.take(4).toList();
    var wx = 0.0, wy = 0.0, ws = 0.0;
    for (final (b, d) in usados) {
      final w = 1 / (d * d + .1);
      wx += b.x * w;
      wy += b.y * w;
      ws += w;
    }
    var x = wx / ws, y = wy / ws;
    if (usados.length == 1) return (usados[0].$1.x, usados[0].$1.y, usados[0].$2 + 2);
    if (usados.length == 2) return (x, y, math.max(usados[0].$2, usados[1].$2) * .7 + 2);
    for (var it = 0; it < 8; it++) {
      var a11 = 0.0, a12 = 0.0, a22 = 0.0, b1 = 0.0, b2 = 0.0;
      for (final (b, d) in usados) {
        final dx = x - b.x, dy = y - b.y, r = math.max(math.sqrt(dx * dx + dy * dy), .3);
        final jx = dx / r, jy = dy / r, res = r - d, w = 1 / (d * d + .1);
        a11 += w * jx * jx;
        a12 += w * jx * jy;
        a22 += w * jy * jy;
        b1 += w * jx * res;
        b2 += w * jy * res;
      }
      final det = a11 * a22 - a12 * a12;
      if (det.abs() < 1e-9) break;
      x -= (a22 * b1 - a12 * b2) / det;
      y -= (a11 * b2 - a12 * b1) / det;
    }
    var rms = 0.0;
    for (final (b, d) in usados) {
      rms += math.pow(math.sqrt(math.pow(x - b.x, 2) + math.pow(y - b.y, 2)) - d, 2);
    }
    return (x, y, math.sqrt(rms / usados.length) + 1.5);
  }

  /// Um passo detectado pelo acelerômetro, com rumo magnético da bússola (graus, horário a partir do norte).
  void passo(DateTime t, double rumoMagnetico, {double comprimento = .7}) {
    if (_x == null || _andar == null) return;
    final andar = pacote.andar(_andar!);
    final a = (andar.norteMapaGraus + rumoMagnetico + declinacao + offsetRumo) * math.pi / 180;
    final nx = _x! + comprimento * math.sin(a), ny = _y! - comprimento * math.cos(a);
    final g = andar.grade;
    final de = math.Point(_x!, _y!);
    if (g == null || g.segmentoLivre(de, math.Point(nx, ny), passo: .1)) {
      _x = nx;
      _y = ny;
    } else if (g.segmentoLivre(de, math.Point(nx, _y!), passo: .1)) {
      _x = nx; // desliza ao longo da parede
    } else if (g.segmentoLivre(de, math.Point(_x!, ny), passo: .1)) {
      _y = ny;
    }
    // incerteza cresce ~10% do passo + 10° de rumo
    _var += math.pow(.1 * comprimento, 2) + math.pow(comprimento * math.sin(10 * math.pi / 180), 2);
    if (_fonte != 'simulacao') _fonte = 'passos';
  }

  /// Rodar ~1 Hz: consome as leituras da janela e devolve a posição a mostrar.
  PosicaoAtual processar(DateTime agora) {
    if (_equipamento != null && _x == null) {
      return PosicaoAtual(_andar ?? 0, 0, 0, double.infinity, EstadoPosicao.indisponivel, 'ble', _equipamento);
    }
    final al = _alcances(agora);
    final andar = _decidirAndar(al);
    final mesmos = al.where((e) => e.$1.andar == andar).toList();
    final f = _fix(mesmos);
    if (f != null && andar != null) {
      final (fx, fy, erroFix) = f;
      if (_x == null || andar != _andar) {
        _andar = andar;
        _x = fx;
        _y = fy;
        _var = erroFix * erroFix;
      } else {
        final dt = agora.difference(_ultimoFix ?? agora).inMilliseconds / 1000;
        final salto = math.sqrt(math.pow(fx - _x!, 2) + math.pow(fy - _y!, 2));
        final limite = 3 * math.sqrt(_var) + 1.5 * dt + 5; // 1,5 m/s é passo rápido
        if (salto > limite && ++_outliers < 3) {
          return _emitir(agora);
        }
        _outliers = 0;
        final k = _var / (_var + erroFix * erroFix);
        _x = _x! + k * (fx - _x!);
        _y = _y! + k * (fy - _y!);
        _var = (1 - k) * _var;
      }
      _ultimoFix = agora;
      if (_fonte != 'simulacao') _fonte = 'ble';
    }
    _encaixar();
    return _emitir(agora);
  }

  /// Map matching: posição sempre numa célula de circulação (até 3 m); se não houver, fica imprecisa.
  void _encaixar() {
    final g = _andar == null ? null : pacote.andar(_andar!).grade;
    if (g == null || _x == null || g.livre(_x!, _y!)) return;
    final p = g.maisProxima(_x!, _y!, 3);
    if (p != null) {
      _var += math.pow(p.distanceTo(math.Point(_x!, _y!)), 2) / 4;
      _x = p.x;
      _y = p.y;
    } else {
      _var = math.max(_var, erroImpreciso * erroImpreciso * 1.1);
    }
  }

  PosicaoAtual _emitir(DateTime agora) {
    if (_x == null) {
      return PosicaoAtual(_andar ?? 0, 0, 0, double.infinity, EstadoPosicao.aguardando, _fonte,
          temBeacons ? 'procurando beacons' : 'nenhum beacon instalado no pacote');
    }
    final erro = math.sqrt(_var);
    final semFix = _ultimoFix == null ? perdidoApos : agora.difference(_ultimoFix!);
    final EstadoPosicao e;
    String? motivo = _equipamento;
    if (_equipamento != null || semFix >= perdidoApos || erro > erroMaximo) {
      e = EstadoPosicao.indisponivel;
      motivo ??= semFix >= perdidoApos ? 'sem sinal de beacon' : 'incerteza acima de ${erroMaximo.round()} m';
    } else if (semFix >= semSinalApos) {
      e = EstadoPosicao.semSinal;
    } else if (erro > erroImpreciso) {
      e = EstadoPosicao.imprecisa;
    } else {
      e = EstadoPosicao.ok;
    }
    return PosicaoAtual(_andar!, _x!, _y!, erro, e, _fonte, motivo);
  }

  /// Calibra o rumo com dois fixes de beacon bons (> 8 m entre si) e o rumo médio dos passos entre eles.
  void calibrarRumo(math.Point<double> de, math.Point<double> para, double rumoMedioPassos) {
    if (de.distanceTo(para) < 8 || _andar == null) return;
    final mapa = math.atan2(para.x - de.x, -(para.y - de.y)) * 180 / math.pi; // horário a partir de "cima"
    final previsto = pacote.andar(_andar!).norteMapaGraus + rumoMedioPassos + declinacao;
    final erro = ((mapa - previsto + 540) % 360) - 180;
    offsetRumo = offsetRumo * .7 + erro * .3;
  }
}
