import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/pacote.dart';
import '../models/rota.dart';
import '../services/feedback_service.dart';
import '../services/instrucao_service.dart';
import '../models/grade.dart';
import '../services/localizacao_service.dart';
import '../services/posicao/fontes.dart';
import '../services/posicao/motor_posicao.dart';
import '../services/rota_service.dart';
import 'app_viewmodel.dart';

enum Fase { explorar, navegando, incerto, semRota, chegou }

/// Jornada: mapa com posição atual → escolha da loja (ícone, busca ou lista)
/// → rota pelo perfil → passo a passo → chegada.
class NavegacaoViewModel extends ChangeNotifier {
  final AppViewModel app;
  final FeedbackService feedback;
  final LocalizacaoService Function(Pacote, int) criarLocalizacao;

  NavegacaoViewModel(this.app, this.feedback, {LocalizacaoService Function(Pacote, int)? localizacao})
      : criarLocalizacao = localizacao ?? ((p, i) => LocalizacaoSimulada(p, indice: i)) {
    app.addListener(_aoMudarApp);
  }

  String? _idiomaVisto;
  Perfil? _perfilVisto;

  /// Mantém a jornada coerente com o app: idioma novo regenera instruções; perfil
  /// editado recalcula a rota com as novas restrições; ao sair, a jornada é zerada.
  void _aoMudarApp() {
    if (app.pacote == null) return;
    if (!app.logado) {
      if (destino != null || fase != Fase.explorar) {
        fase = Fase.explorar;
        origemAlternativa = null;
        limparSelecao();
      }
      _perfilVisto = null;
      return;
    }
    if (_idiomaVisto != null && _idiomaVisto != app.idioma) atualizarIdioma();
    _idiomaVisto = app.idioma;
    final p = app.perfil;
    if (_perfilVisto != null && !identical(_perfilVisto, p) && destino != null) recalcular();
    _perfilVisto = p;
  }

  @override
  void dispose() {
    pararRastreamento();
    app.removeListener(_aoMudarApp);
    super.dispose();
  }

  Fase fase = Fase.explorar;
  String termo = '';

  // posição atual
  PosicaoEstimada? posicao;
  bool localizando = false;
  bool ajustando = false;
  int _beacon = 0;
  int andarMapa = 0;

  // destino e rota
  Poi? destino;
  Rota? rota, rotaPadrao;
  /// Origem alternativa escolhida pelo visitante (ex.: acesso oeste com elevador).
  String? origemAlternativa;
  /// Entradas com rota sem escadas confirmada, oferecidas quando a rota do perfil não serve.
  List<(No, Rota)> alternativas = [];
  List<Etapa> etapas = [];
  int indice = 0;
  No? origem;

  /// Tipos de trecho indisponíveis (ex.: elevador em manutenção).
  Set<String> indisponiveis = {};

  Pacote get _p => app.pacote!;
  String get _idioma => app.idioma;

