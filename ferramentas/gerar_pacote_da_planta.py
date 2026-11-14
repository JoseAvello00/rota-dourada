"""Gera o pacote de navegação a partir da Planta Mix (PDF) do Capim Dourado.

Uso:  python3 -I ferramentas/gerar_pacote_da_planta.py caminho/planta.pdf
Saídas: dados/pacote_capim_dourado.json e dados/planta_*.webp

- Escala calibrada pela Praça de Eventos circular (265,90 m²) e conferida na
  praça retangular (207,36 m²): térreo 0,30 m por ponto do PDF (1:850).
  2º piso: 0,0555 m/ponto (largura das lojas cotadas na folha 2/2).
- Lojas: logotipos (imagens do PDF, nomeados manualmente abaixo) e quiosques
  (texto "Q nn" + nome). Número e área vêm do rótulo "LOJA nn" mais próximo.
- Corredores: traçados sobre a planta (nós abaixo, em pontos do PDF).
"""
from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

import pymupdf as fitz
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
PDF = Path(sys.argv[1] if len(sys.argv) > 1 else "planta.pdf")

# ---------------- andares: recorte (pt), escala (m/pt), zoom da imagem ----------------
ANDARES = {
    0: {"pagina": 1, "recorte": (470, 180, 1760, 1100), "m_por_pt": 0.2997, "zoom": 2.0,
        "nome": "Térreo", "nome_en": "Ground floor", "nome_es": "Planta baja"},
    1: {"pagina": 2, "recorte": (300, 150, 2300, 1300), "m_por_pt": 0.0555, "zoom": 0.62,
        "nome": "2º Piso – Praça de Alimentação", "nome_en": "2nd floor – Food court", "nome_es": "2º piso – Patio de comidas"},
}

def m(andar, x, y):
    a = ANDARES[andar]; x0, y0 = a["recorte"][:2]; k = a["m_por_pt"]
    return round((x - x0) * k, 1), round((y - y0) * k, 1)

# ---------------- logotipos (índice da imagem no PDF → nome, categoria) ----------------
L, A, S, Z = "loja", "alimentacao", "servico", "lazer"
LOGOS_T = {
    0: ("Renner", L), 1: ("Resolve Palmas", S), 2: ("DayCâmbio", S), 3: ("Labvida", S),
    4: ("NK Sobrancelhas", S), 5: ("Hot Stamp", L), 6: ("Casa do Celular", L), 7: ("Correios", S),
    9: ("Lemos Pelissari", S), 10: ("Polo Wear", L), 11: ("Life by Vivara", L), 14: ("Kekala", A),
    15: ("We Pink", L), 16: ("Havanna", A), 17: ("Youcom", L), 18: ("Lez a Lez", L), 19: ("Colcci", L),
    21: ("Jean Darrot", L), 22: ("Authentic Feet", L), 23: ("C&A", L), 24: ("Riachuelo", L),
    25: ("Damyller", L), 26: ("Lupo Sport", L), 27: ("Crocs", L), 28: ("Quem Disse, Berenice?", L),
    29: ("Avatim", L), 32: ("Levi's", L), 34: ("Milon", L), 35: ("Babi Fitness & Praia", L),
    36: ("Schutz", L), 38: ("Sestini", L), 39: ("Track&Field", L), 40: ("Brooksfield", L),
    41: ("Kings Sneakers", L), 42: ("Democrata", L), 43: ("Cia do Verão", L), 44: ("Leitura", L),
    46: ("Clube Morena Rosa", L), 47: ("L'essence", L), 49: ("Ellus", L), 52: ("Morofit", Z),
    53: ("Wow Park", Z), 54: ("Super Big", L), 55: ("Zig Zag Play", Z), 56: ("Big Lar", L),
    57: ("Pernambucanas", L), 58: ("Lojas Avenida", L), 59: ("STZ", L), 61: ("Usaflex", L), 63: ("Chiquinho Sorvetes", A),
    64: ("Amanda's Make", L), 65: ("Burger King", A), 66: ("Lady&Lord", L), 67: ("Chilli Beans", L),
    68: ("Nathalia Fraga", L), 70: ("Vitória Geek", L), 71: ("CS Club", L), 72: ("Sapatinho de Luxo", L),
    73: ("Puket", L), 74: ("Hering", L), 75: ("Hope", L), 76: ("Footwear Shop", L), 77: ("Constance", L),
    78: ("Dudalina", L), 79: ("Bibi", L), 81: ("Rommanel", L), 82: ("Tip Top", L), 83: ("Natura", L),
    84: ("Luz da Lua", L), 85: ("Mahogany", L), 86: ("Scamboo", L), 87: ("Lupo", L), 88: ("Live!", L),
    89: ("Criamigos", L), 90: ("Cacau Show", A), 91: ("Berry's", A), 92: ("Ri Happy", L),
    93: ("Camisaria FMW", L), 94: ("Bagaggio", L), 95: ("TXC", L), 96: ("Óticas Carol", L),
    97: ("Botoclinic", S), 98: ("Detran-TO", S), 99: ("Polícia Federal", S), 100: ("Drogarias Econômica", L),
    101: ("Vivo", L), 102: ("Claro", L), 103: ("Centauro", L), 104: ("Aleatory", L), 105: ("Inovar", L),
    106: ("Anacapri", L), 107: ("Loungerie", L), 108: ("Farm", L), 109: ("Aramis", L), 110: ("Camicado", L),
    111: ("Outback", A), 112: ("Vivara", L), 113: ("Adcos", L), 115: ("Reserva", L),
    116: ("L'essence Lingerie", L), 117: ("Kopenhagen", A), 118: ("Oficial", L), 120: ("Carter's", L),
    121: ("DB Gelato", A), 122: ("Havaianas", L), 123: ("Marisa", L), 124: ("Melissa", L), 125: ("TIM", L),
    126: ("Cinemark", Z), 127: ("Colégio Interação", S), 128: ("Madero", A), 136: ("Pronto Fibra", S),
    137: ("Use AO", L), 156: ("Tommy Hilfiger", L), 157: ("Omoda | Jaecoo", L), 158: ("Drogasil", L),
    162: ("Stilo", L), 171: ("Fuel", L), 172: ("Bistrô 81", A), 173: ("Andabella", L),
}
LOGOS_P = {
    0: ("McDonald's", A), 1: ("Spoleto", A), 2: ("Pizza Hut", A), 3: ("Vivenda do Camarão", A),
    4: ("Dona Maria Express", A), 5: ("Divino Fogão", A), 6: ("Express Grill", A), 7: ("Subway", A),
    8: ("Spaguettinni", A), 9: ("Giraffas", A), 10: ("Kin Sui", A),
}
ALIMENTACAO_Q = {"Chopp Brahma", "Mc Donald's", "Bubble Mix", "Rei da Paçoca", "Toca da Pipoca", "Kekala",
                 "Gelatos Sorveteria", "Pop Corn", "Havanna", "Oakberry", "MilkMoo", "Super Soft", "Fini",
                 "Nutty Bavarian", "American Cookies", "Tropimanga", "Giraffas", "Happy hour", "Buriti"}
