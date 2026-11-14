/* Rota Dourada — núcleo de navegação local (rotas + instruções).
 * Mesma regra do app Flutter (lib/services) e da API (api/app/navegacao.py).
 * Roda no navegador (window.Nucleo) e no Node (module.exports) para testes. */
(function (raiz) {
  'use strict';

  // ---------- Grafo ----------
  function montarGrafo(pacote) {
    const nos = {};
    pacote.nos.forEach(n => { nos[n.id] = n; });
    const adj = {};
    Object.keys(nos).forEach(id => { adj[id] = []; });
    pacote.arestas.forEach(e => {
      const a = nos[e.de], b = nos[e.para];
      const dist = e.distancia || Math.hypot(a.x - b.x, a.y - b.y);
      const base = { id: e.id, tipo: e.tipo, distancia: dist, estimulo: e.estimulo || 'medio', descricao: e.descricao, confirmado: !e.a_validar };
      adj[e.de].push(Object.assign({ de: e.de, para: e.para }, base));
      if (e.bidirecional !== false) adj[e.para].push(Object.assign({ de: e.para, para: e.de }, base));
    });
    return { nos, adj };
  }

  function houveCurva(nos, a, b, c) {
    const pa = nos[a], pb = nos[b], pc = nos[c];
    if (pa.andar !== pb.andar || pb.andar !== pc.andar) return false;
    return Math.abs(anguloCurva(pa, pb, pc)) > 30;
  }

  /** Ângulo (graus) da curva em b. Positivo = direita (eixo y da tela aponta para baixo). */
  function anguloCurva(pa, pb, pc) {
    const v1x = pb.x - pa.x, v1y = pb.y - pa.y, v2x = pc.x - pb.x, v2y = pc.y - pb.y;
    const cruz = v1x * v2y - v1y * v2x, esc = v1x * v2x + v1y * v2y;
    return Math.atan2(cruz, esc) * 180 / Math.PI;
  }

  // ---------- Dijkstra com estado (nó, anterior) ----------
  function calcularRota(grafo, perfil, origem, destino) {
    const proibidos = new Set(perfil.proibidos || []);
    const mt = perfil.multiplicador_tipo || {}, me = perfil.multiplicador_estimulo || {};
    const pen = perfil.penalidade_curva || 0;
    const soConfirmados = !!perfil.exigir_confirmado; // rotas acessíveis só com trechos confirmados na planta
    const chave = (n, v) => n + '|' + (v || '');
    const melhor = new Map([[chave(origem, null), 0]]);
    const ant = new Map();
    const fila = [[0, origem, null]];
    let final = null;

    while (fila.length) {
      // fila de prioridade simples (grafos pequenos do pacote)
      let iMin = 0;
      for (let i = 1; i < fila.length; i++) if (fila[i][0] < fila[iMin][0]) iMin = i;
      const [custo, no, veio] = fila.splice(iMin, 1)[0];
      if (custo > (melhor.get(chave(no, veio)) ?? Infinity)) continue;
      if (no === destino) { final = [no, veio]; break; }
      for (const a of grafo.adj[no]) {
        if (proibidos.has(a.tipo) || (soConfirmados && !a.confirmado)) continue;
        let c = a.distancia * (mt[a.tipo] || 1) * (me[a.estimulo] || 1);
        if (veio && pen && houveCurva(grafo.nos, veio, no, a.para)) c += pen;
        const novo = custo + c, k = chave(a.para, no);
        if (novo < (melhor.get(k) ?? Infinity)) {
          melhor.set(k, novo);
          ant.set(k, [[no, veio], a]);
          fila.push([novo, a.para, no]);
        }
      }
    }
    if (!final) return null;

    const nosRota = [final[0]], arestas = [];
    let k = chave(final[0], final[1]);
    while (ant.has(k)) {
      const [[n, v], a] = ant.get(k);
      arestas.push(a); nosRota.push(n); k = chave(n, v);
    }
    nosRota.reverse(); arestas.reverse();
    return {
      nos: nosRota,
      arestas,
      distancia: Math.round(arestas.reduce((s, a) => s + a.distancia, 0)),
      custo: melhor.get(chave(final[0], final[1])),
    };
  }

  // ---------- Instruções ----------
  const T = {
    pt: {
      sair: (o, d, r) => `Saindo de ${o}, siga por cerca de ${d} metros até chegar ${r}.`,
      estaRef: (o, d, r) => `Você está ${o}. Siga por cerca de ${d} metros até chegar ${r}.`,
      virar: (lado, d, r) => `Vire à ${lado} e siga por cerca de ${d} metros até chegar ${r}.`,
      frente: (d, r) => `Continue em frente por cerca de ${d} metros até chegar ${r}.`,
      voltar: (d, r) => `Dê meia-volta e siga por cerca de ${d} metros até chegar ${r}.`,
      aoSair: (d, r) => `Ao sair, siga por cerca de ${d} metros até chegar ${r}.`,
      esquerda: 'esquerda', direita: 'direita',
      elevador: a => `Pegue o elevador até o ${a}.`,
      escadaSobe: a => `Suba a escada até o ${a}.`,
      escadaDesce: a => `Desça a escada até o ${a}.`,
      esteira: a => `Use a esteira rolante até o ${a}.`,
      escadaRolanteSobe: a => `Pegue a escada rolante e suba até o ${a}.`,
      escadaRolanteDesce: a => `Pegue a escada rolante e desça até o ${a}.`,
      rampa: (d, r) => `Siga pela rampa por cerca de ${d} metros até chegar ${r}.`,
      escadaLocal: (d, r) => `Use a escada (cerca de ${d} metros) até chegar ${r}.`,
      chegou: (n, lado) => lado ? `Você chegou. ${n} fica à sua ${lado}.` : `Você chegou. ${n} fica à sua frente.`,
      jaEsta: n => `Você já está no ponto de acesso de ${n}.`,
      prefixo: o => `Saindo de ${o}:`,
    },
    en: {
      sair: (o, d, r) => `From ${o}, walk about ${d} meters until you are ${r}.`,
      estaRef: (o, d, r) => `You are ${o}. Walk about ${d} meters until you are ${r}.`,
      virar: (lado, d, r) => `Turn ${lado} and walk about ${d} meters until you are ${r}.`,
      frente: (d, r) => `Keep straight for about ${d} meters until you are ${r}.`,
      voltar: (d, r) => `Turn around and walk about ${d} meters until you are ${r}.`,
      aoSair: (d, r) => `When you exit, walk about ${d} meters until you are ${r}.`,
      esquerda: 'left', direita: 'right',
      elevador: a => `Take the elevator to the ${a}.`,
      escadaSobe: a => `Go up the stairs to the ${a}.`,
      escadaDesce: a => `Go down the stairs to the ${a}.`,
      esteira: a => `Take the moving walkway to the ${a}.`,
      escadaRolanteSobe: a => `Take the escalator up to the ${a}.`,
      escadaRolanteDesce: a => `Take the escalator down to the ${a}.`,
      rampa: (d, r) => `Follow the ramp for about ${d} meters until you are ${r}.`,
      escadaLocal: (d, r) => `Take the stairs (about ${d} meters) until you are ${r}.`,
      chegou: (n, lado) => lado ? `You have arrived. ${n} is on your ${lado}.` : `You have arrived. ${n} is in front of you.`,
      jaEsta: n => `You are already at the access point of ${n}.`,
      prefixo: o => `From ${o}:`,
    },
    es: {
      sair: (o, d, r) => `Desde ${o}, camine unos ${d} metros hasta llegar ${r}.`,
      estaRef: (o, d, r) => `Usted está ${o}. Camine unos ${d} metros hasta llegar ${r}.`,
      virar: (lado, d, r) => `Gire a la ${lado} y camine unos ${d} metros hasta llegar ${r}.`,
      frente: (d, r) => `Siga recto unos ${d} metros hasta llegar ${r}.`,
      voltar: (d, r) => `Dé la vuelta y camine unos ${d} metros hasta llegar ${r}.`,
      aoSair: (d, r) => `Al salir, camine unos ${d} metros hasta llegar ${r}.`,
      esquerda: 'izquierda', direita: 'derecha',
      elevador: a => `Tome el ascensor hasta el ${a}.`,
      escadaSobe: a => `Suba la escalera hasta el ${a}.`,
      escadaDesce: a => `Baje la escalera hasta el ${a}.`,
      esteira: a => `Use la cinta transportadora hasta el ${a}.`,
      escadaRolanteSobe: a => `Tome la escalera mecánica y suba hasta el ${a}.`,
      escadaRolanteDesce: a => `Tome la escalera mecánica y baje hasta el ${a}.`,
      rampa: (d, r) => `Siga por la rampa unos ${d} metros hasta llegar ${r}.`,
      escadaLocal: (d, r) => `Use la escalera (unos ${d} metros) hasta llegar ${r}.`,
      chegou: (n, lado) => lado ? `Ha llegado. ${n} está a su ${lado}.` : `Ha llegado. ${n} está frente a usted.`,
      jaEsta: n => `Ya está en el punto de acceso de ${n}.`,
      prefixo: o => `Desde ${o}:`,
    },
  };

  const VERTICAIS = new Set(['elevador', 'escada', 'esteira', 'escada_rolante']);
  const arred = d => Math.max(5, Math.round(d / 5) * 5);

  function textoLocal(obj, campo, idioma) {
    return (idioma !== 'pt' && obj[campo + '_' + idioma]) || obj[campo] || '';
  }
  function refNo(no, idioma) { return textoLocal(no, 'referencia', idioma) || textoLocal(no, 'nome', idioma); }
  function nomeAndar(pacote, id, idioma) {
    const a = pacote.edificio.andares.find(x => x.id === id);
    return textoLocal(a, 'nome', idioma);
  }
  function ladoDe(ang, t) {
    if (Math.abs(ang) <= 30) return null;
    return ang > 0 ? t.direita : t.esquerda;
  }

  /**
   * Converte a rota em etapas: uma por ponto de decisão.
   * Cada etapa: {texto, icone, no (onde termina), andar, distancia}
   * origemNome: nome de uma entrada; null = descrever pela referência do nó de origem.
   */
  function gerarInstrucoes(pacote, grafo, rota, origemNome, poi, idioma) {
    idioma = idioma || 'pt';
    const t = T[idioma], nos = grafo.nos, etapas = [];
    const nomePoi = textoLocal(poi, 'nome', idioma);
    if (rota.arestas.length === 0) {
      etapas.push({ texto: t.jaEsta(nomePoi), icone: 'chegada', no: rota.nos[0], andar: nos[rota.nos[0]].andar, distancia: 0 });
      return etapas;
    }

    let i = 0, primeiro = true, aposVertical = false, anguloEntrada = null;
    const A = rota.arestas;
    while (i < A.length) {
      const a = A[i];
      const de = nos[a.de], para = nos[a.para];
      const entreAndares = VERTICAIS.has(a.tipo) && de.andar !== para.andar;

      if (entreAndares) {
        const andar = nomeAndar(pacote, para.andar, idioma);
        let texto, icone = a.tipo;
        if (a.tipo === 'elevador') texto = t.elevador(andar);
        else if (a.tipo === 'esteira') texto = t.esteira(andar);
        else if (a.tipo === 'escada_rolante') { texto = para.andar > de.andar ? t.escadaRolanteSobe(andar) : t.escadaRolanteDesce(andar); icone = 'escada'; }
        else texto = para.andar > de.andar ? t.escadaSobe(andar) : t.escadaDesce(andar);
        etapas.push({ texto, icone, no: a.para, andar: para.andar, distancia: Math.round(a.distancia) });
        i++; aposVertical = true; anguloEntrada = null; primeiro = false;
        continue;
      }

      if (a.tipo === 'rampa' || a.tipo === 'escada') {
        const d = arred(a.distancia), r = refNo(para, idioma);
        let texto = a.tipo === 'rampa' ? t.rampa(d, r) : t.escadaLocal(d, r);
        if (primeiro && origemNome) texto = t.prefixo(origemNome) + ' ' + texto.charAt(0).toLowerCase() + texto.slice(1);
        etapas.push({ texto, icone: a.tipo, no: a.para, andar: para.andar, distancia: Math.round(a.distancia) });
        i++; primeiro = false; aposVertical = false; anguloEntrada = null;
        continue;
      }

      // Agrupa corredores em linha reta até o próximo ponto de decisão.
      let dist = a.distancia, j = i;
      // retas longas (> 60 m) viram mais de uma etapa, com referência no meio
      while (j + 1 < A.length && A[j + 1].tipo === 'corredor' && dist < 60 &&
             Math.abs(anguloCurva(nos[A[j].de], nos[A[j].para], nos[A[j + 1].para])) <= 30) {
        j++; dist += A[j].distancia;
      }
      const fim = nos[A[j].para], d = arred(dist), r = refNo(fim, idioma);
      let texto, icone = 'frente';
      if (primeiro) texto = origemNome ? t.sair(origemNome, d, r) : t.estaRef(refNo(nos[A[0].de], idioma), d, r);
      else if (aposVertical) texto = t.aoSair(d, r);
      else {
        const ang = anguloEntrada ?? 0;
        if (Math.abs(ang) > 150) { texto = t.voltar(d, r); icone = 'voltar'; }
        else if (Math.abs(ang) > 30) { texto = t.virar(ladoDe(ang, t), d, r); icone = ang > 0 ? 'direita' : 'esquerda'; }
        else texto = t.frente(d, r);
      }
      etapas.push({ texto, icone, no: fim.id, andar: fim.andar, distancia: Math.round(dist) });
      if (j + 1 < A.length) {
        const prox = nos[A[j + 1].para];
        anguloEntrada = fim.andar === prox.andar ? anguloCurva(nos[A[j].de], fim, prox) : null;
      }
      i = j + 1; primeiro = false; aposVertical = false;
    }

    // Chegada: lado do destino em relação à última direção de caminhada.
    const ult = A[A.length - 1], pa = nos[ult.de], pb = nos[ult.para];
    let lado = null;
    if (pa.andar === pb.andar) lado = ladoDe(anguloCurva(pa, pb, poi), t);
    etapas.push({ texto: t.chegou(nomePoi, lado), icone: 'chegada', no: pb.id, andar: pb.andar, distancia: 0 });
    return etapas;
  }

  // ---------- Busca ----------
  function normalizar(s) {
    return (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  }
  function buscar(pacote, termo, categoria) {
    const q = normalizar(termo).trim();
    return pacote.pois.filter(p => {
      if (categoria && p.categoria !== categoria) return false;
      if (!q) return true;
      const alvo = normalizar([p.nome, p.nome_en, p.nome_es, ...(p.tags || [])].join(' '));
      return q.split(/\s+/).every(w => alvo.includes(w));
    });
  }


  // ---------- Perfil do usuário ----------
  /** Tipos de deficiência do cadastro → perfil de rota + ajustes de interface. */
  const TIPOS_DEFICIENCIA = [
    { id: 'cadeirante', perfil: 'mobilidade', ui: ['semEscadas'],
      pt: 'Cadeirante (cadeira de rodas)', en: 'Wheelchair user', es: 'Usuario de silla de ruedas' },
    { id: 'mobilidade_reduzida', perfil: 'mobilidade', ui: ['semEscadas'],
      pt: 'Mobilidade reduzida (muletas, andador, bengala)', en: 'Reduced mobility (crutches, walker, cane)', es: 'Movilidad reducida (muletas, andador, bastón)' },
    { id: 'cegueira', perfil: 'visual', ui: ['altoContraste', 'audioAuto', 'listaPrimeiro'],
      pt: 'Deficiência visual (cegueira)', en: 'Blindness', es: 'Ceguera' },
    { id: 'baixa_visao', perfil: 'visual', ui: ['altoContraste'],
      pt: 'Baixa visão', en: 'Low vision', es: 'Baja visión' },
    { id: 'auditiva', perfil: 'auditiva', ui: ['vibracao', 'conversar'],
      pt: 'Deficiência auditiva ou surdez', en: 'Hearing impairment or deafness', es: 'Discapacidad auditiva o sordera' },
    { id: 'fala', perfil: 'padrao', ui: ['conversar'],
      pt: 'Deficiência na fala', en: 'Speech impairment', es: 'Discapacidad del habla' },
    { id: 'tea', perfil: 'sensorial', ui: ['calmo', 'passoAPasso'],
      pt: 'Autismo (TEA) ou sensibilidade sensorial', en: 'Autism or sensory sensitivity', es: 'Autismo (TEA) o sensibilidad sensorial' },
    { id: 'intelectual', perfil: 'sensorial', ui: ['passoAPasso'],
      pt: 'Deficiência intelectual (instruções mais simples)', en: 'Intellectual disability (simpler directions)', es: 'Discapacidad intelectual (indicaciones más simples)' },
    { id: 'outra', perfil: 'padrao', ui: [],
      pt: 'Outra', en: 'Other', es: 'Otra' },
  ];

  /** Junta perfis: restrições somam, multiplicadores e penalidades usam o maior valor. */
  function combinarPerfis(pacote, ids) {
    const lista = (ids && ids.length ? ids : ['padrao']).filter(id => pacote.perfis[id]);
    const out = { ids: lista, nome: lista.map(id => pacote.perfis[id].nome).join(' + '),
      proibidos: [], multiplicador_tipo: {}, multiplicador_estimulo: {}, penalidade_curva: 0, exigir_confirmado: false };
    const proib = new Set();
    lista.forEach(id => {
      const p = pacote.perfis[id];
      (p.proibidos || []).forEach(t => proib.add(t));
      for (const [k, v] of Object.entries(p.multiplicador_tipo || {})) out.multiplicador_tipo[k] = Math.max(out.multiplicador_tipo[k] || 1, v);
      for (const [k, v] of Object.entries(p.multiplicador_estimulo || {})) out.multiplicador_estimulo[k] = Math.max(out.multiplicador_estimulo[k] || 1, v);
      out.penalidade_curva = Math.max(out.penalidade_curva, p.penalidade_curva || 0);
      out.exigir_confirmado = out.exigir_confirmado || !!p.exigir_confirmado;
    });
    out.proibidos = [...proib];
    return out;
  }

  /** usuario = { possuiDeficiencia: bool, tipos: [ids] } → { perfil, perfis, ui:Set } */
  function perfilDoUsuario(pacote, usuario) {
    const tipos = usuario && usuario.possuiDeficiencia ? (usuario.tipos || []) : [];
    const defs = TIPOS_DEFICIENCIA.filter(t => tipos.includes(t.id));
    const perfis = [...new Set(defs.map(d => d.perfil).filter(p => p !== 'padrao'))];
    const ui = new Set(defs.flatMap(d => d.ui));
    return { perfil: combinarPerfis(pacote, perfis), perfis: perfis.length ? perfis : ['padrao'], ui };
  }

  /** Entradas a partir das quais existe rota compatível com o perfil (para oferecer como alternativa). */
  function entradasComRota(pacote, grafo, perfil, destino) {
    return pacote.nos.filter(n => n.tipo === 'entrada')
      .map(n => ({ entrada: n, rota: calcularRota(grafo, perfil, n.id, destino) }))
      .filter(x => x.rota).sort((a, b) => a.rota.distancia - b.rota.distancia);
  }

  /** Nó conhecido (corredor/entrada) mais próximo de um ponto do mapa. */
  function noMaisProximo(pacote, andar, x, y) {
    let melhor = null, dMin = Infinity;
    pacote.nos.forEach(n => {
      if (n.andar !== andar || n.tipo === 'vertical') return;
      const d = Math.hypot(n.x - x, n.y - y);
      if (d < dMin) { dMin = d; melhor = n; }
    });
    return melhor;
  }

  const api = { montarGrafo, TIPOS_DEFICIENCIA, combinarPerfis, perfilDoUsuario, noMaisProximo, entradasComRota, calcularRota, gerarInstrucoes, buscar, anguloCurva, normalizar, TEXTOS: T };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else raiz.Nucleo = api;
})(typeof window !== 'undefined' ? window : globalThis);
