# SelecaoMusica (layout de escolha de música)

Extraia na pasta do projeto (fica `res://SelecaoMusica/`). Abra `selecao_musica.tscn` e clique no nó raiz:

- **Musicas**: lista de `ItemMusica` (nome, artista, audio, capa, bpm, inicio_previa, cena_destino, extras).
- **Audios Rapidos**: arraste só os arquivos de áudio.
- **Cena Ao Confirmar**: cena carregada ao apertar ENTER (cada música pode ter a sua `Cena Destino`, que tem prioridade).
- **Cena Ao Voltar**: cena do ESC.
- Aparência (título, fundo, cor, fonte) e prévia (liga/desliga, volume, atraso).

Na cena de destino: `SelecaoMusica.escolhida` (ItemMusica) tem a música confirmada
(`.audio`, `.bpm`, `.nome_exibido`, `.extras`). Também existe o sinal `musica_confirmada(item)`.

Controles: setas/WS escolhem, ENTER/ESPAÇO/F confirmam, R sorteia, ESC volta.