LAZER_Q = {"Panda Pool", "Fun Photo", "Mini Cars", "Chute Play", "Salve Club"}
SERVICO_Q = {"Unicesumar", "ProntoFibra", "Grua Chaves", "Comodato"}

# ---------------- serviços e marcos (pt) ----------------
SERVICOS = [
    # (id, andar, x, y, nome, nome_en, nome_es, categoria, tags, extras)
    ("poi_sanit_oeste_fem", 0, 960, 574, "Sanitário Feminino (ala oeste)", "Women's restroom (west)", "Baño de mujeres (oeste)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_sanit_oeste_masc", 0, 969, 586, "Sanitário Masculino (ala oeste)", "Men's restroom (west)", "Baño de hombres (oeste)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_pne_oeste", 0, 957, 592, "Sanitário Acessível (ala oeste)", "Accessible restroom (west)", "Baño accesible (oeste)", "sanitario", ["banheiro", "wc", "pcd", "acessivel"], {"acessivel": True}),
    ("poi_espaco_familia", 0, 981, 601, "Espaço Família", "Family Room", "Espacio Familia", "servico", ["fraldário", "descanso", "tranquilo", "bebê"], {"descanso": True}),
    ("poi_sanit_leste_masc", 0, 1235, 805, "Sanitário Masculino (ala leste)", "Men's restroom (east)", "Baño de hombres (este)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_sanit_leste_fem", 0, 1238, 830, "Sanitário Feminino (ala leste)", "Women's restroom (east)", "Baño de mujeres (este)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_pne_leste", 0, 1256, 842, "Sanitário Acessível (ala leste)", "Accessible restroom (east)", "Baño accesible (este)", "sanitario", ["banheiro", "wc", "pcd", "acessivel"], {"acessivel": True}),
    ("poi_brigada_leste", 0, 1247, 842, "Brigada / Primeiros Socorros", "First Aid", "Primeros Auxilios", "servico", ["socorro", "emergência", "ajuda"], {}),
    ("poi_brigada_oeste", 0, 952, 754, "Brigada (ala oeste)", "First Aid (west)", "Primeros Auxilios (oeste)", "servico", ["socorro", "emergência", "ajuda"], {}),
    ("poi_seguranca", 0, 1514, 756, "Segurança", "Security", "Seguridad", "servico", ["ajuda", "achados e perdidos"], {}),
    ("poi_praca_eventos_central", 0, 1086, 860, "Praça de Eventos (central)", "Events Square (central)", "Plaza de Eventos (central)", "lazer", ["eventos"], {}),
    ("poi_praca_eventos_norte", 0, 1087, 634, "Praça de Eventos (norte)", "Events Square (north)", "Plaza de Eventos (norte)", "lazer", ["eventos"], {}),
    ("poi_praca_eventos_oeste", 0, 841, 917, "Praça de Eventos (oeste)", "Events Square (west)", "Plaza de Eventos (oeste)", "lazer", ["eventos", "escada rolante"], {}),
    ("poi_praca_eventos_leste", 0, 1314, 718, "Praça de Eventos (leste)", "Events Square (east)", "Plaza de Eventos (este)", "lazer", ["eventos"], {}),
    ("poi_praca_eventos_noroeste", 0, 767, 730, "Praça de Eventos (noroeste)", "Events Square (northwest)", "Plaza de Eventos (noroeste)", "lazer", ["eventos"], {}),
    # 2º piso
    ("poi_praca_alim", 1, 1260, 765, "Praça de Alimentação", "Food Court", "Patio de comidas", "alimentacao", ["comida", "restaurantes", "almoço", "mesas"], {}),
    ("poi_wc_masc_l2", 1, 1578, 325, "Sanitário Masculino (2º piso)", "Men's restroom (2nd floor)", "Baño de hombres (2º piso)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_wc_fem_l2", 1, 1580, 1125, "Sanitário Feminino (2º piso)", "Women's restroom (2nd floor)", "Baño de mujeres (2º piso)", "sanitario", ["banheiro", "wc"], {}),
    ("poi_pne_l2", 1, 1516, 1196, "Sanitário Acessível (2º piso)", "Accessible restroom (2nd floor)", "Baño accesible (2º piso)", "sanitario", ["banheiro", "wc", "pcd", "acessivel"], {"acessivel": True}),
    ("poi_brigada_l2", 1, 1466, 1187, "Brigada (2º piso)", "First Aid (2nd floor)", "Primeros Auxilios (2º piso)", "servico", ["socorro", "emergência"], {}),
    ("poi_mundo_imersivo", 1, 743, 470, "Mundo Imersivo", "Mundo Imersivo", "Mundo Imersivo", "lazer", ["atração", "crianças"], {"no": "p_w2"}),
    ("poi_evento_imerso_mar", 1, 748, 1030, "Evento Imerso Mar", "Evento Imerso Mar", "Evento Imerso Mar", "lazer", ["atração", "crianças"], {"no": "p_w2"}),
]

