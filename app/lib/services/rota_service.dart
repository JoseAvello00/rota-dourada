import 'dart:collection';
import 'dart:math' as math;

import '../models/grade.dart';
import '../models/pacote.dart';
import '../models/rota.dart';

/// Cálculo de rotas no próprio celular (offline), a partir do pacote baixado.
/// Mesma regra de web-demo/nucleo.js e api/app/navegacao.py.
class RotaService {
  final Pacote pacote;
  final Map<String, List<Trecho>> _adj = {};

  /// [tiposIndisponiveis]: ex. {'elevador'} quando o pacote informar manutenção.
  RotaService(this.pacote, {Set<String> tiposIndisponiveis = const {}}) {
    for (final id in pacote.nos.keys) {
      _adj[id] = [];
    }
    for (final a in pacote.arestas) {
      if (tiposIndisponiveis.contains(a.tipo)) continue;
      final p = pacote.nos[a.de]!, q = pacote.nos[a.para]!;
      final d = a.distancia ?? math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.y - q.y, 2));
      _adj[a.de]!.add(Trecho(a.id, a.de, a.para, a.tipo, d, a.estimulo, a.confirmado));
      if (a.bidirecional) _adj[a.para]!.add(Trecho(a.id, a.para, a.de, a.tipo, d, a.estimulo, a.confirmado));
    }
  }

  /// Ângulo da curva em [b], em graus. Positivo = direita (y cresce para baixo).
  static double anguloCurva(double ax, double ay, double bx, double by, double cx, double cy) {
    final v1x = bx - ax, v1y = by - ay, v2x = cx - bx, v2y = cy - by;
    return math.atan2(v1x * v2y - v1y * v2x, v1x * v2x + v1y * v2y) * 180 / math.pi;
  }

  bool _curva(String a, String b, String c) {
    final pa = pacote.nos[a]!, pb = pacote.nos[b]!, pc = pacote.nos[c]!;
    if (pa.andar != pb.andar || pb.andar != pc.andar) return false;
    return anguloCurva(pa.x, pa.y, pb.x, pb.y, pc.x, pc.y).abs() > 30;
  }

  /// Dijkstra com estado (nó, anterior) para suportar penalidade de curva.
  /// Retorna null quando não existe rota compatível — nunca relaxa o perfil.
  Rota? calcular(Perfil perfil, String origem, String destino) {
    String chave(String n, String? v) => '$n|${v ?? ''}';
    final melhor = <String, double>{chave(origem, null): 0};
    final anterior = <String, (String, String?, Trecho)>{};
    final fila = SplayTreeSet<(double, int, String, String?)>((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });
    var seq = 0;
    fila.add((0, seq++, origem, null));
    (String, String?)? fim;

    while (fila.isNotEmpty) {
      final atual = fila.first;
      fila.remove(atual);
      final (custo, _, no, veio) = atual;
      if (custo > (melhor[chave(no, veio)] ?? double.infinity)) continue;
      if (no == destino) {
        fim = (no, veio);
        break;
      }
      for (final t in _adj[no]!) {
        if (perfil.proibidos.contains(t.tipo)) continue;
        if (perfil.exigirConfirmado && !t.confirmado) continue; // acessível só com trechos confirmados
        var c = t.distancia * (perfil.multTipo[t.tipo] ?? 1) * (perfil.multEstimulo[t.estimulo] ?? 1);
        if (veio != null && perfil.penalidadeCurva > 0 && _curva(veio, no, t.para)) {
          c += perfil.penalidadeCurva;
        }
        final novo = custo + c;
        final k = chave(t.para, no);
        if (novo < (melhor[k] ?? double.infinity)) {
          melhor[k] = novo;
          anterior[k] = (no, veio, t);
          fila.add((novo, seq++, t.para, no));
        }
      }
    }
    if (fim == null) return null;

    final nos = <String>[fim.$1];
    final trechos = <Trecho>[];
    var k = chave(fim.$1, fim.$2);
    while (anterior.containsKey(k)) {
      final (n, v, t) = anterior[k]!;
      trechos.add(t);
      nos.add(n);
      k = chave(n, v);
    }
    return Rota(nos.reversed.toList(), trechos.reversed.toList(), melhor[chave(fim.$1, fim.$2)]!);
  }

  /// Entradas a partir das quais existe rota compatível com o perfil (alternativas a oferecer).
  List<(No, Rota)> entradasComRota(Perfil perfil, String destino) {
    final out = <(No, Rota)>[];
    for (final n in pacote.nos.values.where((n) => n.tipo == 'entrada')) {
      final r = calcular(perfil, n.id, destino);
      if (r != null) out.add((n, r));
    }
    out.sort((a, b) => a.$2.distancia.compareTo(b.$2.distancia));
    return out;
  }

  // ---------- rotas a partir de posição contínua (beacon + passos) ----------

  /// Liga um ponto do mapa ao trecho de corredor mais próximo que ele enxerga sem obstáculo
  /// (até [raio] m). Devolve o ponto de projeção, o trecho e a distância a cada extremidade.
  ({math.Point<double> ponto, Aresta aresta, double ateDe, double atePara, double aproximacao})? ancorar(
      int andar, math.Point<double> p, {double raio = 8}) {
    final g = pacote.andar(andar).grade;
    ({math.Point<double> ponto, Aresta aresta, double ateDe, double atePara, double aproximacao})? melhor;
    for (final a in pacote.arestas) {
      if (a.geometria.length < 2 || pacote.nos[a.de]!.andar != andar) continue;
      var acum = 0.0;
      final total = _comprimento(a.geometria);
      for (var i = 1; i < a.geometria.length; i++) {
        final (q, t) = projetar(p, a.geometria[i - 1], a.geometria[i]);
        final seg = a.geometria[i - 1].distanceTo(a.geometria[i]);
        final d = q.distanceTo(p);
        if (d <= raio && (melhor == null || d < melhor.aproximacao) && (g == null || g.segmentoLivre(p, q))) {
          final s = acum + t * seg;
          melhor = (ponto: q, aresta: a, ateDe: s, atePara: total - s, aproximacao: d);
        }
        acum += seg;
      }
    }
    return melhor;
  }

  static double _comprimento(List<math.Point<double>> g) {
    var d = 0.0;
    for (var i = 1; i < g.length; i++) {
      d += g[i - 1].distanceTo(g[i]);
    }
    return d;
  }

  /// Rota do ponto atual até a ENTRADA cadastrada do destino: testa as duas extremidades do trecho
  /// de origem e do trecho da entrada e fica com o menor custo. Null = sem rota compatível.
  ({Rota rota, String origemNo, double inicio, double fim})? calcularDoPonto(
      Perfil perfil, int andar, math.Point<double> p, Poi destino) {
    final o = ancorar(andar, p);
    if (o == null) return null;
    final ent = destino.entrada;
    final candidatas = ent == null ? const <Aresta>[] : pacote.arestas.where((a) => a.id == ent.aresta).toList();
    final fins = <(String, double)>[];
    if (ent != null && candidatas.isNotEmpty) {
      final total = _comprimento(candidatas.first.geometria);
      fins
        ..add((candidatas.first.de, ent.t * total))
        ..add((candidatas.first.para, (1 - ent.t) * total));
    } else {
      fins.add((destino.no, 0));
    }
    ({Rota rota, String origemNo, double inicio, double fim})? melhor;
    for (final (no0, d0) in [(o.aresta.de, o.ateDe), (o.aresta.para, o.atePara)]) {
      if (perfil.exigirConfirmado && !o.aresta.confirmado) continue;
      for (final (no1, d1) in fins) {
        final r = calcular(perfil, no0, no1);
        if (r == null) continue;
        final custo = r.custo + o.aproximacao + d0 + d1;
        if (melhor == null || custo < melhor.rota.custo + melhor.inicio + melhor.fim) {
          melhor = (rota: r, origemNo: no0, inicio: o.aproximacao + d0, fim: d1);
        }
      }
    }
    return melhor;
  }

  /// Polilinha da rota no [andar] (geometria verificada de cada trecho, na direção percorrida).
  List<math.Point<double>> polilinha(Rota r, int andar) {
    final out = <math.Point<double>>[];
    for (final t in r.trechos) {
      final a = pacote.arestas.firstWhere((x) => x.id == t.id);
      if (pacote.nos[t.de]!.andar != andar || pacote.nos[t.para]!.andar != andar) continue;
      final g = a.geometria.isNotEmpty
          ? (a.de == t.de ? a.geometria : a.geometria.reversed.toList())
          : [math.Point(pacote.nos[t.de]!.x, pacote.nos[t.de]!.y), math.Point(pacote.nos[t.para]!.x, pacote.nos[t.para]!.y)];
      out.addAll(out.isEmpty ? g : g.skip(1));
    }
    return out;
  }
}
