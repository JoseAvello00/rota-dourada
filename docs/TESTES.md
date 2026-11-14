# Evidências de testes e correções

Última execução: 13/11/2026.

## API (pytest) – 24/24
```
tests/test_api.py::test_saude PASSED
tests/test_api.py::test_versao_tem_hash_e_data PASSED
tests/test_api.py::test_download_e_etag_304 PASSED
tests/test_api.py::test_pacote_inexistente_404 PASSED
tests/test_api.py::test_validacao_endpoint_com_avisos_de_acessibilidade PASSED
tests/test_api.py::test_padrao_usa_escada_rolante_ate_a_praca_de_alimentacao PASSED
tests/test_api.py::test_mobilidade_sem_rota_confirmada_por_dentro_ate_o_2o_piso PASSED
tests/test_api.py::test_mobilidade_pelo_acesso_oeste_usa_elevador PASSED
tests/test_api.py::test_visual_prefere_escada_fixa_a_escada_rolante PASSED
tests/test_api.py::test_trecho_nao_confirmado_nao_entra_em_rota_acessivel PASSED
tests/test_api.py::test_distancias_em_metros_reais PASSED
tests/test_api.py::test_sensorial_evita_praca_de_eventos_central PASSED
tests/test_api.py::test_validador_detecta_poi_quebrado PASSED
tests/test_api.py::test_validador_detecta_destino_inacessivel PASSED
tests/test_api.py::test_pacote_tem_lojas_da_planta_e_imagens PASSED
tests/test_contas.py::test_criar_conta_retorna_token_e_perfil_sem_senha PASSED
tests/test_contas.py::test_campos_obrigatorios_e_validacao PASSED
tests/test_contas.py::test_sem_consentimento_recusa_dados_sensiveis PASSED
tests/test_contas.py::test_email_duplicado_409 PASSED
tests/test_contas.py::test_entrar_com_email_e_senha PASSED
tests/test_contas.py::test_editar_perfil_varias_necessidades_e_apagar PASSED
tests/test_contas.py::test_sem_sessao_401 PASSED
tests/test_contas.py::test_tipos_inclui_fala PASSED
tests/test_contas.py::test_perfil_combinado_exige_trechos_confirmados PASSED
============================== 24 passed in 1.52s ==============================
```

## Núcleo de navegação web (node --test) – 16/16
```
ok 1 - padrão sobe pela escada rolante até a praça de alimentação
ok 2 - mobilidade: sem rota confirmada por dentro; pelo acesso oeste usa elevador
ok 3 - visual prefere escada fixa a escada rolante
ok 4 - trecho não confirmado nunca entra em rota acessível
ok 5 - sem rota compatível retorna null (não sugere escada)
ok 6 - sensorial desvia da Praça de Eventos central
ok 7 - paridade com a API Python (mesmos nós)
ok 8 - instruções: entrada P1 → escada rolante → praça de alimentação
ok 9 - retas longas são divididas (nenhuma etapa acima de ~90 m)
ok 10 - instruções em inglês e espanhol
ok 11 - busca sem acento, por nome e em inglês
ok 12 - perfil combinado: cadeirante + cego soma restrições e penalidades
ok 13 - sem deficiência (ou tipos ignorados quando "não") usa perfil padrão
ok 14 - toque no mapa: nó mais próximo (em metros) ignora escadas e elevadores
ok 15 - cadeirante: todo o térreo tem rota sem escada; o 2º piso só pelo acesso oeste
ok 16 - deficiência na fala e auditiva liberam Conversar; outras não
# pass 16
# fail 0
```

## Mapa real (rede sobre a planta)
A rede de corredores foi desenhada por cima da própria planta para conferência: ![](rede-sobre-planta-terreo.png) ![](rede-sobre-planta-piso2.png)