# ---------------- rede de corredores (pontos do PDF) ----------------
# id: (andar, x, y, tipo, nome/ref pt, ref en, ref es, extras)
NOS = {
    # entradas
    "t_p1": (0, 1085, 935, "entrada", "Entrada principal P1 – Av. NS-05", "Main entrance P1 – Av. NS-05", "Entrada principal P1 – Av. NS-05", {}),
    "t_p2": (0, 1404, 621, "entrada", "Entrada P2 – estacionamento leste", "Entrance P2 – east parking", "Entrada P2 – estacionamiento este", {}),
    "t_p3": (0, 818, 668, "entrada", "Entrada P3 – estacionamento norte", "Entrance P3 – north parking", "Entrada P3 – estacionamiento norte", {}),
    "t_pn": (0, 1404, 400, "entrada", "Acesso de pedestres – Super Big", "Pedestrian access – Super Big", "Acceso peatonal – Super Big", {}),
    # anel em volta da Riachuelo
    "t_rn": (0, 1088, 657, "corredor", "na Praça de Eventos norte, em frente à C&A", "at the north Events Square, in front of C&A", "en la Plaza de Eventos norte, frente a C&A", {}),
    "t_rne": (0, 1170, 682, "corredor", "no anel em frente à Leitura", "on the ring in front of Leitura", "en el anillo frente a Leitura", {}),
    "t_re": (0, 1222, 745, "corredor", "no anel em frente à Brooksfield", "on the ring in front of Brooksfield", "en el anillo frente a Brooksfield", {}),
    "t_rse": (0, 1180, 815, "corredor", "no anel em frente à Drogasil", "on the ring in front of Drogasil", "en el anillo frente a Drogasil", {}),
    "t_rs": (0, 1086, 832, "corredor", "na Praça de Eventos central", "at the central Events Square", "en la Plaza de Eventos central", {}),
    "t_rsw": (0, 995, 815, "corredor", "no anel em frente à Lupo", "on the ring in front of Lupo", "en el anillo frente a Lupo", {}),
    "t_rw": (0, 952, 745, "corredor", "no anel oeste, perto da Levi's", "on the west ring, near Levi's", "en el anillo oeste, cerca de Levi's", {}),
    "t_rnw": (0, 1000, 677, "corredor", "no anel em frente à Schutz", "on the ring in front of Schutz", "en el anillo frente a Schutz", {}),
    "t_praca": (0, 1086, 878, "corredor", "na saída da Praça de Eventos central", "at the central Events Square exit", "en la salida de la Plaza de Eventos central", {}),
    # corredor sul (Renner ↔ Marisa)
    "t_s0": (0, 1086, 912, "corredor", "no corredor sul, em frente à entrada P1", "on the south corridor, in front of entrance P1", "en el pasillo sur, frente a la entrada P1", {}),
    "t_sw1": (0, 1000, 912, "corredor", "no corredor sul, perto da Aramis", "on the south corridor, near Aramis", "en el pasillo sur, cerca de Aramis", {}),
    "t_sw2": (0, 915, 915, "corredor", "no corredor sul, perto dos quiosques Fini e Toca da Pipoca", "on the south corridor, near the Fini and Toca da Pipoca kiosks", "en el pasillo sur, cerca de los quioscos Fini y Toca da Pipoca", {}),
    "t_sw3": (0, 840, 900, "corredor", "na Praça de Eventos oeste", "at the west Events Square", "en la Plaza de Eventos oeste", {}),
    "t_sw4": (0, 760, 875, "corredor", "no corredor da Renner, perto do Giraffas", "in the Renner corridor, near Giraffas", "en el pasillo de Renner, cerca de Giraffas", {}),
    "t_renner": (0, 700, 880, "corredor", "na entrada da Renner", "at the Renner entrance", "en la entrada de Renner", {}),
    "t_se1": (0, 1180, 905, "corredor", "no corredor sul, perto da Vivara", "on the south corridor, near Vivara", "en el pasillo sur, cerca de Vivara", {}),
    "t_se2": (0, 1262, 915, "corredor", "no corredor sul, perto do quiosque Artes Jalapão", "on the south corridor, near the Artes Jalapão kiosk", "en el pasillo sur, cerca del quiosco Artes Jalapão", {}),
    "t_se3": (0, 1335, 918, "corredor", "no corredor sul, perto do quiosque My Case", "on the south corridor, near the My Case kiosk", "en el pasillo sur, cerca del quiosco My Case", {}),
    "t_se4": (0, 1405, 920, "corredor", "no fim do corredor sul, em frente à Marisa", "at the end of the south corridor, in front of Marisa", "al final del pasillo sur, frente a Marisa", {}),
    "t_swa": (0, 957, 913, "corredor", "no corredor sul, na entrada da Alameda das Cores", "on the south corridor, at the Alameda das Cores", "en el pasillo sur, en la Alameda das Cores", {}),
    "t_al": (0, 960, 985, "corredor", "na Alameda das Cores, em frente à Centauro", "on Alameda das Cores, in front of Centauro", "en la Alameda das Cores, frente a Centauro", {}),
    # escadas rolantes / escada fixa para o 2º piso
    "t_esc": (0, 808, 917, "vertical", "ao pé das escadas rolantes para a Praça de Alimentação", "at the foot of the escalators to the Food Court", "al pie de las escaleras mecánicas al patio de comidas", {}),
    # corredor noroeste (P3 ↔ anel oeste)
    "t_nw1": (0, 905, 726, "corredor", "no corredor noroeste, perto do quiosque MilkMoo", "on the northwest corridor, near the MilkMoo kiosk", "en el pasillo noroeste, cerca del quiosco MilkMoo", {}),
    "t_nw2": (0, 818, 726, "corredor", "no corredor noroeste, perto do quiosque Havanna", "on the northwest corridor, near the Havanna kiosk", "en el pasillo noroeste, cerca del quiosco Havanna", {}),
    "t_nw3": (0, 765, 745, "corredor", "na Praça de Eventos noroeste", "at the northwest Events Square", "en la Plaza de Eventos noroeste", {}),
    "t_nw4": (0, 790, 800, "corredor", "no corredor da Machine Games", "in the Machine Games corridor", "en el pasillo de Machine Games", {}),
    "t_nw5": (0, 720, 760, "corredor", "em frente à Polo Wear", "in front of Polo Wear", "frente a Polo Wear", {}),
    # sanitários oeste
    "t_sanw1": (0, 978, 640, "corredor", "no corredor dos sanitários da ala oeste", "in the west restroom corridor", "en el pasillo de los baños del ala oeste", {"estimulo": "baixo"}),
    "t_sanw2": (0, 968, 600, "corredor", "na entrada dos sanitários e do Espaço Família", "at the restrooms and Family Room entrance", "en la entrada de los baños y del Espacio Familia", {"estimulo": "baixo"}),
    # sanitários leste (circulação social)
    "t_sane1": (0, 1262, 870, "corredor", "na circulação dos sanitários da ala leste", "in the east restroom hallway", "en el pasillo de los baños del ala este", {"estimulo": "baixo"}),
    "t_sane2": (0, 1250, 830, "corredor", "na entrada dos sanitários da ala leste", "at the east restrooms entrance", "en la entrada de los baños del ala este", {"estimulo": "baixo"}),
    # ala leste e "Avenida"
    "t_e1": (0, 1265, 718, "corredor", "no corredor leste, perto do quiosque Pronto Fibra", "on the east corridor, near the Pronto Fibra kiosk", "en el pasillo este, cerca del quiosco Pronto Fibra", {}),
    "t_e2": (0, 1314, 735, "corredor", "na Praça de Eventos leste", "at the east Events Square", "en la Plaza de Eventos este", {}),
    "t_e3": (0, 1370, 740, "corredor", "no corredor leste, perto da Kazzu Sports", "on the east corridor, near Kazzu Sports", "en el pasillo este, cerca de Kazzu Sports", {}),
    "t_a1": (0, 1440, 420, "corredor", "no início do corredor das megalojas, perto do Super Big", "at the start of the megastore corridor, near Super Big", "al inicio del pasillo de las megatiendas, cerca de Super Big", {}),
    "t_a2": (0, 1440, 500, "corredor", "no corredor das megalojas, perto do quiosque Chute Play", "on the megastore corridor, near the Chute Play kiosk", "en el pasillo de las megatiendas, cerca del quiosco Chute Play", {}),
    "t_a3": (0, 1440, 570, "corredor", "no corredor das megalojas, perto do quiosque do McDonald's", "on the megastore corridor, near the McDonald's kiosk", "en el pasillo de las megatiendas, cerca del quiosco de McDonald's", {}),
    "t_a4": (0, 1440, 621, "corredor", "no corredor das megalojas, em frente à entrada P2", "on the megastore corridor, in front of entrance P2", "en el pasillo de las megatiendas, frente a la entrada P2", {}),
    "t_a5": (0, 1440, 690, "corredor", "no corredor das megalojas, perto da Lojas Avenida", "on the megastore corridor, near Lojas Avenida", "en el pasillo de las megatiendas, cerca de Lojas Avenida", {}),
    "t_a6": (0, 1440, 742, "corredor", "no cruzamento do corredor das megalojas com o corredor leste", "at the junction of the megastore corridor and the east corridor", "en el cruce del pasillo de las megatiendas con el pasillo este", {}),
    "t_a7": (0, 1440, 830, "corredor", "no corredor das megalojas, perto do Cinemark", "on the megastore corridor, near Cinemark", "en el pasillo de las megatiendas, cerca de Cinemark", {}),
    # acesso oeste: vestíbulo com elevador e faixa de pedestres para a Av. JK (desenhado na planta).
    # A planta NÃO mostra ligação interna entre este vestíbulo e os corredores do shopping.
    "t_po": (0, 497, 918, "entrada", "Acesso oeste – Av. JK (elevador)", "West access – Av. JK (elevator)", "Acceso oeste – Av. JK (ascensor)", {}),
    "t_elev": (0, 535, 918, "vertical", "na porta do elevador do acesso oeste", "at the west access elevator door", "en la puerta del ascensor del acceso oeste", {}),
    # ---------------- 2º piso (pontos da folha 2/2) ----------------
    "p_esc": (1, 1585, 765, "vertical", "no topo das escadas rolantes", "at the top of the escalators", "en lo alto de las escaleras mecánicas", {}),
    "p_e": (1, 1500, 765, "corredor", "na entrada da Praça de Alimentação, junto às escadas rolantes", "at the Food Court entrance, by the escalators", "en la entrada del patio de comidas, junto a las escaleras mecánicas", {}),
    "p_n1": (1, 1460, 585, "corredor", "em frente ao Divino Fogão", "in front of Divino Fogão", "frente a Divino Fogão", {}),
    "p_n2": (1, 1270, 575, "corredor", "em frente à Vivenda do Camarão", "in front of Vivenda do Camarão", "frente a Vivenda do Camarão", {}),
    "p_n3": (1, 1110, 600, "corredor", "em frente ao Spoleto", "in front of Spoleto", "frente a Spoleto", {}),
    "p_n4": (1, 960, 650, "corredor", "em frente ao McDonald's", "in front of McDonald's", "frente a McDonald's", {}),
    "p_s1": (1, 1460, 950, "corredor", "em frente ao Express Grill", "in front of Express Grill", "frente a Express Grill", {}),
    "p_s2": (1, 1270, 975, "corredor", "em frente ao Subway", "in front of Subway", "frente a Subway", {}),
    "p_s3": (1, 1110, 965, "corredor", "em frente ao Spaguettinni", "in front of Spaguettinni", "frente a Spaguettinni", {}),
    "p_s4": (1, 960, 900, "corredor", "em frente ao Kin Sui", "in front of Kin Sui", "frente a Kin Sui", {}),
    "p_c": (1, 1260, 765, "corredor", "no centro das mesas", "in the middle of the seating area", "en el centro de las mesas", {}),
    "p_w": (1, 820, 767, "corredor", "na passagem oeste (P4)", "at the west passage (P4)", "en el pasaje oeste (P4)", {}),
    "p_w2": (1, 620, 767, "corredor", "no hall oeste, perto do Mundo Imersivo", "in the west hall, near Mundo Imersivo", "en el hall oeste, cerca de Mundo Imersivo", {}),
    "p_elev": (1, 450, 767, "vertical", "na saída do elevador", "at the elevator exit", "a la salida del ascensor", {}),
    "p_wcm": (1, 1520, 420, "corredor", "na circulação dos sanitários masculinos", "in the men's restroom hallway", "en el pasillo de los baños de hombres", {"estimulo": "baixo"}),
    "p_wcf": (1, 1470, 1110, "corredor", "na circulação dos sanitários femininos e acessível", "in the women's and accessible restroom hallway", "en el pasillo de los baños de mujeres y accesible", {"estimulo": "baixo"}),
}

