import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pacote.dart';
import '../services/localizacao_service.dart';
import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/navegacao_viewmodel.dart';
import 'conversa_view.dart';
import 'navegacao_page.dart';
import 'tema.dart';
import 'widgets/mapa_explorar_painter.dart';

String rotuloPonto(No n, String idioma) {
  final s = n.tipo == 'entrada' ? (n.nome(idioma) ?? n.id) : (n.referencia(idioma) ?? n.id);
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// "Aonde você quer ir?": mapa do shopping com todas as lojas e a posição atual.
/// A loja pode ser escolhida tocando no ícone, pela busca ou pela lista que
/// abre arrastando a borda direita da tela.
class ExplorarView extends StatefulWidget {
  const ExplorarView({super.key});
  @override
  State<ExplorarView> createState() => _ExplorarViewState();
}

class _ExplorarViewState extends State<ExplorarView> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _ctrl = TransformationController();
  final _busca = TextEditingController();
  double _zoom = 1;
  Size? _viewport;
  String? _centradoEm;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final z = _ctrl.value.getMaxScaleOnAxis();
      if ((z - _zoom).abs() > .05) setState(() => _zoom = z);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavegacaoViewModel>();
      final app = context.read<AppViewModel>();
      if (nav.posicao == null && !nav.localizando) nav.localizar();
      if (app.tem('listaPrimeiro') && nav.destino == null) _scaffold.currentState?.openEndDrawer();
    });
  }

  /// Centraliza o mapa num ponto do pacote com o zoom pedido.
  void _centralizar(double x, double y, double zoom) {
    final v = _viewport;
    if (v == null) return;
    final tx = v.width / 2 - x * escalaMapa * zoom;
    final ty = v.height / 2 - y * escalaMapa * zoom;
    _ctrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(zoom);
  }

  void _zoomBotao(double fator) {
    final v = _viewport;
    if (v == null) return;
    final centro = _ctrl.toScene(Offset(v.width / 2, v.height / 2));
    final z = (_zoom * fator).clamp(.08, 4.0);
    _centralizar(centro.dx / escalaMapa, centro.dy / escalaMapa, z);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    final t = app.t, p = app.pacote!, tema = Theme.of(context);

    // centraliza no visitante quando a posição chega (ou muda)
    final pos = nav.posicao;
    if (pos != null && _centradoEm != pos.no && _viewport != null) {
      _centradoEm = pos.no;
      final n = p.nos[pos.no]!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centralizar(n.x, n.y + 10, 1.0));
    }

    return Scaffold(
      key: _scaffold,
      // lista de lojas: abre arrastando a borda direita da tela ou pela alça "Lojas"
      endDrawer: ListaLojasDrawer(aoEscolher: (poi) => _selecionar(nav, poi)),
      endDrawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 40,
      body: Column(children: [
      // busca
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: TextField(
          controller: _busca,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t['ondeIr'],
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          onChanged: nav.digitar,
          onSubmitted: (v) {
            final r = nav.buscar(v);
            if (r.isNotEmpty) _selecionar(nav, r.first);
          },
        ),
      ),
      _BarraLocal(nav: nav, t: (k) => t[k], idioma: app.idioma, pacote: p),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final primeiraVez = _viewport == null;
          _viewport = Size(c.maxWidth, c.maxHeight);
          final andarAtual = p.andar(nav.andarMapa);
          if (primeiraVez) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _verAndarInteiro(andarAtual));
          }
          return Stack(children: [
            Positioned.fill(
              child: Semantics(
                label: t['mapa'],
                child: InteractiveViewer(
                  transformationController: _ctrl,
                  constrained: false,
                  minScale: .08,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: GestureDetector(
                    // raio de toque: ~22 px de tela, convertidos para metros
                    onTapUp: (d) => nav.tocarMapa(d.localPosition.dx / escalaMapa, d.localPosition.dy / escalaMapa,
                        raio: 22 / (escalaMapa * _zoom)),
                    child: CustomPaint(
                      size: Size(andarAtual.largura * escalaMapa, andarAtual.altura * escalaMapa),
                      painter: MapaExplorarPainter(
                        pacote: p,
                        andar: nav.andarMapa,
                        planta: app.planta(nav.andarMapa),
                        paleta: PaletaMapa.de(app.tema, altoContraste: app.tem('altoContraste')),
                        idioma: app.idioma,
                        posicao: nav.origemId,
                        posicaoConfirmada: nav.origemAlternativa != null || nav.posicao?.confianca == Confianca.alta,
                        selecionado: nav.destino,
                        destacados: nav.destacados,
                        rota: nav.rota,
                        rotaPadrao: nav.rotaPadrao,
                        altoContraste: app.tem('altoContraste'),
                        zoom: _zoom,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // andares
            Positioned(
              top: 8,
              left: 8,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final a in p.andares) ButtonSegment(value: a.id, label: Text(a.nome(app.idioma).split(' –').first)),
                ],
                selected: {nav.andarMapa},
                onSelectionChanged: (s) {
                  nav.trocarAndar(s.first);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _verAndarInteiro(p.andar(s.first)));
                },
              ),
            ),
            // zoom
            Positioned(
              right: 46,
              bottom: nav.destino == null ? 12 : 200,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _BotaoMapa(Icons.add, 'Zoom +', () => _zoomBotao(1.4)),
                _BotaoMapa(Icons.remove, 'Zoom −', () => _zoomBotao(1 / 1.4)),
                _BotaoMapa(Icons.my_location, t['vcAqui'], () {
                  final n = nav.posicao == null ? null : p.nos[nav.posicao!.no];
                  if (n == null) return;
                  nav.trocarAndar(n.andar);
                  _centralizar(n.x, n.y, 1.2);
                }),
              ]),
            ),
            // alça da lista (arrastar ou tocar)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < 0) _scaffold.currentState?.openEndDrawer();
                  },
                  child: Material(
                    color: tema.colorScheme.primary,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    child: InkWell(
                      onTap: () => _scaffold.currentState?.openEndDrawer(),
                      child: SizedBox(
                        width: 34,
                        height: 120,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.chevron_left, color: tema.colorScheme.onPrimary),
                          RotatedBox(
                            quarterTurns: 3,
                            child: Text(t['lojas'],
                                style: TextStyle(color: tema.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (nav.destino != null)
              Positioned(left: 8, right: 8, bottom: 8, child: _CartaoLoja(nav: nav, app: app)),
          ]);
        }),
      ),
    ]),
    );
  }

  void _selecionar(NavegacaoViewModel nav, Poi poi) {
    final p = nav.app.pacote!;
    nav.selecionar(poi);
    FocusScope.of(context).unfocus();
    // mostra o andar onde o visitante está (início da rota); se não houver rota, o da loja
    final inicio = nav.origemId == null ? null : p.nos[nav.origemId!]!;
    if (inicio == null || nav.rota == null) {
      nav.trocarAndar(poi.andar);
      _centralizar(poi.x, poi.y + 12, 1.2);
    } else {
      nav.trocarAndar(inicio.andar);
      // enquadra a parte da rota neste andar (e a loja, se for no mesmo andar)
      final pts = [
        for (final id in nav.rota!.nos)
          if (p.nos[id]!.andar == inicio.andar) Offset(p.nos[id]!.x, p.nos[id]!.y),
        if (poi.andar == inicio.andar) Offset(poi.x, poi.y),
      ];
      final xs = pts.map((o) => o.dx), ys = pts.map((o) => o.dy);
      final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max), y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
      final v = _viewport!;
      final util = Size(v.width - 60, v.height - 230); // desconta a alça e o cartão
      final z = math.min(util.width / ((x1 - x0 + 20) * escalaMapa), util.height / ((y1 - y0 + 20) * escalaMapa)).clamp(.08, 2.0);
      final tx = util.width / 2 - (x0 + x1) / 2 * escalaMapa * z;
      final ty = util.height / 2 - (y0 + y1) / 2 * escalaMapa * z;
      _ctrl.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(z);
    }
  }

  void _verAndarInteiro(Andar a) {
    final v = _viewport;
    if (v == null) return;
    final z = math.min(v.width / (a.largura * escalaMapa), v.height / (a.altura * escalaMapa));
    _centralizar(a.largura / 2, a.altura / 2, z);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _busca.dispose();
    super.dispose();
  }
}

