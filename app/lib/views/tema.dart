import 'package:flutter/material.dart';

class Cores {
  static const cerrado = Color(0xFF1F3B2D);
  static const capim = Color(0xFFE3A92B);
  static const folha = Color(0xFFEEF3EE);
  static const tinta = Color(0xFF13261C);
  static const barro = Color(0xFFB4442E);
  static const linha = Color(0xFFCBD6CC);
  static const altoContraste = Color(0xFFFFE27A);
  static const sos = Color(0xFF8E0016);
}

/// Cores do mapa por tema: pinos, rota (sempre com borda escura) e "você está aqui".
class PaletaMapa {
  final Map<String, Color> categorias;
  final Color rota, rotaBorda, rotulo, contorno, voce, padrao, fundo, iconePino;
  const PaletaMapa(this.categorias, this.rota, this.rotaBorda, this.rotulo, this.contorno, this.voce, this.padrao,
      this.fundo, this.iconePino);

  static PaletaMapa de(String tema, {bool altoContraste = false}) {
    if (altoContraste) {
      const a = Cores.altoContraste;
      return const PaletaMapa({'loja': a, 'alimentacao': a, 'sanitario': a, 'servico': a, 'lazer': a}, Colors.white,
          Colors.black, a, Colors.black, Color(0xFF5B9BFF), Color(0xFF9A9A9A), Colors.black, Colors.black);
    }
    return switch (tema) {
      'escuro' => const PaletaMapa({
          'loja': Color(0xFF6FBF8F), 'alimentacao': Color(0xFFFF8A73), 'sanitario': Color(0xFF7FB0FF),
          'servico': Color(0xFFC7A6FF), 'lazer': Color(0xFFF2C14E),
        }, Color(0xFFFFC23D), Colors.black, Color(0xFFE8EFEA), Color(0xFF0B0E0D), Color(0xFF5B9BFF), Color(0xFF9FB0A6),
          Color(0xFF141917), Color(0xFF111111)),
      'terror' => const PaletaMapa({
          'loja': Color(0xFFD9C2B0), 'alimentacao': Color(0xFFFF6B5A), 'sanitario': Color(0xFF8FB8FF),
          'servico': Color(0xFFD7A6FF), 'lazer': Color(0xFFF0A04B),
        }, Color(0xFFFF8A3D), Colors.black, Color(0xFFF2E6E0), Color(0xFF0E0809), Color(0xFF6FA8FF), Color(0xFFB39A92),
          Color(0xFF0E0809), Color(0xFF111111)),
      _ => const PaletaMapa({
          'loja': Color(0xFF1F3B2D), 'alimentacao': Color(0xFFB4442E), 'sanitario': Color(0xFF2D5DA8),
          'servico': Color(0xFF6B4FA0), 'lazer': Color(0xFF8A5F08),
        }, Cores.capim, Cores.cerrado, Cores.tinta, Colors.white, Color(0xFF2D6CDF), Color(0xFF56645B),
          Color(0xFFF3F5F1), Colors.white),
    };
  }
}

/// Tema do app: claro, escuro ou "Sexta-feira 13" (estética de terror, sem flashes nem sustos).
/// O alto contraste do perfil tem prioridade sobre o tema.
ThemeData temaPara(String tema, Set<String> ui) {
  final hc = ui.contains('altoContraste'), calmo = ui.contains('calmo'), terror = tema == 'terror';
  late final ColorScheme cs;
  late final Color fundo, topo, sobreTopo;
  if (hc) {
    cs = const ColorScheme(
      brightness: Brightness.dark, primary: Cores.altoContraste, onPrimary: Colors.black,
      secondary: Cores.altoContraste, onSecondary: Colors.black, error: Color(0xFFFF8A73), onError: Colors.black,
      surface: Colors.black, onSurface: Cores.altoContraste,
    );
    fundo = Colors.black; topo = Colors.black; sobreTopo = Cores.altoContraste;
  } else if (tema == 'escuro') {
    cs = const ColorScheme(
      brightness: Brightness.dark, primary: Cores.capim, onPrimary: Color(0xFF121614),
      secondary: Cores.capim, onSecondary: Color(0xFF121614), error: Color(0xFFFF8A73), onError: Colors.black,
      surface: Color(0xFF1C2320), onSurface: Color(0xFFE8EFEA),
    );
    fundo = const Color(0xFF121614); topo = const Color(0xFF0B0E0D); sobreTopo = const Color(0xFFE8EFEA);
  } else if (terror) {
    cs = const ColorScheme(
      brightness: Brightness.dark, primary: Color(0xFFA3121F), onPrimary: Colors.white,
      secondary: Color(0xFFF0A04B), onSecondary: Color(0xFF160A0B), error: Color(0xFFFF7A7A), onError: Colors.black,
      surface: Color(0xFF1B1012), onSurface: Color(0xFFF2E6E0),
    );
    fundo = const Color(0xFF0E0809); topo = const Color(0xFF120708); sobreTopo = const Color(0xFFF2E6E0);
  } else {
    final primaria = calmo ? const Color(0xFF4F6B5C) : Cores.cerrado;
    cs = ColorScheme(
      brightness: Brightness.light, primary: primaria, onPrimary: Colors.white,
      secondary: calmo ? const Color(0xFFD8BE84) : Cores.capim, onSecondary: Cores.tinta,
      error: Cores.barro, onError: Colors.white, surface: Colors.white, onSurface: Cores.tinta,
    );
    fundo = Cores.folha; topo = primaria; sobreTopo = Colors.white;
  }
  final base = ThemeData(useMaterial3: true, colorScheme: cs, scaffoldBackgroundColor: fundo);
  final semTransicao = calmo || terror; // sem animações no modo calmo e no tema de terror
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface, fontSizeFactor: hc ? 1.2 : 1.0),
    appBarTheme: AppBarTheme(
      backgroundColor: topo,
      foregroundColor: sobreTopo,
      shape: terror ? const Border(bottom: BorderSide(color: Color(0xFF6B0F17), width: 2)) : null,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: cs.brightness == Brightness.dark ? cs.onSurface.withOpacity(.7) : cs.primary, width: 2),
        foregroundColor: cs.onSurface,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      errorStyle: TextStyle(fontWeight: FontWeight.w700, color: cs.error),
    ),
    pageTransitionsTheme: semTransicao
        ? const PageTransitionsTheme(builders: {
            TargetPlatform.android: _SemTransicao(),
            TargetPlatform.iOS: _SemTransicao(),
          })
        : null,
  );
}

class _SemTransicao extends PageTransitionsBuilder {
  const _SemTransicao();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> a,
          Animation<double> b, Widget child) =>
      child;
}
