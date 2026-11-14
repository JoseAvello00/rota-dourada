import 'dart:math' as math;

import '../models/pacote.dart';
import '../models/rota.dart';
import 'rota_service.dart';

/// Gera instruções compreensíveis sem depender do mapa (PT, EN, ES).
class InstrucaoService {
  final Pacote pacote;
  InstrucaoService(this.pacote);

  static const _verticais = {'elevador', 'escada', 'esteira', 'escada_rolante'};
  static int _arred(double d) => math.max(5, (d / 5).round() * 5);

  String _ref(No n, String idioma) => n.referencia(idioma) ?? n.nome(idioma) ?? n.id;

  String? _lado(double ang, _Textos t) {
    if (ang.abs() <= 30) return null;
    return ang > 0 ? t.direita : t.esquerda;
  }

  double _ang(No a, No b, double cx, double cy) => RotaService.anguloCurva(a.x, a.y, b.x, b.y, cx, cy);

  /// [nomeEntrada]: nome da entrada de origem; null descreve pela referência do ponto.
  List<Etapa> gerar(Rota rota, Poi destino, String idioma, {String? nomeEntrada}) {
    final t = _Textos.de(idioma);
    final nos = pacote.nos;
    final a = rota.trechos;
    final etapas = <Etapa>[];
    final nomePoi = destino.nome(idioma);

    if (a.isEmpty) {
      final n = nos[rota.nos.first]!;
      return [Etapa(t.jaEsta(nomePoi), 'chegada', n.id, n.andar, 0)];
    }

    var i = 0;
    var primeiro = true, aposVertical = false;
    double? anguloEntrada;

    while (i < a.length) {
      final tr = a[i];
      final de = nos[tr.de]!, para = nos[tr.para]!;

      if (_verticais.contains(tr.tipo) && de.andar != para.andar) {
        final andar = pacote.andar(para.andar).nome(idioma);
        final sobe = para.andar > de.andar;
        final texto = switch (tr.tipo) {
          'elevador' => t.elevador(andar),
          'esteira' => t.esteira(andar),
          'escada_rolante' => sobe ? t.rolanteSobe(andar) : t.rolanteDesce(andar),
          _ => sobe ? t.escadaSobe(andar) : t.escadaDesce(andar),
        };
        etapas.add(Etapa(texto, tr.tipo == 'escada_rolante' ? 'escada' : tr.tipo, para.id, para.andar, tr.distancia.round()));
        i++;
        aposVertical = true;
        primeiro = false;
        anguloEntrada = null;
        continue;
      }

      if (tr.tipo == 'rampa' || tr.tipo == 'escada') {
        final d = _arred(tr.distancia), r = _ref(para, idioma);
        var texto = tr.tipo == 'rampa' ? t.rampa(d, r) : t.escadaLocal(d, r);
        if (primeiro && nomeEntrada != null) {
          texto = '${t.prefixo(nomeEntrada)} ${texto[0].toLowerCase()}${texto.substring(1)}';
        }
        etapas.add(Etapa(texto, tr.tipo, para.id, para.andar, tr.distancia.round()));
        i++;
        primeiro = false;
        aposVertical = false;
        anguloEntrada = null;
        continue;
      }

      // Agrupa corredores em linha reta até o próximo ponto de decisão.
      var dist = tr.distancia;
      var j = i;
      // retas longas (> 60 m) viram mais de uma etapa, com referência no meio
      while (j + 1 < a.length && a[j + 1].tipo == 'corredor' && dist < 60) {
        final p0 = nos[a[j].de]!, p1 = nos[a[j].para]!, p2 = nos[a[j + 1].para]!;
        if (_ang(p0, p1, p2.x, p2.y).abs() > 30) break;
        j++;
        dist += a[j].distancia;
      }
      final fim = nos[a[j].para]!;
      final d = _arred(dist), r = _ref(fim, idioma);
      String texto;
      var icone = 'frente';
      if (primeiro) {
        texto = nomeEntrada != null ? t.sair(nomeEntrada, d, r) : t.estaRef(_ref(nos[a.first.de]!, idioma), d, r);
      } else if (aposVertical) {
        texto = t.aoSair(d, r);
      } else {
        final ang = anguloEntrada ?? 0;
        if (ang.abs() > 150) {
          texto = t.voltar(d, r);
          icone = 'voltar';
        } else if (ang.abs() > 30) {
          texto = t.virar(_lado(ang, t)!, d, r);
          icone = ang > 0 ? 'direita' : 'esquerda';
        } else {
          texto = t.frente(d, r);
        }
      }
      etapas.add(Etapa(texto, icone, fim.id, fim.andar, dist.round()));
      if (j + 1 < a.length) {
        final prox = nos[a[j + 1].para]!;
        anguloEntrada = fim.andar == prox.andar ? _ang(nos[a[j].de]!, fim, prox.x, prox.y) : null;
      }
      i = j + 1;
      primeiro = false;
      aposVertical = false;
    }

    final ult = a.last;
    final pa = nos[ult.de]!, pb = nos[ult.para]!;
    final lado = pa.andar == pb.andar ? _lado(_ang(pa, pb, destino.x, destino.y), t) : null;
    etapas.add(Etapa(t.chegou(nomePoi, lado), 'chegada', pb.id, pb.andar, 0));
    return etapas;
  }
}