ARESTAS = [
    # anel
    ("t_rn", "t_rne"), ("t_rne", "t_re"), ("t_re", "t_rse"), ("t_rse", "t_rs"), ("t_rs", "t_rsw"),
    ("t_rsw", "t_rw"), ("t_rw", "t_rnw"), ("t_rnw", "t_rn"),
    # sul
    ("t_rs", "t_praca"), ("t_praca", "t_s0"), ("t_s0", "t_p1"),
    ("t_s0", "t_sw1"), ("t_sw1", "t_swa"), ("t_swa", "t_sw2"), ("t_swa", "t_al"), ("t_sw2", "t_sw3"), ("t_sw3", "t_esc"), ("t_esc", "t_sw4"), ("t_sw4", "t_renner"),
    ("t_rsw", "t_sw1"),
    ("t_s0", "t_se1"), ("t_se1", "t_se2"), ("t_se2", "t_se3"), ("t_se3", "t_se4"), ("t_se4", "t_a7"),
    ("t_rse", "t_se1"),
    # noroeste
    ("t_rw", "t_nw1"), ("t_nw1", "t_nw2"), ("t_nw2", "t_p3"), ("t_nw2", "t_nw3"), ("t_nw3", "t_nw5"),
    ("t_nw3", "t_nw4"), ("t_nw4", "t_sw4"),
    # sanitários
    ("t_rnw", "t_sanw1"), ("t_sanw1", "t_sanw2"),
    ("t_se2", "t_sane1"), ("t_sane1", "t_sane2"),
    # leste e Avenida
    ("t_rne", "t_e1"), ("t_re", "t_e1"), ("t_e1", "t_e2"), ("t_e2", "t_e3"), ("t_e3", "t_a6"),
    ("t_pn", "t_a1"), ("t_a1", "t_a2"), ("t_a2", "t_a3"), ("t_a3", "t_a4"), ("t_a4", "t_p2"), ("t_a4", "t_a5"),
    ("t_a5", "t_a6"), ("t_a6", "t_a7"),
    # acesso oeste → elevador
    ("t_po", "t_elev"),
    # 2º piso
    ("p_esc", "p_e"), ("p_e", "p_n1"), ("p_n1", "p_n2"), ("p_n2", "p_n3"), ("p_n3", "p_n4"), ("p_n4", "p_w"),
    ("p_e", "p_s1"), ("p_s1", "p_s2"), ("p_s2", "p_s3"), ("p_s3", "p_s4"), ("p_s4", "p_w"),
    ("p_e", "p_c"), ("p_c", "p_n2"), ("p_c", "p_s2"), ("p_c", "p_w"),
    ("p_w", "p_w2"), ("p_w2", "p_elev"),
    ("p_n1", "p_wcm"), ("p_s1", "p_wcf"),
]
VERTICAIS = [
    ("v_rolante", "t_esc", "p_esc", "escada_rolante", 18, "escadas rolantes"),
    ("v_escada", "t_esc", "p_esc", "escada", 20, "escada fixa entre as escadas rolantes"),
    ("v_elevador", "t_elev", "p_elev", "elevador", 30, "elevador do acesso oeste (inclui espera)"),
]
ESTIMULO_ALTO = {("t_rs", "t_praca"), ("t_praca", "t_s0"), ("t_sw2", "t_sw3"), ("t_sw3", "t_esc"), ("t_rn", "t_rne"),
                 ("t_rnw", "t_rn"), ("t_e1", "t_e2"), ("t_e2", "t_e3"), ("t_nw2", "t_nw3"),
                 ("p_e", "p_c"), ("p_c", "p_n2"), ("p_c", "p_s2"), ("p_c", "p_w"), ("p_n1", "p_n2"), ("p_s1", "p_s2")}
