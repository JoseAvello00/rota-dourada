import 'package:shared_preferences/shared_preferences.dart';

/// Tema e idioma escolhidos (salvos no aparelho).
class PreferenciasService {
  static const temas = ['claro', 'escuro', 'terror'];

  Future<(String, String?)> carregar() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('rd_tema');
    return (temas.contains(t) ? t! : 'claro', p.getString('rd_idioma'));
  }

  Future<void> salvarTema(String t) async => (await SharedPreferences.getInstance()).setString('rd_tema', t);
  Future<void> salvarIdioma(String i) async => (await SharedPreferences.getInstance()).setString('rd_idioma', i);
}
