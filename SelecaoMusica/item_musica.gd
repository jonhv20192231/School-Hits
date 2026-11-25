class_name ItemMusica
extends Resource
## UMA MÚSICA DA LISTA da SelecaoMusica. Crie pelo Inspetor (Novo Recurso > ItemMusica) ou direto dentro da lista "Musicas".

## Nome mostrado na lista.
@export var nome_exibido: String = "NOVA MÚSICA"
## Artista / banda / anime (texto opcional).
@export var artista: String = ""
## O arquivo de áudio (.mp3, .ogg, .wav). Arraste aqui.
@export var audio: AudioStream
## Capa opcional (se vazio aparece um disco de vinil desenhado).
@export var capa: Texture2D
## BPM (aparece nos detalhes; use como quiser na cena de destino lendo SelecaoMusica.escolhida.bpm).
@export_range(40.0, 240.0, 1.0, "suffix:bpm") var bpm: float = 120.0
## Em que segundo a prévia começa na tela de escolha.
@export_range(0.0, 600.0, 1.0, "suffix:s") var inicio_previa: float = 0.0
## CENA PARA ONDE IR quando o jogador escolher ESTA música. Vazio = usa a "Cena Ao Confirmar" da SelecaoMusica.
@export_file("*.tscn") var cena_destino: String = ""
## Dados livres para a sua cena de destino (ex.: {"dificuldade": 2, "fase": "praia"}). Leia em SelecaoMusica.escolhida.extras
@export var extras: Dictionary = {}
