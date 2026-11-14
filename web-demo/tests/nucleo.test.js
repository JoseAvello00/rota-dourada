// Testes do núcleo de navegação (rede traçada sobre a Planta Mix): node --test tests/nucleo.test.js
const { test } = require('node:test');
const assert = require('node:assert');
const N = require('../nucleo.js');
const pacote = require('../../dados/pacote_capim_dourado.json');
const g = N.montarGrafo(pacote);
const P = pacote.perfis;
const poi = id => pacote.pois.find(p => p.id === id);
const tipos = r => r.arestas.map(a => a.tipo);

test('padrão sobe pela escada rolante até a praça de alimentação', () => {
  const r = N.calcularRota(g, P.padrao, 't_p1', 'p_c');
  assert.ok(tipos(r).includes('escada_rolante'));
  assert.ok(r.distancia > 100 && r.distancia < 160, 'distância em metros reais');
});

test('mobilidade: sem rota confirmada por dentro; pelo acesso oeste usa elevador', () => {
  assert.strictEqual(N.calcularRota(g, P.mobilidade, 't_p1', 'p_c'), null);
  const r = N.calcularRota(g, P.mobilidade, 't_po', 'p_c');
  assert.ok(tipos(r).includes('elevador'));
  assert.ok(!tipos(r).some(t => ['escada', 'escada_rolante', 'esteira'].includes(t)));
  const alt = N.entradasComRota(pacote, g, P.mobilidade, 'p_c');
  assert.deepStrictEqual(alt.map(x => x.entrada.id), ['t_po']);
});

test('visual prefere escada fixa a escada rolante', () => {
  const r = N.calcularRota(g, P.visual, 't_p1', 'p_c');
  assert.ok(tipos(r).includes('escada') && !tipos(r).includes('escada_rolante'));
});

test('trecho não confirmado nunca entra em rota acessível', () => {
  const p2 = JSON.parse(JSON.stringify(pacote));
  p2.arestas.find(a => a.id === 'v_elevador').a_validar = true;
  const g2 = N.montarGrafo(p2);
  assert.strictEqual(N.calcularRota(g2, P.mobilidade, 't_po', 'p_c'), null);
  assert.ok(N.calcularRota(g2, P.padrao, 't_po', 'p_c'));
});

test('sem rota compatível retorna null (não sugere escada)', () => {
  const p2 = JSON.parse(JSON.stringify(pacote));
  p2.arestas = p2.arestas.filter(a => a.tipo !== 'elevador');
  assert.strictEqual(N.calcularRota(N.montarGrafo(p2), P.mobilidade, 't_po', 'p_c'), null);
});

test('sensorial desvia da Praça de Eventos central', () => {
  const pad = N.calcularRota(g, P.padrao, 't_p1', 't_rn');
  const sen = N.calcularRota(g, P.sensorial, 't_p1', 't_rn');
  assert.ok(pad.nos.includes('t_praca') && !sen.nos.includes('t_praca'));
});

test('paridade com a API Python (mesmos nós)', () => {
  const r = N.calcularRota(g, P.sensorial, 't_p1', 'p_c');
  assert.deepStrictEqual(r.nos, ['t_p1', 't_s0', 't_sw1', 't_swa', 't_sw2', 't_sw3', 't_esc', 'p_esc', 'p_e', 'p_c']);
});

test('instruções: entrada P1 → escada rolante → praça de alimentação', () => {
  const r = N.calcularRota(g, P.padrao, 't_p1', 'p_c');
  const txt = N.gerarInstrucoes(pacote, g, r, 'Entrada principal P1', poi('poi_praca_alim'), 'pt').map(e => e.texto);
  assert.match(txt[0], /^Saindo de Entrada principal P1/);
  assert.ok(txt.some(t => /Pegue a escada rolante e suba até o 2º Piso/.test(t)));
  assert.match(txt[txt.length - 1], /^Você chegou\. Praça de Alimentação/);
});

