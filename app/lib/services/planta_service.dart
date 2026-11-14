import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../models/pacote.dart';

/// Carrega os recortes limpos da Planta Mix: um por andar e por tema (claro, escuro, terror).
class PlantaService {
  Future<Map<int, Map<String, ui.Image>>> carregar(Pacote pacote) async {
    final out = <int, Map<String, ui.Image>>{};
    for (final a in pacote.andares) {
      final arquivos = a.imagens.isNotEmpty ? a.imagens : {if (a.imagem != null) 'claro': a.imagem!};
      for (final e in arquivos.entries) {
        try {
          final bytes = await rootBundle.load('assets/${e.value}');
          final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
          (out[a.id] ??= {})[e.key] = (await codec.getNextFrame()).image;
        } catch (_) {
          // sem imagem: o mapa mostra só a rota e os pontos
        }
      }
    }
    return out;
  }
}
