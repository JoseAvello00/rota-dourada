import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/pacote.dart';
import '../../models/rota.dart';
import '../tema.dart';

/// Mapa da navegação passo a passo: planta do andar enquadrada no trecho da rota,
/// fio dourado e posição estimada. Coordenadas em metros.
class MapaPainter extends CustomPainter {
  final Pacote pacote;
  final Rota rota;
  final Rota? rotaPadrao;
  final Poi destino;
  final int andar;
  final String posicao;
  final String idioma;
  final bool altoContraste;
  final ui.Image? planta;
  final PaletaMapa paleta;

  MapaPainter({
    required this.pacote,
    required this.rota,
    required this.destino,
    required this.andar,
    required this.posicao,
    required this.idioma,
    this.rotaPadrao,
    this.altoContraste = false,
    this.planta,
    PaletaMapa? paleta,
  }) : paleta = paleta ?? PaletaMapa.de('claro', altoContraste: altoContraste);

  Rect _enquadramento(double proporcao) {
    final a = pacote.andar(andar);
    final pts = <Offset>[
      for (final id in rota.nos)
        if (pacote.nos[id]!.andar == andar) Offset(pacote.nos[id]!.x, pacote.nos[id]!.y),
      if (destino.andar == andar) Offset(destino.x, destino.y),
    ];
    if (pts.isEmpty) return Rect.fromLTWH(0, 0, a.largura, a.largura / proporcao);
    const pad = 15.0;
    final x0 = pts.map((p) => p.dx).reduce(math.min) - pad, x1 = pts.map((p) => p.dx).reduce(math.max) + pad;
    final y0 = pts.map((p) => p.dy).reduce(math.min) - pad, y1 = pts.map((p) => p.dy).reduce(math.max) + pad;
    var w = math.max(x1 - x0, 60.0);
    var h = math.max(y1 - y0, w / proporcao);
    w = math.max(w, h * proporcao);
    return Rect.fromCenter(center: Offset((x0 + x1) / 2, (y0 + y1) / 2), width: w, height: h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vista = _enquadramento(size.width / size.height);
    final escala = size.width / vista.width;
    final px = 1 / escala;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(escala);
    canvas.translate(-vista.left, -vista.top);

    final a = pacote.andar(andar);
    final area = Rect.fromLTWH(0, 0, a.largura, a.altura);
    canvas.drawRect(vista.inflate(50), Paint()..color = paleta.fundo);
    if (planta != null) {
      canvas.drawImageRect(planta!, Rect.fromLTWH(0, 0, planta!.width.toDouble(), planta!.height.toDouble()), area,
          Paint()..color = Colors.white.withOpacity(altoContraste ? .55 : 1)..filterQuality = FilterQuality.medium);
    }

    Path linha(Rota r) {
      final path = Path();
      var primeiro = true;
      for (final id in r.nos) {
        final n = pacote.nos[id]!;
        if (n.andar != andar) continue;
        if (primeiro) {
          path.moveTo(n.x, n.y);
        } else {
          path.lineTo(n.x, n.y);
        }
        primeiro = false;
      }
      return path;
    }

    if (rotaPadrao != null && rotaPadrao!.nos.join() != rota.nos.join()) {
      canvas.drawPath(linha(rotaPadrao!), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * px
        ..color = paleta.padrao.withOpacity(.8));
    }
    final caminho = linha(rota);
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(caminho, traco..strokeWidth = 10 * px..color = paleta.rotaBorda);
    canvas.drawPath(caminho, traco..strokeWidth = 6 * px..color = paleta.rota);

    if (destino.andar == andar) {
      canvas.drawCircle(Offset(destino.x, destino.y), 11 * px, Paint()..color = paleta.rota);
      canvas.drawCircle(Offset(destino.x, destino.y), 11 * px,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5 * px..color = paleta.rotaBorda);
      final tp = TextPainter(
        text: TextSpan(
            text: destino.nome(idioma),
            style: TextStyle(
              fontSize: 13 * px,
              fontWeight: FontWeight.w700,
              color: paleta.rotulo,
              shadows: [for (final o in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) Shadow(color: paleta.contorno, offset: o * px)],
            )),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(destino.x - tp.width / 2, destino.y + 14 * px));
    }

    final aqui = pacote.nos[posicao]!;
    if (aqui.andar == andar) {
      final azul = paleta.voce;
      canvas.drawCircle(Offset(aqui.x, aqui.y), 16 * px, Paint()..color = azul.withOpacity(.3));
      canvas.drawCircle(Offset(aqui.x, aqui.y), 8 * px, Paint()..color = azul);
      canvas.drawCircle(Offset(aqui.x, aqui.y), 8 * px, Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * px..color = paleta.contorno);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MapaPainter old) =>
      old.posicao != posicao || old.andar != andar || old.rota != rota || old.idioma != idioma || old.planta != planta || old.paleta != paleta;
}
