class_name ElencoCenarios
extends Resource
## LISTA DE MAPAS que aparecem na tela de escolha de mapa (arquivo padrão: res://Versus/Dados/elenco_cenarios.tres).
## Para adicionar um mapa, crie um "CenarioVersus" (.tres) e acrescente-o na lista abaixo.

## Mapas disponíveis, na ordem em que aparecem.
@export var cenarios: Array[CenarioVersus] = []