BEACONS = [("ble-t-01", "t_rs"), ("ble-t-02", "t_sw3"), ("ble-t-03", "t_rw"), ("ble-t-04", "t_e2"),
           ("ble-t-05", "t_a4"), ("ble-t-06", "t_se3"), ("ble-p-01", "p_e"), ("ble-p-02", "p_w")]


# Camadas do CAD que só poluem o mapa (o resto é renderizado exatamente como no projeto)
CAMADAS_POLUICAO = re.compile(r"LOGOS|^VGA$|VAGAS|vagas|pintura|DIMENS|COTAS|TX|TEXT|TEXTO|HATCH|HACH|Hatch|HUMA|^veg$|EIX|"
                              r"Eixos|CONTROLES|DEMARC|INSTALA|AREA|ANNO|^AUX$|\$AUX|NORTE|SIMB|CHAM|MEIO-FIO|RUA|Linha de piso", re.I)
TEMAS = {  # fundo, faixa de circulação, traços
    "claro": ((250, 251, 248), (241, 230, 200), (62, 76, 68)),
    "escuro": ((20, 25, 23), (44, 55, 49), (178, 192, 184)),
    "terror": ((14, 8, 9), (48, 20, 22), (196, 166, 156)),
}


def pdf_sem_poluicao():
    d = fitz.open(PDF)
    ocgs = d.get_ocgs()
    off = [x for x, v in ocgs.items() if CAMADAS_POLUICAO.search(v["name"])]
    d.set_layer(-1, on=[x for x in ocgs if x not in off], off=off)
    return fitz.open("pdf", d.tobytes())