## App Flutter (flutter test) – 14 casos
`app/test/rota_service_test.dart` (9) e `app/test/usuario_test.dart` (5) cobrem as mesmas regras do núcleo web e da API: mobilidade sem rota confirmada por dentro e com elevador a partir do acesso oeste, visual preferindo escada fixa, trecho não confirmado fora da rota acessível, perfil combinado, Conversar só para surdez e fala. Eles rodam no CI do GitHub (`.github/workflows/ci.yml`) e localmente com `flutter test`.

## Testes de ponta a ponta no protótipo (Chromium headless, sem erros de JavaScript)
1. Cadastro sem consentimento é bloqueado com mensagem clara. ![](evidencia-cadastro-consentimento.png)
2. Cadeirante toca no ícone de uma loja no mapa: rota sem escadas a partir da posição atual. ![](evidencia-toque-icone.png)
3. Busca "alimentação" + Enter: rota pelo elevador, rota padrão (escada) em cinza. ![](evidencia-busca-rota-elevador.png)
4. Lista de lojas aberta arrastando a aba da borda direita. ![](evidencia-lista-deslizante.png)
5. Elevador em manutenção: "Não há rota compatível", sem sugerir escada. ![](evidencia-sem-rota.png)
6. Ajuste de posição tocando no mapa: posição confirmada e rota recalculada.
7. Perfil cegueira + cadeirante em inglês: alto contraste, lista aberta primeiro, rota sem escadas; o perfil continua salvo depois de recarregar a página. ![](evidencia-perfil-cegueira.png)
8. Conversa face a face. ![](evidencia-conversa.png)
9. Mapa real abrindo centrado no visitante, com os logotipos da planta. ![](evidencia-mapa-real.png)
10. Cadeirante → Praça de Alimentação: rota pela calçada até o elevador externo (306 m), com a escada rolante em cinza. ![](evidencia-elevador-externo.png)
11. Rota até o Cinemark pelos corredores reais (148 m) e passo a passo sobre a planta. ![](evidencia-rota-cinemark.png)
12. 2º piso com a planta da praça de alimentação. ![](evidencia-piso2.png)

## Rodada 4 – ponta a ponta no protótipo (Chromium headless, sem erros de JavaScript)
1. Tela de acesso com as três opções. ![](evidencia-r4-01_acesso.png)
2. Criar conta vazio: obrigatórios marcados, erro em cada campo e resumo com links. ![](evidencia-r4-02_erros.png)
3. *Voltar* a partir do cadastro e retorno: o nome digitado continua lá.
4. Cadeirante: mapa limpo, sem botão *Conversar*. ![](evidencia-r4-03_mapa.png)
5. Cadeirante → Praça de Alimentação a partir da P1: "Não há rota acessível confirmada", com o motivo e as alternativas. ![](evidencia-r4-04_semrota.png)
6. Alternativa "Ver rota a partir de: Acesso oeste – Av. JK (elevador)": rota pelo elevador, com o aviso de que é preciso chegar ao acesso por fora. ![](evidencia-r4-05_alt_oeste.png)
7. Passo a passo a partir do acesso oeste: selo "Sem escadas", instrução até o elevador e *Voltar* no canto esquerdo. ![](evidencia-r4-06_rota.png)
8. Tema *Sexta-feira 13* em Configurações e no mapa (sem animação). ![](evidencia-r4-07_config_terror.png) ![](evidencia-r4-08_mapa_terror.png)
9. Tema escuro. ![](evidencia-r4-09_mapa_escuro.png)
10. Edição de perfil: adicionando surdez, o botão *Conversar* aparece. ![](evidencia-r4-10_conversa.png)
11. SOS: confirmação acessível → tela cheia estática que diz que nenhum alerta foi enviado → "Fechar e voltar à conversa". ![](evidencia-r4-11_sos_confirma.png) ![](evidencia-r4-12_sos_tela.png)
12. Login com senha errada: uma única mensagem que não revela se o e-mail existe; depois login correto. ![](evidencia-r4-13_login_erro.png)
13. Visitante cego → 2º piso: rota pela escada fixa com aviso "Inclui escada" e a alternativa sem escadas. ![](evidencia-r4-14_visual_escada.png)