  // ---------- busca ----------
  static String normalizar(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ', para = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? para[i] : c);
    }
    return b.toString();
  }

  List<Poi> buscar(String t) {
    final q = normalizar(t).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return _p.pois.where((p) => q.every(normalizar(p.textoBusca).contains)).toList();
  }

  List<Poi> get resultados => buscar(termo);
  Set<String>? get destacados => termo.trim().isEmpty ? null : resultados.map((p) => p.id).toSet();

  void digitar(String t) {
    termo = t;
    notifyListeners();
  }

  // ---------- localização ----------
  Future<void> localizar() async {
    localizando = true;
    notifyListeners();
    final p = await criarLocalizacao(_p, _beacon).estimar();
    localizando = false;
    if (p != null) _definirPosicao(p);
    notifyListeners();
  }

  /// Painel de demonstração: simula o visitante se deslocando até outro beacon.
  Future<void> simularDeslocamento() {
    _beacon++;
    return localizar();
  }

  void _definirPosicao(PosicaoEstimada p) {
    posicao = p;
    if (p.fonte == 'manual') ancorarMotor(_p.nos[p.no]!);
    origemAlternativa = null;
    andarMapa = _p.nos[p.no]!.andar;
    _tracar();
  }

  void confirmarPosicao() {
    final p = posicao;
    if (p == null) return;
    posicao = PosicaoEstimada(p.no, Confianca.alta, 'manual');
    notifyListeners();
  }

  void iniciarAjuste([bool v = true]) {
    ajustando = v;
    notifyListeners();
  }

  void trocarAndar(int a) {
    andarMapa = a;
    notifyListeners();
  }

  /// Toque no mapa (coordenadas do pacote). Ajuste de posição ou seleção de loja.
  void tocarMapa(double x, double y, {double raio = 6}) {
    if (ajustando) {
      final n = noMaisProximo(andarMapa, x, y);
      ajustando = false;
      if (n != null) _definirPosicao(PosicaoEstimada(n.id, Confianca.alta, 'manual'));
      notifyListeners();
      return;
    }
    Poi? alvo;
    var dMin = raio; // raio de toque em metros
    for (final p in _p.pois.where((p) => p.andar == andarMapa)) {
      final d = math.sqrt(math.pow(p.x - x, 2) + math.pow(p.y - y, 2));
      if (d < dMin) {
        dMin = d;
        alvo = p;
      }
    }
    if (alvo != null) selecionar(alvo);
  }

  No? noMaisProximo(int andar, double x, double y) {
    No? melhor;
    var dMin = double.infinity;
    for (final n in _p.nos.values) {
      if (n.andar != andar || n.tipo == 'vertical') continue;
      final d = math.sqrt(math.pow(n.x - x, 2) + math.pow(n.y - y, 2));
      if (d < dMin) {
        dMin = d;
        melhor = n;
      }
    }
    return melhor;
  }

  // ---------- seleção e rota ----------
  void selecionar(Poi p) {
    destino = p;
    origemAlternativa = null;
    _tracar();
    notifyListeners();
  }

  void limparSelecao() {
    destino = null;
    rota = null;
    rotaPadrao = null;
    origemAlternativa = null;
    alternativas = [];
    notifyListeners();
  }

  String? get origemId => origemAlternativa ?? posicao?.no;

  /// O perfil tem restrições de acessibilidade (rotas precisam ser confirmadas).
  bool get exigeAcessivel => app.perfil.exigirConfirmado || app.perfil.proibidos.isNotEmpty;

  bool get rotaTemEscada =>
      rota != null && (rota!.tipos.contains('escada') || rota!.tipos.contains('escada_rolante'));

  void _tracar() {
    alternativas = [];
    final origem = origemId;
    if (destino == null || origem == null) {
      rota = null;
      return;
    }
    final servico = RotaService(_p, tiposIndisponiveis: indisponiveis);
    rota = servico.calcular(app.perfil, origem, destino!.no);
    rotaPadrao = servico.calcular(_p.perfis['padrao']!, origem, destino!.no);
    // Nunca apresenta um percurso inadequado como acessível: sem rota (ou rota com escada
    // para quem precisa evitar), oferece entradas com rota sem escadas confirmada.
    if (exigeAcessivel && (rota == null || rotaTemEscada)) {
      alternativas = servico
          .entradasComRota(app.perfil.semEscadas, destino!.no)
          .where((x) => x.$1.id != origem)
          .take(2)
          .toList();
    }
  }

  void usarAlternativa(No entrada) {
    origemAlternativa = entrada.id;
    _tracar();
    notifyListeners();
  }

  /// Recalcula quando o perfil ou a disponibilidade mudam.
  void recalcular() {
    _tracar();
    notifyListeners();
  }

  void alternarElevador(bool indisponivel) {
    indisponivel ? indisponiveis.add('elevador') : indisponiveis.remove('elevador');
    recalcular();
  }

  void iniciarNavegacao() {
    if (rota == null) return;
    origem = _p.nos[origemId!];
    _gerarEtapas();
    indice = 0;
    fase = Fase.navegando;
    notifyListeners();
    _anunciarEtapa();
  }

  void _gerarEtapas() {
    final nomeEntrada = origem!.tipo == 'entrada' ? origem!.nome(_idioma) : null;
    etapas = InstrucaoService(_p).gerar(rota!, destino!, _idioma, nomeEntrada: nomeEntrada);
  }

  void atualizarIdioma() {
    if (fase == Fase.navegando && rota != null) {
      _gerarEtapas();
      notifyListeners();
    }
  }

  Etapa get etapaAtual => etapas[indice];
  bool get ultimaEtapa => indice == etapas.length - 1;
  int get andarAtual => indice == 0 ? origem!.andar : etapas[indice - 1].andar;
  String get posicaoNaRota => indice == 0 ? origem!.id : etapas[indice - 1].no;

  void proximo() {
    if (ultimaEtapa) {
      fase = Fase.chegou;
      // a posição passa a ser o destino, confirmado pelo visitante
      posicao = PosicaoEstimada(destino!.no, Confianca.alta, 'manual');
      andarMapa = destino!.andar;
      feedback.vibrar('chegada');
      if (app.tem('audioAuto')) feedback.falar(etapaAtual.texto, _idioma);
    } else {
      indice++;
      _anunciarEtapa();
    }
    notifyListeners();
  }

  void ouvir() => feedback.falar(etapaAtual.texto, _idioma);

  void _anunciarEtapa() {
    if (app.tem('audioAuto')) feedback.falar(etapaAtual.texto, _idioma);
    if (app.tem('vibracao')) feedback.vibrar(etapaAtual.icone);
  }

  // ---------- exceções ----------
  void perdido() {
    fase = Fase.incerto;
    notifyListeners();
  }

  /// Ponto conhecido escolhido em "Estou perdido": recalcula a partir dele.
  void recomecarDe(String noId) {
    _definirPosicao(PosicaoEstimada(noId, Confianca.alta, 'manual'));
    if (rota == null) {
      fase = Fase.semRota;
      notifyListeners();
    } else {
      iniciarNavegacao();
    }
  }

  List<No> pontosConhecidos(int andar) =>
      _p.nos.values.where((n) => n.pontoConhecido && n.andar == andar).toList();

  void voltarParaRota() {
    fase = Fase.navegando;
    notifyListeners();
  }

  void voltarAoMapa({bool ajustar = false, bool limpar = false}) {
    fase = Fase.explorar;
    ajustando = ajustar;
    if (limpar) {
      destino = null;
      rota = null;
      termo = '';
    } else {
      _tracar();
    }
    notifyListeners();
  }

  // ---------- posição em tempo real (BLE + passos, processada no aparelho) ----------
  FontePosicao? _fonte;
  MotorPosicao? motor;
  StreamSubscription<PosicaoAtual>? _sub;
  PosicaoAtual? posicaoAtual;
  bool get emSimulacao => _fonte?.simulacao ?? false;
  int _desvios = 0;
  DateTime? _ultimoRecalculo;
  String? avisoRota; // "Rota recalculada" etc.

  /// Liga a fonte de posição. [fonte] null = sensores reais.
  Future<void> iniciarRastreamento({FontePosicao? fonte, MotorPosicao? motorPronto}) async {
    await pararRastreamento();
    motor = motorPronto ?? MotorPosicao(_p);
    _fonte = fonte ?? FonteSensoresReais();
    _sub = _fonte!.iniciar(motor!).listen(receberPosicao);
  }

  Future<void> pararRastreamento() async {
    await _sub?.cancel();
    await _fonte?.parar();
    _sub = null;
    _fonte = null;
  }

  /// Ponto conhecido (toque no mapa, QR ou "Estou perdido") também ancora o motor.
  void ancorarMotor(No n) => motor?.definirInicial(n.andar, n.x, n.y, DateTime.now());

  void receberPosicao(PosicaoAtual p) {
    posicaoAtual = p;
    if (!p.confiavel) {
      // Sem dados confiáveis: não move a origem nem recalcula; a interface mostra o estado.
      notifyListeners();
      return;
    }
    andarMapa = fase == Fase.navegando ? andarMapa : p.andar;
    final servico = RotaService(_p, tiposIndisponiveis: indisponiveis);
    final ancora = servico.ancorar(p.andar, p.ponto);
    if (ancora != null && fase == Fase.explorar && origemAlternativa == null) {
      final no = ancora.ateDe <= ancora.atePara ? ancora.aresta.de : ancora.aresta.para;
      posicao = PosicaoEstimada(no, p.estado == EstadoPosicao.ok ? Confianca.alta : Confianca.media, p.fonte);
      _tracar();
    }
    if (fase == Fase.navegando && rota != null) _acompanhar(p, servico);
    notifyListeners();
  }

  /// Durante a navegação: avança as etapas pela proximidade e recalcula após desvio confirmado.
  void _acompanhar(PosicaoAtual p, RotaService servico) {
    final alvo = _p.nos[etapaAtual.no]!;
    if (alvo.andar == p.andar && p.ponto.distanceTo(math.Point(alvo.x, alvo.y)) <= math.max(3.0, p.erro)) {
      proximo();
      return;
    }
    if (p.erro > 8) return; // imprecisa demais para afirmar desvio
    final linha = servico.polilinha(rota!, p.andar);
    if (linha.isEmpty) return;
    final fora = distanciaPolilinha(p.ponto, linha);
    _desvios = fora > math.max(5.0, 2 * p.erro) ? _desvios + 1 : 0;
    final agora = DateTime.now();
    if (_desvios < 3 || (_ultimoRecalculo != null && agora.difference(_ultimoRecalculo!).inSeconds < 5)) return;
    _desvios = 0;
    _ultimoRecalculo = agora;
    final r = servico.calcularDoPonto(app.perfil, p.andar, p.ponto, destino!);
    if (r == null) {
      rota = null;
      fase = Fase.semRota;
      feedback.vibrar('alerta');
      return;
    }
    rota = r.rota;
    origem = _p.nos[r.origemNo];
    _gerarEtapas();
    indice = 0;
    avisoRota = 'recalculada';
    _anunciarEtapa();
  }

}