def ARESTAS_DO_ANDAR(aid, nos):
    porid = {n["id"]: n for n in nos}
    return [(porid[a], porid[b]) for a, b in ARESTAS
            if porid[a]["andar"] == aid and porid[b]["andar"] == aid and porid[a]["tipo"] != "vertical" and porid[b]["tipo"] != "vertical"]


def planta_limpa(limpo, original, aid, nos, arestas):
    """Planta sem logotipos/textos/vagas/cotas + faixa suave nas áreas de circulação.
    A faixa é o espaço livre (sem atravessar paredes) a até 9 m da rede de corredores."""
    from PIL import ImageChops, ImageDraw, ImageFilter
    a = ANDARES[aid]; x0, y0, x1, y1 = a["recorte"]; z = a["zoom"]
    pg = limpo[a["pagina"]]
    pix = pg.get_pixmap(matrix=fitz.Matrix(z, z), clip=fitz.Rect(x0, y0, x1, y1))
    cinza = Image.frombytes("RGB", (pix.width, pix.height), pix.samples).convert("L")
    dr = ImageDraw.Draw(cinza)
    for im in original[a["pagina"]].get_image_info():  # logotipos soltos em camadas genéricas
        r = im["bbox"]; dr.rectangle([(r[0] - x0) * z, (r[1] - y0) * z, (r[2] - x0) * z, (r[3] - y0) * z], fill=255)
    linhas = cinza.point(lambda v: 255 if v < 200 else 0)
    paredes = cinza.point(lambda v: 0 if v < 200 else 255).filter(ImageFilter.MinFilter(3))
    s = z / a["m_por_pt"]  # px por metro
    livre = paredes.copy()
    faixa = Image.new("L", livre.size, 0); fd = ImageDraw.Draw(faixa)
    for p, q in arestas:
        fd.line([(p["x"] * s, p["y"] * s), (q["x"] * s, q["y"] * s)], fill=255, width=int(18 * s))
        for n in (p, q):
            r = 9 * s; fd.ellipse([n["x"] * s - r, n["y"] * s - r, n["x"] * s + r, n["y"] * s + r], fill=255)
    for n in nos:
        if n["andar"] != aid or n["tipo"] == "vertical": continue
        xy = (int(n["x"] * s), int(n["y"] * s))
        if 0 <= xy[0] < livre.width and 0 <= xy[1] < livre.height and livre.getpixel(xy) == 255:
            ImageDraw.floodfill(livre, xy, 128)
    circ = ImageChops.multiply(livre.point(lambda v: 255 if v == 128 else 0), faixa)
    saida = {}
    for tema, (fundo, corr, traco) in TEMAS.items():
        img = Image.new("RGB", livre.size, fundo)
        img.paste(corr, mask=circ)
        img.paste(traco, mask=linhas)
        saida[tema] = img
    return saida


