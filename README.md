# Rota Dourada

Navegação indoor acessível para o **Capim Dourado Shopping** (Palmas – TO).
O visitante cria um perfil dizendo se tem alguma deficiência (e quais). O app se adapta a esse perfil: abre o mapa do shopping com todas as lojas e a posição atual dele, e traça a melhor rota para o perfil quando ele toca numa loja, pesquisa ou escolhe na lista. As instruções saem em texto, áudio e vibração. O cadastro é opcional e o app funciona sem internet depois que o mapa é salvo no aparelho.

HackaRun 2026 · Desafio *Acessibilidade e comunicação universal*
Equipe: Gabriel Silveira Figueira, Jose Eduardo Peixoto, Raphael Olimpio e Jose Guilherme Avello Peres

## O que o MVP faz

| Fluxo | Onde está |
|---|---|
| **Tela de acesso** com três opções: *Entrar sem conta* (visitante, só preferências de acessibilidade), *Entrar com e-mail* e *Criar conta* | `acesso_view.dart`, `entrar_view.dart`, `cadastro_view.dart` |
| **Conta**: nome, telefone, e-mail e necessidades (várias ao mesmo tempo), obrigatórios marcados, validação por campo, mensagens de carregamento, erro e sucesso. Perfil editável em *Configurações* | `conta_service.dart`, `api/app/contas.py` |
| **Voltar** em todas as telas secundárias, sempre no canto esquerdo, com rótulo "Voltar para {tela}" para leitores de tela. Preserva o que já foi preenchido | `widgets/barra.dart`, `navegacao_page.dart` |
| **Três temas** salvos no aparelho: Claro, Escuro e *Sexta-feira 13* (terror sem flashes, sustos ou animações) | `config_view.dart`, `tema.dart` |
| **Mapa limpo** gerado das camadas CAD da Planta Mix: corredores, lojas, entradas, escadas, escadas rolantes, elevador e sanitários, sem cotas e hachuras. Uma versão por tema | `ferramentas/gerar_pacote_da_planta.py` |
| **Mapa com todas as lojas**: toque no ícone, busca ou lista que abre arrastando a borda | `explorar_view.dart` |
| **Rota pelo perfil**, priorizando acessibilidade, com aviso honesto quando não há rota acessível confirmada | `rota_service.dart`, `navegacao_viewmodel.dart` |
| **Conversar** (só para perfis com surdez ou deficiência na fala) com botão **SOS – Preciso de ajuda** | `conversa_view.dart`, `sos_view.dart` |
| Instruções em texto, áudio e vibração (PT, EN, ES) | `instrucao_service.dart` |
| Pacote offline versionado + API | `pacote_service.dart`, `api/` |

### Como cada necessidade adapta o app

| Necessidade | Rota | Tela |
|---|---|---|
| Cadeirante / mobilidade reduzida | **exclui** escadas, escadas rolantes e esteiras; usa elevador, rampas e trechos confirmados | selo "Sem escadas" |
| Cegueira | **prioriza** caminhos sem escada; menos curvas; só trechos confirmados | alto contraste, passos falados, lista de lojas primeiro |
| Baixa visão | igual à cegueira | alto contraste |
| Surdez / auditiva | padrão | vibração em cada passo e botão *Conversar* |
| Deficiência na fala | padrão | botão *Conversar* |
| TEA / sensorial | evita áreas de estímulo alto | paleta calma, sem animações, um passo por vez |
| Intelectual | evita áreas de estímulo alto | um passo por vez |

Várias necessidades se somam: as proibições se acumulam, vale a penalidade mais alta e basta uma delas exigir trechos confirmados.

### Rotas acessíveis: regras

- A rota mais curta **não** é considerada acessível por padrão. Para perfis com restrição só entram trechos confirmados na planta; um trecho marcado `a_validar` nunca entra.
- **Mobilidade** nunca usa escada, escada rolante ou esteira.
- **Visual** aceita escada fixa só se não houver alternativa, e então a tela avisa "Inclui escada" e oferece a alternativa sem escadas.
- **Sem rota acessível confirmada**: o app diz isso e mostra por quê, sem apresentar outro percurso como acessível. Oferece: rota a partir de outra entrada que tenha rota sem escadas (se existir), *Conversar* ou "Ver onde fica a Segurança", *Revisar origem* e *Outro destino*.
- **O que a planta mostra hoje**: a única ligação desenhada entre o térreo e o 2º piso por dentro é o conjunto escadas rolantes + escada fixa da Praça de Eventos oeste. O único elevador fica no vestíbulo do acesso oeste (Av. JK). Por isso, para cadeirantes, a rota até o 2º piso só é oferecida **a partir do acesso oeste**, com o aviso de que é preciso chegar até lá por fora. Não inventamos passagens.

### SOS – Preciso de ajuda

Dentro de *Conversar*. Pede confirmação acessível (diálogo com foco, sem som), depois abre uma **mensagem em tela cheia** para mostrar a quem estiver perto ("Sou surdo / não consigo falar. Preciso de ajuda. Por favor, chame um funcionário do shopping."), com a posição atual e o botão "Fechar e voltar à conversa".

**Não há integração com central de atendimento no MVP.** O app não simula envio: a tela diz explicitamente que *nenhum alerta foi enviado*. O ponto de integração está pronto (`CentralAtendimento` em `central_service.dart`). Quando o shopping tiver uma central, a tela passa a mostrar o status real (enviado / falhou).

## Proposta e wireframes

- [Proposta de solução tecnológica](docs/proposta/PROPOSTA%20DE%20SOLU%C3%87%C3%83O%20TECNOL%C3%93GICA.pdf)
- [Wireframes de baixa fidelidade](docs/proposta/Wireframes-Acessibilidade-BaixaFidelidade.pdf)

