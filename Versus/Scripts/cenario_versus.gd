class_name CenarioVersus
extends Resource
## DADOS DE UM MAPA (cenário) DO VERSUS  (um arquivo .tres por mapa, em res://Versus/Dados/Cenarios/)
##
## COMO CRIAR UM MAPA NOVO (sem mexer em código):
##   1. No FileSystem: clique direito em Versus/Dados/Cenarios > Novo Recurso > "CenarioVersus" > salve (ex.: praia.tres).
##   2. No Inspetor, arraste as imagens para "Foto" e "Fundo" (veja abaixo) e escreva o nome.
##   3. Abra Versus/Dados/elenco_cenarios.tres e adicione o arquivo na lista "Cenarios".
## Ele aparece sozinho na tela de escolha de mapa.

## Nome do mapa (aparece na escolha de mapa e na apresentação).
@export var nome_exibido: String = "NOVO MAPA"
## FOTO: imagem mostrada ao jogador na tela de escolha de mapa (pré-visualização). Pode ser qualquer imagem (.png, .jpg).
@export var foto: Texture2D
## FUNDO: imagem de cenário usada atrás dos lutadores durante a luta (png/jpg). Se ficar vazio, usa a "Foto".
@export var fundo: Texture2D
## Quanto o fundo é escurecido durante a luta (0 = nada, 1 = preto) para as notas ficarem legíveis.
@export_range(0.0, 0.9, 0.05) var escurecer: float = 0.35


## Imagem do fundo da luta (usa a foto se o fundo estiver vazio).
func obter_fundo() -> Texture2D:
	return fundo if fundo != null else foto


## Imagem da pré-visualização (usa o fundo se a foto estiver vazia).
func obter_foto() -> Texture2D:
	return foto if foto != null else fundo
