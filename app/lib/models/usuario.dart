import 'pacote.dart';

/// Tipo de deficiência do cadastro → perfil de rota + ajustes de interface.
/// Mesma tabela de web-demo/nucleo.js e api/app/perfis.py.
class TipoDeficiencia {
  final String id, perfil;
  final Set<String> ui;
  final Map<String, String> rotulo;
  const TipoDeficiencia(this.id, this.perfil, this.ui, this.rotulo);
}

const tiposDeficiencia = <TipoDeficiencia>[
  TipoDeficiencia('cadeirante', 'mobilidade', {'semEscadas'},
      {'pt': 'Cadeirante (cadeira de rodas)', 'en': 'Wheelchair user', 'es': 'Usuario de silla de ruedas'}),
  TipoDeficiencia('mobilidade_reduzida', 'mobilidade', {'semEscadas'}, {
    'pt': 'Mobilidade reduzida (muletas, andador, bengala)',
    'en': 'Reduced mobility (crutches, walker, cane)',
    'es': 'Movilidad reducida (muletas, andador, bastón)'
  }),
  TipoDeficiencia('cegueira', 'visual', {'altoContraste', 'audioAuto', 'listaPrimeiro'},
      {'pt': 'Deficiência visual (cegueira)', 'en': 'Blindness', 'es': 'Ceguera'}),
  TipoDeficiencia('baixa_visao', 'visual', {'altoContraste'}, {'pt': 'Baixa visão', 'en': 'Low vision', 'es': 'Baja visión'}),
  TipoDeficiencia('auditiva', 'auditiva', {'vibracao', 'conversar'}, {
    'pt': 'Deficiência auditiva ou surdez',
    'en': 'Hearing impairment or deafness',
    'es': 'Discapacidad auditiva o sordera'
  }),
  TipoDeficiencia('fala', 'padrao', {'conversar'},
      {'pt': 'Deficiência na fala', 'en': 'Speech impairment', 'es': 'Discapacidad del habla'}),
  TipoDeficiencia('tea', 'sensorial', {'calmo', 'passoAPasso'}, {
    'pt': 'Autismo (TEA) ou sensibilidade sensorial',
    'en': 'Autism or sensory sensitivity',
    'es': 'Autismo (TEA) o sensibilidad sensorial'
  }),
  TipoDeficiencia('intelectual', 'sensorial', {'passoAPasso'}, {
    'pt': 'Deficiência intelectual (instruções mais simples)',
    'en': 'Intellectual disability (simpler directions)',
    'es': 'Discapacidad intelectual (indicaciones más simples)'
  }),
  TipoDeficiencia('outra', 'padrao', {}, {'pt': 'Outra', 'en': 'Other', 'es': 'Otra'}),
];

/// Conta (com nome, telefone e e-mail) ou visitante (só necessidades).
class Usuario {
  final String nome;
  final String? email;
  final String? telefone;
  final bool possuiDeficiencia;
  final List<String> tipos;
  final bool consentimento;
  final String idioma;
  final String criadoEm;
  final String? idRemoto; // id na API, quando sincronizado

  const Usuario({
    required this.nome,
    this.email,
    this.telefone,
    required this.possuiDeficiencia,
    required this.tipos,
    required this.consentimento,
    this.idioma = 'pt',
    required this.criadoEm,
    this.idRemoto,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'possuiDeficiencia': possuiDeficiencia,
        'tipos': tipos,
        'consentimento': consentimento,
        'idioma': idioma,
        'criadoEm': criadoEm,
        'idRemoto': idRemoto,
      };

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        nome: j['nome'] as String,
        email: j['email'] as String?,
        telefone: j['telefone'] as String?,
        possuiDeficiencia: (j['possuiDeficiencia'] as bool?) ?? false,
        tipos: ((j['tipos'] as List?) ?? const []).cast<String>(),
        consentimento: (j['consentimento'] as bool?) ?? false,
        idioma: (j['idioma'] as String?) ?? 'pt',
        criadoEm: j['criadoEm'] as String,
        idRemoto: j['idRemoto'] as String?,
      );

  bool get visitante => email == null;

  /// Conta vinda da API (/contas).
  factory Usuario.daApi(Map<String, dynamic> j) => Usuario(
        nome: j['nome'] as String,
        email: j['email'] as String?,
        telefone: j['telefone'] as String?,
        possuiDeficiencia: (j['possui_deficiencia'] as bool?) ?? false,
        tipos: ((j['tipos'] as List?) ?? const []).cast<String>(),
        consentimento: (j['consentimento_dados_sensiveis'] as bool?) ?? false,
        idioma: (j['idioma'] as String?) ?? 'pt',
        criadoEm: (j['criado_em'] as String?) ?? '',
        idRemoto: j['id'] as String?,
      );

  Map<String, dynamic> paraApi({String? senha}) => {
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'idioma': idioma,
        'possui_deficiencia': possuiDeficiencia,
        'tipos': tipos,
        'consentimento_dados_sensiveis': consentimento,
        if (senha != null && senha.isNotEmpty) 'senha': senha,
      };

  Usuario comIdRemoto(String id) => Usuario(
      nome: nome,
      email: email,
      telefone: telefone,
      possuiDeficiencia: possuiDeficiencia,
      tipos: tipos,
      consentimento: consentimento,
      idioma: idioma,
      criadoEm: criadoEm,
      idRemoto: id);
}

/// Perfil efetivo: regras de rota combinadas + ajustes de interface.
class PerfilUsuario {
  final List<String> perfis;
  final Perfil rota;
  final Set<String> ui;
  const PerfilUsuario(this.perfis, this.rota, this.ui);

  static PerfilUsuario de(Pacote pacote, Usuario? u) {
    final tipos = (u != null && u.possuiDeficiencia) ? u.tipos : const <String>[];
    final defs = tiposDeficiencia.where((t) => tipos.contains(t.id));
    final perfis = defs.map((d) => d.perfil).where((p) => p != 'padrao').toSet().toList()..sort();
    final ui = defs.expand((d) => d.ui).toSet();
    final ids = perfis.isEmpty ? ['padrao'] : perfis;
    return PerfilUsuario(ids, Perfil.combinar(pacote, ids), ui);
  }

  bool tem(String flag) => ui.contains(flag);
  bool usa(String perfil) => perfis.contains(perfil);
}
