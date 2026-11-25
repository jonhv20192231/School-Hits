class_name ElencoLutadores
extends Resource
## ELENCO = a lista de lutadores que aparecem na seleção de personagem.
## O arquivo padrão é res://Versus/Dados/elenco.tres. Para adicionar um personagem novo, abra esse arquivo
## no Inspetor e acrescente o arquivo .tres do lutador na lista abaixo (a ordem da lista é a ordem na grade).

## Lutadores disponíveis, na ordem em que aparecem na grade (esquerda -> direita, de cima para baixo).
@export var lutadores: Array[Lutador] = []