class _Textos {
  final String esquerda, direita;
  final String Function(String o, int d, String r) sair, estaRef;
  final String Function(String lado, int d, String r) virar;
  final String Function(int d, String r) frente, voltar, aoSair, rampa, escadaLocal;
  final String Function(String a) elevador, escadaSobe, escadaDesce, esteira, rolanteSobe, rolanteDesce;
  final String Function(String n, String? lado) chegou;
  final String Function(String n) jaEsta, prefixo;

  const _Textos({
    required this.esquerda, required this.direita, required this.sair, required this.estaRef,
    required this.virar, required this.frente, required this.voltar, required this.aoSair,
    required this.rampa, required this.escadaLocal, required this.elevador, required this.escadaSobe,
    required this.escadaDesce, required this.esteira, required this.rolanteSobe, required this.rolanteDesce, required this.chegou, required this.jaEsta,
    required this.prefixo,
  });

  static _Textos de(String idioma) => switch (idioma) { 'en' => en, 'es' => es, _ => pt };

  static final pt = _Textos(
    esquerda: 'esquerda', direita: 'direita',
    sair: (o, d, r) => 'Saindo de $o, siga por cerca de $d metros até chegar $r.',
    estaRef: (o, d, r) => 'Você está $o. Siga por cerca de $d metros até chegar $r.',
    virar: (l, d, r) => 'Vire à $l e siga por cerca de $d metros até chegar $r.',
    frente: (d, r) => 'Continue em frente por cerca de $d metros até chegar $r.',
    voltar: (d, r) => 'Dê meia-volta e siga por cerca de $d metros até chegar $r.',
    aoSair: (d, r) => 'Ao sair, siga por cerca de $d metros até chegar $r.',
    rampa: (d, r) => 'Siga pela rampa por cerca de $d metros até chegar $r.',
    escadaLocal: (d, r) => 'Use a escada (cerca de $d metros) até chegar $r.',
    elevador: (a) => 'Pegue o elevador até o $a.',
    escadaSobe: (a) => 'Suba a escada até o $a.',
    escadaDesce: (a) => 'Desça a escada até o $a.',
    esteira: (a) => 'Use a esteira rolante até o $a.',
    rolanteSobe: (a) => 'Pegue a escada rolante e suba até o $a.',
    rolanteDesce: (a) => 'Pegue a escada rolante e desça até o $a.',
    chegou: (n, l) => l != null ? 'Você chegou. $n fica à sua $l.' : 'Você chegou. $n fica à sua frente.',
    jaEsta: (n) => 'Você já está no ponto de acesso de $n.',
    prefixo: (o) => 'Saindo de $o:',
  );

  static final en = _Textos(
    esquerda: 'left', direita: 'right',
    sair: (o, d, r) => 'From $o, walk about $d meters until you are $r.',
    estaRef: (o, d, r) => 'You are $o. Walk about $d meters until you are $r.',
    virar: (l, d, r) => 'Turn $l and walk about $d meters until you are $r.',
    frente: (d, r) => 'Keep straight for about $d meters until you are $r.',
    voltar: (d, r) => 'Turn around and walk about $d meters until you are $r.',
    aoSair: (d, r) => 'When you exit, walk about $d meters until you are $r.',
    rampa: (d, r) => 'Follow the ramp for about $d meters until you are $r.',
    escadaLocal: (d, r) => 'Take the stairs (about $d meters) until you are $r.',
    elevador: (a) => 'Take the elevator to the $a.',
    escadaSobe: (a) => 'Go up the stairs to the $a.',
    escadaDesce: (a) => 'Go down the stairs to the $a.',
    esteira: (a) => 'Take the moving walkway to the $a.',
    rolanteSobe: (a) => 'Take the escalator up to the $a.',
    rolanteDesce: (a) => 'Take the escalator down to the $a.',
    chegou: (n, l) => l != null ? 'You have arrived. $n is on your $l.' : 'You have arrived. $n is in front of you.',
    jaEsta: (n) => 'You are already at the access point of $n.',
    prefixo: (o) => 'From $o:',
  );

  static final es = _Textos(
    esquerda: 'izquierda', direita: 'derecha',
    sair: (o, d, r) => 'Desde $o, camine unos $d metros hasta llegar $r.',
    estaRef: (o, d, r) => 'Usted está $o. Camine unos $d metros hasta llegar $r.',
    virar: (l, d, r) => 'Gire a la $l y camine unos $d metros hasta llegar $r.',
    frente: (d, r) => 'Siga recto unos $d metros hasta llegar $r.',
    voltar: (d, r) => 'Dé la vuelta y camine unos $d metros hasta llegar $r.',
    aoSair: (d, r) => 'Al salir, camine unos $d metros hasta llegar $r.',
    rampa: (d, r) => 'Siga por la rampa unos $d metros hasta llegar $r.',
    escadaLocal: (d, r) => 'Use la escalera (unos $d metros) hasta llegar $r.',
    elevador: (a) => 'Tome el ascensor hasta el $a.',
    escadaSobe: (a) => 'Suba la escalera hasta el $a.',
    escadaDesce: (a) => 'Baje la escalera hasta el $a.',
    esteira: (a) => 'Use la cinta transportadora hasta el $a.',
    rolanteSobe: (a) => 'Tome la escalera mecánica y suba hasta el $a.',
    rolanteDesce: (a) => 'Tome la escalera mecánica y baje hasta el $a.',
    chegou: (n, l) => l != null ? 'Ha llegado. $n está a su $l.' : 'Ha llegado. $n está frente a usted.',
    jaEsta: (n) => 'Ya está en el punto de acceso de $n.',
    prefixo: (o) => 'Desde $o:',
  );
}