class _BotaoMapa extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  const _BotaoMapa(this.icone, this.rotulo, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: IconButton(icon: Icon(icone, color: Cores.tinta), tooltip: rotulo, onPressed: onTap),
        ),
      );
}

class _BarraLocal extends StatelessWidget {
  final NavegacaoViewModel nav;
  final String Function(String) t;
  final String idioma;
  final Pacote pacote;
  const _BarraLocal({required this.nav, required this.t, required this.idioma, required this.pacote});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget conteudo;
    if (nav.ajustando) {
      conteudo = Row(children: [
        Expanded(child: Text(t('toqueMapa'), style: const TextStyle(fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => nav.iniciarAjuste(false), child: Text(t('cancelar'))),
      ]);
    } else if (nav.posicao == null) {
      conteudo = Text('📍 ${t('localizando')}');
    } else {
      final n = pacote.nos[nav.posicao!.no]!;
      final conf = nav.posicao!.confianca == Confianca.alta;
      conteudo = Row(children: [
        Expanded(
          child: Text(
            '📍 ${t('vcAqui')} ${n.referencia(idioma) ?? n.nome(idioma) ?? ''} · '
            '${pacote.andar(n.andar).nome(idioma).split(' –').first} (${conf ? t('confirmado') : t('estimado')})',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        if (!conf) TextButton(onPressed: nav.confirmarPosicao, child: Text(t('ehAqui'))),
        TextButton(onPressed: () => nav.iniciarAjuste(), child: Text(t('ajustar'))),
      ]);
    }
    if (!nav.ajustando && nav.origemAlternativa != null) {
      conteudo = Row(children: [
        Expanded(child: Text('📍 ${t('rotaDaEntrada')} ${pacote.nos[nav.origemAlternativa]!.nome(idioma)}', style: const TextStyle(fontSize: 14))),
        TextButton(onPressed: () => nav.iniciarAjuste(), child: Text(t('ajustar'))),
      ]);
    }
    if (nav.ajustando) {
      conteudo = DefaultTextStyle.merge(style: const TextStyle(color: Cores.tinta), child: conteudo);
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: nav.ajustando ? Cores.capim : tema.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tema.dividerColor),
        ),
        child: conteudo,
      ),
    );
  }
}