test('retas longas são divididas (nenhuma etapa acima de ~90 m)', () => {
  const r = N.calcularRota(g, P.padrao, 't_p3', 't_a7');
  const et = N.gerarInstrucoes(pacote, g, r, 'Entrada P3', poi('poi_cinemark'), 'pt');
  assert.ok(et.every(e => e.distancia <= 90));
  assert.ok(et.some(e => /^Continue em frente/.test(e.texto)));
});

test('instruções em inglês e espanhol', () => {
  const r = N.calcularRota(g, P.mobilidade, 't_po', 'p_c');
  const en = N.gerarInstrucoes(pacote, g, r, 'Main entrance P1', poi('poi_praca_alim'), 'en').map(e => e.texto);
  const es = N.gerarInstrucoes(pacote, g, r, 'Entrada principal P1', poi('poi_praca_alim'), 'es').map(e => e.texto);
  assert.ok(en.some(t => /Take the elevator to the 2nd floor/.test(t)));
  assert.ok(es.some(t => /Tome el ascensor/.test(t)));
  assert.ok(!en.join(' ').match(/Vire|Siga/));
});

test('busca sem acento, por nome e em inglês', () => {
  assert.ok(N.buscar(pacote, 'sanitario').length >= 6);
  assert.ok(N.buscar(pacote, 'banheiro acessivel').every(p => p.acessivel));
  assert.deepStrictEqual(N.buscar(pacote, 'renner').map(p => p.id), ['poi_renner']);
  assert.ok(N.buscar(pacote, 'restroom').length >= 6);
});

test('perfil combinado: cadeirante + cego soma restrições e penalidades', () => {
  const u = N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: ['cadeirante', 'cegueira'] });
  assert.deepStrictEqual(u.perfis.sort(), ['mobilidade', 'visual']);
  assert.ok(['escada', 'escada_rolante', 'esteira'].every(t => u.perfil.proibidos.includes(t)));
  assert.strictEqual(u.perfil.penalidade_curva, P.visual.penalidade_curva);
  assert.ok(u.ui.has('altoContraste') && u.ui.has('audioAuto') && u.ui.has('semEscadas'));
  assert.ok(u.perfil.exigir_confirmado);
  assert.ok(N.calcularRota(g, u.perfil, 't_po', 'p_c').arestas.some(a => a.tipo === 'elevador'));
});

test('sem deficiência (ou tipos ignorados quando "não") usa perfil padrão', () => {
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, { possuiDeficiencia: false, tipos: ['cadeirante'] }).perfis, ['padrao']);
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, null).perfil.proibidos, []);
});

test('toque no mapa: nó mais próximo (em metros) ignora escadas e elevadores', () => {
  assert.strictEqual(N.noMaisProximo(pacote, 0, 226, 170).id, 't_re');
  assert.strictEqual(N.noMaisProximo(pacote, 1, 53, 34).id, 'p_c');
});

test('cadeirante: todo o térreo tem rota sem escada; o 2º piso só pelo acesso oeste', () => {
  const u = N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: ['cadeirante'] });
  pacote.pois.filter(p => p.andar === 0).forEach(p => assert.ok(N.calcularRota(g, u.perfil, 't_rs', p.no), p.id));
  pacote.pois.filter(p => p.andar === 1).forEach(p => assert.ok(N.calcularRota(g, u.perfil, 't_po', p.no), p.id));
});

test('deficiência na fala e auditiva liberam Conversar; outras não', () => {
  const f = t => N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: t }).ui.has('conversar');
  assert.ok(f(['fala']) && f(['auditiva']) && f(['cegueira', 'fala']));
  assert.ok(!f(['cadeirante']) && !f(['cegueira']) && !N.perfilDoUsuario(pacote, null).ui.has('conversar'));
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: ['fala'] }).perfis, ['padrao']);
});