def textos(pagina):
    out = []
    for b in pagina.get_text("dict")["blocks"]:
        for l in b.get("lines", []):
            t = " ".join(s["text"] for s in l["spans"]).strip()
            if t:
                x0, y0, x1, y1 = l["bbox"]
                out.append({"t": t, "x": (x0 + x1) / 2, "y": (y0 + y1) / 2})
    return out


def rotulo_loja(txts, x, y, raio):
    """Número e área da loja mais próxima do logotipo."""
    melhor = None
    for i, o in enumerate(txts):
        mm = re.fullmatch(r"LOJA\s+([\w\- ]+)", o["t"])
        if not mm:
            continue
        d = math.hypot(o["x"] - x, o["y"] - y)
        if d < raio and (melhor is None or d < melhor[0]):
            area = None
            for o2 in txts[i + 1:i + 3]:
                a = re.search(r"([\d.,]+)\s*m²", o2["t"])
                if a:
                    area = a.group(1)
                    break
            melhor = (d, mm.group(1).strip(), area)
    return (melhor[1], melhor[2]) if melhor else (None, None)


def slug(s):
    s = s.lower()
    for a, b in zip("áàâãéêíóôõúçñ'&!?,|.", "aaaaeeiooouucn_______"):
        s = s.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def main():
    doc = fitz.open(PDF)
    pois, vistos = [], set()

    def add_poi(pid, andar, x, y, nome, cat, tags=(), extras=None, nome_en=None, nome_es=None, loja=None, area=None):
        mx, my = m(andar, x, y)
        p = {"id": pid, "nome": nome, "categoria": cat, "andar": andar, "x": mx, "y": my, "tags": list(tags)}
        if nome_en and nome_en != nome: p["nome_en"] = nome_en
        if nome_es and nome_es != nome: p["nome_es"] = nome_es
        if loja: p["loja"] = loja
        if area: p["area_m2"] = float(area.replace(".", "").replace(",", ".")) if "," in area else float(area)
        p.update(extras or {})
        pois.append(p)

    for andar, logos in ((0, LOGOS_T), (1, LOGOS_P)):
        pg = doc[ANDARES[andar]["pagina"]]
        txts = textos(pg)
        imgs = pg.get_image_info()
        for idx, (nome, cat) in logos.items():
            r = fitz.Rect(imgs[idx]["bbox"])
            cx, cy = (r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2
            loja, area = rotulo_loja(txts, cx, cy, 30 if andar == 0 else 140)
            pid = "poi_" + slug(nome)
            if pid in vistos:
                pid += f"_{idx}"
            vistos.add(pid)
            area_num = float(area.replace(".", "").replace(",", ".")) if area and "," in area else float(area) if area else 0
            tags = ["âncora"] if area_num > 800 else []
            if loja: tags.append(f"loja {loja}")
            add_poi(pid, andar, cx, cy, nome, cat, tags, loja=loja, area=area)

    # quiosques do térreo
    txts = textos(doc[1])
    nomes_logos = {p["nome"].lower() for p in pois if p["andar"] == 0}
    for q in txts:
        if not re.fullmatch(r"Q\s?P?C?\d+[A-Z]?(-[A-Z])?\s?[A-Z]?", q["t"]):
            continue
        viz = [o for o in txts if 0 < o["y"] - q["y"] < 6 and abs(o["x"] - q["x"]) < 14
               and not re.fullmatch(r"[\d.,\s]+(m²)?", o["t"]) and not o["t"].startswith("Q")]
        if not viz:
            continue
        nome = viz[0]["t"].replace("Mc Donald's", "McDonald's").strip()
        if nome.upper() == nome and len(nome) > 3: nome = nome.title()
        if nome == "Unicesumar":  # o quiosque Q 15 B é Fini Pocket; Unicesumar é um stand ao lado
            nome = "Fini Pocket"
        if nome.lower() in nomes_logos and nome not in ("McDonald's",):
            continue
        cat = A if nome in ALIMENTACAO_Q or nome.startswith("McDonald") or nome == "Fini Pocket" else Z if nome in LAZER_Q else S if nome in SERVICO_Q else L
        pid = "poi_q_" + slug(nome)
        while pid in vistos: pid += "_b"
        vistos.add(pid)
        nome_q = f"{nome} (quiosque)" if nome.startswith("McDonald") else nome
        add_poi(pid, 0, q["x"], q["y"], nome_q, cat, ["quiosque", q["t"].replace(" ", "")])
    add_poi("poi_unicesumar_stand", 0, 1409, 646, "Unicesumar (stand)", S, ["faculdade", "educação"])

    for sid, andar, x, y, nome, en, es, cat, tags, ex in SERVICOS:
        add_poi(sid, andar, x, y, nome, cat, tags, ex, en, es)

    # nós
    nos = []
    for nid, (andar, x, y, tipo, pt, en, es, ex) in NOS.items():
        mx, my = m(andar, x, y)
        n = {"id": nid, "andar": andar, "x": mx, "y": my, "tipo": tipo}
        if tipo == "entrada":
            n["nome"] = pt; n["nome_en"] = en; n["nome_es"] = es
            n["referencia"] = "na " + pt[0].lower() + pt[1:]
            n["referencia_en"] = "at the " + en[0].lower() + en[1:]
            n["referencia_es"] = "en la " + es[0].lower() + es[1:]
        else:
            n["referencia"] = pt; n["referencia_en"] = en; n["referencia_es"] = es
        if tipo == "vertical":
            n["nome"] = {"t_esc": "Escadas rolantes (térreo)", "p_esc": "Escadas rolantes (2º piso)",
                         "t_elev": "Elevador (térreo, acesso oeste)", "p_elev": "Elevador (2º piso)"}[nid]
        for k in ("a_validar", "externo"):
            if ex.get(k): n[k] = True
        nos.append(n)
    porid = {n["id"]: n for n in nos}

    arestas = []
    for i, (a, b) in enumerate(ARESTAS):
        ext = NOS[a][7].get("externo") or NOS[b][7].get("externo")
        est = "alto" if (a, b) in ESTIMULO_ALTO or (b, a) in ESTIMULO_ALTO else (
            "baixo" if NOS[a][7].get("estimulo") == "baixo" or NOS[b][7].get("estimulo") == "baixo" or ext else "medio")
        e = {"id": f"e{i + 1:03d}", "de": a, "para": b, "tipo": "corredor", "estimulo": est}
        if ext:
            e["a_validar"] = True; e["descricao"] = "calçada externa até o elevador da fachada oeste"
        arestas.append(e)
    for vid, a, b, tipo, dist, desc in VERTICAIS:
        e = {"id": vid, "de": a, "para": b, "tipo": tipo, "distancia": dist, "descricao": desc, "estimulo": "medio"}
        arestas.append(e)

    # liga cada loja ao nó de corredor mais próximo do mesmo andar
    corr = [n for n in nos if n["tipo"] in ("corredor", "entrada") and not n.get("externo") and n["id"] != "t_po"]
    for p in pois:
        c = [n for n in corr if n["andar"] == p["andar"]]
        if "no" in p: continue
        p["no"] = min(c, key=lambda n: math.hypot(n["x"] - p["x"], n["y"] - p["y"]))["id"]

    andares = []
    limpo = pdf_sem_poluicao()
    for aid, a in ANDARES.items():
        x0, y0, x1, y1 = a["recorte"]; k = a["m_por_pt"]
        base = f"planta_{'terreo' if aid == 0 else 'piso2'}"
        imagens, tam = {}, None
        for tema, img in planta_limpa(limpo, doc, aid, nos, ARESTAS_DO_ANDAR(aid, nos)).items():
            arq = f"{base}_{tema}.webp"
            img.save(RAIZ / "dados" / arq, "WEBP", quality=80, method=6)
            imagens[tema] = arq; tam = img.size
        andares.append({"id": aid, "nome": a["nome"], "nome_en": a["nome_en"], "nome_es": a["nome_es"],
                        "largura": round((x1 - x0) * k, 1), "altura": round((y1 - y0) * k, 1),
                        "imagem": imagens["claro"], "imagens": imagens, "imagem_px": list(tam)})
    for velho in (RAIZ / "dados").glob("planta_*.webp"):
        if not any(velho.name in a["imagens"].values() for a in andares):
            velho.unlink()

    pacote = {
        "versao": {"pacote_id": "capim-dourado-piloto", "versao": "1.0.0", "atualizado_em": "2026-11-13",
                   "fonte": "Planta Mix – Operações Capim Dourado Shopping, nov/2026 (folhas 1/2 e 2/2)",
                   "observacao": "Coordenadas em metros, medidas sobre a planta (térreo 1:850). Corredores traçados sobre a planta. "
                                 "Só há conexões entre andares desenhadas na planta: escadas rolantes + escada fixa (Praça de Eventos oeste) "
                                 "e o elevador do acesso oeste (Av. JK), que não tem ligação interna desenhada com os corredores. "
                                 "Trechos com a_validar=true não são usados em rotas acessíveis."},
        "edificio": {"id": "capim-dourado", "nome": "Capim Dourado Shopping", "cidade": "Palmas - TO",
                     "area_m2": 38800.5, "andares": andares},
        "nos": nos, "arestas": arestas, "pois": pois,
        "beacons": [{"id": b, "uuid": "a_definir", "andar": porid[n]["andar"], "no": n, "status": "planejado"} for b, n in BEACONS],
        "perfis": {
            "padrao": {"nome": "Navegação padrão", "proibidos": [], "multiplicador_tipo": {}, "multiplicador_estimulo": {}, "penalidade_curva": 0},
            # visual: evita escadas e escadas rolantes sempre que houver alternativa confirmada
            "visual": {"nome": "Acessibilidade visual", "proibidos": [], "multiplicador_tipo": {"escada": 4.0, "escada_rolante": 6.0, "esteira": 6.0}, "multiplicador_estimulo": {"alto": 1.2}, "penalidade_curva": 8, "exigir_confirmado": True},
            "auditiva": {"nome": "Acessibilidade auditiva", "proibidos": [], "multiplicador_tipo": {}, "multiplicador_estimulo": {}, "penalidade_curva": 0},
            "mobilidade": {"nome": "Mobilidade acessível", "proibidos": ["escada", "esteira", "escada_rolante"], "multiplicador_tipo": {}, "multiplicador_estimulo": {}, "penalidade_curva": 0, "exigir_confirmado": True},
            "sensorial": {"nome": "Navegação sensorial", "proibidos": [], "multiplicador_tipo": {"escada_rolante": 1.5, "esteira": 2.0}, "multiplicador_estimulo": {"alto": 2.5, "medio": 1.3}, "penalidade_curva": 3},
        },
    }
    (RAIZ / "dados" / "pacote_capim_dourado.json").write_text(json.dumps(pacote, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(pois)} pontos de interesse, {len(nos)} nós, {len(arestas)} trechos")
    for a in andares: print(a)


if __name__ == "__main__":
    main()
