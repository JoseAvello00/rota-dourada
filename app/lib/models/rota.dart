/// Trecho efetivamente percorrido (direção já resolvida).
class Trecho {
  final String id, de, para, tipo, estimulo;
  final double distancia;
  final bool confirmado;
  const Trecho(this.id, this.de, this.para, this.tipo, this.distancia, this.estimulo, [this.confirmado = true]);
}

class Rota {
  final List<String> nos;
  final List<Trecho> trechos;
  final double custo;
  const Rota(this.nos, this.trechos, this.custo);

  int get distancia => trechos.fold<double>(0, (s, t) => s + t.distancia).round();
  Set<String> get tipos => trechos.map((t) => t.tipo).toSet();
  bool get semEscadas => !tipos.contains('escada') && !tipos.contains('escada_rolante') && !tipos.contains('esteira');
}

/// Uma instrução por ponto de decisão.
class Etapa {
  final String texto;
  final String icone; // frente | direita | esquerda | voltar | elevador | escada | esteira | rampa | chegada
  final String no; // nó onde a etapa termina
  final int andar;
  final int distancia;
  const Etapa(this.texto, this.icone, this.no, this.andar, this.distancia);
}
