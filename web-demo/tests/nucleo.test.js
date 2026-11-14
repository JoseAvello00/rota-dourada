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

test('mobilidade: chega ao 2º piso pelo elevador atrás da Renner (acesso ao lado do Resolve Palmas)', () => {
  const r = N.calcularRota(g, P.mobilidade, 't_p1', 'p_c');
  assert.ok(tipos(r).includes('elevador'));
  assert.ok(!tipos(r).some(t => ['escada', 'escada_rolante', 'esteira'].includes(t)));
  assert.ok(['t_rp', 't_elev', 'p_elev'].every(n => r.nos.includes(n)));
  assert.ok(pacote.arestas.filter(a => a.fonte === 'informado_pela_equipe').length >= 3);
});

test('visual prefere escada fixa a escada rolante', () => {
  const r = N.calcularRota(g, P.visual, 't_p1', 'p_c');
  assert.ok(tipos(r).includes('escada') && !tipos(r).includes('escada_rolante'));
});

test('trecho não confirmado nunca entra em rota acessível', () => {
  const base = N.calcularRota(g, P.mobilidade, 't_p1', 't_rn');
  const p2 = JSON.parse(JSON.stringify(pacote));
  const alvo = base.arestas.find(a => a.tipo === 'corredor' && a.id !== base.arestas[0].id).id;
  p2.arestas.find(a => a.id === alvo).a_validar = true;
  const r = N.calcularRota(N.montarGrafo(p2), P.mobilidade, 't_p1', 't_rn');
  assert.ok(!r || !r.arestas.some(a => a.id === alvo));
  assert.ok(N.calcularRota(N.montarGrafo(p2), P.padrao, 't_p1', 't_rn').arestas.some(a => a.id === alvo) ||
            N.calcularRota(N.montarGrafo(p2), P.padrao, 't_p1', 't_rn'));
});

test('sem rota compatível retorna null (não sugere escada)', () => {
  const p2 = JSON.parse(JSON.stringify(pacote));
  p2.arestas = p2.arestas.filter(a => a.tipo !== 'elevador');
  assert.strictEqual(N.calcularRota(N.montarGrafo(p2), P.mobilidade, 't_po', 'p_c'), null);
});

test('sensorial reduz o trecho em áreas de estímulo alto', () => {
  const alto = r => r.arestas.filter(a => a.estimulo === 'alto').reduce((s, a) => s + a.distancia, 0);
  const pad = N.calcularRota(g, P.padrao, 't_p1', 't_rn');
  const sen = N.calcularRota(g, P.sensorial, 't_p1', 't_rn');
  assert.ok(alto(sen) < alto(pad));
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
  const r = N.calcularRota(g, P.padrao, 't_p1', 'p_c');
  const en = N.gerarInstrucoes(pacote, g, r, 'Main entrance P1', poi('poi_praca_alim'), 'en').map(e => e.texto);
  const es = N.gerarInstrucoes(pacote, g, r, 'Entrada principal P1', poi('poi_praca_alim'), 'es').map(e => e.texto);
  assert.ok(en.some(t => /Take the escalator up to the 2nd floor/.test(t)));
  assert.ok(es.some(t => /Tome la escalera mecánica/.test(t)));
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
  assert.ok(!N.calcularRota(g, u.perfil, 't_p1', 't_rn').arestas.some(a => ['escada', 'escada_rolante', 'esteira'].includes(a.tipo)));
});

test('sem deficiência (ou tipos ignorados quando "não") usa perfil padrão', () => {
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, { possuiDeficiencia: false, tipos: ['cadeirante'] }).perfis, ['padrao']);
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, null).perfil.proibidos, []);
});

test('toque no mapa: nó mais próximo (em metros) ignora escadas e elevadores', () => {
  assert.strictEqual(N.noMaisProximo(pacote, 0, 226, 170).id, 't_re');
  assert.strictEqual(N.noMaisProximo(pacote, 1, 53, 34).id, 'p_c');
});

test('cadeirante: todo destino dos dois andares tem rota sem escada a partir da P1', () => {
  const u = N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: ['cadeirante'] });
  pacote.pois.forEach(p => {
    const r = N.calcularRota(g, u.perfil, 't_p1', p.no);
    assert.ok(r && !r.arestas.some(a => ['escada', 'escada_rolante', 'esteira'].includes(a.tipo)), p.id);
  });
});

test('rede verificada na grade: nenhum trecho de corredor atravessa obstáculo da planta', () => {
  const nos = Object.fromEntries(pacote.nos.map(n => [n.id, n]));
  for (const a of pacote.edificio.andares) {
    const G = a.grade, C = G.celula_m, bits = G.rle.map(r => { const o = []; let v = 0; for (const n of r) { for (let i = 0; i < n; i++) o.push(v); v ^= 1; } return o; });
    const livre = (x, y) => { const l = Math.floor(y / C), c = Math.floor(x / C); return l >= 0 && l < bits.length && c >= 0 && c < bits[0].length && bits[l][c] === 1; };
    for (const e of pacote.arestas.filter(e => e.tipo === 'corredor' && e.geometria && nos[e.de].andar === a.id)) {
      for (let i = 1; i < e.geometria.length; i++) {
        const [ax, ay] = e.geometria[i - 1], [bx, by] = e.geometria[i], n = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay) / 0.25));
        for (let k = 0; k <= n; k++) assert.ok(livre(ax + (bx - ax) * k / n, ay + (by - ay) * k / n), `${e.id} sai da área de circulação`);
      }
    }
  }
});

test('deficiência na fala e auditiva liberam Conversar; outras não', () => {
  const f = t => N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: t }).ui.has('conversar');
  assert.ok(f(['fala']) && f(['auditiva']) && f(['cegueira', 'fala']));
  assert.ok(!f(['cadeirante']) && !f(['cegueira']) && !N.perfilDoUsuario(pacote, null).ui.has('conversar'));
  assert.deepStrictEqual(N.perfilDoUsuario(pacote, { possuiDeficiencia: true, tipos: ['fala'] }).perfis, ['padrao']);
});
