class_name VersusEstado
extends RefCounted
## ESTADO GLOBAL DO MODO VERSUS
## Guarda as escolhas do jogador (modo, lutadores) enquanto o jogo troca de cena:
## "versus_modo" -> "versus_selecao" -> "versus_batalha".
## Também guarda os caminhos das cenas e troca as pistas do ritmo para o formato versus.
## Como tudo aqui é "static", NÃO precisa configurar Autoload no Projeto.

## Modos de jogo do versus.
enum Modo { UM_JOGADOR, DOIS_JOGADORES }

# ───────────── caminhos das cenas (mude aqui se mover os arquivos) ─────────────
const CENA_MODOS_DE_JOGO := "res://Cenas/modos_de_jogo.tscn"   # tela com os botões Um jogador / Coop / Livre / Versus
const CENA_MODO_VERSUS := "res://Versus/Cenas/versus_modo.tscn"   # pergunta: 1 jogador ou 2 jogadores
const CENA_SELECAO := "res://Versus/Cenas/versus_selecao.tscn"    # seleção de personagem (estilo Street Fighter 2)
const CENA_MAPA := "res://Versus/Cenas/versus_mapa.tscn"          # escolha do mapa (cenário)
const CENA_MUSICA := "res://Versus/Cenas/versus_musica.tscn"      # escolha da música
const CENA_APRESENTACAO := "res://Versus/Cenas/versus_apresentacao.tscn"   # cutscene de apresentação antes da luta
const CENA_BATALHA := "res://Versus/Cenas/versus_batalha.tscn"    # a luta de ritmo em si

## Arquivo (.tres) com a lista de lutadores disponíveis. Para adicionar personagem, edite este arquivo.
const ELENCO_PADRAO := "res://Versus/Dados/elenco.tres"
## Arquivo (.tres) com a lista de mapas disponíveis.
const ELENCO_CENARIOS := "res://Versus/Dados/elenco_cenarios.tres"
## Arquivo (.tres) com a lista de músicas disponíveis.
const ELENCO_MUSICAS := "res://Versus/Dados/elenco_musicas.tres"

# ───────────── escolhas atuais ─────────────
## Modo escolhido na tela "versus_modo".
static var modo: int = Modo.UM_JOGADOR
## Lutador do jogador 1 (lado esquerdo da tela).
static var lutador_p1: Lutador = null
## Lutador do jogador 2 ou da CPU (lado direito da tela).
static var lutador_p2: Lutador = null
## Mapa escolhido (null = a batalha usa o cenário padrão dela).
static var cenario: CenarioVersus = null
## Música escolhida (null = a batalha usa as músicas padrão dela).
static var musica: MusicaVersus = null


## true quando o lado direito é controlado pela CPU.
static func p2_eh_cpu() -> bool:
	return modo == Modo.UM_JOGADOR


## Carrega o elenco padrão (lista de lutadores). Devolve null se o arquivo não existir.
static func carregar_elenco() -> ElencoLutadores:
	if ResourceLoader.exists(ELENCO_PADRAO):
		return load(ELENCO_PADRAO) as ElencoLutadores
	return null


## Limpa as escolhas (usado ao voltar para a tela de modos).
static func limpar_escolhas() -> void:
	lutador_p1 = null
	lutador_p2 = null
	cenario = null
	musica = null


## Carrega a lista de mapas. Devolve null se o arquivo não existir.
static func carregar_cenarios() -> ElencoCenarios:
	if ResourceLoader.exists(ELENCO_CENARIOS):
		return load(ELENCO_CENARIOS) as ElencoCenarios
	return null


## Carrega a lista de músicas. Devolve null se o arquivo não existir.
static func carregar_musicas() -> ElencoMusicas:
	if ResourceLoader.exists(ELENCO_MUSICAS):
		return load(ELENCO_MUSICAS) as ElencoMusicas
	return null


## Garante que existam dois lutadores. Serve para abrir a cena de batalha direto no editor (F6)
## sem passar pela seleção: pega os dois primeiros do elenco.
static func garantir_lutadores() -> void:
	if lutador_p1 != null and lutador_p2 != null:
		return
	var elenco := carregar_elenco()
	if elenco == null or elenco.lutadores.is_empty():
		push_error("VersusEstado: o elenco está vazio. Adicione lutadores em %s" % ELENCO_PADRAO)
		return
	if lutador_p1 == null:
		lutador_p1 = elenco.lutadores[0]
	if lutador_p2 == null:
		lutador_p2 = elenco.lutadores[1 % elenco.lutadores.size()]


# ───────────── pistas do ritmo no formato versus ─────────────
# O ritmo original tem 3 pistas (ANA, MARCOS, JUNPEI) com 4/3/3 teclas. No versus cada lado tem uma
# pista de 4 teclas (iguais para os dois), então trocamos RhythmConfig.lanes só enquanto a batalha existe.

static var _pistas_originais: Array = []
static var _pistas_trocadas := false

## Teclas de cada lado: P1 (esquerda) = A S D F, P2 (direita) = J K L Ç.
const TECLAS_P1: Array = [KEY_A, KEY_S, KEY_D, KEY_F]
const ROTULOS_P1: Array = ["A", "S", "D", "F"]
const TECLAS_P2: Array = [KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]
const ROTULOS_P2: Array = ["J", "K", "L", "Ç"]


## Troca as pistas do RhythmConfig pelas duas pistas do versus (chame ao entrar na batalha).
static func aplicar_pistas_versus() -> void:
	if _pistas_trocadas:
		return
	_pistas_originais = RhythmConfig.lanes.duplicate(true)
	RhythmConfig.lanes = [
		{ "name": "P1", "id": "p1", "color": Color("ff5a5a"), "keys": TECLAS_P1.duplicate(), "labels": ROTULOS_P1.duplicate() },
		{ "name": "P2", "id": "p2", "color": Color("5aa0ff"), "keys": TECLAS_P2.duplicate(), "labels": ROTULOS_P2.duplicate() },
	]
	_pistas_trocadas = true


## Devolve as pistas originais do ritmo (chame ao sair da batalha para não quebrar as outras cenas).
static func restaurar_pistas() -> void:
	if not _pistas_trocadas:
		return
	RhythmConfig.lanes = _pistas_originais
	_pistas_originais = []
	_pistas_trocadas = false
