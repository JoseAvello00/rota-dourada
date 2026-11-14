// Gera dist/index.html autocontido (núcleo + pacote + recortes da planta) — funciona offline.
const fs = require('fs'), path = require('path');
const dados = path.join(__dirname, '..', 'dados');
const src = fs.readFileSync(path.join(__dirname, 'index.src.html'), 'utf8');
const nucleo = fs.readFileSync(path.join(__dirname, 'nucleo.js'), 'utf8');
const pacoteTxt = fs.readFileSync(path.join(dados, 'pacote_capim_dourado.json'), 'utf8');
const pacote = JSON.parse(pacoteTxt);
const imagens = {};
for (const a of pacote.edificio.andares) {
  for (const arq of new Set([a.imagem, ...Object.values(a.imagens || {})].filter(Boolean))) {
    imagens[arq] = 'data:image/webp;base64,' + fs.readFileSync(path.join(dados, arq)).toString('base64');
  }
}
fs.mkdirSync(path.join(__dirname, 'dist'), { recursive: true });
const out = src.replace('/*NUCLEO*/', () => nucleo)
  .replace('/*PACOTE*/', () => pacoteTxt.trim())
  .replace('/*IMAGENS*/', () => JSON.stringify(imagens));
fs.writeFileSync(path.join(__dirname, 'dist', 'index.html'), out);
console.log('dist/index.html', (out.length / 1024).toFixed(0), 'KB');
