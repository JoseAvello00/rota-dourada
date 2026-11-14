import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/pacote.dart';
import '../../models/rota.dart';
import '../tema.dart';

/// Escala do mapa ampliável: 1 metro = [escalaMapa] px lógicos (antes do zoom).
const escalaMapa = 6.0;

const coresCategoria = <String, Color>{
  'loja': Color(0xFF1F3B2D),
  'alimentacao': Color(0xFFB4442E),
  'sanitario': Color(0xFF2D5DA8),
  'servico': Color(0xFF6B4FA0),
  'lazer': Color(0xFF9A6B0C),
};

const iconesCategoria = <String, IconData>{
  'loja': Icons.shopping_bag,
  'alimentacao': Icons.restaurant,
  'sanitario': Icons.wc,
  'servico': Icons.info,
  'lazer': Icons.star,
};

/// Desenha a planta do andar, a rota (fio dourado), as lojas e "você está aqui".
/// Coordenadas em metros; pinos e traços mantêm tamanho constante na tela.
class MapaExplorarPainter extends CustomPainter {
  final Pacote pacote;
  final int andar;
  final ui.Image? planta;
  final String idioma;
  final String? posicao;
  final bool posicaoConfirmada;
  final Poi? selecionado;
  final Set<String>? destacados;
  final Rota? rota, rotaPadrao;
  final bool altoContraste;
  final double zoom; // escala atual do InteractiveViewer
  final PaletaMapa paleta;

  MapaExplorarPainter({
    required this.pacote,
    required this.andar,
    required this.idioma,
    this.planta,
    this.posicao,
    this.posicaoConfirmada = false,
    this.selecionado,
    this.destacados,
    this.rota,
    this.rotaPadrao,
    this.altoContraste = false,
    this.zoom = 1,
    PaletaMapa? paleta,
  }) : paleta = paleta ?? PaletaMapa.de('claro', altoContraste: altoContraste);

  @override
  void paint(Canvas canvas, Size size) {
    final a = pacote.andar(andar);
    canvas.save();
    canvas.scale(escalaMapa);
    final px = 1 / (escalaMapa * zoom); // metros por pixel de tela
    final hc = altoContraste, pal = paleta;

    final area = Rect.fromLTWH(0, 0, a.largura, a.altura);
    canvas.drawRect(area, Paint()..color = pal.fundo);
    if (planta != null) {
      final src = Rect.fromLTWH(0, 0, planta!.width.toDouble(), planta!.height.toDouble());
      canvas.drawImageRect(planta!, src, area,
          Paint()..color = Colors.white.withOpacity(hc ? .55 : 1)..filterQuality = FilterQuality.medium);
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

    if (rota != null) {
      if (rotaPadrao != null && rotaPadrao!.nos.join() != rota!.nos.join()) {
        canvas.drawPath(linha(rotaPadrao!), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * px
          ..color = pal.padrao.withOpacity(.8));
      }
      final c = linha(rota!);
      final traco = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(c, traco..strokeWidth = 11 * px..color = pal.rotaBorda);
      canvas.drawPath(c, traco..strokeWidth = 7 * px..color = pal.rota);
    }

    // escadas rolantes e elevador
    for (final n in pacote.nos.values.where((n) => n.andar == andar && n.tipo == 'vertical')) {
      final r = 9 * px;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: Offset(n.x, n.y), radius: r), Radius.circular(3 * px)),
          Paint()..color = pal.categorias['sanitario']!);
      _texto(canvas, n.id.contains('elev') ? 'E' : '⇅', Offset(n.x, n.y), 11 * px, pal.iconePino, FontWeight.w700);
    }

    // muitos pontos no térreo: rótulos só com zoom, na busca ou na seleção
    final mostrarRotulos = (1 / px) > (andar == 0 ? 4 : 5.5); // px de tela por metro
    for (final p in pacote.pois.where((p) => p.andar == andar)) {
      final sel = selecionado?.id == p.id;
      final achado = destacados?.contains(p.id) ?? false;
      final apagado = destacados != null && !achado;
      final r = (sel ? 12 : (achado ? 10 : 8)) * px;
      final opac = apagado ? .3 : 1.0;
      if (sel) canvas.drawCircle(Offset(p.x, p.y), r * 1.8, Paint()..color = pal.rota.withOpacity(.45));
      canvas.drawCircle(Offset(p.x, p.y), r, Paint()..color = pal.categorias[p.categoria]!.withOpacity(opac));
      canvas.drawCircle(Offset(p.x, p.y), r,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5 * px..color = pal.contorno.withOpacity(opac));
      final ic = iconesCategoria[p.categoria]!;
      _texto(canvas, String.fromCharCode(ic.codePoint), Offset(p.x, p.y), r * 1.2, pal.iconePino.withOpacity(opac),
          FontWeight.w400, familia: ic.fontFamily, pacoteFonte: ic.fontPackage);
      if (mostrarRotulos || sel || achado) {
        _texto(canvas, p.nome(idioma).replaceAll(RegExp(r'\s*\(.*\)'), ''), Offset(p.x, p.y + r + 9 * px), 12 * px,
            pal.rotulo.withOpacity(opac), sel ? FontWeight.w700 : FontWeight.w600,
            contorno: pal.contorno);
      }
    }

    if (posicao != null) {
      final n = pacote.nos[posicao]!;
      if (n.andar == andar) {
        final azul = pal.voce;
        canvas.drawCircle(Offset(n.x, n.y), (posicaoConfirmada ? 14 : 24) * px, Paint()..color = azul.withOpacity(.3));
        canvas.drawCircle(Offset(n.x, n.y), 8 * px, Paint()..color = azul);
        canvas.drawCircle(Offset(n.x, n.y), 8 * px, Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * px..color = pal.contorno);
      }
    }
    canvas.restore();
  }

  void _texto(Canvas canvas, String s, Offset centro, double tamanho, Color cor, FontWeight peso,
      {String? familia, String? pacoteFonte, Color? contorno}) {
    TextPainter tp(Paint? fundo) => TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: tamanho,
                color: fundo == null ? cor : null,
                foreground: fundo,
                fontWeight: peso,
                fontFamily: familia,
                package: pacoteFonte),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
    if (contorno != null) {
      final c = tp(Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tamanho * .3
        ..color = contorno);
      c.paint(canvas, centro - Offset(c.width / 2, c.height / 2));
    }
    final t = tp(null);
    t.paint(canvas, centro - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(covariant MapaExplorarPainter o) => true;
}
