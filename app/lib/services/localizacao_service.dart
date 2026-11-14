import '../models/pacote.dart';

enum Confianca { alta, media, baixa }

class PosicaoEstimada {
  final String no;
  final Confianca confianca;
  final String fonte; // manual | simulado | ble
  const PosicaoEstimada(this.no, this.confianca, this.fonte);

  /// Só posições de alta confiança iniciam rota sem confirmação do visitante.
  bool get exigeConfirmacao => confianca != Confianca.alta;
}

/// Contrato único para as fontes de posição. A interface não muda quando
/// o protótipo trocar a simulação por BLE + sensores (etapas 5 e 6).
abstract class LocalizacaoService {
  Future<PosicaoEstimada?> estimar();
}

/// MVP: simula a leitura do beacon planejado mais próximo.
/// NÃO comprova precisão real — serve para validar telas e fluxo.
class LocalizacaoSimulada implements LocalizacaoService {
  final Pacote pacote;
  final int indice;
  LocalizacaoSimulada(this.pacote, {this.indice = 0});

  @override
  Future<PosicaoEstimada?> estimar() async {
    if (pacote.beacons.isEmpty) return null;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final b = pacote.beacons[indice % pacote.beacons.length];
    return PosicaoEstimada(b.no, Confianca.media, 'simulado');
  }
}

/// Etapa 5: leituras BLE reais (ex.: flutter_blue_plus), relacionando o
/// identificador do beacon ao nó do pacote e calculando a confiança pelo RSSI.
class LocalizacaoBle implements LocalizacaoService {
  @override
  Future<PosicaoEstimada?> estimar() async =>
      throw UnimplementedError('Integração BLE prevista para a Etapa 5, após validação em campo.');
}