/// Bloco "sem rota acessível confirmada" + alternativas reais (usado no cartão e na tela de exceção).
class SemRotaAcessivel extends StatelessWidget {
  final NavegacaoViewModel nav;
  final AppViewModel app;
  final VoidCallback? antesDeAgir; // ex.: fechar a página de navegação antes de voltar ao mapa
  const SemRotaAcessivel({super.key, required this.nav, required this.app, this.antesDeAgir});

  @override
  Widget build(BuildContext context) {
    final t = app.t, p = app.pacote!, cs = Theme.of(context).colorScheme;
    final origem = nav.origemId == null ? null : p.nos[nav.origemId!];
    final outroAndar = origem != null && nav.destino != null && origem.andar != nav.destino!.andar;
    final achados = p.pois.where((x) => x.id == 'poi_seguranca');
    final seguranca = achados.isEmpty ? null : achados.first;
    void agir(VoidCallback f) {
      antesDeAgir?.call();
      f();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.error, width: 5))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nav.exigeAcessivel ? t['semRotaAcessT'] : t['semRotaT'], style: const TextStyle(fontWeight: FontWeight.w700)),
            if (nav.exigeAcessivel) Text(t['semRotaAcessD']),
            if (nav.exigeAcessivel && outroAndar) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t['semRotaPisoD'])),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text(t['alternativas'], style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      for (final (entrada, _) in nav.alternativas) ...[
        OutlinedButton(
          onPressed: () => agir(() => nav.usarAlternativa(entrada)),
          child: Text('${t['altEntrada']} ${entrada.nome(app.idioma)}'),
        ),
        const SizedBox(height: 4),
      ],
      if (nav.alternativas.isNotEmpty) Text(t['altEntradaNota'], style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 4),
      if (app.podeConversar)
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversaView())),
          child: Text(t['altConversar']),
        )
      else if (seguranca != null && nav.destino?.id != seguranca.id)
        OutlinedButton(onPressed: () => agir(() => nav.selecionar(seguranca)), child: Text(t['altSeguranca'])),
      const SizedBox(height: 4),
      OutlinedButton(onPressed: () => agir(() => nav.voltarAoMapa(ajustar: true)), child: Text(t['revisarOrigem'])),
      const SizedBox(height: 4),
      OutlinedButton(onPressed: () => agir(() => nav.voltarAoMapa(limpar: true)), child: Text(t['outroDestino'])),
    ]);
  }
}

class _CartaoLoja extends StatelessWidget {
  final NavegacaoViewModel nav;
  final AppViewModel app;
  const _CartaoLoja({required this.nav, required this.app});

