# Roteiro de pitch (1min15s a 2min)

**Fio condutor:** o capim dourado é trançado à mão no Jalapão. A Rota Dourada trança o mapa do shopping com as necessidades de cada visitante, e o fio dourado na tela é a rota.

| Tempo | Cena (tela) | Fala |
|---|---|---|
| 0:00–0:15 | Visitante cadeirante parado diante da escada rolante (ou foto da planta) | "No Capim Dourado, uma placa diz *Praça de Alimentação ↑*. Para quem usa cadeira de rodas, não enxerga a placa, é surdo ou não fala português, essa seta não serve." |
| 0:15–0:25 | Cadastro: "Sim" → marca "Cadeirante"; o quadro "O app vai se adaptar assim" muda na hora | "No cadastro, a pessoa diz se tem alguma deficiência. O app se molda a ela, e ela vê exatamente como." |
| 0:25–0:45 | Tela de acesso (visitante / entrar / criar conta) → marca "Cadeirante" | "Sem conta ou com conta, a pessoa diz o que precisa, e pode marcar mais de uma necessidade. O app se molda a ela." |
| 0:45–1:05 | Mapa limpo; toca na Praça de Alimentação → "Não há rota acessível confirmada" + alternativas | "Montamos o mapa a partir da planta oficial. Nós não mentimos para quem usa cadeira de rodas: a planta não mostra elevador por dentro até o 2º piso. Então o app diz isso e mostra a saída real, o elevador do acesso oeste. Rota mais curta não é rota acessível." |
| 1:05–1:25 | Perfil surdo → *Conversar* → SOS → tela cheia vermelha | "Para quem é surdo ou não fala, a conversa com o atendente é por escrito. Numa emergência, o SOS mostra em tela cheia: preciso de ajuda, chame um funcionário. Sem som e sem fingir que avisou alguém." |
| 1:25–1:40 | Configurações: tema Escuro → *Sexta-feira 13*; perfil com cegueira com passo falado | "Tema claro, escuro e até um de sexta-feira 13, sem sustos nem flashes. No modo visual, cada passo é falado e diz de que lado fica a loja." |
| 1:40–1:55 | Código / CI verde / arquitetura em 1 slide | "Flutter, FastAPI, pacote versionado e 54 testes automatizados. Próximo passo: beacons BLE e teste com usuários reais no térreo." |
| 1:55–2:00 | Logo | "Rota Dourada: o shopping inteiro, para todo mundo." |

## Diferenciais para destacar

0. **Mapa real e dado acionável.** O mapa limpo vem das camadas CAD da Planta Mix, em metros. Além de guiar, ele mostra ao shopping onde estão as barreiras: hoje a planta não tem ligação sem escadas por dentro até o 2º piso.
1a. **Honestidade de rota.** Só trechos confirmados entram numa rota acessível. Sem rota confirmada, o app explica e oferece alternativas reais.
1b. **SOS que não finge.** Mensagem em tela cheia para quem está perto, e o app nunca diz que acionou ajuda sem uma central integrada.

1. **Acessibilidade como regra, não como filtro.** O algoritmo nunca relaxa a restrição; prefere dizer "não há rota" a mandar alguém para uma escada.
2. **Conversa face a face offline.** Resolve a parte do desafio que mapas não resolvem: falar com os profissionais do shopping.
3. **Instruções que não dependem do mapa.** Referências do ambiente ("até chegar na Praça de Eventos") e lado de chegada ("fica à sua direita").
4. **Honestidade técnica.** A posição simulada é apresentada como simulação, com nível de confiança e confirmação do usuário.
5. **Pronto para escalar.** O mesmo pacote serve outros shoppings; o validador garante que nenhuma versão publicada deixe um destino sem rota acessível.

## Dicas de gravação

- Grave a tela do protótipo web no celular (dispositivo real dá mais credibilidade) e corte para o código só no final.
- Ative legendas no vídeo: o pitch também deve ser acessível.
- Teste antes o áudio do modo visual no navegador que vai gravar.
