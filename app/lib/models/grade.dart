import 'dart:math' as math;

/// Área de circulação do andar em células de [celula] m (1 = corredor/passagem livre).
/// Gerada das camadas de parede, vitrine, pilar e quiosque da planta; usada para
/// map matching da posição e para conferir que nenhuma rota sai da circulação.
class GradeCirculacao {
  final double celula;
  final int colunas, linhas;
  final List<List<bool>> _bits;

  GradeCirculacao(this.celula, this.colunas, this.linhas, this._bits);

  factory GradeCirculacao.fromJson(Map<String, dynamic> j) {
    final bits = <List<bool>>[];
    for (final linha in j['rle'] as List) {
      final out = <bool>[];
      var v = false;
      for (final n in linha as List) {
        out.addAll(List.filled(n as int, v));
        v = !v;
      }
      bits.add(out);
    }
    return GradeCirculacao((j['celula_m'] as num).toDouble(), j['colunas'] as int, j['linhas'] as int, bits);
  }

  bool livre(double x, double y) {
    final l = (y / celula).floor(), c = (x / celula).floor();
    return l >= 0 && l < linhas && c >= 0 && c < colunas && _bits[l][c];
  }

  bool segmentoLivre(math.Point<double> a, math.Point<double> b, {double passo = 0.25}) {
    final n = math.max(1, (a.distanceTo(b) / passo).ceil());
    for (var i = 0; i <= n; i++) {
      if (!livre(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n)) return false;
    }
    return true;
  }

  /// Centro da célula livre mais próxima dentro de [raio] m, ou null.
  math.Point<double>? maisProxima(double x, double y, double raio) {
    final l0 = (y / celula).floor(), c0 = (x / celula).floor(), r = (raio / celula).ceil();
    math.Point<double>? melhor;
    var dMelhor = double.infinity;
    for (var l = math.max(0, l0 - r); l <= math.min(linhas - 1, l0 + r); l++) {
      for (var c = math.max(0, c0 - r); c <= math.min(colunas - 1, c0 + r); c++) {
        if (!_bits[l][c]) continue;
        final p = math.Point((c + .5) * celula, (l + .5) * celula);
        final d = p.distanceTo(math.Point(x, y));
        if (d <= raio && d < dMelhor) {
          dMelhor = d;
          melhor = p;
        }
      }
    }
    return melhor;
  }
}

/// Projeção de [p] no segmento a–b: (ponto, fração t).
(math.Point<double>, double) projetar(math.Point<double> p, math.Point<double> a, math.Point<double> b) {
  final vx = b.x - a.x, vy = b.y - a.y, l2 = vx * vx + vy * vy;
  final t = l2 == 0 ? 0.0 : (((p.x - a.x) * vx + (p.y - a.y) * vy) / l2).clamp(0.0, 1.0);
  return (math.Point(a.x + vx * t, a.y + vy * t), t);
}

/// Distância de [p] a uma polilinha.
double distanciaPolilinha(math.Point<double> p, List<math.Point<double>> pts) {
  var d = double.infinity;
  for (var i = 1; i < pts.length; i++) {
    d = math.min(d, projetar(p, pts[i - 1], pts[i]).$1.distanceTo(p));
  }
  return pts.length == 1 ? p.distanceTo(pts.first) : d;
}
