class_name VersusCpu
extends RefCounted
## CÉREBRO DA CPU: "toca" a pista dela como se fosse um jogador.
## Na hora que a música começa (preparar), sorteia para cada nota se vai tentar acertar e com
## quanto atraso/adiantamento. Durante a música (atualizar), aperta e solta as colunas nos tempos sorteados.

## Pista (lane) que a CPU controla.
var lane: int = 1
## Chance (0 a 1) de tentar acertar cada nota. Quanto maior, mais difícil.
var precisao: float = 0.85
## Desvio padrão do tempo do aperto, em segundos. Quanto menor, mais PERFEITOs.
var desvio: float = 0.05

var _rng := RandomNumberGenerator.new()
var _plano: Array = []        # apertos planejados: { "t": tempo, "col": coluna, "soltar": tempo de soltar ou -1 }
var _proximo := 0             # próximo aperto do plano que ainda não aconteceu
var _soltar: Array = []       # notas longas seguradas: { "t": tempo de soltar, "col": coluna }


## Sorteia o plano de apertos para todas as notas da pista da CPU no chart da partida.
func preparar(chart: RhythmChart) -> void:
	_rng.randomize()
	_plano.clear()
	_soltar.clear()
	_proximo = 0
	for n: RhythmChart.Note in chart.notes:
		if n.lane != lane:
			continue
		if _rng.randf() > precisao:
			continue   # a CPU "erra" essa nota: não aperta
		var item := { "t": n.time + _rng.randfn(0.0, desvio), "col": n.col, "soltar": -1.0 }
		if n.is_hold():
			item["soltar"] = n.time + n.duration - 0.03
		_plano.append(item)
	_plano.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])


## Chame todo frame com o tempo atual da música: executa os apertos e as soltadas que já passaram da hora.
func atualizar(ritmo: VersusRitmo, tempo: float) -> void:
	while _proximo < _plano.size() and _plano[_proximo]["t"] <= tempo:
		var item: Dictionary = _plano[_proximo]
		_proximo += 1
		ritmo.apertar_coluna(lane, item["col"], item["t"])
		if item["soltar"] >= 0.0:
			_soltar.append({ "t": item["soltar"], "col": item["col"] })
	for i in range(_soltar.size() - 1, -1, -1):
		if _soltar[i]["t"] <= tempo:
			ritmo.soltar_coluna(lane, _soltar[i]["col"], _soltar[i]["t"])
			_soltar.remove_at(i)
