class_name ElencoMusicas
extends Resource
## LISTA DE MÚSICAS que aparecem na tela de escolha de música (arquivo padrão: res://Versus/Dados/elenco_musicas.tres).
## Abra esse arquivo no Inspetor para adicionar ou trocar músicas:
##   • "Musicas": músicas completas (MusicaVersus), com nome, artista, BPM, capa etc.
##   • "Audios Rapidos": arraste só os arquivos de áudio; o nome vem do nome do arquivo e o BPM do "Bpm Padrao".

## Músicas completas (aparecem primeiro na lista).
@export var musicas: Array[MusicaVersus] = []
## Atalho: arraste arquivos de áudio aqui e eles viram músicas automaticamente (nome = nome do arquivo).
@export var audios_rapidos: Array[AudioStream] = []
## BPM usado nas músicas criadas pelos "Audios Rapidos".
@export_range(40.0, 240.0, 1.0, "suffix:bpm") var bpm_padrao: float = 120.0


## Devolve a lista final: as músicas completas + as criadas a partir dos áudios rápidos.
func todas() -> Array[MusicaVersus]:
	var lista: Array[MusicaVersus] = []
	for m in musicas:
		if m != null and m.audio != null:
			lista.append(m)
	for a in audios_rapidos:
		if a == null:
			continue
		var m := MusicaVersus.new()
		m.audio = a
		m.bpm = bpm_padrao
		var arquivo := a.resource_path.get_file().get_basename()
		m.nome_exibido = arquivo if arquivo != "" else "MÚSICA"
		lista.append(m)
	return lista
