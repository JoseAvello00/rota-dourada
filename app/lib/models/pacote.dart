import 'dart:math' as math;

import 'grade.dart';
/// Modelos do pacote de navegação (espelham dados/pacote_capim_dourado.json).
library;

String? _local(Map<String, dynamic> j, String campo, String idioma) {
  if (idioma != 'pt') {
    final v = j['${campo}_$idioma'];
    if (v is String && v.isNotEmpty) return v;
  }
  return j[campo] as String?;
}

class Andar {
  final int id;
  final double largura, altura; // metros
  final String? imagem; // recorte limpo da Planta Mix (tema claro)
  final Map<String, String> imagens; // claro | escuro | terror
  /// Células de 0,5 m da área de circulação (corredores e passagens) extraídas das camadas CAD.
  final GradeCirculacao? grade;
  /// Ângulo do norte na planta, horário a partir do "para cima" do mapa (rosa dos ventos da folha 1/2: 90° = +x).
  final double norteMapaGraus;
  final Map<String, dynamic> _j;
  Andar(this._j)
      : id = _j['id'] as int,
        largura = ((_j['largura'] as num?) ?? 200).toDouble(),
        altura = ((_j['altura'] as num?) ?? 105).toDouble(),
        imagem = _j['imagem'] as String?,
        imagens = ((_j['imagens'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
        grade = _j['grade'] == null ? null : GradeCirculacao.fromJson(_j['grade'] as Map<String, dynamic>),
        norteMapaGraus = (((_j['orientacao'] as Map?)?['norte_mapa_graus'] as num?) ?? 0).toDouble();
  String nome(String idioma) => _local(_j, 'nome', idioma) ?? '';
}

class No {
  final String id;
  final int andar;
  final double x, y;
  final String tipo; // entrada | corredor | vertical
  final Map<String, dynamic> _j;
  No(this._j)
      : id = _j['id'] as String,
        andar = _j['andar'] as int,
        x = (_j['x'] as num).toDouble(),
        y = (_j['y'] as num).toDouble(),
        tipo = _j['tipo'] as String;

  String? nome(String idioma) => _local(_j, 'nome', idioma);
  String? referencia(String idioma) => _local(_j, 'referencia', idioma);
  bool get pontoConhecido => tipo == 'entrada' || (tipo != 'vertical' && _j['referencia'] != null);
}

class Aresta {
  final String id, de, para, tipo, estimulo;
  final double? distancia;
  final bool bidirecional;
  /// false = trecho não confirmado na planta (nunca entra em rota acessível).
  final bool confirmado;
  /// Polilinha verificada na grade de circulação (de → para). Vazia em trechos verticais.
  final List<math.Point<double>> geometria;
  Aresta.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        de = j['de'] as String,
        para = j['para'] as String,
        tipo = j['tipo'] as String,
        estimulo = (j['estimulo'] as String?) ?? 'medio',
        distancia = (j['distancia'] as num?)?.toDouble(),
        bidirecional = (j['bidirecional'] as bool?) ?? true,
        confirmado = !((j['a_validar'] as bool?) ?? false),
        geometria = ((j['geometria'] as List?) ?? const [])
            .map((p) => math.Point(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
}

/// Porta do estabelecimento na faixa de circulação, ancorada num trecho (t = fração do comprimento).
class Entrada {
  final double x, y, t;
  final String aresta, fonte; // estimada_planta | cadastrada
  Entrada.fromJson(Map<String, dynamic> j)
      : x = (j['x'] as num).toDouble(),
        y = (j['y'] as num).toDouble(),
        t = (j['t'] as num).toDouble(),
        aresta = j['aresta'] as String,
        fonte = (j['fonte'] as String?) ?? 'estimada_planta';
}

class Poi {
  final String id, categoria, no;
  final int andar;
  final double x, y;
  final bool acessivel;
  final List<String> tags;
  final Entrada? entrada;
  final Map<String, dynamic> _j;
  Poi(this._j)
      : id = _j['id'] as String,
        categoria = _j['categoria'] as String,
        no = _j['no'] as String,
        andar = _j['andar'] as int,
        x = (_j['x'] as num).toDouble(),
        y = (_j['y'] as num).toDouble(),
        acessivel = (_j['acessivel'] as bool?) ?? false,
        tags = ((_j['tags'] as List?) ?? const []).cast<String>(),
        entrada = _j['entrada'] == null ? null : Entrada.fromJson(_j['entrada'] as Map<String, dynamic>);

  String nome(String idioma) => _local(_j, 'nome', idioma) ?? '';
  String get textoBusca =>
      [_j['nome'], _j['nome_en'], _j['nome_es'], ...tags].whereType<String>().join(' ');
}

class Perfil {
  final String id, nome;
  final Set<String> proibidos;
  final Map<String, double> multTipo, multEstimulo;
  final double penalidadeCurva;
  /// Rotas acessíveis usam só trechos confirmados na planta.
  final bool exigirConfirmado;
  Perfil.fromJson(this.id, Map<String, dynamic> j)
      : nome = j['nome'] as String,
        proibidos = ((j['proibidos'] as List?) ?? const []).cast<String>().toSet(),
        multTipo = _mapa(j['multiplicador_tipo']),
        multEstimulo = _mapa(j['multiplicador_estimulo']),
        penalidadeCurva = ((j['penalidade_curva'] as num?) ?? 0).toDouble(),
        exigirConfirmado = (j['exigir_confirmado'] as bool?) ?? false;

  Perfil._(this.id, this.nome, this.proibidos, this.multTipo, this.multEstimulo, this.penalidadeCurva,
      [this.exigirConfirmado = false]);

  /// Versão estrita: além do perfil, proíbe escadas e escadas rolantes e exige trechos confirmados.
  Perfil get semEscadas => Perfil._('$id+sem_escadas', nome, {...proibidos, 'escada', 'escada_rolante', 'esteira'},
      multTipo, multEstimulo, penalidadeCurva, true);

  /// Junta perfis: restrições somam; multiplicadores e penalidade usam o maior valor.
  static Perfil combinar(Pacote pacote, List<String> ids) {
    final lista = ids.where(pacote.perfis.containsKey).toList();
    if (lista.isEmpty) lista.add('padrao');
    final proib = <String>{};
    final mt = <String, double>{}, me = <String, double>{};
    var pen = 0.0;
    var conf = false;
    for (final id in lista) {
      final p = pacote.perfis[id]!;
      proib.addAll(p.proibidos);
      p.multTipo.forEach((k, v) => mt[k] = v > (mt[k] ?? 1) ? v : (mt[k] ?? 1));
      p.multEstimulo.forEach((k, v) => me[k] = v > (me[k] ?? 1) ? v : (me[k] ?? 1));
      if (p.penalidadeCurva > pen) pen = p.penalidadeCurva;
      conf = conf || p.exigirConfirmado;
    }
    return Perfil._(lista.join('+'), lista.map((i) => pacote.perfis[i]!.nome).join(' + '), proib, mt, me, pen, conf);
  }

  static Map<String, double> _mapa(dynamic m) =>
      ((m as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
}

class Beacon {
  final String id, uuid, status;
  final String? no;
  final int andar, major, minor;
  final double x, y;
  /// RSSI medido a 1 m (calibração em campo) e expoente de perda do ambiente.
  final double rssi1m, expoente;
  Beacon.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        uuid = ((j['uuid'] as String?) ?? '').toLowerCase(),
        status = (j['status'] as String?) ?? 'planejado',
        no = j['no'] as String?,
        andar = j['andar'] as int,
        major = (j['major'] as int?) ?? 0,
        minor = (j['minor'] as int?) ?? 0,
        x = ((j['x'] as num?) ?? 0).toDouble(),
        y = ((j['y'] as num?) ?? 0).toDouble(),
        rssi1m = ((j['rssi_1m'] as num?) ?? -59).toDouble(),
        expoente = ((j['expoente'] as num?) ?? 2.2).toDouble();

  /// Chave do anúncio iBeacon (uuid:major:minor).
  String get chave => '$uuid:$major:$minor';
  bool get instalado => status == 'instalado';
}

class Pacote {
  final String pacoteId, versao, atualizadoEm;
  final String edificioNome;
  final List<Andar> andares;
  final Map<String, No> nos;
  final List<Aresta> arestas;
  final List<Poi> pois;
  final List<Beacon> beacons;
  final Map<String, Perfil> perfis;

  Pacote.fromJson(Map<String, dynamic> j)
      : pacoteId = j['versao']['pacote_id'] as String,
        versao = j['versao']['versao'] as String,
        atualizadoEm = j['versao']['atualizado_em'] as String,
        edificioNome = j['edificio']['nome'] as String,
        andares = (j['edificio']['andares'] as List).map((a) => Andar(a as Map<String, dynamic>)).toList(),
        nos = {
          for (final n in (j['nos'] as List)) (n['id'] as String): No(n as Map<String, dynamic>)
        },
        arestas = (j['arestas'] as List).map((a) => Aresta.fromJson(a as Map<String, dynamic>)).toList(),
        pois = (j['pois'] as List).map((p) => Poi(p as Map<String, dynamic>)).toList(),
        beacons = ((j['beacons'] as List?) ?? const [])
            .map((b) => Beacon.fromJson(b as Map<String, dynamic>))
            .toList(),
        perfis = (j['perfis'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, Perfil.fromJson(k, v as Map<String, dynamic>)));

  Andar andar(int id) => andares.firstWhere((a) => a.id == id);
}
