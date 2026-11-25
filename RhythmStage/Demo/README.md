# Cena de ritmo reutilizável (100% GDScript, sem .NET)

Teste rápido: abra `RhythmStage/Demo/rhythm_demo.tscn` e aperte **F6**.
Teclas: Ana `A S D F` · Marcos `G H J` · Junpei `K L Ç` · `R` reinicia · `ENTER` continua (na tela de resultado: reinicia a cena atual).
**O ESC não é usado por esta cena**: o seu HUD/menu continua dono dessa tecla.

## Usar em outra cena
Arraste `rhythm_demo.tscn` para a sua cena (ou **Instanciar cena filha**) e ajuste as propriedades do **nó raiz** no Inspector, sem abrir os filhos:

| Grupo | Propriedade | O que faz |
|---|---|---|
| Música | Chart Path | Música e BPM (um `.json` de `RhythmStage/charts/`) |
| Música | Duration Seconds | Duração da faixa em segundos (0 = música inteira). Se for maior que a música, ela toca de novo até completar |
| Música | Fill Duration | Se o chart for mais curto que a duração, repete as notas dele |
| Jogadores | Players | `Do chart`, `1 jogador`, `2 jogadores` ou `3 jogadores` ao mesmo tempo |
| Jogadores | Lane Order | Quem entra primeiro: 0 = Ana, 1 = Marcos, 2 = Junpei (o primeiro é o jogador 1) |
| Jogadores | Distribute Notes | Reparte as notas do chart entre os jogadores |
| Notas aleatórias | Random Notes | Notas sorteadas, sem parar, até o fim da duração |
| Notas aleatórias | Random Notes Per Second | Média de notas por segundo, por jogador |
| Notas aleatórias | Random Seed | 0 = sorteio novo a cada partida; outro número repete a sequência |
| Cena | Show Background | Cenário escurecido e chão. Desligue para jogar o ritmo por cima da sua própria cena |
| Cena | Auto Start | Começa ao entrar na cena (desligue e chame `start_music()` quando quiser) |
| Cena | Show Results | Mostra o resultado no meio da tela quando a música acaba |
| Cena | Continue Action | O que o ENTER faz no resultado: **Reiniciar a cena atual** (padrão), reiniciar só a música, ou nada (use o sinal `continue_requested`) |
| Cena | Allow Restart | `R` reinicia a música durante a partida |

A raiz é um **CanvasLayer**: o ritmo (e o resultado no meio da tela) se posiciona pela janela, não pelo nó onde você instanciar a cena. O Inspector tem a propriedade **Layer**: deixe o seu menu/HUD com um Layer maior para ele aparecer por cima do ritmo.

Só aparecem a **pista, o nome e o personagem de quem está jogando**, centralizados (1 jogador = só o jogador 1).

Por código:
```gdscript
var ritmo = preload("res://RhythmStage/Demo/rhythm_demo.tscn").instantiate()
ritmo.players = 2
ritmo.duration_seconds = 90.0
ritmo.random_notes = true
ritmo.rhythm_finished.connect(_on_ritmo_fim)   # (score, accuracy, rank, max_combo)
add_child(ritmo)

func _on_ritmo_fim(score: int, accuracy: float, rank: String, max_combo: int) -> void:
    print("Terminou! Rank ", rank)   # aqui você troca de cena, dá recompensa etc.
```
Os julgamentos aparecem em português: **PERFEITO, ÓTIMO, BOM, ERROU** (e **RAJADA** para acertos de spam). Os nomes ficam em `JUDGMENT_NAMES`, em `rhythm_config.gd`.
Ao terminar, aparece no meio da tela: **PARABÉNS!**, pontuação, precisão, rank, combo máximo, PERFEITO/ÓTIMO/BOM e **erros**. A cena não fecha sozinha: use o sinal `rhythm_finished` para seguir o fluxo do seu jogo (ou `Show Results` desligado para fazer o seu próprio painel).

## O que é um "chart"
Um chart é o arquivo `.json` (em `RhythmStage/charts/`) que descreve uma música: título, `music` (arquivo em `RhythmStage/music/`), `bpm`, `offset` e a lista de `notes` (`beat`, `lane`, `col`, `len` para nota longa).
- **Chart Path** escolhe qual música toca e em que BPM as notas caem.
- Com **Random Notes** ligado, as notas do chart são ignoradas: só a música, o BPM e o offset dele são usados.
- Se o Chart Path apontar para um arquivo que não existe ou está vazio, o jogo usa em silêncio um chart de emergência embutido no código (32 notas, sem música), sem mostrar nenhuma mensagem.

## Árvore de nós
```
RhythmDemo (CanvasLayer, rhythm_demo.gd)  exports acima, HUD, resultado final
├─ Background / Escurecer / Chao          fundo
├─ Palco (Node2D)
│   └─ Ana / Marcos / Junpei              AnimatedSprite2D + rhythm_character.gd (somem se a lane não tem jogador)
├─ Highway (Control, rhythm_highway.gd)   mostra/centraliza só as pistas dos jogadores ativos
│   ├─ LaneAna / LaneMarcos / LaneJunpei  fundo + nome (editáveis)
│   ├─ LinhaDeAcerto
│   └─ NoteField (rhythm_note_field.gd)   desenha as notas
├─ ScoreLabel, ComboLabel, InfoLabel, CountdownLabel, AjudaLabel
├─ ResultsPanel                           só aparece no final
└─ RhythmPlayer (Node, rhythm_player.gd)  lógica + música + teclas + sinais
```

## Peças reutilizáveis
| Script | Papel |
|---|---|
| `rhythm_player.gd` | O cérebro. Funciona sozinho em qualquer cena: `start(chart)`, `stop()`, `restart()`; sinais `started`, `judged(lane, judgment, sloppy, col)`, `column_changed`, `finished`. Tem os mesmos exports de jogadores/duração/aleatório |
| `rhythm_highway.gd` | Organiza as pistas (só as ativas, centralizadas) |
| `rhythm_note_field.gd` | Desenha as notas |
| `rhythm_character.gd` | Anima um `AnimatedSprite2D` a cada acerto da lane (`idle`, `hit_0…hit_N`, `miss`) |
| `rhythm_config.gd`, `rhythm_chart.gd`, `rhythm_gameplay.gd`, `rhythm_score.gd` | Porte de Config/Chart/Gameplay/ScoreKeeper. Lêem os mesmos `.json` |

Os `SpriteFrames` ficam em `sprites/ana_frames.tres`, `marcos_frames.tres` e `junpei_frames.tres` (painel SpriteFrames do editor).
Os ids das lanes nos charts continuam `susie`/`kris`/`ralsei`; na tela aparecem como ANA/MARCOS/JUNPEI (`lanes` em `rhythm_config.gd`).

## Se der erro ao abrir (`null instance`, "Could not find type", textura sem carregar)
1. Deixe o Godot terminar de importar (barra de progresso no canto) depois de copiar os arquivos.
2. Se continuar, feche e reabra o projeto (**Projeto > Recarregar o projeto atual**): é assim que o editor registra as classes `RhythmPlayer`, `RhythmHighway` etc. e importa os PNGs novos.
3. Se usar só partes da cena em outra, os nomes `%ScoreLabel`, `%ResultsPanel` etc. precisam existir nela. O mais simples é instanciar `rhythm_demo.tscn` inteira.
