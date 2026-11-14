import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/pacote.dart';
import 'motor_posicao.dart';

/// Liga sensores (reais ou simulados) ao [MotorPosicao] e emite a posição ~1 Hz.
abstract class FontePosicao {
  Stream<PosicaoAtual> iniciar(MotorPosicao motor);
  Future<void> parar();
  bool get simulacao;
}

/// Detector de passos: pico de |aceleração| acima de 11,2 m/s² com intervalo mínimo de 300 ms.
class DetectorPassos {
  double _filtrado = 9.81;
  bool _acima = false;
  DateTime? _ultimo;
  bool novaAmostra(double ax, double ay, double az, DateTime t) {
    final m = math.sqrt(ax * ax + ay * ay + az * az);
    _filtrado = _filtrado * .8 + m * .2;
    if (!_acima && _filtrado > 11.2 && (_ultimo == null || t.difference(_ultimo!).inMilliseconds > 300)) {
      _acima = true;
      _ultimo = t;
      return true;
    }
    if (_filtrado < 10.2) _acima = false;
    return false;
  }
}

class FonteSensoresReais implements FontePosicao {
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _tick;
  double? _rumo;
  final _passos = DetectorPassos();

  @override
  bool get simulacao => false;

  @override
  Stream<PosicaoAtual> iniciar(MotorPosicao motor) {
    final saida = StreamController<PosicaoAtual>();
    () async {
      final perm = await [Permission.bluetoothScan, Permission.locationWhenInUse].request();
      if (perm.values.any((s) => !s.isGranted)) {
        motor.equipamentoIndisponivel('permissão de Bluetooth/localização negada');
      } else if (!await FlutterBluePlus.isSupported) {
        motor.equipamentoIndisponivel('aparelho sem Bluetooth LE');
      }
      _subs.add(FlutterBluePlus.adapterState.listen((s) {
        motor.equipamentoIndisponivel(s == BluetoothAdapterState.on ? null : 'Bluetooth desligado');
        if (s == BluetoothAdapterState.on) {
          FlutterBluePlus.startScan(continuousUpdates: true, removeIfGone: const Duration(seconds: 4));
        }
      }));
      _subs.add(FlutterBluePlus.onScanResults.listen((rs) {
        final agora = DateTime.now();
        for (final r in rs) {
          final chave = chaveIBeacon(r.advertisementData.manufacturerData[0x004C]);
          if (chave != null) motor.leituraBle(chave, r.rssi, agora);
        }
      }));
      _subs.add(FlutterCompass.events?.listen((e) => _rumo = e.heading) ?? const Stream<void>.empty().listen(null));
      _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
        final t = DateTime.now();
        if (_passos.novaAmostra(e.x, e.y, e.z, t) && _rumo != null) motor.passo(t, _rumo!);
      }));
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => saida.add(motor.processar(DateTime.now())));
    }();
    return saida.stream;
  }

  @override
  Future<void> parar() async {
    _tick?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await FlutterBluePlus.stopScan();
  }
}

/// Anúncio iBeacon (Apple 0x004C): 02 15 + UUID(16) + major(2) + minor(2) + txPower(1).
String? chaveIBeacon(List<int>? d) {
  if (d == null || d.length < 23 || d[0] != 0x02 || d[1] != 0x15) return null;
  final h = d.sublist(2, 18).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final uuid = '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  return '$uuid:${(d[18] << 8) | d[19]}:${(d[20] << 8) | d[21]}';
}

/// MODO SIMULAÇÃO (identificado na interface). Caminha a 1,2 m/s por uma polilinha do mapa e gera
/// RSSI pelo mesmo modelo log-distância (+ruído gaussiano σ=4 dB, 15% de pacotes perdidos) e passos
/// com rumo ruidoso (σ=8°). Permite ensaiar `perdas` (intervalos sem nenhum beacon).
class FonteSimulada implements FontePosicao {
  final List<math.Point<double>> caminho;
  final int andar;
  final List<(Duration, Duration)> perdas;
  final double desvioRumo;
  final _rnd = math.Random(7);
  Timer? _tick;
  FonteSimulada(this.caminho, this.andar, {this.perdas = const [], this.desvioRumo = 8});

  @override
  bool get simulacao => true;

  double _gauss() => math.sqrt(-2 * math.log(1 - _rnd.nextDouble())) * math.cos(2 * math.pi * _rnd.nextDouble());

  @override
  Stream<PosicaoAtual> iniciar(MotorPosicao motor) {
    final saida = StreamController<PosicaoAtual>();
    final inicio = DateTime.now();
    var percorrido = 0.0;
    motor.definirInicial(andar, caminho.first.x, caminho.first.y, inicio, fonte: 'simulacao');
    _tick = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final agora = DateTime.now();
      percorrido += .6; // 0,5 s a 1,2 m/s
      final (p, rumoMapa) = pontoEm(caminho, percorrido);
      final norte = motor.pacote.andar(andar).norteMapaGraus;
      motor.passo(agora, rumoMapa - norte + _gauss() * desvioRumo, comprimento: .6);
      final dt = agora.difference(inicio);
      final semSinal = perdas.any((x) => dt >= x.$1 && dt < x.$2);
      if (!semSinal) {
        for (final b in motor.beacons.where((b) => b.andar == andar)) {
          final d = math.max(.5, p.distanceTo(math.Point(b.x, b.y)));
          if (d > 20 || _rnd.nextDouble() < .15) continue;
          final rssi = b.rssi1m - 10 * b.expoente * math.log(d) / math.ln10 + _gauss() * 4;
          motor.leituraBle(b.chave, rssi.round(), agora);
        }
      }
      if (t.tick.isEven) saida.add(motor.processar(agora));
    });
    return saida.stream;
  }

  @override
  Future<void> parar() async => _tick?.cancel();
}

/// Ponto a [s] metros ao longo da polilinha e o rumo do segmento no mapa (graus a partir de "cima").
(math.Point<double>, double) pontoEm(List<math.Point<double>> pts, double s) {
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i - 1].distanceTo(pts[i]);
    final rumo = math.atan2(pts[i].x - pts[i - 1].x, -(pts[i].y - pts[i - 1].y)) * 180 / math.pi;
    if (s <= seg || i == pts.length - 1) {
      final t = seg == 0 ? 1.0 : math.min(1.0, s / seg);
      return (math.Point(pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t, pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t), rumo);
    }
    s -= seg;
  }
  return (pts.last, 0);
}

/// Beacons virtuais a cada [espacamento] m ao longo dos corredores (só para simulação):
/// mostra o comportamento com a densidade recomendada antes da instalação real.
List<Beacon> beaconsVirtuais(Pacote p, {double espacamento = 10}) {
  final out = <Beacon>[];
  var n = 0;
  for (final e in p.arestas.where((e) => e.geometria.length > 1)) {
    final andar = p.nos[e.de]!.andar;
    for (var i = 1; i < e.geometria.length; i++) {
      final a = e.geometria[i - 1], b = e.geometria[i], seg = a.distanceTo(b);
      for (var s = 0.0; s < seg; s += espacamento) {
        final t = s / seg;
        out.add(Beacon.fromJson({
          'id': 'sim-${n++}', 'uuid': 'sim', 'major': 0, 'minor': n, 'andar': andar,
          'x': a.x + (b.x - a.x) * t, 'y': a.y + (b.y - a.y) * t, 'status': 'simulado',
        }));
      }
    }
  }
  return out;
}