## Estrutura

```
dados/        pacote de navegação piloto (JSON único e versionado)
api/          FastAPI: entrega e versão do pacote + validador de integridade
app/          Flutter (MVVM): o aplicativo
web-demo/     protótipo clicável (mesmo núcleo, para demo e pitch)
docs/         backlog, roteiro de pitch e evidências de testes
```

## Como executar

### API (Python 3.10+)
```bash
cd api
pip install -r requirements.txt -r requirements-dev.txt
uvicorn app.main:app --reload          # http://localhost:8000/docs
pytest -v                              # 24 testes
```
Endpoints:
- Pacotes: `GET /pacotes`, `GET /pacotes/{id}/versao`, `GET /pacotes/{id}` (com ETag/304), `GET /pacotes/{id}/validacao`.
- Contas: `GET /contas/tipos-deficiencia`, `POST /contas` (criar), `POST /contas/entrar`, `GET|PUT|DELETE /contas/eu` (Bearer), `POST /contas/sair`. Senha com PBKDF2-SHA256; e-mail ou senha errados recebem a mesma mensagem. Necessidades só são aceitas com `consentimento: true` (LGPD, art. 11). `DELETE` atende ao direito de eliminação. Para gravar em arquivo: `CONTAS_ARQUIVO=contas.json`.
Para usar o Firestore: `PACOTE_FONTE=firestore` e as credenciais do Google Cloud.

### App Flutter (3.22+)
```bash
cd app
flutter create . --platforms=android,ios --project-name rota_dourada   # gera as pastas de plataforma
flutter pub get
flutter test                                                         # 14 testes
flutter run                                                          # usa o pacote embutido
flutter run --dart-define=API_URL=http://10.0.2.2:8000               # emulador Android + API local (necessário para contas)
```

### Protótipo web
```bash
cd web-demo
node --test tests/nucleo.test.js       # 16 testes
node build.js                          # gera dist/index.html (abre direto no navegador, offline)
```

## Pacote de navegação (gerado da planta)

`dados/pacote_capim_dourado.json` (v1.0.0) é gerado a partir da **Planta Mix (nov/2026)** por `ferramentas/gerar_pacote_da_planta.py`:

```bash
pip install pymupdf pillow
python3 -I ferramentas/gerar_pacote_da_planta.py caminho/2026_11_CDS_MIX.pdf
```

- **Escala**: o térreo foi calibrado pela Praça de Eventos circular (265,90 m²) e conferido na praça retangular (207,36 m² na planta, 206,7 m² medidos): 0,30 m por ponto do PDF (1:850). O 2º piso foi calibrado pelas cotas das lojas: 0,0555 m por ponto. As distâncias das rotas são em metros reais.
- **Lojas**: 194 pontos. Vêm dos logotipos do PDF (com número e área da loja ao lado), dos quiosques ("Q nn" + nome) e dos serviços escritos na planta (sanitários, PNE, Espaço Família, brigadas, segurança, praças de eventos).
- **Corredores**: a rede de 63 nós e 73 trechos foi traçada sobre a planta. Ela inclui o anel em volta da Riachuelo, o corredor sul (Renner ↔ Marisa, passando pela entrada P1), o corredor noroeste (P3), o corredor das megalojas (P2 e acesso de pedestres), a Alameda das Cores e a praça de alimentação. `docs/rede-sobre-planta-*.png` mostra a rede desenhada por cima da planta.
- **Entre andares**: as escadas rolantes e a escada fixa ao lado da Praça de Eventos oeste chegam ao 2º piso (~15 m nas duas folhas). O **único elevador** desenhado fica no vestíbulo do acesso oeste (Av. JK); a planta não mostra ligação interna até ele, então nenhuma foi criada.
- **Mapa limpo**: `dados/planta_{terreo,piso2}_{claro,escuro,terror}.webp`. O gerador desliga as camadas CAD de poluição visual (logos, cotas, textos, hachuras), cobre logotipos soltos e pinta os corredores (preenchimento do espaço livre limitado a 9 m da rede). Paredes, lojas, entradas, escadas, elevador e sanitários continuam como na planta.
Antes de publicar uma versão, rode `GET /pacotes/{id}/validacao`: ele verifica a integridade e se **todo destino tem rota em todos os perfis** a partir de cada entrada.

## Privacidade

- **Visitante**: nada sai do aparelho. As preferências só ficam salvas se a pessoa marcar "Lembrar neste aparelho".
- **Conta (app Flutter)**: os dados ficam na API (`API_URL`). O app guarda só o token de sessão. Sem API configurada, o app informa que não é possível criar conta e oferece o modo visitante; ele nunca finge uma conta local.
- **Protótipo web**: como não tem servidor, as contas de demonstração ficam no `localStorage` do navegador, com senha em PBKDF2 (WebCrypto). O próprio protótipo avisa isso.
- Necessidades são dado sensível (LGPD art. 11): só com consentimento explícito. "Apagar meus dados" remove tudo.

## Limites assumidos

- **SOS sem central**: ver acima.
- A posição é simulada (beacon) ou ajustada pelo toque no mapa.
- A rede de corredores foi traçada sobre a planta, não medida no local. Portas das lojas, o elevador do acesso oeste e a existência de algum elevador interno precisam de checagem em campo. Se a vistoria confirmar uma ligação, basta incluí-la no pacote, e a rota acessível aparece sozinha.
- Recuperação de senha e login social ficam para a próxima iteração.
- O código Dart foi escrito para Flutter estável, mas não foi compilado neste ambiente (sem SDK). O CI (`.github/workflows/ci.yml`) roda `flutter analyze` e `flutter test` a cada push.
