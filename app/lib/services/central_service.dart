/// Integração com a central de atendimento do shopping (para o SOS).
///
/// Hoje NÃO existe integração: [disponivel] é falso e nada é enviado. O app mostra
/// isso claramente e nunca afirma que a ajuda foi acionada. Quando houver uma central,
/// basta implementar [CentralAtendimento] e devolver o status real do envio.
abstract class CentralAtendimento {
  bool get disponivel;
  Future<StatusEnvio> enviarPedidoDeAjuda({required String local, required List<String> necessidades});
}

enum StatusEnvio { naoEnviado, enviado, falhou }

class SemCentral implements CentralAtendimento {
  const SemCentral();
  @override
  bool get disponivel => false;
  @override
  Future<StatusEnvio> enviarPedidoDeAjuda({required String local, required List<String> necessidades}) async =>
      StatusEnvio.naoEnviado;
}