  @override
  Widget build(BuildContext context) {
    final t = app.t, p = app.pacote!, poi = nav.destino!, tema = Theme.of(context);
    final rota = nav.rota;
    final notas = <String>[];
    if (rota != null) {
      if (nav.origemAlternativa != null) {
        notas.add('${t['rotaDaEntrada']} ${p.nos[nav.origemAlternativa]!.nome(app.idioma)}. ${t['altEntradaNota']}');
      }
      if (app.usa('mobilidade') && nav.rotaPadrao != null && !nav.rotaPadrao!.semEscadas) notas.add(t['padraoUsaria']);
      if (nav.rotaTemEscada && app.perfil.exigirConfirmado) notas.add(t['temEscadaVisual']);
      if (app.usa('sensorial')) notas.add(t['evita']);
      final inicio = p.nos[nav.origemId!]!;
      if (poi.andar != inicio.andar) notas.add('${t['outroAndar']} ${p.andar(poi.andar).nome(app.idioma)}.');
    }
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: tema.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .55),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text('${poi.nome(app.idioma)}${poi.acessivel ? ' ♿' : ''}',
                    style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close), tooltip: t['fechar'], onPressed: nav.limparSelecao),
            ]),
            Text('${t[poi.categoria]} · ${p.andar(poi.andar).nome(app.idioma)}'),
            const SizedBox(height: 8),
            if (nav.posicao == null)
              Text(t['localizando'])
            else if (rota == null)
              SemRotaAcessivel(nav: nav, app: app)
            else ...[
              Wrap(spacing: 6, runSpacing: 4, children: [
                Chip(label: Text('${rota.distancia} m')),
                if (rota.semEscadas)
                  Chip(avatar: const Icon(Icons.accessible, size: 18), label: Text(t['semEscadas']), backgroundColor: Cores.capim,
                      labelStyle: const TextStyle(color: Cores.tinta))
                else
                  Chip(avatar: const Icon(Icons.warning_amber, size: 18), label: Text(t['incluiEscada'])),
                if (rota.semEscadas && app.perfil.exigirConfirmado) Chip(label: Text(t['confirmadaPerfil'])),
              ]),
              for (final n in notas) Text(n, style: const TextStyle(fontSize: 14)),
              if (nav.rotaTemEscada && nav.alternativas.isNotEmpty)
                for (final (entrada, _) in nav.alternativas)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton(
                      onPressed: () => nav.usarAlternativa(entrada),
                      child: Text('${t['altEntrada']} ${entrada.nome(app.idioma)}'),
                    ),
                  ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  nav.iniciarNavegacao();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NavegacaoPage()));
                },
                child: Text(t['iniciar']),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Lista de todas as lojas (gaveta lateral, abre arrastando a borda direita).
class ListaLojasDrawer extends StatelessWidget {
  final void Function(Poi) aoEscolher;
  const ListaLojasDrawer({super.key, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final nav = context.watch<NavegacaoViewModel>();
    final t = app.t, p = app.pacote!;
    final itens = nav.resultados;
    const ordem = ['loja', 'alimentacao', 'sanitario', 'servico', 'lazer'];
    return Drawer(
      width: MediaQuery.of(context).size.width * .88,
      child: SafeArea(
        child: Column(children: [
          ListTile(
            title: Text(t['todasLojas'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            trailing: IconButton(icon: const Icon(Icons.chevron_right), tooltip: t['fechar'], onPressed: () => Scaffold.of(context).closeEndDrawer()),
          ),
          const Divider(height: 1),
          Expanded(
            child: itens.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: Text(t['semResultado']))
                : ListView(children: [
                    for (final c in ordem)
                      if (itens.any((i) => i.categoria == c)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Semantics(header: true, child: Text(t[c], style: const TextStyle(fontWeight: FontWeight.w700))),
                        ),
                        for (final poi in (itens.where((i) => i.categoria == c).toList()
                          ..sort((a, b) => a.nome(app.idioma).compareTo(b.nome(app.idioma)))))
                          ListTile(
                            leading: Icon(iconesCategoria[poi.categoria], color: PaletaMapa.de(app.tema, altoContraste: app.tem('altoContraste')).categorias[poi.categoria]),
                            title: Text('${poi.nome(app.idioma)}${poi.acessivel ? ' ♿' : ''}'),
                            trailing: Text(p.andar(poi.andar).nome(app.idioma).split(' –').first),
                            onTap: () {
                              Scaffold.of(context).closeEndDrawer();
                              aoEscolher(poi);
                            },
                          ),
                      ],
                  ]),
          ),
        ]),
      ),
    );
  }
}
