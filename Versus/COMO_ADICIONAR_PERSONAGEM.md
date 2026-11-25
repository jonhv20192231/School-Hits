# Modo Versus - guia rápido

## Como instalar
Extraia o zip DENTRO da pasta do projeto (onde fica o project.godot), aceitando substituir
`Cenas/modos_de_jogo.tscn` e `scripts/modos_de_jogo.gd`. Abra o projeto no Godot e espere a importação.
Nenhum Autoload nem alteração no project.godot é necessária. Os scripts do ritmo (RhythmStage) NÃO foram alterados.

## Fluxo
Modos de jogo -> MODO VERSUS -> (1 jogador | 2 jogadores) -> Seleção de personagem -> Escolha do mapa ->
Escolha da música -> Cutscene de apresentação -> Batalha.

## Teclas
- Batalha: P1 = A S D F (especial: ESPAÇO) | P2 = J K L Ç (especial: ENTER). A CPU joga sozinha no modo 1 jogador.
- Seleção de personagem: 1 jogador = setas ou WASD + ENTER/ESPAÇO/F (primeiro você, depois o adversário).
  2 jogadores = P1 WASD + F, P2 setas + ENTER.
- Tecla R na seleção de personagem: sorteia o seu personagem e o do adversário. Em mapa e música, R destaca um aleatório.
- Cutscene: ENTER/ESPAÇO/clique pulam. ESC volta uma tela nas telas de escolha.

## Como adicionar um personagem novo (sem mexer em código)
1. Coloque as imagens (todas do mesmo tamanho, personagem olhando para a DIREITA, pés na base) numa pasta, ex.: Versus/Sprites/meu_lutador/
2. Crie um SpriteFrames (.tres) com as animações:
   idle, hit_0, hit_1... (acertos), miss_0, miss_1... (erros) e, opcionais: perfect, special, ko, vitoria.
3. Em Versus/Dados: clique direito > Novo Recurso > "Lutador" e salve (ex.: meu_lutador.tres). Preencha no Inspetor:
   - Nome exibido, Cor, Retrato (imagem do quadradinho; se vazio é recortado do idle)
   - Sprite Frames, Escala Sprite, Deslocamento Pes
   - VOZ DA SELEÇÃO: arraste o áudio em "Voz Selecao" e defina "Voz Duracao" (segundos até cortar; 0 = inteiro)
   - Nome Especial, Dano Especial (%), Cor Especial
4. Abra Versus/Dados/elenco.tres e adicione o arquivo na lista "Lutadores". Ele aparece sozinho na grade.

Voz do Freddie e do Michael: abra Versus/Dados/freddie.tres (ou michael.tres) e arraste o áudio para "Voz Selecao".

## Adicionar MAPAS (cenários)
1. Clique direito em Versus/Dados > Novo Recurso > "CenarioVersus" > salve (ex.: praia.tres).
2. No Inspetor: **Foto** = imagem que o jogador vê na escolha de mapa; **Fundo** = png/jpg usado atrás dos lutadores
   na luta (se um ficar vazio, usa o outro); **Escurecer** = quanto o fundo é escurecido na luta.
3. Abra Versus/Dados/elenco_cenarios.tres e adicione o arquivo na lista "Cenarios".

## Adicionar MÚSICAS
Abra Versus/Dados/elenco_musicas.tres. Duas opções:
- **Audios Rapidos**: arraste o arquivo de áudio (mp3/ogg/wav) na lista. Nome = nome do arquivo, BPM = "Bpm Padrao".
- **Musicas**: crie um recurso "MusicaVersus" (nome, artista, áudio, capa, BPM, notas por segundo, duração da luta,
  volume, início da prévia) e adicione na lista.
O BPM só muda a grade em que as notas aleatórias aparecem; ajuste para combinar com a música.
As músicas padrão da lista usam BPM 120: ajuste cada uma se quiser.

## Cutscene de apresentação
Cena Versus/Cenas/versus_apresentacao.tscn (nó raiz): tempo de cada lutador, voz de apresentação ligada/desligada, altura das barras.

## Ajustes da luta
Abra Versus/Cenas/versus_batalha.tscn e clique no nó raiz "BatalhaVersus": duração, notas por segundo, dano ao errar,
cura ao acertar, enchimento do especial, teclas do especial e dificuldade da CPU. Mapa, música, BPM e duração escolhidos
nas telas anteriores têm prioridade sobre os valores de fundo/música/BPM do nó.