## Problemas encontrados e corrigidos

| # | Problema | Como foi achado | Correção |
|---|---|---|---|
| 1 | O teste do modo sensorial assumia um caminho errado até os sanitários | pytest falhou | Cenário trocado para um destino com a Praça de Eventos no caminho |
| 2 | A primeira instrução por rampa perdia o ponto de partida | Revisão das instruções | Prefixo "Saindo de Acesso P3:" |
| 3 | Origem fora de uma entrada gerava "Saindo de saída das escadas…" | Revisão das telas | Frase "Você está {referência}." em PT/EN/ES |
| 4 | Rótulos do mapa ilegíveis no celular | Captura de tela | Enquadramento automático da rota |
| 5 | Abas de andar invisíveis no alto contraste | Captura de tela | Cores de alto contraste nas abas (também no mapa explorável) |
| 6 | Sanitários sobrepostos no mapa | Captura de tela | Posições reespaçadas |
| 7 | Instruções em inglês misturavam referências em português | Revisão | Referências EN/ES no pacote |
| 8 | Teste da API fixava a versão "0.1.0" e quebrou com o pacote 0.2.0 | pytest falhou | O teste passou a ler a versão do próprio pacote |
| 9 | Botão "Conversar" cortado no cabeçalho depois do botão de perfil | Captura de tela | Cabeçalho compactado |
| 10 | Mapa inicial pequeno e deslocado para baixo em telas altas | Captura de tela | Abre centrado no visitante; limites de arraste corrigidos |
| 11 | Cartão da loja cobria parte da rota | Captura de tela | Enquadramento desconta a altura do cartão |
| 12 | Alto contraste do perfil afetava o painel de demonstração | Captura de tela | Estilos restritos ao app |
| 13 | Mapa esquemático não correspondia ao shopping real (âncoras em posições erradas) | Comparação com a Planta Mix | Pacote regenerado da planta, em escala, com 194 pontos |
| 14 | "AV" na planta parecia nome de corredor ("Avenida") | Sobreposição da rede na planta | Identificado como a loja Lojas Avenida; corredor renomeado para "corredor das megalojas" |
| 15 | Centauro sem acesso próximo | Sobreposição | Incluída a Alameda das Cores |
| 16 | Instrução com reta de 135 m sem referência | Leitura das instruções | Retas acima de 60 m viram etapas com referência no meio |
| 17 | Trecho da rota até o elevador escondido sob o cartão da loja | Captura de tela | Limites de arraste ampliados |
| 18 | Detecção de âncora lia "32.00" como 3200 m² | Revisão dos dados gerados | Leitura de área corrigida |
| 19 | Redesenhar o mapa em vetor perdia paredes | Captura de tela | Mapa limpo feito desligando as camadas CAD de poluição (o PDF precisa ser regravado para a mudança valer) |
| 20 | Desligar as camadas genéricas apagava a fachada da C&A | Captura de tela | Camadas genéricas mantidas; só logos, cotas, textos e hachuras saem |
| 21 | Pintura dos corredores vazava para fora do prédio e para dentro das lojas abertas | Captura de tela | Preenchimento limitado a 9 m da rede de corredores |
| 22 | Calçada até o elevador tinha sido traçada sem estar na planta | Revisão contra a regra "não inventar passagens" | Trecho removido; elevador ligado só ao acesso oeste |
| 23 | Mensagem "Corrija 1 campo" no login | Teste E2E | Título próprio por formulário |
| 24 | Aviso (toast) cobria os botões de ação | Captura de tela | Movido para o topo |
| 25 | Selo "⚠ ≡" não era compreensível | Revisão | Texto "Inclui escada" / "Inclui escada rolante" |

