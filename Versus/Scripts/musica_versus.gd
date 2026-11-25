class_name MusicaVersus
extends Resource
## DADOS DE UMA MÚSICA DO VERSUS  (um arquivo .tres por música, em res://Versus/Dados/Musicas/)
##
## Duas formas de adicionar músicas (veja também ElencoMusicas):
##   A) RÁPIDA: em Versus/Dados/elenco_musicas.tres, arraste o arquivo de áudio na lista "Audios Rapidos".
##   B) COMPLETA: crie um recurso "MusicaVersus" (.tres), preencha os campos abaixo e adicione na lista "Musicas".

## Nome mostrado na lista.
@export var nome_exibido: String = "NOVA MÚSICA"
## Artista / banda / anime (texto livre, opcional).
@export var artista: String = ""
## O arquivo de áudio (.mp3, .ogg, .wav). Arraste aqui.
@export var audio: AudioStream
## Capa da música (imagem opcional mostrada no painel de detalhes).
@export var capa: Texture2D
## BPM da grade de notas: ajuste para combinar com o ritmo da música.
@export_range(40.0, 240.0, 1.0, "suffix:bpm") var bpm: float = 120.0
## Quantas notas por segundo cada lado recebe nesta música (0 = usa o padrão da batalha).
@export_range(0.0, 6.0, 0.1) var notas_por_segundo: float = 0.0
## Duração da luta em segundos (0 = usa o padrão da batalha; se a música for mais curta ela repete).
@export_range(0.0, 600.0, 5.0, "suffix:s") var duracao_luta: float = 0.0
## Volume da música na luta.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_db: float = -4.0
## Em que segundo a prévia começa na tela de escolha (para tocar o refrão, por exemplo).
@export_range(0.0, 600.0, 1.0, "suffix:s") var inicio_previa: float = 0.0
