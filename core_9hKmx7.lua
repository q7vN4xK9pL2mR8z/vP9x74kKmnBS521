setDefaultTab("Main")
TaskDemon = TaskDemon or {}

if taskDemonWindow then
    taskDemonWindow:destroy()
    taskDemonWindow = nil
end

TaskDemon.ROTAS_PADRAO = {CAMINHO = {}, PRINCIPAL = {}, DP = {}}
TaskDemon.PRIMEIROS_PADRAO = {["32367,32218,7"] = 20, ["32368,32215,7"] = 39, ["32362,32221,7"] = 6}

TaskDemon.TAREFAS = {
    infernal     = {nome = "Demolisher Infernal Demon",       titulo = "Infernal Demon",       curto = "Infernal",     meta = 50, duracao = 60},
    goshnar      = {nome = "Demolisher Goshnars Megalomania", titulo = "Goshnars Megalomania", curto = "Megalomania",  meta = 50, duracao = 60},
    merlin       = {nome = "Demolisher Merlin",               titulo = "Merlin",               curto = "Merlin",       meta = 100},
    angrybird    = {nome = "Demolisher Angry Bird",           titulo = "Angry Bird",           curto = "Angry Bird",   meta = 10, dias = {seg = true, sex = true}},
    bloodsugar   = {nome = "Demolisher Blood Sugar Overlord", titulo = "Blood Sugar Overlord", curto = "Blood Sugar",  meta = 1},
    emberwing    = {nome = "Demolisher Emberwing",            titulo = "Emberwing",            curto = "Emberwing",    meta = 1, dias = {sab = true}},
    thundergiant = {nome = "Demolisher Thundergiant",         titulo = "Thundergiant",         curto = "Thundergiant", meta = 1, dias = {dom = true}},
    dragon       = {nome = "Demolisher Dragon",               titulo = "Dragon (TESTE)",       curto = "Dragon",       meta = 50},
}
TaskDemon.ORDEM = {"infernal", "goshnar", "merlin", "angrybird", "bloodsugar", "emberwing", "thundergiant"}
TaskDemon.AGENDAVEIS = {"infernal", "goshnar", "merlin", "angrybird", "bloodsugar", "emberwing", "thundergiant"}
TaskDemon.DIAS = {"dom", "seg", "ter", "qua", "qui", "sex", "sab"}

TaskDemon.TEMPO_HIT = 2
TaskDemon.RAIO_X = 16
TaskDemon.RAIO_Y = 12
TaskDemon.TEMPO_PULO = 6
-- "Matar 100%" / "Bater ate 50%": bicho de muita vida fica varios segundos sem cair 1% na barra (ex.: Angry Bird).
-- Batendo nele, so desiste depois desse tempo sem a vida cair (antes eram 6s e ele largava o bicho no meio).
TaskDemon.MATAR_SEM_DANO_S = 60
TaskDemon.APROXIMAR_S = 4        -- 1 hit: tempo tentando chegar perto antes de pular o bicho
TaskDemon.APROXIMAR_MATAR_S = 10 -- 100% / 50%: persegue mais antes de pular
TaskDemon.DIST_MAX = 20
TaskDemon.MS_DESVIO = 1200
TaskDemon.MS_PRESO = 2500
TaskDemon.MS_MANUAL = 1500
TaskDemon.CHEGOU = 2

storage.TaskDemon = storage.TaskDemon or {}
local cfg = storage.TaskDemon
cfg.metas = cfg.metas or {}
if cfg.meta then
    for _, k in ipairs({"infernal", "goshnar", "dragon"}) do
        if cfg.metas[k] == nil then cfg.metas[k] = cfg.meta end
    end
    cfg.meta = nil
end
function TaskDemon.metaDe(k)
    k = k or cfg.tarefa
    return cfg.metas[k] or (TaskDemon.TAREFAS[k] and TaskDemon.TAREFAS[k].meta) or 50
end
cfg.tarefa = cfg.tarefa or "infernal"
-- tarefa salva que saiu da lista (ex.: dragon de teste): volta pra primeira
do
    local naLista = false
    for _, k in ipairs(TaskDemon.ORDEM) do if k == cfg.tarefa then naLista = true end end
    if not naLista then cfg.tarefa = TaskDemon.ORDEM[1] end
end
cfg.prog = cfg.prog or {}
cfg.progServidor = cfg.progServidor or {}
cfg.progBase = cfg.progBase or {}
cfg.labelVolta = cfg.labelVolta or ""
cfg.modoAtaque = cfg.modoAtaque or "DISTANCIA"
-- modo de ataque por tarefa (MELEE/DISTANCIA); sem escolha a tarefa usa cfg.modoAtaque (o modo antigo, global)
cfg.modos = cfg.modos or {}
function TaskDemon.modoDe(k)
    k = k or cfg.tarefa
    return cfg.modos[k] or cfg.modoAtaque
end
cfg.tempoPrincipal = cfg.tempoPrincipal or tostring(cfg.minPrincipal or 10)
cfg.minPrincipal = nil

function TaskDemon.segundosPrincipal()
    local txt = tostring(cfg.tempoPrincipal or ""):lower():gsub("%s+", "")
    local m, sg = txt:match("^(%d+):(%d%d)$")
    if m then return tonumber(m) * 60 + tonumber(sg) end
    local n, un = txt:match("^(%d+)(%a*)$")
    n = tonumber(n)
    if not n then return nil end
    if un == "" or un == "m" or un == "min" then return n * 60 end
    if un == "s" or un == "seg" then return n end
    if un == "h" then return n * 3600 end
    return nil
end
cfg.alcance = cfg.alcance or 6
cfg.pos = cfg.pos or {x = 260, y = 120}
cfg.agenda = cfg.agenda or {}
cfg.disparos = cfg.disparos or {}
cfg.tempos = cfg.tempos or {}
cfg.inicioTask = cfg.inicioTask or 0
cfg.pkAtivo = (cfg.pkAtivo ~= false)
cfg.pkHistorico = nil

local function copiarRota(r)
    local c = {}
    for i, w in ipairs(r) do c[i] = {w[1], w[2], w[3], w[4] or false, w[5] or false} end   -- false, nunca buraco (o vBot nao salva lista com buraco)
    return c
end
TaskDemon.copiarRota = copiarRota
local function copiarPerfil(p)
    local c = {}
    for nome, r in pairs(TaskDemon.ROTAS_PADRAO) do
        c[nome] = copiarRota((p and p[nome]) or r)
    end
    return c
end
TaskDemon.copiarPerfil = copiarPerfil

-- PERFIS POR PERSONAGEM: arquivo proprio /TaskDemon/<personagem>.json, fora da pasta bot (o vBot lista tudo
-- que esta em /bot/ como config de bot).
-- O storage do vBot e separado por config (bot/<config>/storage/...): codigo novo em outra config
-- abria um storage sem os perfis e sobravam so os 2 padrao. Com o arquivo, os perfis valem em qualquer config.
-- vao pro arquivo do personagem (/TaskDemon/<char>.json), que SEMPRE salva e vale em qualquer bot/config:
-- CaveBots do painel + agenda (horarios/labels) + CaveBot de cada task/evento + label ao terminar de cada evento.
-- (o storage do vBot pode falhar ao salvar; ai na troca de painel/reload voltava a agenda antiga)
TaskDemon.CAMPOS_ARQ = {"perfis", "agenda", "perfilTarefa", "eventoPerfil", "evLabelFimPor", "evDisputar"}
function TaskDemon.arquivoPerfis()
    local ok, nome = pcall(function() return player:getName() end)
    if not ok or type(nome) ~= "string" or nome == "" then return nil end
    nome = nome:gsub("%s*%[%d+%]%s*$", "")   -- neste servidor o nome vem com o nivel: "Fulano [30]"
    return "/TaskDemon/" .. nome:lower():gsub("[^%w]+", "_"):gsub("_+$", "") .. ".json"
end
-- O json do vBot (corelib/json.lua) recusa lista com buraco ("sparse array") e ai NAO salva o storage inteiro.
-- semBuracos tapa buracos com false em toda lista do Task Demon (o codigo trata false igual a vazio).
-- Tabela com chave numerica muito espalhada ou misturada com texto nao da pra tapar: so avisa onde esta.
function TaskDemon.semBuracos(t, caminho, vistos, problemas, soAvisar)
    vistos, problemas = vistos or {}, problemas or {}
    if type(t) ~= "table" or vistos[t] then return problemas end
    vistos[t] = true
    local maior, qtd, temTexto = 0, 0, false
    for k, v in pairs(t) do
        if type(k) == "number" then
            qtd = qtd + 1
            if k > maior then maior = k end
        else
            temTexto = true
        end
        TaskDemon.semBuracos(v, caminho .. "." .. tostring(k), vistos, problemas, soAvisar)
    end
    if qtd > 0 and (temTexto or maior ~= math.floor(maior) or maior > qtd * 2 + 8) then
        table.insert(problemas, caminho)
    elseif qtd > 0 and maior > qtd then
        if soAvisar then
            table.insert(problemas, caminho)
        else
            for i = 1, maior do if t[i] == nil then t[i] = false end end
        end
    end
    return problemas
end
function TaskDemon.textoPerfis()
    local dados = {}
    for _, k in ipairs(TaskDemon.CAMPOS_ARQ) do dados[k] = cfg[k] end
    TaskDemon.semBuracos(dados, "arquivo")
    local ok, txt = pcall(function() return json.encode(dados) end)
    return ok and txt or nil
end
do
    local arq = TaskDemon.arquivoPerfis()
    local ok, dados = pcall(function()
        if not (arq and g_resources and g_resources.fileExists(arq)) then return nil end
        return json.decode(g_resources.readFileContents(arq))
    end)
    local temPerfil = false   -- (o vBot nao tem a funcao next)
    if ok and type(dados) == "table" and type(dados.perfis) == "table" then
        for _ in pairs(dados.perfis) do temPerfil = true break end
    end
    if temPerfil then
        for _, k in ipairs(TaskDemon.CAMPOS_ARQ) do
            if type(dados[k]) == "table" then cfg[k] = dados[k] end
        end
        TaskDemon.avisoPerfis = "Perfis de CaveBot carregados de " .. arq .. "."
        cfg.padraoRemovido = true   -- a limpeza antiga de rotas padrao NAO pode rodar em cima do arquivo
    elseif arq then
        TaskDemon.avisoPerfis = "Perfis de CaveBot: criando " .. arq .. " (vale pra qualquer config deste personagem)."
    else
        TaskDemon.avisoPerfis = "Perfis de CaveBot: nao achei o nome do personagem; usando so o storage da config."
    end
end

if type(cfg.perfis) ~= "table" then
    cfg.perfis = {}
    cfg.perfis["Task Demon"] = copiarPerfil(cfg.rotas)
    cfg.perfis["Task Mega"] = copiarPerfil(cfg.rotas)
end
cfg.rotas = nil
if not cfg.padraoRemovido then
    for _, p in pairs(cfg.perfis) do
        for nome, r in pairs(p) do
            if type(r) == "table" and r[1] and type(r[1]) == "table" then
                local chave = r[1][1] .. "," .. r[1][2] .. "," .. r[1][3]
                if TaskDemon.PRIMEIROS_PADRAO[chave] == #r then
                    for i = #r, 1, -1 do r[i] = nil end
                end
            end
        end
    end
    cfg.padraoRemovido = true
end
for _, p in pairs(cfg.perfis) do
    if type(p.CIDADE) == "table" and p.CAMINHO == nil then
        p.CAMINHO = p.PRINCIPAL
        p.PRINCIPAL = p.CIDADE
        p.CIDADE = nil
    end
    p.CIDADE = nil
end
for _, p in pairs(cfg.perfis) do
    for nome in pairs(TaskDemon.ROTAS_PADRAO) do
        if type(p[nome]) ~= "table" then p[nome] = {} end
    end
end

-- v6.0: CaveBot padrao "Angry Bird" (CAMINHO do Aurahara, DP = percurso de 104 gotos do usuario): PRINCIPAL vazio
-- (cada um grava a sua hunt). So cria 1 vez e so se o char ainda nao tem um perfil com esse nome.
TaskDemon.PERFIL_ANGRY_BIRD = {
    CAMINHO = {
        {32346, 32227, 7, false, false}, {32342, 32225, 7, false, false}, {32342, 32225, 7, false, "W"}, {18422, 18838, 5, false, false},
        {18422, 18829, 5, false, false}, {18422, 18819, 5, false, false}, {18422, 18810, 5, false, false}, {18422, 18802, 5, false, false},
        {18422, 18798, 5, false, false}, {18422, 18798, 5, false, "N"}, {18322, 18829, 5, false, false}, {18322, 18820, 5, false, false},
        {18322, 18811, 5, false, false}, {18322, 18809, 5, false, false}, {18322, 18809, 5, false, "N"}, {5107, 5204, 5, false, false},
        {5114, 5204, 5, false, false}, {5118, 5204, 5, false, false}, {5118, 5204, 5, false, "E"}, {5120, 5204, 6, false, false},
        {5122, 5204, 6, false, false}, {5122, 5204, 6, false, "E"}, {5132, 5208, 7, false, false}, {5137, 5212, 7, false, false},
    },
    DP = {
        {5086, 5264, 7, false, false}, {5084, 5259, 7, false, false}, {5084, 5258, 7, false, false}, {5084, 5257, 7, false, false},
        {5084, 5252, 7, false, false}, {5079, 5250, 7, false, false}, {5078, 5245, 7, false, false}, {5078, 5240, 7, false, false},
        {5078, 5235, 7, false, false}, {5078, 5234, 7, false, false}, {5078, 5233, 7, false, false}, {5078, 5232, 7, false, false},
        {5078, 5227, 7, false, false}, {5078, 5222, 7, false, false}, {5078, 5217, 7, false, false}, {5078, 5212, 7, false, false},
        {5078, 5207, 7, false, false}, {5077, 5202, 7, false, false}, {5077, 5198, 7, false, false}, {5077, 5197, 7, false, false},
        {5077, 5196, 7, false, false}, {5077, 5193, 7, false, false}, {5077, 5192, 7, false, false}, {5077, 5191, 7, false, false},
        {5077, 5187, 7, false, false}, {5077, 5186, 7, false, false}, {5077, 5185, 7, false, false}, {5077, 5180, 7, false, false},
        {5077, 5175, 7, false, false}, {5077, 5170, 7, false, false}, {5082, 5170, 7, false, false}, {5087, 5170, 7, false, false},
        {5092, 5170, 7, false, false}, {5097, 5170, 7, false, false}, {5099, 5170, 7, false, false}, {5100, 5170, 7, false, false},
        {5101, 5170, 7, false, false}, {5101, 5165, 7, false, false}, {5106, 5165, 7, false, false}, {5110, 5165, 7, false, false},
        {5111, 5165, 7, false, false}, {5112, 5165, 7, false, false}, {5117, 5162, 7, false, false}, {5122, 5162, 7, false, false},
        {5123, 5162, 7, false, false}, {5124, 5162, 7, false, false}, {5128, 5162, 7, false, false}, {5128, 5161, 7, false, false},
        {5128, 5160, 7, false, false}, {5133, 5156, 7, false, false}, {5136, 5156, 7, false, false}, {5137, 5156, 7, false, false},
        {5138, 5156, 7, false, false}, {5143, 5154, 7, false, false}, {5148, 5154, 7, false, false}, {5153, 5154, 7, false, false},
        {5154, 5154, 7, false, false}, {5155, 5154, 7, false, false}, {5156, 5154, 7, false, false}, {5160, 5154, 7, false, false},
        {5161, 5154, 7, false, false}, {5162, 5154, 7, false, false}, {5167, 5154, 7, false, false}, {5170, 5159, 7, false, false},
        {5170, 5162, 7, false, false}, {5170, 5163, 7, false, false}, {5170, 5164, 7, false, false}, {5170, 5169, 7, false, false},
        {5165, 5170, 7, false, false}, {5160, 5170, 7, false, false}, {5158, 5173, 7, false, false}, {5158, 5174, 7, false, false},
        {5158, 5175, 7, false, false}, {5158, 5177, 7, false, false}, {5158, 5178, 7, false, false}, {5158, 5179, 7, false, false},
        {5163, 5183, 7, false, false}, {5166, 5183, 7, false, false}, {5166, 5184, 7, false, false}, {5166, 5185, 7, false, false},
        {5166, 5190, 7, false, false}, {5166, 5195, 7, false, false}, {5166, 5200, 7, false, false}, {5163, 5203, 7, false, false},
        {5162, 5203, 7, false, false}, {5161, 5203, 7, false, false}, {5156, 5203, 7, false, false}, {5153, 5203, 7, false, false},
        {5152, 5203, 7, false, false}, {5151, 5203, 7, false, false}, {5150, 5203, 7, false, false}, {5149, 5203, 7, false, false},
        {5148, 5203, 7, false, false}, {5147, 5203, 7, false, false}, {5146, 5208, 7, false, false}, {5144, 5211, 7, false, false},
        {5143, 5211, 7, false, false}, {5142, 5211, 7, false, false}, {5139, 5216, 7, false, false}, {5139, 5221, 7, false, false},
        {5139, 5224, 7, false, false}, {5139, 5225, 7, false, false}, {5139, 5226, 7, false, false}, {5139, 5229, 7, false, false},
    },
}
local criouAngryBird = false
if not cfg.angryBirdPadrao then
    cfg.angryBirdPadrao = true
    if not cfg.perfis["Angry Bird"] then
        cfg.perfis["Angry Bird"] = copiarPerfil(TaskDemon.PERFIL_ANGRY_BIRD)
        criouAngryBird = true
    end
end

cfg.perfilTarefa = cfg.perfilTarefa or {infernal = "Task Demon", goshnar = "Task Mega", dragon = "Task Demon"}
if criouAngryBird and not cfg.perfilTarefa.angrybird then cfg.perfilTarefa.angrybird = "Angry Bird" end
TaskDemon.buracosNaCarga = TaskDemon.semBuracos(cfg, "storage.TaskDemon")

function TaskDemon.nomesPerfis()
    local l = {}
    for nome in pairs(cfg.perfis) do table.insert(l, nome) end
    table.sort(l, function(a, b) return a:lower() < b:lower() end)
    return l
end
function TaskDemon.perfilDaTarefa(k)
    local nome = cfg.perfilTarefa[k]
    if not nome or not cfg.perfis[nome] then nome = TaskDemon.nomesPerfis()[1] end
    return nome
end
TaskDemon.perfilAtivo = TaskDemon.perfilDaTarefa(cfg.tarefa)
TaskDemon.ROTAS = cfg.perfis[TaskDemon.perfilAtivo]

cfg.cb = cfg.cb or {}
cfg.cb.hunt = cfg.cb.hunt or ""
cfg.cb.task, cfg.cb.ativo, cfg.cb.labelHunt = nil, nil, nil

-- agenda padrao dos EVENTOS (todos os dias, label "tasks", DESATIVADOS: a pessoa ativa se quiser). So entra quando o personagem ainda nao
-- tem agenda daquele evento ou no botao Restaurar; o que a pessoa mudar fica salvo e vale.
TaskDemon.AGENDA_EVENTOS_PADRAO = {
    ev_snowball  = {horarios = "14:27", label = "tasks"},
    ev_island    = {horarios = "12:57, 18:57, 22:27", label = "tasks"},
    ev_firestorm = {horarios = "12:27, 18:27, 23:27", label = "tasks"},
    ev_zombie    = {horarios = "13:27, 19:27, 22:57", label = "tasks"},
}
function TaskDemon.agendaPadrao(k)
    local p = k and TaskDemon.AGENDA_EVENTOS_PADRAO[k]
    local h = p and p.horarios or ""
    return {ativo = false, label = p and p.label or "",
            horariosDia = {dom = h, seg = h, ter = h, qua = h, qui = h, sex = h, sab = h}}
end
TaskDemon.EVENTOS = {
    ev_snowball  = {titulo = "Snowball War", curto = "Snowball", pronto = true},
    ev_island    = {titulo = "Island Of Elementals", curto = "Island", pronto = true},
    ev_firestorm = {titulo = "FireStorm", curto = "FireStorm", pronto = true},
    ev_zombie    = {titulo = "Zombie", curto = "Zombie", pronto = true},
}
TaskDemon.ORDEM_EVENTOS = {"ev_snowball", "ev_island", "ev_firestorm", "ev_zombie"}
for _, k in ipairs(TaskDemon.ORDEM_EVENTOS) do
    -- padrao entra 1x: sem agenda, ou agenda VAZIA nunca configurada (criada vazia pelas versoes antigas).
    -- Marca ag.padrao: se a pessoa apagar tudo depois, nao volta sozinho (vale o que a pessoa decidiu).
    local ag = cfg.agenda[k]
    local vazia = not ag or (not ag.ativo and (ag.label or "") == "" and not ag.padrao)
    if vazia and ag and type(ag.horariosDia) == "table" then
        for _, h in pairs(ag.horariosDia) do if tostring(h):match("%S") then vazia = false end end
    end
    if vazia then
        cfg.agenda[k] = TaskDemon.agendaPadrao(k)
        cfg.agenda[k].padrao = true
    end
end
cfg.evLabelFim = cfg.evLabelFim or "inicio"

for _, k in ipairs(TaskDemon.AGENDAVEIS) do
    local ag = cfg.agenda[k] or TaskDemon.agendaPadrao()
    if not ag.horariosDia then

        ag.horariosDia = {}
        for _, d in ipairs(TaskDemon.DIAS) do
            ag.horariosDia[d] = (ag.dias and ag.dias[d] and ag.horarios) or ""
        end
    end
    ag.horarios, ag.dias = nil, nil
    cfg.agenda[k] = ag
end

local TD = TaskDemon
TD.ativo = false
TD.rota = "CAMINHO"
TD.wp = 1
TD.tagueados = {}
TD.pulados = {}
TD.alvo = nil
TD.alvoDesde = 0
TD.ultimoAlvoNovo = os.time()
cfg.principalDesde = cfg.principalDesde or os.time()
TD.passosRota = 0
TD.estado = "DESLIGADO"
TD.evento = "-"
TD.naTela, TD.novosNaTela = 0, 0
TD.ultimaPos = nil
TD.paradoDesdeMs = 0
TD.destinoAtual = nil
TD.desvioAte = 0
TD.numerados = {}
TD.fugindo = false
TD.fugas = 0
TD.manualAte = 0
TD.estavaManual = false
TD.origemAgenda = nil
TD.targetBotEstava = nil

function TD.log(t)
    -- com evento rodando, as mensagens (rota, teleporte...) vao para a aba EVENTOS
    if TD.evRun and not TD.ativo then return TD.logEv(t) end
    TD.evento = os.date("%H:%M:%S") .. " - " .. t
    print("[Task Demon] " .. t)
end
-- versao do codigo: aparece no log ao carregar, pra confirmar que o vBot esta rodando o arquivo novo
-- SUBIR a cada entrega (1.0, 1.1, 1.2 ...): aparece no titulo do painel "TASKS 1.0" e no log ao carregar
TD.VERSAO = "6.3"
TD.log("Task Demon versao " .. TD.VERSAO .. " carregado.")
-- aviso dos perfis: so no terminal do cliente (o usuario nao quer isso no log do painel)
if TaskDemon.avisoPerfis then print("[Task Demon] " .. TaskDemon.avisoPerfis) end
for _, onde in ipairs(TaskDemon.buracosNaCarga or {}) do TD.log("AVISO: tabela que o vBot nao consegue salvar em " .. onde) end

-- rede de seguranca: tapa buracos no storage antes do vBot salvar (o vBot salva sozinho de tempos em tempos)
TD.avisadosBuraco = {}
macro(2000, function()
    local problemas = TaskDemon.semBuracos(cfg, "storage.TaskDemon")
    -- o resto do storage e de outros scripts: nao mexe, so avisa onde esta o que trava o save
    local vistos = {[cfg] = true}
    for k, v in pairs(storage) do
        TaskDemon.semBuracos(v, "storage." .. tostring(k), vistos, problemas, true)
    end
    for _, onde in ipairs(problemas) do
        if not TD.avisadosBuraco[onde] then
            TD.avisadosBuraco[onde] = true
            TD.log("AVISO: o vBot nao consegue salvar " .. onde .. (onde:find("^storage%.TaskDemon") and "" or " (e de OUTRO script, nao do Task Demon)"))
        end
    end
    -- teste definitivo: o mesmo json.encode que o vBot usa pra gravar o storage. Se falhar, o vBot NAO grava
    -- nada (nem o codigo colado no editor): no proximo reload volta o codigo e os dados antigos do disco.
    -- (storage tem ~300KB com o codigo do editor: testa a cada 10s, nao a cada 2s)
    if os.time() < (TD.proxTesteStorage or 0) then return end
    TD.proxTesteStorage = os.time() + 10
    local ok = pcall(json.encode, storage)
    if ok then TD.erroStorage = nil return end
    local culpadas = {}
    for k, v in pairs(storage) do
        local okK, erro = pcall(json.encode, v)
        if not okK then table.insert(culpadas, tostring(k) .. " (" .. tostring(erro):sub(1, 60) .. ")") end
    end
    local msg = "ERRO: o vBot NAO esta salvando o storage. Culpado: " .. (#culpadas > 0 and table.concat(culpadas, ", ") or "?") ..
        ". Codigo colado no editor volta ao antigo no reload!"
    if msg ~= TD.erroStorage or os.time() - (TD.erroStorageMs or 0) > 30 then
        TD.erroStorage, TD.erroStorageMs = msg, os.time()
        TD.log(msg)
    end
end)

-- grava os perfis no arquivo do personagem quando mudarem (confere a cada 5s)
TD.ultimoArquivo = nil
macro(5000, function()
    local arq = TaskDemon.arquivoPerfis()
    if not (arq and g_resources and g_resources.writeFileContents) then return end
    local txt = TaskDemon.textoPerfis()
    if not txt or txt == TD.ultimoArquivo then return end
    if g_resources.makeDir and g_resources.directoryExists and not g_resources.directoryExists("/TaskDemon") then
        pcall(g_resources.makeDir, "/TaskDemon")
    end
    local ok, err = pcall(g_resources.writeFileContents, arq, txt)
    if ok then
        TD.ultimoArquivo = txt
    elseif not TD.avisouErroArquivo then
        TD.avisouErroArquivo = true
        TD.log("ERRO ao salvar perfis em " .. arq .. ": " .. tostring(err))
    end
end)
TD.eventoEv = "-"
function TD.logEv(t)
    TD.eventoEv = os.date("%H:%M:%S") .. " - " .. t
    print("[Eventos] " .. t)
end

function TD.progresso() return cfg.prog[cfg.tarefa] or 0 end
function TD.somar(n) cfg.prog[cfg.tarefa] = TD.progresso() + n end
function TD.zerarTarefa(k)
    k = k or cfg.tarefa
    cfg.progBase[k] = cfg.progServidor[k] or 0
    cfg.prog[k] = 0
end
-- v5.8: virada do dia das tasks (06:15, depois do SS, igual Boss Farm). O servidor zera as tasks no SS, entao
-- zera o progresso que sobrou (ex.: Angry Bird 2/10 de sexta: na segunda matava so 8 e a task nao concluia).
-- 1a vez (sem cfg.progDia) so marca o dia: nao apaga o progresso de hoje de quem acabou de atualizar.
TD.VIRADA_TASKS_MIN = 6 * 60 + 15
-- v5.9: tasks que, ao terminar, voltam pela rota DP (goto mais perto ate o ultimo = dentro do DP)
TD.VOLTA_PELO_DP = {angrybird = true}
function TD.viradaDiaTasks()
    local dia = os.date("%Y-%m-%d", os.time() - TD.VIRADA_TASKS_MIN * 60)
    if cfg.progDia == dia then return end
    local primeiraVez = cfg.progDia == nil
    cfg.progDia = dia
    if primeiraVez then return end
    local pendentes = {}
    for k, v in pairs(cfg.prog) do
        if (tonumber(v) or 0) > 0 then table.insert(pendentes, (TD.TAREFAS[k] and TD.TAREFAS[k].titulo or k) .. " " .. v) end
        cfg.prog[k] = 0
    end
    cfg.progBase, cfg.progServidor = {}, {}
    if TD.log then TD.log("Novo dia (06:15): progresso das tasks zerado" .. (#pendentes > 0 and (" (" .. table.concat(pendentes, ", ") .. ")") or "") .. ".") end
end
TD.viradaDiaTasks()
macro(60000, TD.viradaDiaTasks)
function TD.definir(n)
    if n == 0 then TD.zerarTarefa(cfg.tarefa) return end
    cfg.prog[cfg.tarefa] = n
end
function TD.tarefaAtual() return TD.TAREFAS[cfg.tarefa] or TD.TAREFAS.infernal end

local function agoraMs()
    if type(now) == "number" then return now end
    return os.time() * 1000
end

-- relogio que anda DENTRO de um calculo (o "now" do vBot so muda entre ciclos); nil se nao tiver nenhum
local function relogioMs()
    local ok, v = pcall(function() return g_clock.millis() end)
    if ok and type(v) == "number" then return v end
    ok, v = pcall(function() return os.clock() * 1000 end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function mesmaPos(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function formatarTempo(seg)
    if not seg or seg < 0 then return "--:--" end
    local h = math.floor(seg / 3600)
    local m = math.floor((seg % 3600) / 60)
    local sg = seg % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sg) end
    return string.format("%02d:%02d", m, sg)
end
TD.formatarTempo = formatarTempo

local function dist(a, b)
    if not a or not b or a.z ~= b.z then return 999 end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

TD.PORTAIS = {[24733] = true, [24731] = true, [1949] = true}
TD.LADOS = {N = North or 0, E = East or 1, S = South or 2, W = West or 3}
TD.NOME_LADO = {N = "NORTH", E = "EAST", S = "SOUTH", W = "WEST"}
local function rotaAtual()
    if TD.rota == "VOLTA" then return TD.rotaVolta or {} end
    return TD.ROTAS[TD.rota] or {}
end

local function wpPos(i)
    local w = rotaAtual()[i] or rotaAtual()[1]
    if not w then
        local p = player:getPosition()
        return p and {x = p.x, y = p.y, z = p.z} or {x = 0, y = 0, z = 0}
    end
    return {x = w[1], y = w[2], z = w[3]}
end

TD.textoCache = {}
function TD.protegido(nome, f)
    return function()
        local ok, erro = pcall(f)
        if not ok and os.time() - (TD.ultimoErro or 0) >= 10 then
            TD.ultimoErro = os.time()
            TD.log("Erro em " .. nome .. ": " .. tostring(erro))
        end
    end
end
function TD.ehDaTask(c)
    local ok, nome = pcall(function() return c:getName():lower() end)
    if not ok then return false end
    for _, t in pairs(TD.TAREFAS) do
        if t.nome:lower() == nome then return true end
    end
    return false
end

function TD.marcarTexto(c, texto, cor)
    if not c or not c.setText then return end
    local okI, id = pcall(function() return c:getId() end)
    local chave = okI and id or tostring(c)
    local novo = tostring(texto) .. "|" .. tostring(cor)
    local agoraT = os.time()
    local antigo = TD.textoCache[chave]
    if antigo and antigo.t == novo and agoraT - antigo.quando < 2 then return end
    TD.textoCache[chave] = {t = novo, quando = agoraT}
    pcall(function() c:setText(texto, cor) end)
end
local marcarTexto = TD.marcarTexto

function TD.entrarNaRota(nome)
    local trocou = TD.rota ~= nome
    TD.rotaAnterior = TD.rota
    TD.rota = nome
    local p = player:getPosition()
    local rota, melhor, melhorD = rotaAtual(), 1, 99999
    for i = 1, #rota do
        local d = dist(p, {x = rota[i][1], y = rota[i][2], z = rota[i][3]})
        if d < melhorD then melhor, melhorD = i, d end
    end
    TD.wp = melhor
    TD.paradoDesdeMs = agoraMs()
    TD.destinoAtual = nil
    TD.desvioAte = 0
    if trocou then
        TD.passosRota = 0
        TD.ultimoAlvoNovo = os.time()
    end
end

local TECLAS_ANDAR = {
    Up = true, Down = true, Left = true, Right = true,
    W = true, A = true, S = true, D = true, Q = true, E = true, Z = true, C = true,
    Numpad1 = true, Numpad2 = true, Numpad3 = true, Numpad4 = true,
    Numpad6 = true, Numpad7 = true, Numpad8 = true, Numpad9 = true,
}

local function teclaManual(keys)
    if not TD.ativo and not TD.evRun then return end
    if TECLAS_ANDAR[keys] then
        TD.manualAte = agoraMs() + TD.MS_MANUAL
    end
end
onKeyDown(teclaManual)
onKeyPress(teclaManual)

function TD.emManual() return agoraMs() < TD.manualAte end

local PF_NAO_VISTO, PF_CRIATURAS, PF_NAO_PATHABLE = 1, 2, 4
if Otc then
    PF_NAO_VISTO = Otc.PathFindAllowNotSeenTiles or PF_NAO_VISTO
    PF_CRIATURAS = Otc.PathFindAllowCreatures or PF_CRIATURAS
    PF_NAO_PATHABLE = Otc.PathFindAllowNonPathable or PF_NAO_PATHABLE
end

local function calcularCaminho(de, para, evitarGente, alcance)
    if not de or not para or de.z ~= para.z then return nil end
    if math.max(math.abs(de.x - para.x), math.abs(de.y - para.y)) > (alcance or 30) then return nil end
    if g_map and g_map.findPath then
        local flags = PF_NAO_VISTO + PF_NAO_PATHABLE
        if not evitarGente then flags = flags + PF_CRIATURAS end
        local distancia = math.max(math.abs(de.x - para.x), math.abs(de.y - para.y))
        local complexidade = math.max(10000, math.min(90000, distancia * distancia * 4))
        local ok, dirs, resultado = pcall(function() return g_map.findPath(de, para, complexidade, flags) end)
        if ok then
            if type(dirs) == "table" and #dirs > 0 and (resultado == nil or resultado == 0) then return dirs end
            return nil
        end
    end
    if not findPath then return nil end
    local ok, caminho = pcall(findPath, de, para, alcance or 30, {
        ignoreNonPathable = true, ignoreCreatures = not evitarGente, ignoreFields = true,
        precision = 1, allowUnseen = true, allowOnlyVisibleTiles = false,
    })
    if ok and caminho and #caminho > 0 then return caminho end
    return nil
end

function TD.retomarRota()
    local rota = rotaAtual()
    if not rota or #rota == 0 then return end
    local p = player:getPosition()
    if not p then return end
    if type(TD.wp) ~= "number" or TD.wp < 1 then TD.wp = 1 end
    local melhor, melhorD = TD.wp, 99999
    local ate = math.min(#rota, TD.wp + 8)
    for i = TD.wp, ate do
        local w = rota[i]
        if w then
            local d = dist(p, {x = w[1], y = w[2], z = w[3]})
            if d < melhorD then melhor, melhorD = i, d end
        end
    end
    if melhorD > 15 then
        TD.entrarNaRota(TD.rota)
        return
    end
    local function wpos(i) local w = rota[i] return w and {x = w[1], y = w[2], z = w[3]} end
    while melhor < #rota do
        local atual, prox = wpos(melhor), wpos(melhor + 1)
        if not atual or not prox or prox.z ~= p.z then break end
        if dist(p, prox) <= dist(atual, prox) then
            melhor = melhor + 1
        else
            break
        end
    end
    TD.wp = melhor
    TD.paradoDesdeMs = agoraMs()
    TD.destinoAtual = nil
    TD.desvioAte = 0
end

local function andando()
    return (player.isWalking and player:isWalking()) or (player.isAutoWalking and player:isAutoWalking())
end

local DIAGONAIS = {
    [NorthEast or 4] = {{North or 0, 0, -1}, {East or 1, 1, 0}},
    [SouthEast or 5] = {{South or 2, 0, 1}, {East or 1, 1, 0}},
    [SouthWest or 6] = {{South or 2, 0, 1}, {West or 3, -1, 0}},
    [NorthWest or 7] = {{North or 0, 0, -1}, {West or 3, -1, 0}},
}
local VETOR = {
    [North or 0] = {0, -1}, [East or 1] = {1, 0}, [South or 2] = {0, 1}, [West or 3] = {-1, 0},
    [NorthEast or 4] = {1, -1}, [SouthEast or 5] = {1, 1}, [SouthWest or 6] = {-1, 1}, [NorthWest or 7] = {-1, -1},
}

-- v6.0: escada/buraco = minimapa amarelo (210) + tile nao "pathable" (mesmo teste do vBot/follow). O findPath do
-- painel aceita sqm nao pathable, entao indo atras de bicho as vezes cortava caminho pela escada e subia de andar.
function TD.ehEscada(pos)
    local okC, cor = pcall(function() return g_map.getMinimapColor(pos) end)
    if not okC or cor ~= 210 then return false end
    local tile = g_map.getTile(pos)
    if not tile then return false end
    local okP, pathable = pcall(function() return tile:isPathable() end)
    return okP and pathable == false
end
function TD.caminhoPassaEscada(p, dirs)
    local q = {x = p.x, y = p.y, z = p.z}
    for i = 1, #dirs - 1 do   -- o ultimo sqm (o destino) pode ser escada: goto posto na escada de proposito
        local v = VETOR[dirs[i]]
        if not v then return false end
        q = {x = q.x + v[1], y = q.y + v[2], z = q.z}
        if TD.ehEscada(q) then return true end
    end
    return false
end

function TD.endireitar(p, dirs)
    if not TD.analisarTile or not g_map then return dirs end
    local saida, q = {}, {x = p.x, y = p.y, z = p.z}
    for idx, d in ipairs(dirs) do
        if idx > 25 then
            table.insert(saida, d)
        else
        local opcoes = DIAGONAIS[d]
        local feito = false
        if opcoes then
            for _, o in ipairs(opcoes) do
                local meio = {x = q.x + o[2], y = q.y + o[3], z = q.z}
                if TD.analisarTile(meio).tipo == "livre" then
                    local resto = (o[1] == opcoes[1][1]) and opcoes[2][1] or opcoes[1][1]
                    table.insert(saida, o[1])
                    table.insert(saida, resto)
                    feito = true
                    break
                end
            end
        end
        if not feito then table.insert(saida, d) end
        local v = VETOR[d]
        if v then q = {x = q.x + v[1], y = q.y + v[2], z = q.z} end
        end
    end
    return saida
end

function TD.caminhoReto(de, para)
    if not TD.analisarTile or not g_map then return nil end
    local distancia = math.max(math.abs(para.x - de.x), math.abs(para.y - de.y))
    if distancia == 0 or distancia > math.min(40, cfg.buscaMax or 150) then return nil end
    local dirs, x, y = {}, de.x, de.y
    local mapa = {["0,-1"] = North or 0, ["1,0"] = East or 1, ["0,1"] = South or 2, ["-1,0"] = West or 3,
        ["1,-1"] = NorthEast or 4, ["1,1"] = SouthEast or 5, ["-1,1"] = SouthWest or 6, ["-1,-1"] = NorthWest or 7}
    while x ~= para.x or y ~= para.y do
        local dx = para.x > x and 1 or (para.x < x and -1 or 0)
        local dy = para.y > y and 1 or (para.y < y and -1 or 0)
        local nx, ny = x + dx, y + dy
        local ultimo = nx == para.x and ny == para.y
        local info = TD.analisarTile({x = nx, y = ny, z = de.z})
        if info.tipo ~= "livre" and not (ultimo and (info.tipo == "monstro" or info.tipo == "player")) then
            return nil
        end
        table.insert(dirs, mapa[dx .. "," .. dy])
        x, y = nx, ny
    end
    return dirs
end

function TD.irPara(destino)
    TD.irParaCaminho(destino)
end

function TD.irParaCaminho(destino)
    local p = player:getPosition()
    if not p or not destino then return end
    local t = agoraMs()
    if TD.caminho and TD.proximoBloqueado and TD.proximoBloqueado(p, destino) then
        if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
        TD.caminho, TD.caminhoCalc = nil, 0
    end
    local mudou = not mesmaPos(destino, TD.destinoAtual)
    local precisa = mudou or not TD.caminho
        or (not andando() and t - (TD.caminhoCalc or 0) > 400)
        or t - (TD.caminhoCalc or 0) > 2500
    if not mudou and TD.semCaminhoAte and t < TD.semCaminhoAte then return end
    local mudouPouco = mudou and TD.destinoAtual and destino.z == TD.destinoAtual.z
        and math.max(math.abs(destino.x - TD.destinoAtual.x), math.abs(destino.y - TD.destinoAtual.y)) <= 1
    if mudouPouco and TD.caminho and t - (TD.caminhoCalc or 0) < 400 then precisa = false end
    if precisa and t - (TD.caminhoCalc or 0) >= 150 then
        TD.destinoAtual = destino
        TD.caminhoCalc = t
        TD.caminho = nil
        if destino.z == p.z then
            local busca = cfg.buscaMax or 150
            TD.caminho = TD.caminhoReto(p, destino) or calcularCaminho(p, destino, true, busca) or calcularCaminho(p, destino, false, busca)
        end
        if TD.caminho then TD.caminho = TD.endireitar(p, TD.caminho) end
        -- v6.0: caminho passando por escada no meio: descarta (o autoWalk do client abaixo desvia de escada)
        if TD.caminho and TD.caminhoPassaEscada(p, TD.caminho) then TD.caminho = nil end
        if TD.caminho and TD.caminhoPassaTravado and TD.caminhoPassaTravado(p, TD.caminho) then
            TD.caminho = TD.desvioLateral(p, destino)
        end
        TD.caminhoDe = {x = p.x, y = p.y, z = p.z}
        TD.caminhoIdx = 1
        TD.caminhoAuto = false
        if not TD.caminho then
            TD.semCaminhoAte = t + 500
            if player.autoWalk then pcall(function() player:autoWalk(destino) end) end
            return
        end
        TD.semCaminhoAte = nil
        if g_game.autoWalk then
            local ok = pcall(function() g_game.autoWalk(TD.caminho, p) end)
            TD.caminhoAuto = ok
        end
    end
    if TD.caminhoAuto or not TD.caminho then return end
    if player.isWalking and player:isWalking() then return end
    local dir = TD.caminho[TD.caminhoIdx]
    if dir ~= nil then
        TD.caminhoIdx = TD.caminhoIdx + 1
        TD.passoProprioAte = t + 600
        g_game.walk(dir)
    else
        TD.caminho = nil
    end
end

function TD.proximoWp()
    TD.wp = TD.wp + 1
    TD.passosRota = TD.passosRota + 1
    local rota = rotaAtual()

    if TD.rota == "DP" then
        if TD.wp > #rota then
            TD.fugindo = false
            TD.log("Passou pelo DP. Voltando pelo CAMINHO.")
            TD.escolherRotaInicial()
        end
        return
    end

    if TD.rota == "CAMINHO" and TD.wp > #rota then
        -- Island/Zombie/FireStorm/Snowball: o CAMINHO so termina entrando no TP (quem troca de fase e a deteccao da
        -- sala/arena). Se foi empurrado ou o passo pro TP nao pegou, repete o ultimo goto em vez de ir pra PRINCIPAL.
        local tipoEv = TD.evRun and TD.evRun.rota and TD.evRun.tipo
        if (tipoEv == "island" or tipoEv == "zombie" or tipoEv == "firestorm" or tipoEv == "snowball") and #rota > 0 then
            TD.wp = #rota
            if not TD.evRun.avisouRepetir then
                TD.evRun.avisouRepetir = true
                TD.logEv("Ainda nao entrou no TP: repetindo o ultimo goto do CAMINHO ate entrar.")
            end
            return
        end
        if #(TD.ROTAS.PRINCIPAL or {}) == 0 then
            TD.log("CAMINHO concluido, mas a PRINCIPAL esta vazia. Parado aqui.")
            TD.rota = "PRINCIPAL"
            TD.wp = 1
            return
        end
        TD.log("CAMINHO concluido. Rodando a rota PRINCIPAL.")
        TD.entrarNaRota("PRINCIPAL")
        TD.wp = 1
        return
    end

    if TD.rota == "VOLTA" and TD.wp > #rota then
        TD.wp = #rota + 1
        TD.voltaFeita = true
        return
    end

    if TD.wp > #rota then TD.wp = 1 end
    if #rota == 0 then TD.wp = 1 end
end

function TD.pertoDaRota(nome, raio)
    local rota = TD.ROTAS and TD.ROTAS[nome]
    local p = player:getPosition()
    if not rota or not p then return false end
    for _, w in ipairs(rota) do
        if w[3] == p.z and math.max(math.abs(w[1] - p.x), math.abs(w[2] - p.y)) <= raio then return true end
    end
    return false
end

function TD.escolherRotaInicial()
    TD.rota = ""
    -- Evento com TP (Island/Zombie/FireStorm/Snowball): sempre comeca pelo CAMINHO, mesmo parado na frente do TP.
    -- Antes, se algum goto da PRINCIPAL ficava a 12 sqm, ia direto pra PRINCIPAL sem ter entrado no TP.
    -- Quem passa pra dentro e a deteccao da sala/arena.
    local tipoEv = TD.evRun and TD.evRun.rota and TD.evRun.tipo
    local eventoTp = tipoEv == "island" or tipoEv == "zombie" or tipoEv == "firestorm" or tipoEv == "snowball"
    if eventoTp and #(TD.ROTAS.CAMINHO or {}) > 0 then
        TD.entrarNaRota("CAMINHO")
        return
    end
    if #(TD.ROTAS.PRINCIPAL or {}) > 0 and (TD.pertoDaRota("PRINCIPAL", 12) or #(TD.ROTAS.CAMINHO or {}) == 0) then
        TD.entrarNaRota("PRINCIPAL")
    else
        TD.entrarNaRota("CAMINHO")
    end
end

function TD.gotoExato(i)
    local rota = rotaAtual()
    local w = rota[i]
    if not w then return false end
    local tile = g_map and g_map.getTile({x = w[1], y = w[2], z = w[3]})
    if tile then
        local ok, itens = pcall(function() return tile:getItems() end)
        if ok and itens then
            for _, it in ipairs(itens) do
                if TD.PORTAIS[it:getId()] then return true end
            end
        end
    end
    local prox = rota[i + 1]
    if prox and (prox[3] ~= w[3] or math.max(math.abs(prox[1] - w[1]), math.abs(prox[2] - w[2])) > 20) then return true end
    return false
end

local DIR_DELTA = {
    ["0,-1"] = North or 0, ["1,0"] = East or 1, ["0,1"] = South or 2, ["-1,0"] = West or 3,
    ["1,-1"] = NorthEast or 4, ["1,1"] = SouthEast or 5, ["-1,1"] = SouthWest or 6, ["-1,-1"] = NorthWest or 7,
}

-- TP de entrada dos eventos: so aparece quando o evento abre
TD.TP_EVENTO = {x = 32350, y = 32230, z = 7}
-- entrada dos EVENTOS (todos usam o mesmo TP): 3 gotos, o ultimo pisa pro SUL em cima do TP.
-- Saiu do lugar / foi empurrado / TP fechado: repete o ultimo goto ate entrar (TD.proximoWp).
TD.EVENTO_ESPERA_TP_MIN = 8   -- comecou o evento e nao entrou no TP nesse tempo = TP fechou: encerra e volta
-- v4.5 (rota do usuario): pisa no TP (goto 4), se nao entrou da a volta pelo leste e pisa de novo (goto 12);
-- do goto 12 em diante o "forcar" (eventoRota) fica pisando no TP ate entrar.
TD.ENTRADA_EVENTO = {
    {32346, 32227, 7, false, false},
    {32348, 32228, 7, false, false},
    {32350, 32229, 7, false, false},
    {32350, 32229, 7, false, "S"},
    {32369, 32235, 7, false, false},
    {32369, 32230, 7, false, false},
    {32364, 32228, 7, false, false},
    {32355, 32228, 7, false, false},
    {32351, 32228, 7, false, false},
    {32350, 32228, 7, false, false},
    {32350, 32229, 7, false, false},
    {32350, 32229, 7, false, "S"},
}
-- v5.5: escada do lado do TP leva pro andar 8 (area abaixo). Caiu ali: vai pro pe da escada e sobe pro NORTH.
TD.BURACO_EVENTO = {x1 = 32343, x2 = 32352, y1 = 32226, y2 = 32240, z = 8}
TD.SUBIDA_BURACO_EVENTO = {x = 32347, y = 32232, z = 8}
-- v5.5: pisar no sqm do TP SEM portal joga o char aqui (corredor a leste). E o "vai e volta" da entrada.
TD.VOLTA_TP_EVENTO = {x1 = 32365, x2 = 32374, y1 = 32228, y2 = 32243, z = 7}
function TD.naVoltaTpEvento(p)
    local b = TD.VOLTA_TP_EVENTO
    return p and p.z == b.z and p.x >= b.x1 and p.x <= b.x2 and p.y >= b.y1 and p.y <= b.y2
end
function TD.noBuracoEvento(p)
    local b = TD.BURACO_EVENTO
    return p and p.z == b.z and p.x >= b.x1 and p.x <= b.x2 and p.y >= b.y1 and p.y <= b.y2
end
-- v5.5: 10s sem pisar no sqm do TP do evento, com ou sem portal (preso na multidao, caiu na escada, empurrado...): "!tp thais"
-- (cai perto do TP) e a rota segue de onde cair. Repete a cada 10s. Entrou no TP (ev.dentro) = para.
TD.TP_THAIS_SEG = 10

function TD.portalEventoAberto()
    local tile = g_map and g_map.getTile(TD.TP_EVENTO)
    if not tile then return false end
    local ok, itens = pcall(function() return tile:getItems() end)
    for _, it in ipairs(ok and itens or {}) do
        if it:getId() == 1949 then return true end
    end
    return false
end

function TD.esperandoTpEvento(w, lado)
    local tp = TD.TP_EVENTO
    local alvo = {x = w[1], y = w[2], z = w[3]}
    local v = lado ~= nil and VETOR[lado]
    if v then alvo = {x = alvo.x + v[1], y = alvo.y + v[2], z = alvo.z} end
    if not mesmaPos(alvo, tp) or dist(player:getPosition(), tp) > 1 then return false end
    local tile = g_map and g_map.getTile(tp)
    local ok, itens = pcall(function() return tile:getItems() end)
    for _, it in ipairs(ok and itens or {}) do
        if it:getId() == 1949 then return false end
    end
    return true
end

function TD.andarRota()
    local p = player:getPosition()
    if not p then return end
    local rotaA = rotaAtual()
    if #rotaA == 0 then
        TD.estado = TD.semRota and "SEM ROTA (ANDANDO NA MAO)" or ("SEM GOTOS NA ROTA " .. tostring(TD.rota))
        return
    end
    local t = agoraMs()

    if TD.emManual() then
        TD.estavaManual = true
        TD.ultimaPos = p
        TD.paradoDesdeMs = t
        TD.destinoAtual = nil
        return
    end

    if TD.estavaManual then
        TD.estavaManual = false
        TD.retomarRota()
        TD.log("Retomando a rota " .. TD.rota .. ".")
    end

    if TD.ultimaPosRota and (TD.ultimaPosRota.z ~= p.z or math.max(math.abs(TD.ultimaPosRota.x - p.x), math.abs(TD.ultimaPosRota.y - p.y)) > 4) then
        TD.ultimaPosRota = p
        TD.esperaAte, TD.esperaWp = nil, nil
        TD.caminho = nil
        TD.destinoAtual = nil
        local antes = TD.wp
        TD.wp = math.min(TD.wp + 1, #rotaA)
        TD.retomarRota()
        TD.paradoDesdeMs = t
        TD.log("Teleporte/escada: goto " .. antes .. " -> " .. TD.wp .. ".")
        return
    end
    TD.ultimaPosRota = p

    local wAtual = rotaA[TD.wp]
    if not wAtual then return end
    local espera = tonumber(wAtual[4]) or math.floor((cfg.delayGoto or 0) * 1000)
    local lado = TD.LADOS[wAtual[5] or ""]
    local exato = TD.gotoExato(TD.wp) or lado ~= nil

    -- (removido: esperar o TP do evento abrir. O lado marcado no goto e sempre obedecido.)

    if TD.esperaAte and TD.esperaWp == TD.wp then
        if t < TD.esperaAte then
            TD.estado = "WAIT " .. math.ceil((TD.esperaAte - t) / 100) / 10 .. "s"
            TD.paradoDesdeMs = t
            return
        end
        TD.esperaAte, TD.esperaWp = nil, nil
        TD.ladoFeito = nil
        TD.proximoWp()
        TD.destinoAtual = nil
        TD.caminho = nil
        TD.paradoDesdeMs = t
        return
    end

    local alvoW = {x = wAtual[1], y = wAtual[2], z = wAtual[3]}
    local d = dist(p, alvoW)

    if exato and d == 1 then
        if t >= (TD.passoExatoAte or 0) then
            local dir = DIR_DELTA[(alvoW.x - p.x) .. "," .. (alvoW.y - p.y)]
            if dir ~= nil then
                TD.passoExatoAte = t + 500
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                TD.caminho = nil
                TD.passoProprioAte = t + 600
                g_game.walk(dir)
            end
        end
        TD.paradoDesdeMs = t
        return
    end

    local ocupado = false
    if not exato and d > 0 and d <= 4 and TD.analisarTile and g_map then
        local info = TD.analisarTile(alvoW)
        ocupado = info.tipo == "player" or info.tipo == "monstro" or info.tipo == "npc" or info.tipo == "barreira"
        if not ocupado and t >= (TD.proxChecaOcupado or 0) then
            TD.proxChecaOcupado = t + 300
            local livre = calcularCaminho(p, alvoW, true, 12)
            if not livre and calcularCaminho(p, alvoW, false, 12) then ocupado = true end
        end
    end

    local chegou = exato and d == 0 or (not exato and d <= TD.CHEGOU)
    if chegou or ocupado then
        if lado ~= nil and d == 0 and TD.ladoFeito ~= TD.wp then
            TD.ladoFeito = TD.wp
            TD.passoProprioAte = t + 600
            if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            TD.caminho = nil
            g_game.walk(lado)
            TD.esperaAte = t + math.max(espera, 600)
            TD.esperaWp = TD.wp
            TD.paradoDesdeMs = t
            return
        end
        if espera > 0 then
            TD.esperaAte = t + espera
            TD.esperaWp = TD.wp
            if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            TD.caminho = nil
            TD.paradoDesdeMs = t
            return
        end
        if ocupado and not chegou then TD.log("Goto " .. TD.wp .. " ocupado. Seguindo sem forcar.") end
        TD.ladoFeito = nil
        TD.proximoWp()
        TD.destinoAtual = nil
        TD.caminho = nil
        TD.paradoDesdeMs = t
        return
    end

    if TD.ultimaPos and mesmaPos(p, TD.ultimaPos) then
        local parado = t - TD.paradoDesdeMs
        if parado >= TD.MS_PRESO and not TD.gotoExato(TD.wp) then
            TD.log("Bloqueado no goto " .. TD.wp .. ". Indo para o proximo.")
            TD.proximoWp()
            TD.paradoDesdeMs = t
            TD.destinoAtual = nil
            TD.desvioAte = 0
        elseif parado >= TD.MS_DESVIO and t >= TD.desvioAte then
            TD.desvioAte = t + 2000
            TD.marcarTravado(p)
            TD.caminho = nil
        end
    else
        TD.paradoDesdeMs = t
    end
    TD.ultimaPos = p

    if (TD.ativo or TD.evRun) and TD.rota ~= "" then TD.irPara(wpPos(TD.wp)) end
end

function TD.listarAlvos()
    local nome = TD.tarefaAtual().nome:lower()
    local p = player:getPosition()
    local agora = os.time()
    local lista, total = {}, 0
    -- "Matar 100%": finaliza QUALQUER bicho da task, com a vida que estiver (ignora a marca ATINGIDO, que e do
    -- modo 1 hit / 50%). Antes um bicho ja machucado/marcado ficava fora da lista e ele nao batia.
    local matar100 = TD.cfgTarget().modo == "100"
    for _, spec in ipairs(getSpectators()) do
        if spec:isMonster() and spec:getName():lower() == nome then
            local sp = spec:getPosition()
            local d = dist(p, sp)
            local naTela = sp and sp.z == p.z and math.abs(sp.x - p.x) <= TD.RAIO_X and math.abs(sp.y - p.y) <= TD.RAIO_Y
            if (spec:getHealthPercent() or 100) > 0 and naTela then
                total = total + 1
                local id = spec:getId()
                local pulado = TD.pulados[id] and TD.pulados[id] > agora
                if (matar100 or not TD.tagueados[id]) and not pulado then
                    table.insert(lista, {c = spec, d = d})
                end
            end
        end
    end
    table.sort(lista, function(a, b) return a.d < b.d end)
    TD.naTela, TD.novosNaTela = total, #lista
    return lista
end

function TD.bichoDaTaskMaisPerto(raio)
    local nome = TD.tarefaAtual().nome:lower()
    local p = player:getPosition()
    local melhor, melhorD = nil, 99
    for _, spec in ipairs(getSpectators()) do
        local okM, ehM = pcall(function() return spec:isMonster() end)
        if okM and ehM and spec:getName():lower() == nome and (spec:getHealthPercent() or 0) > 0 then
            local sp = spec:getPosition()
            if sp and sp.z == p.z then
                local d = dist(p, sp)
                if d <= raio and d < melhorD then melhor, melhorD = spec, d end
            end
        end
    end
    return melhor
end

function TD.planejarSequencia(lista)
    local restantes, ordem = {}, {}
    local ponto = player:getPosition()
    for _, item in ipairs(lista) do
        if TD.alvo and item.c:getId() == TD.alvo:getId() then
            table.insert(ordem, item)
            ponto = item.c:getPosition()
        else
            table.insert(restantes, item)
        end
    end
    while #restantes > 0 do
        local melhor, melhorD = 1, 99999
        for i, item in ipairs(restantes) do
            local d = dist(ponto, item.c:getPosition())
            if d < melhorD then melhor, melhorD = i, d end
        end
        local escolhido = table.remove(restantes, melhor)
        table.insert(ordem, escolhido)
        ponto = escolhido.c:getPosition()
    end
    return ordem
end

function TD.alcanceAtual()
    return TaskDemon.modoDe() == "MELEE" and 1 or cfg.alcance
end

cfg.target = cfg.target or {}
function TD.cfgTarget(k)
    k = k or cfg.tarefa
    cfg.target[k] = cfg.target[k] or {modo = "1", semMagia = true}
    local tc = cfg.target[k]
    if tc.modo ~= "100" and tc.modo ~= "50" and tc.modo ~= "1" then tc.modo = "1" end
    local escolhido = nil
    for _, ch in ipairs({"semMagia", "exoriCon", "exoriSan", "exoriHur", "exoriMas", "exevoMasSan", "gfb", "avalanche", "sd"}) do
        if tc[ch] and not escolhido then escolhido = ch else tc[ch] = false end
    end
    tc[escolhido or "semMagia"] = true
    return tc
end

function TD.confirmarHit(c, origem)
    if not c then return end
    local id = c:getId()
    if TD.tagueados[id] then return end
    local modoT = TD.cfgTarget().modo
    local umHit = modoT == "1"
    if not umHit and not (TD.focoTrap and TD.alvo == c) and origem ~= "vida" then return end
    TD.tagueados[id] = {nome = c:getName(), hora = os.time()}
    TD.marcarTexto(c, "ATINGIDO", "#55FF55")
    if TD.focoTrap and TD.alvo == c then return end
    TD.alvo = nil
    TD.saiuDaRota = true
    TD.log("Hit confirmado (" .. origem .. "). Proximo!")
    TD.irProProximo()
end

function TD.semSaidaMsg()
    local t = agoraMs()
    if t - (TD.ultimoSemSaida or 0) < 400 then return end
    TD.ultimoSemSaida = t
    TD.caminho = nil
    TD.destinoAtual, TD.destinoCliente = nil, nil
    TD.semCaminhoAte = t + 1500
    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
    local p = player:getPosition()
    if TD.alvo and p then
        local okA, ap = pcall(function() return TD.alvo:getPosition() end)
        if okA and ap and dist(p, ap) > TD.alcanceAtual() then
            TD.pularAlvo(TD.alvo, "sem caminho ate o bicho")
            return
        end
    end
    if not TD.alvo and not TD.gotoExato(TD.wp) and #(rotaAtual() or {}) > 1 then
        TD.log("Sem caminho ate o goto " .. TD.wp .. ". Indo para o proximo.")
        TD.proximoWp()
    end
end

TD.vezesPulado = {}
function TD.pularAlvo(c, motivo)
    if not c then return end
    local okI, id = pcall(function() return c:getId() end)
    if not okI then return end
    TD.pulados[id] = os.time() + 3
    pcall(function() c:setText("", "#FFFFFF") end)
    if TD.alvo == c then
        TD.alvo = nil
        TD.tentativasAtaque = 0
        if g_game.cancelAttack then g_game.cancelAttack() end
        TD.saiuDaRota = true
    end
    TD.log("Sem alcance no alvo (" .. (motivo or "?") .. "). Indo no mais perto.")
    TD.irProProximo()
end

function TD.irProProximo()
    if not TD.ativo or TD.alvo then return end
    local agora = os.time()
    local matar100 = TD.cfgTarget().modo == "100"
    for _, c in ipairs(TD.numerados or {}) do
        local okI, id = pcall(function() return c:getId() end)
        local okH, hp = pcall(function() return c:getHealthPercent() end)
        local pulado = okI and TD.pulados[id] and TD.pulados[id] > agora
        if okI and okH and (hp or 0) > 0 and (matar100 or not TD.tagueados[id]) and not pulado then
            TD.alvo = c
            TD.alvoDesde = agora
            TD.alvoHpInicial = hp or 100
            TD.alvoHpId = nil
            TD.ultimoAtaque = agoraMs()
            TD.tentativasId, TD.tentativasAtaque = id, 0
            g_game.attack(c)
            if TD.tentarMagia then pcall(TD.tentarMagia) end
            return
        end
    end
end

function TD.fugirPK(atacante)
    if TD.marcarInimigo then TD.marcarInimigo(atacante) end
    if TD.entrarEmPerigo then TD.entrarEmPerigo() end
    if not cfg.pkAtivo then
        TD.log("Atacado por PK (" .. atacante .. "), mas a protecao esta desligada.")
        return
    end
    TD.fugas = TD.fugas + 1
    TD.alvo = nil
    if g_game.cancelAttack then g_game.cancelAttack() end
    if TD.fugindo then
        TD.log("Atacado de novo por " .. atacante .. ". Seguindo pelo DP.")
        return
    end
    TD.fugindo = true
    TD.entrarNaRota("DP")
    TD.log("Atacado por PK (" .. atacante .. ")! Fugindo pelo DP.")
end

cfg.pkHunt = cfg.pkHunt or {}
cfg.pkHunt.ativo = (cfg.pkHunt.ativo == true)
cfg.pkHunt.labelFuga = cfg.pkHunt.labelFuga or ""
cfg.pkHunt.labelVolta = cfg.pkHunt.labelVolta or ""
cfg.pkHunt.tempo = cfg.pkHunt.tempo or "10s"
TD.pkFase = nil
TD.pkDesde = 0

function TD.lerTempo(txt)
    txt = tostring(txt or ""):lower():gsub("%s+", "")
    local m, sg = txt:match("^(%d+):(%d%d)$")
    if m then return tonumber(m) * 60 + tonumber(sg) end
    local n, un = txt:match("^(%d+)(%a*)$")
    n = tonumber(n)
    if not n then return nil end
    if un == "" or un == "s" or un == "seg" then return n end
    if un == "m" or un == "min" then return n * 60 end
    if un == "h" then return n * 3600 end
    return nil
end

local function emPz()
    if isInPz then
        local ok, r = pcall(isInPz)
        if ok and r then return true end
    end
    local okS, estados = pcall(function() return player:getStates() end)
    if okS and type(estados) == "number" then
        local pzBit = (PlayerStates and PlayerStates.Pz) or 16384
        if math.floor(estados / pzBit) % 2 == 1 then return true end
    end
    if player.hasState and PlayerStates and PlayerStates.Pz then
        local okH, r = pcall(function() return player:hasState(PlayerStates.Pz) end)
        if okH and r then return true end
    end
    local alvo = cfg.fuga and cfg.fuga.pz
    local p = player:getPosition()
    if alvo and p and p.z == alvo.z and math.max(math.abs(p.x - alvo.x), math.abs(p.y - alvo.y)) <= 1 then
        return true
    end
    return false
end
TD.emPz = emPz

function TD.pkHuntAtacado(atacante)
    if TD.evRun then return end
    if storage.BossAntiTrapTPEnabled and not TD.ativo then return end
    if TD.marcarInimigo then TD.marcarInimigo(atacante) end
    if TD.entrarEmPerigo then TD.entrarEmPerigo() end
    if not cfg.pkHunt.ativo or TD.pkFase then return end
    if not TD.ativo and not (CaveBot and CaveBot.isOn and CaveBot.isOn()) then return end
    if cfg.pkHunt.labelFuga == "" then
        TD.log("PK na hunt: configure a label de fuga na aba PK.")
        return
    end
    TD.fugas = TD.fugas + 1
    TD.pkFase = "FUGINDO"
    TD.fugindoDesde = os.time()
    TD.corridaReenviada = false
    TD.iniciarCorrida()
    TD.log("PK na hunt (" .. atacante .. ")! Indo para '" .. cfg.pkHunt.labelFuga .. "'.")
end

function TD.iniciarCorrida()
    if TargetBot and TargetBot.isOn then
        if TD.tbAntesFuga == nil then TD.tbAntesFuga = TargetBot.isOn() end
        if TargetBot.isOn() then TargetBot.setOff() end
    end
    if g_game.cancelAttack then g_game.cancelAttack() end
    if g_game.cancelFollow then g_game.cancelFollow() end
    if CaveBot and CaveBot.setOn then CaveBot.setOn() end
    local ok = CaveBot.gotoLabel(cfg.pkHunt.labelFuga)
    if ok == false then
        TD.log("ERRO: a label '" .. cfg.pkHunt.labelFuga .. "' nao existe no CaveBot carregado.")
    end
    TD.corridaPos = player:getPosition()
    TD.corridaParadoDesde = os.time()
end

function TD.devolverTargetBot()
    if TD.tbAntesFuga and TargetBot and TargetBot.setOn then TargetBot.setOn() end
    TD.tbAntesFuga = nil
end

macro(50, function()
    if not TD.pkFase or TD.ativo then return end
    if TD.pkFase == "FUGINDO" then
        if emPz() then
            TD.pkFase = "NO PZ"
            TD.pkDesde = os.time()
            if CaveBot and CaveBot.setOff then CaveBot.setOff() end
            TD.log("No PZ. Esperando " .. cfg.pkHunt.tempo .. ".")
            return
        end
        if TargetBot and TargetBot.isOn and TargetBot.isOn() then
            TargetBot.setOff()
        end
        if not TD.focoMonstro and g_game.getAttackingCreature() and g_game.cancelAttack then
            g_game.cancelAttack()
        end
        local p = player:getPosition()
        if p and TD.corridaPos and p.x == TD.corridaPos.x and p.y == TD.corridaPos.y and p.z == TD.corridaPos.z then
            local parado = os.time() - (TD.corridaParadoDesde or os.time())
            local livre = TD.statusFuga ~= "TRAPADO" and not TD.bicoAte
            if parado >= 3 and livre then
                CaveBot.gotoLabel(cfg.pkHunt.labelFuga)
                TD.corridaParadoDesde = os.time()
            end
        else
            TD.corridaPos = p
            TD.corridaParadoDesde = os.time()
        end
        if os.time() - (TD.fugindoDesde or os.time()) > 180 then
            TD.pkFase = nil
            TD.inimigos = {}
            TD.perigoAte = 0
            TD.devolverTargetBot()
            TD.log("Nao chegou no PZ em 3 min. Fuga cancelada (salve o PZ na aba PK).")
            return
        end
    elseif TD.pkFase == "NO PZ" then
        if CaveBot and CaveBot.isOn and CaveBot.isOn() then CaveBot.setOff() end
        if not emPz() then
            TD.foraPzDesde = TD.foraPzDesde or os.time()
            if os.time() - TD.foraPzDesde >= 2 then
                TD.foraPzDesde = nil
                TD.pkFase = "FUGINDO"
                TD.log("Saiu do PZ antes do tempo. Voltando para o PZ.")
                TD.iniciarCorrida()
            end
            return
        end
        TD.foraPzDesde = nil
        local espera = TD.lerTempo(cfg.pkHunt.tempo) or 10
        if os.time() - TD.pkDesde >= espera then
            TD.pkFase = nil
            TD.inimigos = {}
            TD.perigoAte = 0
            TD.devolverTargetBot()
            if CaveBot and CaveBot.setOn then CaveBot.setOn() end
            if cfg.pkHunt.labelVolta ~= "" then CaveBot.gotoLabel(cfg.pkHunt.labelVolta) end
            TD.log("Tempo no PZ acabou. Voltando" ..
                (cfg.pkHunt.labelVolta ~= "" and (" para '" .. cfg.pkHunt.labelVolta .. "'.") or "."))
        end
    end
end)

TD.SKULLS_PK = {[4] = true, [5] = true}

function TD.pkNaTela()
    for _, spec in ipairs(getSpectators()) do
        if spec:isPlayer() and spec ~= player then
            local escudo = spec.getShield and spec:getShield() or 0
            if escudo < 3 then
                local okS, sk = pcall(function() return spec:getSkull() end)
                if (okS and TD.SKULLS_PK[sk]) or (TD.ehInimigo and TD.ehInimigo(spec)) then return spec end
            end
        end
    end
    return nil
end

macro(50, function()
    if TD.pkFase or not cfg.pkHunt.ativo or not cfg.fuga or cfg.fuga.skull == false then return end
    if emPz() then return end
    for _, spec in ipairs(getSpectators()) do
        if spec:isPlayer() and spec ~= player then
            local okS, sk = pcall(function() return spec:getSkull() end)
            local escudo = spec.getShield and spec:getShield() or 0
            if okS and TD.SKULLS_PK[sk] and escudo < 3 then
                if TD.ativo then
                    if cfg.pkAtivo and not TD.fugindo then TD.fugirPK(spec:getName()) end
                else
                    TD.pkHuntAtacado(spec:getName())
                end
                return
            end
        end
    end
end)

cfg.fuga = cfg.fuga or {}
if not cfg.fuga.skullV2 then
    cfg.fuga.skull = false
    cfg.fuga.skullV2 = true
end
if cfg.fuga.bicar == nil then cfg.fuga.bicar = true end
if cfg.fuga.mw == nil then cfg.fuga.mw = true end
cfg.fuga.empurrado = nil
if cfg.fuga.escudoAtivo == nil then cfg.fuga.escudoAtivo = (cfg.fuga.escudo or 2) > 0 end
cfg.fuga.escudoSqm = cfg.fuga.escudoSqm or ((cfg.fuga.escudo and cfg.fuga.escudo > 0) and cfg.fuga.escudo or 2)
cfg.fuga.escudoQtd = cfg.fuga.escudoQtd or 1
cfg.fuga.escudoCor = nil
cfg.fuga.escudo = nil
cfg.fuga.runaMW = cfg.fuga.runaMW or 3180
cfg.fuga.runaVip = cfg.fuga.runaVip or 0

TD.BARREIRAS = {
    [2129] = {nome = "MW", tempo = 19.9},
    [7925] = {nome = "MW VIP", tempo = 19.9},
    [2130] = {nome = "GRAV", tempo = 45},
}
TD.barreirasVistas = {}
-- v5.6: sqm que recusou o passo ("Sorry, not possible": MW que o client nao reconhece, etc). Vira barreira por
-- TD.TRAVADO_SEG e o caminho desvia dele (antes o desvio recalculava o MESMO caminho e empurrava de novo).
TD.travados = {}
TD.TRAVADO_SEG = 20        -- sqm vazio que recusou o passo (MW, parede invisivel...): MW dura ~20s
TD.TRAVADO_GENTE_SEG = 3   -- player/bicho parado no caminho: desvia, mas logo pode passar de novo (eles andam)
TD.inimigos = {}
TD.ultimoBico = 0
TD.ultimaMW = 0
TD.statusFuga = "Livre"
TD.bicoAte = nil

local DELTAS = {
    {0, -1, North or 0}, {1, 0, East or 1}, {0, 1, South or 2}, {-1, 0, West or 3},
    {1, -1, NorthEast or 4}, {1, 1, SouthEast or 5}, {-1, 1, SouthWest or 6}, {-1, -1, NorthWest or 7},
}

local function deltaDe(dir)
    for _, d in ipairs(DELTAS) do if d[3] == dir then return d[1], d[2] end end
    return 0, 0
end

local function posMais(p, dx, dy) return {x = p.x + dx, y = p.y + dy, z = p.z} end
local function chavePos(p) return p.x .. "," .. p.y .. "," .. p.z end

function TD.marcarInimigo(nome)
    local n = TD.nomeLimpo(nome)
    if n ~= "" then TD.inimigos[n] = os.time() end
end

function TD.ehInimigo(c)
    local t = TD.inimigos[TD.nomeLimpo(c:getName())]
    return t and os.time() - t < 20
end

function TD.contarItem(id)
    if not id or id == 0 then return 0 end
    local total = 0
    for _, container in pairs(getContainers()) do
        for _, it in ipairs(container:getItems()) do
            if it:getId() == id then total = total + it:getCount() end
        end
    end
    return total
end

TD.cacheTiles = nil

-- v5.6: chave numerica no cache (a de texto criava milhares de strings por decisao do zombie = travadinha)
local function chaveNum(p) return (p.z * 100000 + p.x) * 100000 + p.y end

function TD.analisarTile(pos)
    local cache = TD.cacheTiles
    if cache then
        local k = chaveNum(pos)
        local r = cache[k]
        if r then return r end
        r = TD.analisarTileReal(pos)
        cache[k] = r
        return r
    end
    return TD.analisarTileReal(pos)
end

function TD.analisarTileReal(pos)
    local trav = TD.travados[chavePos(pos)]
    if trav and trav > os.time() then return {tipo = "barreira", nome = "travado", resta = trav - os.time()} end
    local tile = g_map.getTile(pos)
    if not tile then return {tipo = "parede", desconhecido = true} end
    for _, it in ipairs(tile:getItems() or {}) do
        local b = TD.BARREIRAS[it:getId()]
        if b then
            local k = chavePos(pos)
            TD.barreirasVistas[k] = TD.barreirasVistas[k] or os.time()
            return {tipo = "barreira", nome = b.nome, resta = math.max(0, b.tempo - (os.time() - TD.barreirasVistas[k]))}
        end
    end
    for _, c in ipairs(tile:getCreatures() or {}) do
        if c ~= player then
            local okP, ehP = pcall(function() return c:isPlayer() end)
            if okP and ehP then return {tipo = "player", criatura = c} end
            local okM, ehM = pcall(function() return c:isMonster() end)
            if okM and ehM then return {tipo = "monstro", criatura = c} end
            return {tipo = "npc", criatura = c}
        end
    end
    local ok, andavel = pcall(function() return tile:isWalkable(true) end)
    if ok and andavel == false then return {tipo = "parede"} end
    return {tipo = "livre"}
end

macro(1000, function()
    local agora = os.time()
    for k, t in pairs(TD.barreirasVistas) do
        if agora - t > 60 then TD.barreirasVistas[k] = nil end
    end
    for k, t in pairs(TD.travados) do
        if t <= agora then TD.travados[k] = nil end
    end
end)

-- proximo sqm do caminho atual a partir de p (o que ele esta tentando pisar)
function TD.proximoSqmCaminho(p)
    local q = TD.caminhoDe
    if not TD.caminho or not q or q.z ~= p.z then return nil end
    for _, d in ipairs(TD.caminho) do
        local v = VETOR[d]
        if not v then return nil end
        local n = {x = q.x + v[1], y = q.y + v[2], z = q.z}
        if q.x == p.x and q.y == p.y then return n end
        q = n
    end
    return nil
end

-- parado tentando andar: marca o sqm da frente como travado. MW/vazio = 20s; player/bicho = 3s (ele anda).
function TD.marcarTravado(p)
    local n = TD.proximoSqmCaminho(p)
    if n then TD.travarSqm(n) end
end

function TD.travarSqm(n)
    local k = chavePos(n)
    if TD.travados[k] then return end
    local info = TD.analisarTileReal(n)
    local gente = info.tipo == "player" or info.tipo == "monstro" or info.tipo == "npc"
    local seg = gente and TD.TRAVADO_GENTE_SEG or TD.TRAVADO_SEG
    TD.travados[k] = os.time() + seg
    local quem = gente and ((info.tipo == "monstro" and "bicho" or "player") ..
        (info.criatura and (" " .. info.criatura:getName()) or "")) or "MW?"
    TD.log("Sqm " .. n.x .. ", " .. n.y .. " bloqueado (" .. quem .. "): desviando por " .. seg .. "s.")
end

-- v5.6: olha o PROXIMO sqm do caminho a cada ciclo (50 ms): player, bicho, MW ou parede la = trava e recalcula
-- na hora, sem esperar 1,2 s parado. O destino em si nao conta (goto ocupado o andarRota ja pula).
function TD.proximoBloqueado(p, destino)
    local n = TD.proximoSqmCaminho(p)
    if not n or mesmaPos(n, destino) then return false end
    local info = TD.analisarTileReal(n)
    if info.tipo == "livre" or info.desconhecido then return false end
    TD.travarSqm(n)
    return true
end

-- o caminho passa por sqm travado nos primeiros passos?
function TD.caminhoPassaTravado(p, dirs)
    local q = {x = p.x, y = p.y, z = p.z}
    for i = 1, math.min(#dirs, 6) do
        local v = VETOR[dirs[i]]
        if not v then return false end
        q = {x = q.x + v[1], y = q.y + v[2], z = q.z}
        local trav = TD.travados[chavePos(q)]
        if trav and trav > os.time() then return true end
    end
    return false
end

-- 1 passo pro lado: sqm vizinho livre que mais aproxima do destino (sai de perto do travado)
function TD.desvioLateral(p, destino)
    local melhor, md = nil, 999
    for delta, dir in pairs(DIR_DELTA) do
        local vx, vy = delta:match("^(-?%d+),(-?%d+)$")
        local n = {x = p.x + tonumber(vx), y = p.y + tonumber(vy), z = p.z}
        if TD.analisarTile(n).tipo == "livre" then
            local d = math.max(math.abs(destino.x - n.x), math.abs(destino.y - n.y))
            if d < md then melhor, md = dir, d end
        end
    end
    return melhor and {melhor} or nil
end

function TD.gotoCaveBot()
    local ok, pos = pcall(function()
        local lista = CaveBot.actionList or (CaveBot.ui and CaveBot.ui.list)
        local atual = lista and lista:getFocusedChild()
        if atual and atual.action == "goto" then
            local x, y, z = tostring(atual.value):match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
            if x then return {x = tonumber(x), y = tonumber(y), z = tonumber(z)} end
        end
    end)
    if ok then return pos end
    return nil
end

function TD.destinoFuga()
    if TD.ativo and TD.fugindo then return wpPos(TD.wp) end
    if TD.pkFase == "FUGINDO" then
        local ok, pos = pcall(function()
            local lista = CaveBot.actionList or (CaveBot.ui and CaveBot.ui.list)
            local atual = lista and lista:getFocusedChild()
            if atual and atual.action == "goto" then
                local x, y, z = tostring(atual.value):match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
                if x then return {x = tonumber(x), y = tonumber(y), z = tonumber(z)} end
            end
        end)
        if ok and pos then return pos end
        if cfg.fuga.pz then return cfg.fuga.pz end
    end
    return nil
end

function TD.areaLivre(origem, liberado, limite, bloqueado)
    limite = limite or 25
    local fila, visto, total = {origem}, {[chavePos(origem)] = true}, 0
    local i = 1
    while i <= #fila and total < limite do
        local n = fila[i]
        i = i + 1
        for _, d in ipairs(DELTAS) do
            local tp = posMais(n, d[1], d[2])
            local k = chavePos(tp)
            if not visto[k] and math.abs(tp.x - origem.x) <= 7 and math.abs(tp.y - origem.y) <= 6 then
                visto[k] = true
                local livre = (liberado and k == chavePos(liberado)) or TD.analisarTile(tp).tipo == "livre"
                if bloqueado and k == chavePos(bloqueado) then livre = false end
                if livre then
                    total = total + 1
                    table.insert(fila, tp)
                end
            end
        end
    end
    return total
end

function TD.melhorTileParaBicar(cpos, meuPos, fuga, evitarExtra)
    local evitar = {}
    for k in pairs(evitarExtra or {}) do evitar[k] = true end
    evitar[chavePos(posMais(cpos, cpos.x - meuPos.x, cpos.y - meuPos.y))] = true
    if fuga then
        local c = calcularCaminho(cpos, fuga, false)
        if c then
            local dx, dy = deltaDe(c[1])
            evitar[chavePos(posMais(cpos, dx, dy))] = true
        end
    end
    local melhor, melhorNota = nil, -99999
    for _, d in ipairs(DELTAS) do
        local tp = posMais(cpos, d[1], d[2])
        if not (tp.x == meuPos.x and tp.y == meuPos.y) and TD.analisarTile(tp).tipo == "livre" then
            local vizinhosLivres = 0
            for _, e in ipairs(DELTAS) do
                if TD.analisarTile(posMais(tp, e[1], e[2])).tipo == "livre" then vizinhosLivres = vizinhosLivres + 1 end
            end
            local nota = -vizinhosLivres * 10 + dist(tp, meuPos) * 5
            if evitar[chavePos(tp)] then nota = nota - 500 end
            if fuga then
                nota = nota + math.sqrt((tp.x - fuga.x) ^ 2 + (tp.y - fuga.y) ^ 2) * 3
            end
            if nota > melhorNota then melhor, melhorNota = tp, nota end
        end
    end
    return melhor
end

function TD.caminhoTerreno(p, destino)
    if not destino then return nil end
    local c = calcularCaminho(p, destino, false)
    if not c then return nil end
    local lista, set = {}, {}
    local q = {x = p.x, y = p.y, z = p.z}
    for i = 1, math.min(#c, 12) do
        local dx, dy = deltaDe(c[i])
        q = posMais(q, dx, dy)
        table.insert(lista, {pos = q, dir = c[i]})
        set[chavePos(q)] = true
    end
    return lista, set
end

function TD.bloqueadorNoCaminho(p, destino)
    local lista, set = TD.caminhoTerreno(p, destino)
    if not lista then return nil end
    for i, passo in ipairs(lista) do
        local info = TD.analisarTile(passo.pos)
        if info.tipo == "player" or info.tipo == "monstro" then
            return info.criatura, i, lista, set
        end
    end
    return nil, nil, lista, set
end

function TD.tentarBicar(p, destino)
    if agoraMs() - TD.ultimoBico < 400 then return false end
    local bloqueador, _, _, setCaminho = TD.bloqueadorNoCaminho(p, destino)
    local candidatos = {}
    for _, d in ipairs(DELTAS) do
        local tp = posMais(p, d[1], d[2])
        local info = TD.analisarTile(tp)
        if info.tipo == "player" or info.tipo == "monstro" then
            local area = TD.areaLivre(tp, tp, 25)
            local nota = area * 10
            if destino then
                local resto = calcularCaminho(tp, destino, true)
                if resto then nota = nota + 300 - #resto * 5 end
                nota = nota - math.sqrt((tp.x - destino.x) ^ 2 + (tp.y - destino.y) ^ 2)
            end
            if info.tipo == "player" and not TD.ehInimigo(info.criatura) then nota = nota + 1 end
            if bloqueador and info.criatura == bloqueador then nota = nota + 10000 end
            table.insert(candidatos, {c = info.criatura, pos = tp, dir = d[3], nota = nota})
        end
    end
    table.sort(candidatos, function(a, b) return a.nota > b.nota end)
    for _, cand in ipairs(candidatos) do
        if not cand.c:isPlayer() then
            -- so chega aqui na fuga de PK (PK atacou / escudo azul na quantidade / MW + inimigo colado) e trapado:
            -- bate no monstro que bloqueia, qualquer nome, pra abrir caminho. Fora disso o PK nao bate em bicho.
            TD.focarMonstro(cand.c, cand.dir, cand.pos)
            return true
        end
        local para = cand.c:isPlayer() and TD.melhorTileParaBicar(cand.pos, p, destino, setCaminho)
        if para then
            g_game.move(cand.c, para, 1)
            TD.ultimoBico = agoraMs()
            TD.bicoDir, TD.bicoPos, TD.bicoAte = cand.dir, cand.pos, agoraMs() + 1200
            TD.log("Trapado! Bicando " .. cand.c:getName() .. " e saindo.")
            return true
        end
    end
    return false
end

function TD.focarMonstro(c, dir, pos)
    -- o painel bate sozinho: nao liga/desliga TargetBot do vBot
    if g_game.getAttackingCreature() ~= c then g_game.attack(c) end
    TD.focoMonstro = c
    TD.bicoDir, TD.bicoPos, TD.bicoAte = dir, pos, agoraMs() + 6000
    TD.statusFuga = "TRAPADO: matando " .. c:getName()
end

function TD.soltarFoco()
    local foco = TD.focoMonstro
    TD.focoMonstro = nil
    -- para de bater so se ainda estava batendo no bicho do foco (nao mexe no ataque da task)
    if foco and g_game.getAttackingCreature() == foco and g_game.cancelAttack then pcall(g_game.cancelAttack) end
end

function TD.jogarMW(p, destino)
    if not cfg.fuga.mw or agoraMs() - TD.ultimaMW < 2500 then return end
    local inimigo, dmin = nil, 99
    for _, spec in ipairs(getSpectators()) do
        if spec:isPlayer() and spec ~= player and TD.ehInimigo(spec) then
            local d = dist(p, spec:getPosition())
            if d <= 4 and d < dmin then inimigo, dmin = spec, d end
        end
    end
    if not inimigo or dmin < 2 then return end
    local ep = inimigo:getPosition()

    local passos = {}
    if destino then
        local c = calcularCaminho(p, destino, true)
        if c then
            local q = {x = p.x, y = p.y, z = p.z}
            for i = 1, math.min(#c, 4) do
                local cx, cy = deltaDe(c[i])
                q = posMais(q, cx, cy)
                passos[chavePos(q)] = true
            end
        end
    end

    local antes = TD.areaLivre(p, nil, 20)
    local alvo, melhorNota = nil, -99999
    for _, d in ipairs(DELTAS) do
        local tp = posMais(p, d[1], d[2])
        if not passos[chavePos(tp)] and dist(tp, ep) < dmin and TD.analisarTile(tp).tipo == "livre" then
            local barreiraPerto = false
            local livresEmVolta = 0
            for _, e in ipairs(DELTAS) do
                local v = posMais(tp, e[1], e[2])
                if not (v.x == p.x and v.y == p.y) then
                    local info = TD.analisarTile(v)
                    if info.tipo == "livre" then livresEmVolta = livresEmVolta + 1 end
                    if info.tipo == "barreira" then barreiraPerto = true end
                end
            end
            if not barreiraPerto then
                local depois = TD.areaLivre(p, nil, 20, tp)
                if depois >= 10 and depois >= antes - 6 then
                    local nota = -livresEmVolta * 10 - dist(tp, ep) * 3
                    if nota > melhorNota then alvo, melhorNota = tp, nota end
                end
            end
        end
    end
    if not alvo then return end

    local runa = nil
    if TD.contarItem(cfg.fuga.runaMW) > 0 then
        runa = cfg.fuga.runaMW
    elseif TD.contarItem(cfg.fuga.runaVip) > 0 then
        runa = cfg.fuga.runaVip
    end
    if not runa then return end
    local tile = g_map.getTile(alvo)
    if not tile then return end
    pcall(function() g_game.useInventoryItemWith(runa, tile:getTopUseThing()) end)
    TD.ultimaMW = agoraMs()
    TD.log("MW na passagem entre voce e " .. inimigo:getName() .. ".")
end

TD.perigoAte = 0

function TD.entrarEmPerigo()
    TD.perigoAte = agoraMs() + 20000
    TD.avaliarFuga()
end

function TD.avaliarFuga()
    if not g_map then return end
    -- evento: nada de anti-trap/PK (ele "bica" qualquer monstro que bloqueia). No evento o painel so ataca
    -- os bosses do Island pelo nome; Zombie/Snowball/FireStorm nao atacam ninguem.
    if TD.evRun then
        if TD.focoMonstro and TD.soltarFoco then TD.soltarFoco() end
        TD.bicoAte, TD.statusFuga = nil, "Livre (evento)"
        return
    end
    local fugindo = (TD.ativo and TD.fugindo) or TD.pkFase == "FUGINDO" or agoraMs() < TD.perigoAte
    local p = player:getPosition()
    if not p then return end
    TD.cacheTiles = {}

    if not fugindo then
        local temInimigo = false
        for _ in pairs(TD.inimigos) do temInimigo = true break end
        if not temInimigo then
            TD.statusFuga = "Livre"
            TD.cacheTiles = nil
            return
        end
        local barreira, estranho = false, false
        for _, d in ipairs(DELTAS) do
            local info = TD.analisarTile(posMais(p, d[1], d[2]))
            if info.tipo == "barreira" then barreira = true end
            if info.tipo == "player" and TD.ehInimigo(info.criatura) then
                local esc = info.criatura.getShield and info.criatura:getShield() or 0
                if esc < 3 then estranho = true end
            end
        end
        if not (barreira and estranho) then
            TD.statusFuga = "Livre"
            TD.cacheTiles = nil
            return
        end
        TD.perigoAte = agoraMs() + 20000
    end

    local destino = TD.destinoFuga()

    if TD.bicoAte then
        if agoraMs() < TD.bicoAte then
            local info = TD.analisarTile(TD.bicoPos)
            if info.tipo == "livre" then
                if not (player.isWalking and player:isWalking()) then
                    TD.passoProprioAte = agoraMs() + 600
                    g_game.walk(TD.bicoDir)
                    TD.bicoAte = nil
                    TD.soltarFoco()
                    TD.statusFuga = "Saindo pelo sqm aberto"
                end
            elseif TD.focoMonstro and info.criatura == TD.focoMonstro then
                if g_game.getAttackingCreature() ~= TD.focoMonstro then g_game.attack(TD.focoMonstro) end
            elseif not TD.focoMonstro and agoraMs() - TD.ultimoBico >= 400 and info.tipo == "player" then
                TD.bicoAte = nil
            end
            if TD.bicoAte then
                TD.cacheTiles = nil
                return
            end
        else
            TD.bicoAte = nil
            TD.soltarFoco()
        end
    end

    if agoraMs() < (TD.proximaAvaliacao or 0) then
        TD.cacheTiles = nil
        return
    end
    TD.proximaAvaliacao = agoraMs() + 120
    local area = TD.areaLivre(p, nil, 12)
    local trapado = area < 4
    if not trapado and destino then
        local terreno = calcularCaminho(p, destino, false)
        local comGente = calcularCaminho(p, destino, true)
        trapado = terreno ~= nil and (comGente == nil or #comGente > #terreno + 6)
    end

    if trapado then
        TD.statusFuga = "TRAPADO"
        local bloqueador, indice, lista = nil, nil, nil
        if destino then bloqueador, indice, lista = TD.bloqueadorNoCaminho(p, destino) end
        if bloqueador and indice and indice > 1 and bloqueador:isPlayer() then
            TD.statusFuga = "INDO BICAR " .. bloqueador:getName()
            if not (player.isWalking and player:isWalking()) then
                local passo = lista[1]
                if TD.analisarTile(passo.pos).tipo == "livre" then
                    TD.passoProprioAte = agoraMs() + 600
                    g_game.walk(passo.dir)
                end
            end
        elseif cfg.fuga.bicar then
            TD.tentarBicar(p, destino)
        end
    else
        TD.statusFuga = "Fugindo"
        if TD.focoMonstro then TD.soltarFoco() end
    end
    if (TD.ativo and TD.fugindo) or TD.pkFase == "FUGINDO" then TD.jogarMW(p, destino) end
    TD.cacheTiles = nil
end

macro(50, function() TD.avaliarFuga() end)

TD.EMBLEMA_AZUL = 3
TD.NOME_COR = {[1] = "VERDE", [2] = "VERMELHO", [3] = "AZUL", [4] = "MEMBRO", [5] = "OUTRO"}
TD.escudoVisto = "-"

function TD.contarGuildAzul(p, marcar)
    local total, primeiro, perto, pertoD = 0, nil, nil, 99
    for _, spec in ipairs(getSpectators()) do
        local okP, ehPlayer = pcall(function() return spec:isPlayer() end)
        if okP and ehPlayer and spec ~= player then
            local okE, emblema = pcall(function() return spec:getEmblem() end)
            local sp = spec:getPosition()
            local d = (sp and sp.z == p.z) and dist(p, sp) or 99
            if d < pertoD then perto, pertoD = {nome = spec:getName(), emb = okE and emblema or "?"}, d end
            if okE and emblema == TD.EMBLEMA_AZUL and d <= cfg.fuga.escudoSqm then
                local escudoParty = spec.getShield and spec:getShield() or 0
                if escudoParty < 3 then
                    total = total + 1
                    primeiro = primeiro or spec
                    if marcar then TD.marcarInimigo(spec:getName()) end
                end
            end
        end
    end
    TD.escudoVisto = perto and (tostring(perto.nome):gsub("%s*%[%d+%]%s*$", "") .. " = " .. (TD.NOME_COR[perto.emb] or tostring(perto.emb))) or "-"
    return total, primeiro
end

function TD.vigiarEscudo()
    if storage.BossAntiTrapTPEnabled or TD.evRun then return end
    if TD.pkFase or not cfg.fuga or not cfg.fuga.escudoAtivo then return end
    if TD.ativo or not cfg.pkHunt.ativo then return end
    if not (CaveBot and CaveBot.isOn and CaveBot.isOn()) then return end
    local p = player:getPosition()
    if not p or TD.emPz() then return end
    -- regra: so corre com a QUANTIDADE configurada de escudo azul perto (trapado por bicho nao conta).
    -- Marca como inimigo so quando dispara (antes marcava 1 escudo azul qualquer e ligava a fuga sem PK).
    local total, primeiro = TD.contarGuildAzul(p, false)
    if not primeiro then return end
    if total >= cfg.fuga.escudoQtd then
        TD.contarGuildAzul(p, true)
        TD.log(total .. " de escudo azul perto! Correndo.")
        TD.pkHuntAtacado(primeiro:getName())
    end
end

macro(100, function()
    local ok, erro = pcall(TD.vigiarEscudo)
    if not ok and os.time() - (TD.ultimoErroEscudo or 0) > 10 then
        TD.ultimoErroEscudo = os.time()
        TD.log("Escudo: " .. tostring(erro))
    end
end)

function TD.resetarPK()
    if TD.pkFase == "NO PZ" or TD.pkFase == "FUGINDO" then
        if CaveBot and CaveBot.setOn then CaveBot.setOn() end
    end
    TD.pkFase = nil
    TD.pkDesde = 0
    TD.foraPzDesde = nil
    TD.inimigos = {}
    TD.perigoAte = 0
    TD.bicoAte = nil
    TD.ultimoBico = 0
    TD.ultimaMW = 0
    TD.barreirasVistas = {}
    TD.fugas = 0
    TD.statusFuga = "Livre"
    if TD.soltarFoco then TD.soltarFoco() end
    if TD.devolverTargetBot then TD.devolverTargetBot() end
    if TD.ativo and TD.fugindo then
        TD.fugindo = false
        TD.escolherRotaInicial()
    end
    TD.log("PK resetado.")
end

TD.evRun = nil
TD.ISLAND = {
    sala = {x1 = 19286, x2 = 19298, y1 = 19121, y2 = 19129, z = 7},
    bosses = {"island fire", "island ice", "island earth", "island energy", "island death"},
    tp = 1949,
}

function TD.salaIslandValida(s)
    local c = TD.ISLAND.sala
    return type(s) == "table" and s.z == c.z and math.abs(s.x1 - c.x1) <= 30 and math.abs(s.y1 - c.y1) <= 30
end

-- sala cadastrada OU a aprendida (onde o TP do evento te deixou da ultima vez: cfg.islandSala)
function TD.naSalaIsland(p)
    if not p then return false end
    -- perto do TP do evento NUNCA e a sala (uma sala aprendida errada fazia ele achar que ja tinha entrado)
    if dist(p, TD.TP_EVENTO) <= 20 then return false end
    -- v5.5: sala aprendida longe da cadastrada = aprendeu errado (ex.: templo depois do "!tp thais"): ignora
    local aprendida = TD.salaIslandValida(cfg.islandSala) and cfg.islandSala or nil
    for _, s in ipairs({TD.ISLAND.sala, aprendida}) do
        if s and p.z == s.z and p.x >= s.x1 and p.x <= s.x2 and p.y >= s.y1 and p.y <= s.y2 then return true end
    end
    return false
end

-- Seguranca (5.4): a agenda ja chamou (evento/task) mas o CaveBot passou no checkin DE NOVO = o char nao chegou
-- na label (travou no caminho e a cave voltou a rodar). Antes ele ignorava ate o horario acabar; agora manda
-- pra label de novo, ate 3 vezes por chamada (sem chegadaDP na label nao fica em loop pra sempre).
TD.reenvio = {chave = nil, n = 0, t = 0}
local function reenviarLabel(k, logar)
    local ag = cfg.agenda[k]
    local j = TD.janelaAgora(k)
    if not ag or ag.label == "" or not j then return nil end
    local chave = os.date("%Y-%m-%d") .. "|" .. k .. "|" .. j.txt   -- zera a cada horario da agenda
    if TD.reenvio.chave ~= chave then TD.reenvio = {chave = chave, n = 0, t = 0} end
    -- 10 s entre reenvios: o checkin repetido logo em seguida nao gasta as 3 tentativas de uma vez
    if TD.reenvio.n >= 3 or os.time() - TD.reenvio.t < 10 then return nil end
    TD.reenvio.n, TD.reenvio.t = TD.reenvio.n + 1, os.time()
    logar("Passou no checkin sem chegar na label '" .. ag.label .. "' (travou?). Indo de novo (" .. TD.reenvio.n .. "/3).")
    if CaveBot.gotoLabel(ag.label) == false then return nil end
    return "retry"
end

TD.reenviarLabel = reenviarLabel

function TaskDemon.checkinEvento()
    if TD.evRun or TD.ativo then return true end
    if TD.eventoChamado then
        local r = reenviarLabel(TD.eventoChamado, TD.logEv)
        if r then return r end
    end
    local hoje = os.date("%Y-%m-%d")
    for _, k in ipairs(TD.ORDEM_EVENTOS) do
        local j = TD.EVENTOS[k].pronto and TD.janelaAgora(k)
        if j then
            local chave = hoje .. "|" .. k .. "|" .. j.txt
            if not cfg.disparos[chave] then
                local ag = cfg.agenda[k]
                TD.eventoChamado = k
                TD.eventoJanela = j
                cfg.eventosAtivo = true -- a agenda liga o EVENTOS
                TD.evEditando = k
                if TD.atualizarEventos then pcall(TD.atualizarEventos) end
                if ag.label == "" then
                    cfg.disparos[chave] = true
                    TD.iniciarEventoRota(k)
                    if not TD.evRun then TD.eventoChamado, cfg.eventosAtivo = nil, false end
                    return true
                end
                TD.logEv("Evento " .. TD.EVENTOS[k].titulo .. " (" .. j.txt .. "). Indo para '" .. ag.label .. "'.")
                if CaveBot.gotoLabel(ag.label) == false then
                    TD.logEv("ERRO: a label '" .. ag.label .. "' nao existe no CaveBot carregado.")
                    TD.eventoChamado = nil
                    return true
                end
                cfg.disparos[chave] = true
                return "retry"
            end
        end
    end
    return true
end

-- Marca o horario atual da agenda como ja feito (todos os eventos): depois de terminar ou desligar na mao,
-- o CaveBot volta a passar no checkin e a agenda religava o mesmo evento no mesmo horario (ON sem parar).
function TD.marcarJanelasFeitas()
    local hoje = os.date("%Y-%m-%d")
    for _, k in ipairs(TD.ORDEM_EVENTOS) do
        local ok, j = pcall(TD.janelaAgora, k)
        if ok and j then cfg.disparos[hoje .. "|" .. k .. "|" .. j.txt] = true end
    end
end

function TaskDemon.iniciarEvento(tipo)
    if TD.evRun or not cfg.eventosAtivo then return true end
    if TD.ativo then
        TD.logEv("Evento nao iniciado: tem uma task rodando.")
        return true
    end
    TD.evRun = {tipo = tipo or "island", fase = "SALA", inicio = os.time(), bossIdx = 0}
    TD.evEditando = "ev_" .. TD.evRun.tipo
    if TD.atualizarEventos then pcall(TD.atualizarEventos) end
    TD.assumirControleEvento()
    -- auto chase SO no Island (segue o boss). Todos os outros eventos: chase desligado.
    if g_game.setChaseMode then pcall(function() g_game.setChaseMode(1) end) end
    TD.caminho, TD.destinoAtual, TD.destinoCliente, TD.semCaminhoAte = nil, nil, nil, nil
    TD.logEv("Island Of Elementals iniciado (auto chase LIGADO).")
    return true
end

-- Evento comeca: guarda como o bot estava (uma vez so) e o painel assume o andar e o ataque
function TD.assumirControleEvento()
    if TD.evAntes == nil then
        local okC, chase = pcall(function() return g_game.getChaseMode() end)
        TD.evAntes = {
            cave = CaveBot and CaveBot.isOn and CaveBot.isOn() or false,
            target = TargetBot and TargetBot.isOn and TargetBot.isOn() or false,
            chase = okC and chase or 0,
        }
    end
    if TargetBot and TargetBot.setOff then TargetBot.setOff() end
    if CaveBot and CaveBot.setOff then CaveBot.setOff() end
    if TD.logEv then TD.logEv("Evento comecou: CaveBot e TargetBot do bot DESLIGADOS (o painel assume).") end
end

-- CaveBot da task usado pelo evento: o escolhido na aba EVENTOS ou um com o mesmo nome do evento
function TD.perfilDoEvento(k)
    local nome = cfg.eventoPerfil and cfg.eventoPerfil[k]
    if nome and cfg.perfis[nome] then return nome end
    local curto = TD.EVENTOS[k] and TD.EVENTOS[k].curto:lower()
    for n in pairs(cfg.perfis) do
        if n:lower() == curto then return n end
    end
    return nil
end

function TD.iniciarEventoRota(k, perfil)
    if TD.evRun then return true end
    if TD.ativo then
        TD.logEv("Evento nao iniciado: tem uma task rodando.")
        return true
    end
    -- EVENTOS: o CAMINHO e sempre a entrada fixa do TP (TD.ENTRADA_EVENTO), igual pra todos.
    -- O perfil e opcional e so da a PRINCIPAL (rota dentro da arena: Snowball/FireStorm).
    -- Island e Zombie nao precisam de perfil (o painel controla la dentro). Tasks nao passam por aqui.
    local nome = perfil or TD.perfilDoEvento(k)
    local p = nome and cfg.perfis[nome]
    local titulo = TD.EVENTOS[k].titulo
    if (k == "ev_snowball" or k == "ev_firestorm") and #(p and p.PRINCIPAL or {}) == 0 then
        TD.logEv(titulo .. ": sem PRINCIPAL (rota da arena). Entra e fica parado la dentro; grave a PRINCIPAL no perfil.")
    end
    TD.evRun = {tipo = k:sub(4), rota = true, fase = "ROTA", inicio = os.time(),
                janela = TD.eventoChamado == k and TD.eventoJanela or nil}
    TD.evEditando = k
    TD.assumirControleEvento()
    if g_game.setChaseMode then pcall(function() g_game.setChaseMode(0) end) end -- chase so dentro do Island
    TD.limparEstado()
    TD.perfilAtivo = p and nome or titulo
    -- copia so a "casca": PRINCIPAL/DP continuam sendo as tabelas do perfil (editar ao vivo funciona)
    TD.ROTAS = {CAMINHO = TD.ENTRADA_EVENTO, PRINCIPAL = p and p.PRINCIPAL or {}, DP = p and p.DP or {}}
    TD.escolherRotaInicial()
    if TD.atualizarEventos then pcall(TD.atualizarEventos) end
    TD.logEv(titulo .. " iniciado: indo pro TP do evento" .. (p and (" (PRINCIPAL de '" .. nome .. "')") or "") .. ".")
    return true
end

-- Para usar no CaveBot na label do evento (igual ao chegadaDP da task)
function TaskDemon.chegadaEvento()
    local k = TD.eventoChamado
    if not k or TD.evRun then return true end
    return TD.iniciarEventoRota(k)
end

-- ZOMBIE EVENT: nao ataca, so foge. Automatico (sem campos no painel). Objetivo: ficar vivo o maximo.
-- Como decide (planejador, olhando TODOS os zombies da tela + os que sairam da tela ha pouco):
--  1) memoria: lembra onde viu cada zombie nos ultimos TD.ZOMBIE_MEMORIA_MS e supoe que ele continua vindo
--     (sem isso, o zombie saia 1 sqm da tela, ele achava "Seguro" e parava a cada passo)
--  2) simula os proximos TD.ZOMBIE_PROF passos: para cada sequencia de passos (N/S/L/O/parado) move os
--     zombies atras de mim na velocidade deles, contornando parede, e descarta o que for capturado
--  3) guarda so as TD.ZOMBIE_FEIXE melhores sequencias a cada passo (nota: zombie mais perto bem longe +
--     todos longe) e anda o 1o passo da melhor. Assim acha a janela pra passar e evita beco.
--  4) comeca com zombie a TD.ZOMBIE_ALERTA sqm. Diagonal so quando nenhum passo reto sobrevive:
--     ai simula de novo com diagonal; se nem assim, anda pro sqm que mais afasta (nunca fica parado esperando).
--  5) teimosia (anti-samba): mantem a direcao anterior se ela for quase tao boa quanto a melhor.
-- Visao: o cliente afastado enxerga ~18 sqm; usa TD.ZOMBIE_VISAO_X/Y, mas so o que o mapa conhece (tile existe).
-- Testado em simulacao na arena do evento (minimapa): dura ~2x mais que fugir do mais perto.
-- so pelo nome exato (nenhum outro monstro conta como zombie)
TD.ZOMBIE_NOMES = {["event zombie"] = true}
function TD.zombiesNaTela(p)
    local lista = {}
    for _, spec in ipairs(getSpectators()) do
        local okN, nome = pcall(function() return spec:isMonster() and spec:getName():lower() end)
        if okN and nome and TD.ZOMBIE_NOMES[nome] then
            local sp = spec:getPosition()
            if sp and sp.z == p.z then
                local okV, v = pcall(function() return spec:getSpeed() end)
                local okI, id = pcall(function() return spec:getId() end)
                table.insert(lista, {x = sp.x, y = sp.y, z = sp.z, vel = okV and v or nil, id = okI and id or (sp.x .. "," .. sp.y)})
            end
        end
    end
    return lista
end

local function distZombie(pos, zs)
    local m = 99
    for _, z in ipairs(zs) do
        local d = math.max(math.abs(pos.x - z.x), math.abs(pos.y - z.y))
        if d < m then m = d end
    end
    return m
end

TD.ZOMBIE_VISAO_X = 18         -- tela afastada: sqm visiveis pros lados (tile que o cliente nao tem conta como desconhecido)
TD.ZOMBIE_VISAO_Y = 14         -- tela afastada: sqm visiveis pra cima/baixo
TD.ZOMBIE_SEM_PARADO = 8      -- zombie a essa distancia ou menos: proibido ficar parado (4 -> 8: sim 120->141 / 156->176 de 200)
TD.ZOMBIE_VOLTA = 1.3          -- voltar pro lado oposto so se for 30% melhor que a outra opcao (anti-samba)
TD.ZOMBIE_TEIMA = 0.9          -- mantem a direcao anterior se a nota dela for >= 90% da melhor (anti-samba)
TD.ZOMBIE_CAPTURA = 2          -- a 2 sqm o jogo ja conta como capturado
TD.ZOMBIE_ALERTA = 14          -- comeca a planejar com zombie a essa distancia (6 -> 10 -> 14: sim "zombies chegando de longe" 134 -> 159/200)
TD.ZOMBIE_ESPACO_RAIO = 8      -- espaco livre: olha ate 8 sqm em cada uma das 8 direcoes
TD.ZOMBIE_ESPACO_PESO = 2      -- espaco livre na nota (anti-beco). 5.3: sim arena real + 15 players, 72 jogos: 208 -> 237/270s, ganhou 44 -> 54
TD.ZOMBIE_PROF = 16            -- passos simulados a frente
TD.ZOMBIE_FEIXE = 40           -- sequencias guardadas por passo (mais = melhor e mais pesado; 60 -> 40 com a diagonal)
TD.ZOMBIE_CUSTO_DIAG = 3       -- passo diagonal demora ~3x o reto (Tibia): na conta o zombie anda 3x mais nesse passo
TD.ZOMBIE_MEMORIA_MS = 4000    -- lembra de zombie que saiu da tela por esse tempo

local ORTO, DIAGS = {DELTAS[1], DELTAS[2], DELTAS[3], DELTAS[4]}, {DELTAS[5], DELTAS[6], DELTAS[7], DELTAS[8]}
local MOVS = {DELTAS[1], DELTAS[2], DELTAS[3], DELTAS[4], {0, 0, nil}}   -- 4 retos + ficar parado
local function chaveXY(x, y) return x * 100000 + y end
local function chebyshev(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

-- zombies visiveis + lembrados (os que sairam da tela andam na minha direcao pelo tempo que passou)
local function zombiesConhecidos(ev, p, zsTela)
    local agora = agoraMs()
    ev.memZ = ev.memZ or {}
    for _, z in ipairs(zsTela) do ev.memZ[z.id] = {x = z.x, y = z.y, z = z.z, vel = z.vel, t = agora} end
    local lista, lembrados = {}, 0
    for id, m in pairs(ev.memZ) do
        local idade = agora - m.t
        if idade > TD.ZOMBIE_MEMORIA_MS or m.z ~= p.z then
            ev.memZ[id] = nil
        else
            local z = {x = m.x, y = m.y, z = m.z, vel = m.vel}
            if idade > 0 then
                lembrados = lembrados + 1
                -- ponytail: passo de ~150 de chao por sqm (grama); ajustar se o chao da arena for outro
                local passos = math.floor(idade / 1000 * (m.vel or 100) / 150)
                for _ = 1, passos do
                    z.x = z.x + (p.x > z.x and 1 or (p.x < z.x and -1 or 0))
                    z.y = z.y + (p.y > z.y and 1 or (p.y < z.y and -1 or 0))
                end
            end
            table.insert(lista, z)
        end
    end
    return lista, lembrados
end

-- retorna a direcao pra andar (ou nil) e o motivo
function TD.decidirFugaZombie(ev, p, zsTela)
    local zs, lembrados = zombiesConhecidos(ev, p, zsTela)
    ev.pertoZombie = distZombie(p, zs)
    if #zs == 0 then return nil, "Seguro" end
    local info = " (" .. #zs .. " zombies" .. (lembrados > 0 and (", " .. lembrados .. " fora da tela") or "") .. ")"
    if ev.pertoZombie > TD.ZOMBIE_ALERTA then return nil, "Observando" .. info end

    local vp = 0
    pcall(function() vp = player:getSpeed() end)
    local r = 0.5   -- sem velocidade: zombie anda ~1 a cada 2 passos nossos
    if vp > 0 then
        r = 0
        for _, z in ipairs(zs) do r = math.max(r, (z.vel or vp * 0.5) / vp) end
        r = math.min(math.max(r, 0.2), 2)
    end
    local VX, VY = TD.ZOMBIE_VISAO_X, TD.ZOMBIE_VISAO_Y
    local function naTela(q) return math.abs(q.x - p.x) <= VX and math.abs(q.y - p.y) <= VY end
    local function euPiso(q) return naTela(q) and TD.analisarTile(q).tipo == "livre" end
    -- espaco livre em volta de q: soma, nas 8 direcoes, dos sqm livres em linha reta (ate TD.ZOMBIE_ESPACO_RAIO).
    -- Video 2026-10-02: sem isso ele fugia sempre pra borda da arena e era encurralado na pedra.
    local espacoCache = {}
    local function espaco(q)
        local k = chaveXY(q.x, q.y)
        local v = espacoCache[k]
        if v then return v end
        v = 0
        for _, d in ipairs(DELTAS) do
            for i = 1, TD.ZOMBIE_ESPACO_RAIO do
                if not euPiso({x = q.x + d[1] * i, y = q.y + d[2] * i, z = q.z}) then break end
                v = v + 1
            end
        end
        espacoCache[k] = v
        return v
    end
    local function zombieAnda(q)   -- fora da tela / tile desconhecido: deixa andar (pior caso)
        if not naTela(q) then return true end
        local a = TD.analisarTile(q)
        if a.desconhecido then return true end
        return a.tipo ~= "parede" and a.tipo ~= "barreira"
    end
    -- previsao do zombie: anda RETO (videos 2026-10-02: 95% dos passos dos zombies sao num eixo so; a diagonal
    -- e cara pra eles tambem). Sim na arena real com grupos: 8 zombies 110 -> 141/200, 5 zombies 187 -> 200.
    -- otimizacao EXATA: a escolha do zombie em z indo atras de alvo so depende dessas 2 posicoes (o mapa nao
    -- muda dentro de 1 decisao). Calcula 1 vez os vizinhos que melhoram, ja na ordem de preferencia (menor distancia;
    -- empate = o primeiro na ordem N, L, S, O, igual ao laco antigo) e depois so pula os ocupados.
    local memoZ = {}
    local function candidatosZ(z, alvo)
        -- chave unica: posicoes relativas a mim (a arena inteira cabe folgado em +-2048)
        local ka = (((z.x - p.x + 2048) * 4096 + (z.y - p.y + 2048)) * 4096 + (alvo.x - p.x + 2048)) * 4096 + (alvo.y - p.y + 2048)
        local lista = memoZ[ka]
        if lista then return lista end
        lista = {}
        local md, mm = chebyshev(z, alvo), math.abs(z.x - alvo.x) + math.abs(z.y - alvo.y)
        for i, d in ipairs(ORTO) do
            local q = {x = z.x + d[1], y = z.y + d[2], z = z.z}
            if zombieAnda(q) then
                local dq, mq = chebyshev(q, alvo), math.abs(q.x - alvo.x) + math.abs(q.y - alvo.y)
                if dq < md or (dq == md and mq < mm) then
                    table.insert(lista, {q = q, k = chaveXY(q.x, q.y), dq = dq, mq = mq, i = i})
                end
            end
        end
        table.sort(lista, function(a, b)
            if a.dq ~= b.dq then return a.dq < b.dq end
            if a.mq ~= b.mq then return a.mq < b.mq end
            return a.i < b.i
        end)
        memoZ[ka] = lista
        return lista
    end
    -- ocupado nesta rodada de passos dos zombies: ocup[k] == geracao (sem criar tabela nova a cada rodada)
    local ocup, geracao = {}, 0
    local function passoZ(z, alvo)
        local lista = candidatosZ(z, alvo)
        for i = 1, #lista do
            local c = lista[i]
            if ocup[c.k] ~= geracao then return c.q end
        end
        return z
    end

    -- feixe: cada estado = eu, zombies, 1o passo, sobra de passo de zombie.
    -- Retorna a lista de 1os passos da melhor pra pior nota final ({dir, nota}), ou nil se nada sobrevive.
    local function feixe(movs, CAPT, prof)
        local estados, fim = {{eu = p, zs = zs, pr = false, acc = 0}}, nil
        for t = 1, prof do
            local novos, lista = {}, {}
            for _, e in ipairs(estados) do
                for _, d in ipairs(movs) do
                    local q = {x = e.eu.x + d[1], y = e.eu.y + d[2], z = p.z}
                    if d[3] == nil or euPiso(q) then
                        -- diagonal: demora mais, entao o zombie anda mais nesse passo (escolhe diagonal so quando compensa)
                        local custo = (d[3] ~= nil and d[1] ~= 0 and d[2] ~= 0) and TD.ZOMBIE_CUSTO_DIAG or 1
                        local a, z2 = e.acc + r * custo, e.zs
                        while a >= 1 do
                            local novo = {}
                            geracao = geracao + 1
                            for i = 1, #z2 do
                                local nz = passoZ(z2[i], q)
                                novo[i] = nz
                                ocup[chaveXY(nz.x, nz.y)] = geracao
                            end
                            z2, a = novo, a - 1
                        end
                        local dmin, soma = 99, 0
                        for i = 1, #z2 do
                            local z = z2[i]
                            local dx, dy = q.x - z.x, q.y - z.y
                            if dx < 0 then dx = -dx end
                            if dy < 0 then dy = -dy end
                            local dz = dx > dy and dx or dy
                            if dz < dmin then dmin = dz end
                            soma = soma + (dz < 20 and dz or 20)
                        end
                        if dmin > CAPT then
                            local k = { chaveXY(q.x, q.y) }
                            for _, z in ipairs(z2) do k[#k + 1] = chaveXY(z.x, z.y) end
                            k = table.concat(k, ":")
                            local nota = 5 * dmin + soma
                            if TD.ZOMBIE_ESPACO_PESO > 0 then nota = nota + TD.ZOMBIE_ESPACO_PESO * espaco(q) end
                            -- novos[k] = posicao na lista (antes procurava o estado antigo na lista inteira a cada troca)
                            local ai = novos[k]
                            local ant = ai and lista[ai]
                            if not ant or nota > ant.nota then
                                local pr = e.pr
                                if t == 1 then pr = d[3] end
                                local s = {eu = q, zs = z2, pr = pr, acc = a, nota = nota}
                                if ai then
                                    lista[ai] = s
                                else
                                    table.insert(lista, s)
                                    novos[k] = #lista
                                end
                            end
                        end
                    end
                end
            end
            if #lista == 0 then break end
            table.sort(lista, function(x, y) return x.nota > y.nota end)
            for i = #lista, TD.ZOMBIE_FEIXE + 1, -1 do lista[i] = nil end
            estados, fim = lista, lista
        end
        if not fim then return nil end
        local porDir, visto = {}, {}
        for _, e in ipairs(fim) do
            local k = e.pr == nil and "parado" or e.pr
            if not visto[k] then visto[k] = true; table.insert(porDir, {dir = e.pr, nota = e.nota}) end
        end
        return porDir
    end

    -- 4 retos + 4 diagonais + parado (a diagonal entra com o custo real; antes so no ultimo recurso)
    local MOVS8 = {MOVS[1], MOVS[2], MOVS[3], MOVS[4], DIAGS[1], DIAGS[2], DIAGS[3], DIAGS[4], MOVS[5]}
    local porDir = feixe(MOVS8, TD.ZOMBIE_CAPTURA, TD.ZOMBIE_PROF)
    local modo = "Fugindo"
    if not porDir then
        -- nenhum passo reto sobrevive: libera diagonal e so conta captura encostado
        local todos = {MOVS[1], MOVS[2], MOVS[3], MOVS[4], DIAGS[1], DIAGS[2], DIAGS[3], DIAGS[4], MOVS[5]}
        porDir, modo = feixe(todos, 1, math.floor(TD.ZOMBIE_PROF / 2)), "Fugindo (diagonal)"
    end
    if not porDir then
        -- ultimo recurso: o sqm vizinho que mais afasta (mesmo empatado: nunca fica parado com zombie chegando)
        local passo, melhorD = nil, -1
        for _, d in ipairs(DELTAS) do
            local q = posMais(p, d[1], d[2])
            if euPiso(q) and distZombie(q, zs) > melhorD then passo, melhorD = d[3], distZombie(q, zs) end
        end
        ev.ultDir = passo
        return passo, "Sem saida" .. info
    end
    -- 1) zombie a <= TD.ZOMBIE_SEM_PARADO sqm: ficar parado nao e opcao (video top 2: ficou "Parado" com o
    --    zombie vindo de 6 ate 3 sqm e nao pegou a brecha). Sim: 8 zombies, parado perto 3,1 -> 0,6/partida.
    local function filtrar(cond)
        local resto = {}
        for _, o in ipairs(porDir) do if not cond(o) then table.insert(resto, o) end end
        if #resto > 0 then porDir = resto end
    end
    if ev.pertoZombie <= TD.ZOMBIE_SEM_PARADO then filtrar(function(o) return o.dir == nil end) end
    -- 2) anti-volta: so volta pro lado oposto do ultimo passo se for >= TD.ZOMBIE_VOLTA x a melhor outra opcao
    if ev.ultDir ~= nil then
        local dx, dy = deltaDe(ev.ultDir)
        local oposta = nil
        for _, d in ipairs(DELTAS) do if d[1] == -dx and d[2] == -dy and (dx ~= 0 or dy ~= 0) then oposta = d[3] end end
        local melhorOutra = nil
        for _, o in ipairs(porDir) do if o.dir ~= oposta and (not melhorOutra or o.nota > melhorOutra) then melhorOutra = o.nota end end
        if oposta ~= nil and melhorOutra then
            filtrar(function(o) return o.dir == oposta and o.nota < TD.ZOMBIE_VOLTA * melhorOutra end)
        end
    end
    local escolha = porDir[1]
    for _, o in ipairs(porDir) do   -- anti-samba: fica na direcao anterior se for quase tao boa
        if o.dir ~= nil and o.dir == ev.ultDir and o.dir ~= escolha.dir and o.nota >= TD.ZOMBIE_TEIMA * escolha.nota then escolha = o end
    end
    ev.ultDir = escolha.dir
    if escolha.dir == nil then return nil, "Parado (melhor lugar)" .. info end
    return escolha.dir, modo .. info
end

function TD.fugirZombies(ev, zs)
    local p = player:getPosition()
    if not p then return end
    if g_game.getAttackingCreature() and g_game.cancelAttack then g_game.cancelAttack() end
    local t = agoraMs()
    if andando() or t < (ev.proxPasso or 0) then return end
    ev.proxPasso = t + 100
    TD.cacheTiles = {}
    local t0 = relogioMs()
    local ok, dir, motivo = pcall(TD.decidirFugaZombie, ev, p, zs)
    TD.cacheTiles = nil
    -- v5.6: quanto o calculo da fuga demorou (o client nao desenha enquanto calcula): aparece no painel
    if t0 then
        ev.calcMs = relogioMs() - t0
        if ev.calcMs > (ev.calcMax or 0) then ev.calcMax = ev.calcMs end
    end
    if not ok then
        ev.fugaEstado = "Erro: " .. tostring(dir)
        return
    end
    ev.fugaEstado = motivo
    if dir ~= nil then
        TD.passoProprioAte = t + 600
        g_game.walk(dir)
    end
end

-- SNOWBALL WAR: alinha com um player (mesma linha/coluna), vira pra ele e "!snowball atirar"
TD.SNOW = {
    sala = {x1 = 19001, x2 = 19007, y1 = 19238, y2 = 19244, z = 6}, -- sala de espera
    alcance = 4,          -- a bola vai mais longe, mas ate 4 sqm e garantido
    visao = 15,           -- so sai da rota PRINCIPAL pra cacar player a ate essa distancia
    paradoMs = 500,       -- player parado ha pelo menos isso = alvo (em movimento e ignorado)
    intervalo = 1000,     -- ms entre tiros (ajustar no teste)
    recarregarCom = 0,    -- vai no gerador quando as bolas chegarem nisso
    telaSegura = {7, 5},  -- v5.6: sqm ate essa distancia (x, y) com certeza aparece na tela (pra esquecer lembrado)
}
local DIR4 = {{0, -1, North or 0}, {1, 0, East or 1}, {0, 1, South or 2}, {-1, 0, West or 3}}

function TD.naSalaSnow(p)
    local s = TD.SNOW.sala
    return p and p.z == s.z and p.x >= s.x1 and p.x <= s.x2 and p.y >= s.y1 and p.y <= s.y2
end

-- ZOMBIE: quadrado de entrada da arena (4 gotos 18965,18943 / 18964,18951 / 18981,18952 / 18982,18945, z7).
-- Pisou aqui = entrou no Zombie: a rota do painel desliga e so a fuga anda.
TD.ZOMBIE_ENTRADA = {x1 = 18964, x2 = 18982, y1 = 18943, y2 = 18952, z = 7}
-- v5.6: assim que entra, sai do bolo de player (todo mundo cai empilhado): vai pra 1 desses sqm, escolhido
-- aleatorio entre os livres (ocupado = tenta outro). Uma vez so: chegou, deu o tempo ou apareceu zombie = desliga
-- de vez (deixar ativo brigava com a fuga).
TD.ZOMBIE_SAIDAS = {
    {18976, 18950, 7}, {18976, 18948, 7}, {18975, 18951, 7}, {18977, 18951, 7},
    {18974, 18950, 7}, {18973, 18951, 7}, {18979, 18950, 7},
}
TD.ZOMBIE_SAIDA_MAX_MS = 8000   -- nao conseguiu chegar nesse tempo: fica onde esta

function TD.escolherSaidaZombie(ev)
    ev.zSaidaTentadas = ev.zSaidaTentadas or {}
    local livres = {}
    for _, w in ipairs(TD.ZOMBIE_SAIDAS) do
        local q = {x = w[1], y = w[2], z = w[3]}
        local k = q.x .. "," .. q.y
        if not ev.zSaidaTentadas[k] and TD.analisarTile(q).tipo == "livre" then table.insert(livres, q) end
    end
    if #livres == 0 then return nil end
    local ok, i = pcall(math.random, #livres)   -- sem math.random: pega o primeiro livre
    return livres[ok and i or 1]
end

-- true = ainda saindo do bolo (o ciclo do zombie para aqui)
function TD.sairDoBoloZombie(ev, p, t)
    if ev.zSaida == false then return false end
    ev.zSaidaAte = ev.zSaidaAte or t + TD.ZOMBIE_SAIDA_MAX_MS
    if t > ev.zSaidaAte then ev.zSaida = false return false end
    if not ev.zSaida then
        ev.zSaida = TD.escolherSaidaZombie(ev)
        if not ev.zSaida then ev.zSaida = false return false end
        TD.logEv("Zombie: saindo do bolo para " .. ev.zSaida.x .. ", " .. ev.zSaida.y .. ".")
    end
    if mesmaPos(p, ev.zSaida) then
        ev.zSaida = false
        TD.caminho, TD.destinoAtual = nil, nil
        if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
        TD.logEv("Zombie: saiu do bolo. Parado esperando.")
        return false
    end
    if TD.analisarTile(ev.zSaida).tipo ~= "livre" then
        -- ocupou no caminho: marca e escolhe outro no proximo ciclo
        ev.zSaidaTentadas[ev.zSaida.x .. "," .. ev.zSaida.y] = true
        ev.zSaida = nil
        return true
    end
    ev.fugaEstado = "Saindo do bolo de player"
    TD.irPara(ev.zSaida)
    return true
end

function TD.naEntradaZombie(p)
    local s = TD.ZOMBIE_ENTRADA
    return p and p.z == s.z and p.x >= s.x1 and p.x <= s.x2 and p.y >= s.y1 and p.y <= s.y2
end

-- FIRESTORM: arena = retangulo dos 4 cantos (18957,18817 / 18968,18824, z7). Dentro dela roda a PRINCIPAL.
TD.FIRE_ARENA = {x1 = 18957, x2 = 18968, y1 = 18817, y2 = 18824, z = 7}
function TD.naArenaFire(p)
    local s = TD.FIRE_ARENA
    return p and p.z == s.z and p.x >= s.x1 and p.x <= s.x2 and p.y >= s.y1 and p.y <= s.y2
end

-- direcao para atirar de p no alvo: alinhado, no alcance e sem parede no meio
local function direcaoTiro(p, alvo)
    if p.z ~= alvo.z or (p.x ~= alvo.x and p.y ~= alvo.y) then return nil end
    local d = dist(p, alvo)
    if d == 0 or d > TD.SNOW.alcance then return nil end
    local dx = alvo.x > p.x and 1 or (alvo.x < p.x and -1 or 0)
    local dy = alvo.y > p.y and 1 or (alvo.y < p.y and -1 or 0)
    for k = 1, d - 1 do
        local tipo = TD.analisarTile({x = p.x + dx * k, y = p.y + dy * k, z = p.z}).tipo
        if tipo == "parede" or tipo == "barreira" then return nil end
    end
    if dx == 0 then return dy < 0 and (North or 0) or (South or 2) end
    return dx < 0 and (West or 3) or (East or 1)
end

-- so players PARADOS: em movimento e dificil de acertar, entao ignora
-- v5.6: quase todo mundo fica AFK. ev.snowMem lembra onde vi player PARADO (mesmo depois de sair da tela):
-- sem alvo na tela, vai nele em vez de andar a rota (sim testes/snow: 27/48 -> 42/48 vitorias).
function TD.playersSnow(ev, p, t)
    ev.snowPos = ev.snowPos or {}
    ev.snowMem = ev.snowMem or {}
    local vistos = {}
    local lista, total = {}, 0
    for _, spec in ipairs(getSpectators()) do
        local okP, ehP = pcall(function() return spec:isPlayer() end)
        if okP and ehP and spec ~= player then
            local sp = spec:getPosition()
            if sp and sp.z == p.z then
                total = total + 1
                local id = spec:getId()
                local r = ev.snowPos[id]
                if not r or not mesmaPos(r.pos, sp) then
                    r = {pos = {x = sp.x, y = sp.y, z = sp.z}, desde = t}
                    ev.snowPos[id] = r
                end
                local okW, anda = pcall(function() return spec:isWalking() end)
                local parado = not (okW and anda) and t - r.desde >= TD.SNOW.paradoMs
                vistos[id] = sp
                if parado then ev.snowMem[id] = r.pos elseif okW and anda then ev.snowMem[id] = nil end
                if parado and dist(p, sp) <= TD.SNOW.visao then
                    table.insert(lista, {c = spec, pos = sp, d = dist(p, sp)})
                end
            end
        end
    end
    -- lembrado num sqm que esta na tela e ele nao esta mais la (levou bola/saiu): esquece
    local tx, ty = TD.SNOW.telaSegura[1], TD.SNOW.telaSegura[2]
    for id, q in pairs(ev.snowMem) do
        if q.z ~= p.z or (math.abs(q.x - p.x) <= tx and math.abs(q.y - p.y) <= ty and not mesmaPos(vistos[id], q)) then
            ev.snowMem[id] = nil
        end
    end
    ev.nPlayers, ev.nParados = total, #lista
    table.sort(lista, function(a, b) return a.d < b.d end)
    return lista
end

-- player parado lembrado mais perto (fora da tela)
function TD.lembradoSnow(ev, p)
    local melhor, md = nil, 999
    for _, q in pairs(ev.snowMem or {}) do
        local d = dist(p, q)
        if d < md then melhor, md = q, d end
    end
    return melhor
end

local function falar(msg)
    if say and pcall(function() say(msg) end) then return end
    pcall(function() g_game.talk(msg) end)
end

-- gerador (posicoes dadas pelo usuario): fica em pe no sqm da frente e da "use" no gerador.
-- Sem bolas: vai direto pra la, usa ate TD.SNOW.usosGerador vezes (10 bolas por uso) e volta pro jogo.
TD.SNOW.geradorPe = {x = 19004, y = 19243, z = 7}
TD.SNOW.gerador = {x = 19004, y = 19242, z = 7}
TD.SNOW.usosGerador = 2   -- sim testes/snow (v5.6): 4 por ida perdeu ~4 pontos (sobra bola no fim)

-- sai da rota PRINCIPAL pra cacar/ir no gerador: para o autoWalk do goto na hora (sem esperar chegar nele)
local function pausarRotaSnow(ev)
    if ev.cacando then return end
    ev.cacando = true -- ao voltar, retoma a rota pelo goto mais perto
    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
    TD.caminho, TD.destinoAtual = nil, nil
end

function TD.recarregarSnow(ev, p, t)
    local pe, g = TD.SNOW.geradorPe, TD.SNOW.gerador
    ev.snowEstado = "Indo no gerador"
    pausarRotaSnow(ev)
    -- da pra usar o gerador de QUALQUER sqm colado nele (frente ou lados): vai no sqm livre colado mais perto.
    -- Todos ocupados: tenta o da frente (pe). Ja colado: usa daqui mesmo.
    if dist(p, g) > 1 then
        local alvo, md = pe, 99
        for _, d in ipairs(DELTAS) do
            local q = {x = g.x + d[1], y = g.y + d[2], z = g.z}
            if TD.analisarTile(q).tipo == "livre" and dist(p, q) < md then alvo, md = q, dist(p, q) end
        end
        return TD.irPara(alvo)   -- v5.6: autoWalk direto pro gerador (antes 1 passo por vez)
    end
    if t < (ev.proxUso or 0) then return end
    ev.usos = ev.usos or 0
    if ev.usos >= TD.SNOW.usosGerador then
        -- ja usou o maximo: volta pro jogo (bolas = desconhecido ate o proximo "Restam Nx")
        ev.usos, ev.bolas = nil, nil
        return
    end
    ev.proxUso = t + 1500
    local tile = g_map.getTile(g)
    local coisa = tile and tile:getTopUseThing()
    if coisa then
        g_game.use(coisa)
        ev.usos = ev.usos + 1
        TD.logEv("Snowball: usando o gerador (" .. ev.usos .. "/" .. TD.SNOW.usosGerador .. ").")
        -- ultimo uso: volta pro jogo na hora (nao espera mais 1,5s parado)
        if ev.usos >= TD.SNOW.usosGerador then ev.usos, ev.bolas = nil, nil end
    end
end

function TD.passoSnow(ev, p, t)
    if (ev.bolas and ev.bolas <= TD.SNOW.recarregarCom) or ev.usos then
        if t >= (ev.geradorAte or 0) then return TD.recarregarSnow(ev, p, t) end
        -- sem bolas e sem pontos: nao adianta cacar, so segue a rota (tenta o gerador de novo em 1 min)
        ev.usos = nil
        ev.snowEstado = "Sem bolas (sem pontos): seguindo a rota"
        return "rota"
    end
    local players = TD.playersSnow(ev, p, t)
    -- 1) ja alinhado com alguem: vira e atira
    for _, a in ipairs(players) do
        local dir = direcaoTiro(p, a.pos)
        if dir then
            ev.alvoSnow = TD.nomeLimpo(a.c:getName())
            ev.snowEstado = "Atirando"
            pausarRotaSnow(ev)
            if andando() then
                -- v5.6: andando pro proximo e alinhou com alguem no caminho: para e atira (antes passava direto)
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                TD.caminho, TD.destinoAtual = nil, nil
                return
            end
            local okD, olhando = pcall(function() return player:getDirection() end)
            if okD and olhando ~= dir then
                if t >= (ev.proxVirar or 0) then
                    ev.proxVirar = t + 150
                    g_game.turn(dir)
                end
                return
            end
            if t >= (ev.proxTiro or 0) then
                ev.proxTiro = t + TD.SNOW.intervalo
                falar("!snowball atirar")
                ev.tiros = (ev.tiros or 0) + 1
            end
            return
        end
    end
    -- 2) anda ate o sqm alinhado mais perto de algum player
    local melhor, melhorCusto = nil, 999
    for i = 1, math.min(#players, 6) do
        local a = players[i]
        for _, v in ipairs(DIR4) do
            for k = 1, TD.SNOW.alcance do
                local tp = {x = a.pos.x + v[1] * k, y = a.pos.y + v[2] * k, z = a.pos.z}
                local tipo = TD.analisarTile(tp).tipo
                if tipo == "parede" or tipo == "barreira" then break end
                if tipo == "livre" and dist(p, tp) < melhorCusto then melhor, melhorCusto = tp, dist(p, tp) end
            end
        end
    end
    ev.alvoSnow = nil
    if not melhor then
        local lembrado = TD.lembradoSnow(ev, p)
        if lembrado then
            ev.snowEstado = "Indo no player parado que vi"
            pausarRotaSnow(ev)
            return TD.irPara(lembrado)
        end
        -- ninguem pra cacar perto: segue a rota PRINCIPAL do painel
        ev.snowEstado = "Rota (" .. ((ev.nPlayers or 0) == 0 and "sem players" or "ninguem parado a " .. TD.SNOW.visao .. " sqm") .. ")"
        return "rota"
    end
    ev.snowEstado = "Alinhando com player"
    pausarRotaSnow(ev)
    -- v5.6: autoWalk direto (andar 1 passo e esperar terminar pra calcular o proximo deixava ele lento)
    TD.irPara(melhor)
end

function TD.cicloSnow(ev)
    local p = player:getPosition()
    if not p then return end
    if g_game.getAttackingCreature() and g_game.cancelAttack then g_game.cancelAttack() end
    TD.cacheTiles = {}
    local ok, r = pcall(TD.passoSnow, ev, p, agoraMs())
    TD.cacheTiles = nil
    if not ok then error(r) end
    if r ~= "rota" or #(TD.ROTAS.PRINCIPAL or {}) == 0 then return end
    if ev.cacando or TD.rota ~= "PRINCIPAL" then
        -- voltou da caca (ou acabou de comecar): retoma pelo goto MAIS PERTO da PRINCIPAL
        ev.cacando = nil
        TD.entrarNaRota("PRINCIPAL")
        -- andou mais de 4 sqm cacando: sem isso a rota achava que foi teleporte e pulava 1 goto
        TD.ultimaPosRota = p
    end
    TD.andarRota()
end

-- manual = desligado no botao EVENTOS: CaveBot e TargetBot do vBot ficam DESLIGADOS (voce liga quando quiser).
-- Fim automatico (venceu, perdeu, horario, morreu...): religa os dois e vai pra label final.
function TD.terminarEvento(motivo, irFim, manual)
    if not TD.evRun then return end
    TD.evTipoFim = TD.evRun.tipo
    TD.evRun = nil
    TD.eventoChamado = nil
    cfg.eventosAtivo = false -- so volta a ligar clicando ou pela agenda
    TD.marcarJanelasFeitas() -- a agenda nao religa o mesmo evento no mesmo horario
    if not TD.ativo then TD.estado = "DESLIGADO" end
    TD.evAntes = nil
    if g_game.cancelAttack then pcall(g_game.cancelAttack) end
    if g_game.cancelFollow then pcall(g_game.cancelFollow) end
    -- auto chase desligado ao terminar qualquer evento (so o Island liga)
    if g_game.setChaseMode then pcall(function() g_game.setChaseMode(0) end) end
    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
    if manual then
        -- desligou na mao: nao religa nada do vBot (religar aqui fazia o CaveBot do vBot brigar com o painel)
        if CaveBot and CaveBot.setOff then pcall(CaveBot.setOff) end
        TD.logEv("Desligado na mao: CaveBot e TargetBot do bot continuam DESLIGADOS.")
    else
        -- fim automatico: SEMPRE religa CaveBot e TargetBot (antes so religava o target se estava ligado no
        -- inicio, e as vezes ele ja estava desligado nessa hora -> ficava sem target depois do evento)
        if TargetBot and TargetBot.setOn then pcall(TargetBot.setOn) end
        local labelFim = TD.labelFimEvento and TD.labelFimEvento("ev_" .. (TD.evTipoFim or "island")) or cfg.evLabelFim
        if CaveBot and CaveBot.setOn then pcall(CaveBot.setOn) end
        if irFim and labelFim ~= "" then pcall(CaveBot.gotoLabel, labelFim) end
        TD.logEv("Fim automatico: CaveBot e TargetBot do bot LIGADOS" .. ((irFim and labelFim ~= "") and (", indo pra label '" .. labelFim .. "'.") or "."))
    end
    if TD.pintarEventos then pcall(TD.pintarEventos) end
    local info = TD.EVENTOS["ev_" .. (TD.evTipoFim or "")] or {titulo = "Evento", curto = "Evento"}
    -- motivo que ja comeca com o nome do evento ("FireStorm: atingido") nao repete o nome
    local jaTemNome = motivo:sub(1, #info.curto + 1):lower() == (info.curto .. ":"):lower()
    TD.evUltimo = (jaTemNome and motivo or (info.titulo .. ": " .. motivo)) .. " (" .. os.date("%H:%M") .. ")"
    TD.logEv("Evento encerrado: " .. motivo .. ".")
end

function TD.acharTpIsland(centro, raio)
    if not centro or not g_map then return nil end
    raio = raio or 4
    local melhor, melhorD = nil, 99
    for dx = -raio, raio do
        for dy = -raio, raio do
            local pos = {x = centro.x + dx, y = centro.y + dy, z = centro.z}
            local tile = g_map.getTile(pos)
            if tile then
                local ok, itens = pcall(function() return tile:getItems() end)
                for _, it in ipairs(ok and itens or {}) do
                    if it:getId() == TD.ISLAND.tp then
                        local d = math.max(math.abs(dx), math.abs(dy))
                        if d < melhorD then melhor, melhorD = pos, d end
                    end
                end
            end
        end
    end
    return melhor
end

function TD.pisarEm(alvo, t)
    local p = player:getPosition()
    if not p or not alvo then return end
    local d = dist(p, alvo)
    if d == 0 then return end
    if d == 1 then
        if t >= (TD.evPassoAte or 0) then
            local dir = DIR_DELTA[(alvo.x - p.x) .. "," .. (alvo.y - p.y)]
            if dir ~= nil then
                TD.evPassoAte = t + 300
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                g_game.walk(dir)
            end
        end
        return
    end
    TD.irParaCaminho(alvo)
end

function TD.cicloIsland()
    local ev = TD.evRun
    local p = player:getPosition()
    if not p then return end
    local t = agoraMs()
    local okH, hp = pcall(function() return player:getHealth() end)
    if okH and hp and hp <= 0 then return TD.terminarEvento("morreu", false) end
    if os.time() - ev.inicio > 45 * 60 then return TD.terminarEvento("passou de 45 min", true) end

    local antes = ev.ultimaPos
    ev.ultimaPos = {x = p.x, y = p.y, z = p.z}
    local pulou = antes and (antes.z ~= p.z or math.max(math.abs(antes.x - p.x), math.abs(antes.y - p.y)) > 5)

    -- Island Death morreu (mensagem do servidor): sai pelo TP e so entao encerra
    if ev.morteFinal then
        if pulou then return TD.terminarEvento("Island Death concluido (saiu pelo TP)", true) end
        -- o TP de saida leva pra cidade (PZ): pisou na PZ = ja esta fora, pode encerrar
        if TD.emPz and TD.emPz() then return TD.terminarEvento("Island Death concluido (chegou na PZ)", true) end
        if os.time() - ev.morteFinal > 90 then
            return TD.terminarEvento("Island Death concluido (nao consegui sair pelo TP em 90s)", true)
        end
        if ev.fase ~= "TP" then
            ev.fase, ev.mortePos, ev.tpDesde = "TP", ev.mortePos or ev.bossPos or {x = p.x, y = p.y, z = p.z}, t
        end
    end

    if TD.naSalaIsland(p) and not ev.morteFinal then
        ev.fase = "SALA"
        return
    end

    if pulou and ev.fase == "TP" then
        if ev.bossNome == "island death" then return TD.terminarEvento("Island Death concluido", true) end
        ev.fase = "BOSS"
        ev.mortePos, ev.bossPos = nil, nil
    elseif ev.fase == "SALA" then
        ev.fase = "BOSS"
    end

    local boss = nil
    for _, spec in ipairs(getSpectators()) do
        local okM, ehM = pcall(function() return spec:isMonster() end)
        if okM and ehM and (spec:getHealthPercent() or 0) > 0 then
            local nome = spec:getName():lower()
            for i, b in ipairs(TD.ISLAND.bosses) do
                if nome:find(b, 1, true) then boss = spec ev.bossIdx = i ev.bossNome = b break end
            end
            if boss then break end
        end
    end

    if boss then
        ev.fase = "BOSS"
        ev.bossPos = boss:getPosition()
        ev.bossVisto = t
        if g_game.getAttackingCreature() ~= boss and t >= (ev.ataqueAte or 0) then
            ev.ataqueAte = t + 150
            g_game.attack(boss)
        end
        if g_game.getFollowingCreature and g_game.getFollowingCreature() ~= boss and g_game.getAttackingCreature() ~= boss then
            pcall(function() g_game.follow(boss) end)
        end
        return
    end

    if ev.fase == "BOSS" and ev.bossPos and t - (ev.bossVisto or 0) > 300 then
        ev.fase = "TP"
        ev.mortePos = ev.bossPos
        ev.tpDesde = t
        TD.logEv((ev.bossNome or "Boss") .. " morreu. Indo para o TP.")
    end

    if ev.fase == "TP" then
        local tp = TD.acharTpIsland(ev.mortePos) or TD.acharTpIsland(p, 8) or ev.mortePos
        ev.tpPos = tp
        TD.pisarEm(tp, t)
        if tp and dist(p, tp) == 0 and t - (ev.tpDesde or t) > 4000 then
            local alt = TD.acharTpIsland(p)
            if alt and dist(p, alt) > 0 then TD.pisarEm(alt, t) end
        end
    end
end

macro(50, TD.protegido("evento", function()
    if not TD.evRun then
        if cfg.eventosAtivo and not TD.ativo and TD.naSalaIsland(player:getPosition()) then TaskDemon.iniciarEvento("island") end
        return
    end
    if TD.evRun.tipo == "island" and not TD.evRun.rota then TD.cicloIsland() end
end))

macro(50, TD.protegido("eventoRota", function()
    local ev = TD.evRun
    if not ev or not ev.rota then return end
    local pAgora = player:getPosition()
    local pAntes = ev.posAntes
    ev.posAntes = pAgora and {x = pAgora.x, y = pAgora.y, z = pAgora.z}
    -- entrou no TP do evento (vale pra todos): estava colado nele e a posicao pulou longe
    local entrouTp = pAntes and pAgora and dist(pAntes, TD.TP_EVENTO) <= 2
        and (pAntes.z ~= pAgora.z or math.max(math.abs(pAntes.x - pAgora.x), math.abs(pAntes.y - pAgora.y)) > 8)
        and dist(pAgora, TD.TP_EVENTO) > 20   -- caiu longe do TP de verdade (nao foi so empurrado)
        and not TD.noBuracoEvento(pAgora)     -- v5.5: cair na escada (andar 8) NAO e entrar no TP
        and agoraMs() >= (ev.tpThaisAte or 0)  -- v5.5: o pulo do "!tp thais" NAO e entrar no TP
        and ev.portalVisto                     -- v5.5: o portal (1949) estava no sqm; sem ele o sqm leva pro templo
        and not TD.naVoltaTpEvento(pAgora)     -- v5.5: o sqm sem portal joga no corredor: NAO e entrar no TP
    -- v5.5: guarda se o portal do evento esta aberto (so da pra ver de perto)
    if pAgora and dist(pAgora, TD.TP_EVENTO) <= 2 then ev.portalVisto = TD.portalEventoAberto() end
    -- o 1o pulo depois do "!tp thais" foi ele: libera a deteccao pro TP de verdade
    if ev.tpThaisAte and pAntes and pAgora and (pAntes.z ~= pAgora.z
        or math.max(math.abs(pAntes.x - pAgora.x), math.abs(pAntes.y - pAgora.y)) > 8) then
        ev.tpThaisAte = nil
    end
    if entrouTp and not ev.dentro then
        ev.dentro = true
        TD.logEv("Entrou no TP do evento (" .. pAgora.x .. ", " .. pAgora.y .. ", " .. pAgora.z .. ").")
    end
    if ev.tipo == "island" and pAgora then
        if entrouTp then
            local sala = {x1 = pAgora.x - 8, x2 = pAgora.x + 8, y1 = pAgora.y - 6, y2 = pAgora.y + 6, z = pAgora.z}
            if TD.salaIslandValida(sala) then
                cfg.islandSala = sala
                TD.logEv("Sala do Island aprendida.")
            end
        end
        if entrouTp or TD.naSalaIsland(pAgora) then
            -- os gotos trouxeram ate a sala: a automacao do Island assume daqui
            TD.evRun = nil
            return TaskDemon.iniciarEvento("island")
        end
    end
    local okH, hp = pcall(function() return player:getHealth() end)
    if okH and hp and hp <= 0 then return TD.terminarEvento("morreu", false) end
    if ev.janela and ev.janela.comFim and not TD.janelaAgora("ev_" .. ev.tipo) then
        return TD.terminarEvento("horario acabou", true)
    end
    if os.time() - ev.inicio > 45 * 60 then return TD.terminarEvento("passou de 45 min", true) end
    -- chegou tarde e o TP ja fechou: nao fica forcando o SOUTH ate os 45 min, volta pra hunt
    if not ev.dentro and os.time() - ev.inicio > TD.EVENTO_ESPERA_TP_MIN * 60 then
        return TD.terminarEvento("nao conseguiu entrar no TP em " .. TD.EVENTO_ESPERA_TP_MIN .. " min (fechou?)", true)
    end
    -- v5.5: 10s sem pisar no sqm do TP: "!tp thais" (ver TD.TP_THAIS_SEG)
    if not ev.dentro and pAgora then
        local t = agoraMs()
        -- pisou no sqm do TP: esta conseguindo chegar, zera a contagem. Sem portal o sqm teleporta na hora pro
        -- corredor (o char nunca aparece EM CIMA dele): estava colado no sqm e caiu no corredor = pisou.
        local pisouSemPortal = pAntes and dist(pAntes, TD.TP_EVENTO) <= 1 and TD.naVoltaTpEvento(pAgora)
        if pisouSemPortal then TD.logEv("Pisou no sqm do TP (sem portal, voltou pro corredor): contagem zerada.") end
        if pisouSemPortal or mesmaPos(pAgora, TD.TP_EVENTO) then ev.semTpDesde = t end
        ev.semTpDesde = ev.semTpDesde or t
        if t - ev.semTpDesde >= TD.TP_THAIS_SEG * 1000 then
            ev.semTpDesde = t
            ev.tpThaisAte = t + 15000
            if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            local okSay = say and pcall(function() say("!tp thais") end)
            local okTalk = not okSay and g_game.talk and pcall(function() g_game.talk("!tp thais") end)
            TD.logEv(TD.TP_THAIS_SEG .. "s sem pisar no sqm do TP: !tp thais ("
                .. (okSay and "say" or (okTalk and "talk" or "FALHOU")) .. ").")
        end
    end
    -- v5.5: caiu na escada do lado do TP (andar 8): vai pro pe da escada e pisa NORTH ate voltar pra cima
    if not ev.dentro and TD.noBuracoEvento(pAgora) then
        if ev.fase ~= "SUBINDO ESCADA" then TD.logEv("Caiu na escada do TP: voltando pra cima.") end
        ev.fase = "SUBINDO ESCADA"
        local s = TD.SUBIDA_BURACO_EVENTO
        if not mesmaPos(pAgora, s) then return TD.irPara(s) end
        local t = agoraMs()
        if t >= (ev.proxSubida or 0) then
            ev.proxSubida = t + 1000
            if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            TD.caminho = nil
            TD.passoProprioAte = t + 600
            g_game.walk(TD.LADOS.N)
        end
        return
    end
    if ev.fase == "SUBINDO ESCADA" then ev.fase = "ROTA" end
    if ev.tipo == "firestorm" and pAgora and TD.naArenaFire(pAgora) and not ev.dentro then
        ev.dentro = true
        TD.logEv("FireStorm: entrou na arena.")
    end
    if ev.tipo == "firestorm" and ev.dentro and TD.rota ~= "PRINCIPAL" and #(TD.ROTAS.PRINCIPAL or {}) > 0 then
        TD.entrarNaRota("PRINCIPAL")
        TD.logEv("FireStorm: rodando a PRINCIPAL.")
    end
    if ev.tipo == "zombie" then
        -- Fora da arena: so o CAMINHO (forca entrar no TP). Pisou no quadrado de entrada (ou o TP do evento
        -- levou): marca ev.naArena e a rota do painel PARA de vez (nao briga com a fuga). Dentro: espera parado
        -- e foge quando aparece zombie (ou chega a mensagem de inicio).
        local p = pAgora
        if not ev.naArena and p then
            if ev.dentro or TD.naEntradaZombie(p) then
                ev.naArena, ev.dentro, ev.fase, ev.fugaEstado = true, true, "ESPERA", "Esperando comecar"
                TD.caminho, TD.destinoAtual = nil, nil
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                TD.logEv("Zombie: entrou na arena. Rota do painel desligada; so a fuga a partir daqui.")
            end
        end
        if not ev.naArena then return TD.andarRota() end
        local zs = p and TD.zombiesNaTela(p) or {}
        ev.zombies = #zs
        -- v5.7: "Disputar" desmarcado na aba EVENTOS (makers/MC): entrou na arena = fica parado, nao foge
        if not TD.zombieDisputar() then
            ev.fugaEstado = "Parado (Disputar desmarcado)"
            return
        end
        if ev.fase ~= "FUGA" and #zs > 0 then
            ev.fase = "FUGA"
            if ev.zSaida then
                -- apareceu zombie no meio da saida do bolo: larga a saida, a fuga assume
                ev.zSaida = false
                TD.caminho, TD.destinoAtual = nil, nil
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            end
            ev.zSaida = false
        end
        if ev.fase ~= "FUGA" and p and TD.sairDoBoloZombie(ev, p, agoraMs()) then return end
        if ev.fase == "FUGA" then return TD.fugirZombies(ev, zs) end
        return
    elseif ev.tipo == "snowball" then
        -- na sala de espera: parado. Saiu da sala depois de entrar (ou ja esta na arena, perto da PRINCIPAL,
        -- ex.: ligou o evento la dentro): o jogo comecou -> PRINCIPAL + caca de player (TD.cicloSnow)
        local p = pAgora
        if entrouTp then ev.entrouSala = true end
        if TD.naSalaSnow(p) then
            ev.entrouSala, ev.dentro, ev.fase, ev.snowEstado = true, true, "ESPERA", "Esperando comecar"
            return
        end
        if not ev.jogando and (ev.entrouSala or TD.pertoDaRota("PRINCIPAL", TD.SNOW.visao)) then
            ev.dentro = true
            ev.jogando = true
            TD.logEv("Snowball: na arena. Seguindo a PRINCIPAL e cacando player a ate " .. TD.SNOW.visao .. " sqm.")
        end
        if ev.jogando then
            ev.fase = "JOGO"
            return TD.cicloSnow(ev)
        end
    end
    -- ja entrou: nunca mais anda a entrada (voltaria pro TP). Sem PRINCIPAL = fica parado la dentro.
    if ev.dentro and TD.rota == "CAMINHO" then return end
    -- perto do TP e ainda fora: FORCA o passo pro TP a cada 1s, igual pra todos os eventos (Island tambem).
    -- No ultimo sqm da entrada = SOUTH. Empurrado/sqm da frente ocupado (ja no ultimo goto, ate 2 sqm do TP):
    -- anda direto pro TP de onde estiver (qualquer lado/diagonal). Antes so forcava no sqm exato e, fora dele,
    -- o goto "exato" ocupado deixava ele parado num sqm pra sempre.
    local ult = TD.ENTRADA_EVENTO[#TD.ENTRADA_EVENTO]
    local tp = TD.TP_EVENTO
    -- so no FIM da entrada (goto 12): no goto 4 (mesmo sqm) a rota pisa 1x e segue a volta pelo leste
    local noUltimo = TD.wp >= #TD.ENTRADA_EVENTO and pAgora and pAgora.x == ult[1] and pAgora.y == ult[2] and pAgora.z == ult[3]
    local dx = pAgora and (tp.x - pAgora.x) or 0
    local dy = pAgora and (tp.y - pAgora.y) or 0
    local dTp = pAgora and pAgora.z == tp.z and math.max(math.abs(dx), math.abs(dy)) or 99
    -- ate 2 sqm do TP: anda pro TP. Video 14-22-54: a 2 sqm o passo "na direcao do TP" caiu na ESCADA do lado
    -- e ele ficou subindo/descendo. Agora: sqm que leva pra outro lugar fica proibido (aprende na 1a vez) e o
    -- passo so vai pra sqm livre e nao proibido.
    local pertoTp = TD.wp >= #TD.ENTRADA_EVENTO and dTp >= 1 and dTp <= 2
    -- passo forcado que levou pra outro andar/lugar sem ser o TP do evento (escada, buraco): nunca mais pisa ali
    ev.proibido = ev.proibido or {}
    if ev.passoForcado and pAntes and pAgora and not entrouTp and
        (pAntes.z ~= pAgora.z or math.max(math.abs(pAntes.x - pAgora.x), math.abs(pAntes.y - pAgora.y)) > 1) then
        local f = ev.passoForcado
        ev.proibido[f.x .. "," .. f.y .. "," .. f.z] = true
        TD.logEv("O sqm " .. f.x .. ", " .. f.y .. " leva pra outro lugar (escada?): nao piso mais nele.")
    end
    if pAntes and pAgora and not mesmaPos(pAntes, pAgora) then ev.passoForcado = nil end
    -- EM CIMA do TP e nao teleportou (pisou nele ainda fechado e ele abriu embaixo, ou foi empurrado pra cima):
    -- sai pra um sqm livre do lado (de preferencia a frente); no segundo seguinte o forcar abaixo pisa de novo.
    -- Antes: o sqm da frente ocupado deixava ele parado em cima do TP pra sempre.
    if not ev.dentro and TD.rota == "CAMINHO" and TD.wp >= #TD.ENTRADA_EVENTO and dTp == 0 then
        ev.fase = "FORCANDO"
        local t = agoraMs()
        if t >= (ev.proxForca or 0) then
            ev.proxForca = t + 1000
            -- so pros lados retos (frente primeiro): diagonal/tras podia ser escada
            for _, d in ipairs({"0,-1", "1,0", "-1,0"}) do
                local vx, vy = d:match("^(-?%d+),(-?%d+)$")
                local viz = {x = pAgora.x + tonumber(vx), y = pAgora.y + tonumber(vy), z = pAgora.z}
                if not ev.proibido[viz.x .. "," .. viz.y .. "," .. viz.z] and TD.analisarTile(viz).tipo == "livre" then
                    TD.logEv("Em cima do TP sem entrar: saindo 1 sqm pra pisar de novo.")
                    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                    TD.passoProprioAte = t + 600
                    ev.passoForcado = viz
                    g_game.walk(DIR_DELTA[d])
                    break
                end
            end
        end
        return
    end
    if not ev.dentro and TD.rota == "CAMINHO" and pAgora and (noUltimo or pertoTp) then
        ev.fase = "FORCANDO"
        local t = agoraMs()
        -- nao espera "parar de andar": um auto walk travado deixava andando() sempre true e ele nunca forcava
        if t >= (ev.proxForca or 0) then
            ev.proxForca = t + 1000
            ev.forcadas = (ev.forcadas or 0) + 1
            local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
            local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
            local dir, destino = nil, nil
            if noUltimo or dTp == 1 then
                dir, destino = noUltimo and TD.LADOS.S or DIR_DELTA[sx .. "," .. sy], {x = tp.x, y = tp.y, z = tp.z}
            else
                -- 2 sqm: diagonal pro TP; se for proibido/ocupado, tenta so o x ou so o y
                for _, o in ipairs({{sx, sy}, {sx, 0}, {0, sy}}) do
                    if o[1] ~= 0 or o[2] ~= 0 then
                        local q = {x = pAgora.x + o[1], y = pAgora.y + o[2], z = pAgora.z}
                        if not ev.proibido[q.x .. "," .. q.y .. "," .. q.z] and TD.analisarTile(q).tipo == "livre" then
                            dir, destino = DIR_DELTA[o[1] .. "," .. o[2]], q
                            break
                        end
                    end
                end
            end
            if ev.forcadas % 10 == 1 then
                TD.logEv("Forcando entrar no TP do evento (tentativa " .. ev.forcadas .. ", " .. dTp .. " sqm do TP).")
            end
            if dir ~= nil then
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
                TD.passoProprioAte = t + 600
                -- pisar no TP (destino = TP) nao conta como "escada": o detector de entrada cuida disso
                ev.passoForcado = (destino and not mesmaPos(destino, tp)) and destino or nil
                g_game.walk(dir)
            end
        end
        return
    end
    if ev.fase == "FORCANDO" then ev.fase = "ROTA" end
    TD.andarRota()
end))

function TD.macrosExternos()
    return {
        ["Auto Exori/SD"] = ubatuba,
        ["Auto Rune"] = autorune,
        ["Exori San"] = exorisan,
        ["Exori Con"] = exoricon,
    }
end

function TD.pausarExternos()
    if TD.externosAntes then return end
    TD.externosAntes = {}
    local nomes = {}
    for nome, m in pairs(TD.macrosExternos()) do
        if type(m) == "table" and m.isOn and m.setOn then
            local ok, ligado = pcall(function() return m.isOn() end)
            if ok and ligado then
                TD.externosAntes[nome] = true
                pcall(function() m.setOn(false) end)
                table.insert(nomes, nome)
            end
        end
    end
    if #nomes > 0 then TD.log("Target do bot pausado na task: " .. table.concat(nomes, ", ") .. ".") end
end

function TD.voltarExternos()
    if not TD.externosAntes then return end
    local lista = TD.macrosExternos()
    for nome in pairs(TD.externosAntes) do
        local m = lista[nome]
        if type(m) == "table" and m.setOn then pcall(function() m.setOn(true) end) end
    end
    TD.externosAntes = nil
end

macro(1000, function()
    if TD.ativo and not TD.cfgTarget().semMagia then
        TD.pausarExternos()
    else
        TD.voltarExternos()
    end
end)

function TD.ligar()
    if TD.ativo then return end
    TD.ativo = true
    cfg.eventosAtivo = false
    if CaveBot and CaveBot.isOn and CaveBot.isOn() then
        TD.caveBotEstava = true
        CaveBot.setOff()
    end
    if TargetBot and TargetBot.isOn then
        TD.targetBotEstava = TargetBot.isOn()
        if TargetBot.isOn() then TargetBot.setOff() end
    end
    if g_game.setChaseMode then g_game.setChaseMode(TaskDemon.modoDe() == "MELEE" and 1 or 0) end
    TD.fugindo = false
    TD.voltando = false
    if cfg.inicioTask == 0 then cfg.inicioTask = os.time() end

    TD.perfilAtivo = TD.perfilDaTarefa(cfg.tarefa)
    TD.ROTAS = cfg.perfis[TD.perfilAtivo]
    TD.log("Usando os gotos de '" .. TD.perfilAtivo .. "'.")
    TD.escolherRotaInicial()
    TD.estado = "ROTA " .. TD.rota
    TD.log("Task " .. TD.tarefaAtual().titulo .. " iniciada (" .. TD.progresso() .. "/" .. TD.metaDe() .. ").")
end

function TD.desligar(motivo)
    if TD.marcarQuadrado then TD.marcarQuadrado(nil) end
    if not TD.ativo then return end
    TD.ativo = false
    TD.voltarExternos()
    TD.alvo = nil
    TD.fugindo = false
    TD.voltando = false
    if g_game.cancelAttack then g_game.cancelAttack() end
    -- task OFF/terminou: desliga o auto chase (o MELEE liga) pra ele nao ficar salvo no cliente
    if g_game.setChaseMode then pcall(function() g_game.setChaseMode(0) end) end
    if TargetBot and TargetBot.setOn and TD.targetBotEstava then TargetBot.setOn() end
    TD.estado = motivo or "DESLIGADO"
    TD.log("Task parada: " .. (motivo or "manual"))
end

function TD.finalizar(motivo)
    if TD.janelaChave and TD.progresso() >= TD.metaDe() then cfg.concluidas[TD.janelaChave] = true end

    if TD.progresso() >= TD.metaDe() and cfg.inicioTask > 0 then
        local gasto = os.time() - cfg.inicioTask
        local t = cfg.tempos[cfg.tarefa] or {}
        t.ultimo = gasto
        if not t.melhor or gasto < t.melhor then t.melhor = gasto end
        cfg.tempos[cfg.tarefa] = t
        TD.log("Tempo da task: " .. formatarTempo(gasto) .. " (melhor: " .. formatarTempo(t.melhor) .. ")")
    end
    cfg.inicioTask = 0
    TD.origemAgenda = nil
    TD.alvo = nil
    TD.fugindo = false
    if g_game.cancelAttack then g_game.cancelAttack() end

    if TD.ativo and TD.posDP then
        TD.voltando = true
        TD.voltandoDesde = os.time()
        TD.voltaFeita = true
        local cam = TD.ROTAS and TD.ROTAS.CAMINHO or {}
        local dp = TD.ROTAS and TD.ROTAS.DP or {}
        TD.rotaVolta = nil
        TD.voltaPeloDP = #dp > 0 and TD.VOLTA_PELO_DP[cfg.tarefa] or false
        if TD.voltaPeloDP then
            -- v5.8: rota DP com gotos = percurso ate o DP (ultimo goto = dentro do DP). Comeca no goto mais
            -- perto de onde terminou e segue ate o fim (antes so voltava pelo CAMINHO e se perdia longe dele)
            -- v5.9: so nas tasks de TD.VOLTA_PELO_DP (Angry Bird); as outras voltam pelo CAMINHO como antes
            TD.rotaVolta = {}
            for i = 1, #dp do TD.rotaVolta[i] = dp[i] end
            local u = dp[#dp]
            TD.posDP = {x = u[1], y = u[2], z = u[3]}
        elseif #cam > 0 and not TD.pertoDaRota("DP", 3) then
            TD.rotaVolta = {}
            for i = #cam, 1, -1 do table.insert(TD.rotaVolta, cam[i]) end
        end
        if TD.rotaVolta then
            TD.rota = "VOLTA"
            local p = player:getPosition()
            local melhor, melhorD = 1, 99999
            for i, w in ipairs(TD.rotaVolta) do
                local d = dist(p, {x = w[1], y = w[2], z = w[3]})
                if d < melhorD then melhor, melhorD = i, d end
            end
            TD.wp = melhor
            TD.voltaFeita = false
        end
        TD.destinoAtual = nil
        TD.estado = "VOLTANDO AO DP"
        TD.log((motivo or "Task concluida") .. ". Voltando ao DP.")
    else
        TD.entregarAoBot(motivo)
    end
end

function TD.entregarAoBot(motivo)
    TD.voltando = false
    TD.destinoAtual = nil
    if player.stopAutoWalk then player:stopAutoWalk() end
    TD.desligar(motivo or "TASK CONCLUIDA")
    TD.caveBotEstava = nil
    if cfg.cb.hunt ~= "" then TD.trocarCaveBot(cfg.cb.hunt) end
    if CaveBot and CaveBot.setOn then CaveBot.setOn() end
    if cfg.labelVolta ~= "" then CaveBot.gotoLabel(cfg.labelVolta) end
    TD.log("No DP. CaveBot do bot ligado" ..
        (cfg.cb.hunt ~= "" and (" com '" .. cfg.cb.hunt .. "'") or "") ..
        (cfg.labelVolta ~= "" and (", label '" .. cfg.labelVolta .. "'.") or "."))
end

function TD.iniciar(tarefa, labelVolta)
    if tarefa and TD.TAREFAS[tarefa] then cfg.tarefa = tarefa end
    if labelVolta then cfg.labelVolta = labelVolta end
    if TD.progresso() >= TD.metaDe() then
        TD.log("Task " .. TD.tarefaAtual().titulo .. " ja estava concluida.")
        if cfg.labelVolta ~= "" then CaveBot.gotoLabel(cfg.labelVolta) end
        return true
    end
    if CaveBot and CaveBot.setOff then CaveBot.setOff() end
    cfg.inicioTask = os.time()
    cfg.principalDesde = os.time()
    local p = player:getPosition()
    TD.posDP = p and {x = p.x, y = p.y, z = p.z} or nil
    TD.ligar()
    return true
end

macro(50, TD.protegido("alvos", function()
    if not TD.ativo then return end
    local agora = os.time()

    if TD.voltando then
        TD.estado = "VOLTANDO AO DP"
        return
    end

    if TD.progresso() >= TD.metaDe() then
        TD.finalizar("Task concluida")
        return
    end

    if TD.fugindo then
        TD.estado = "FUGINDO PELO DP"
        if g_game.getAttackingCreature() and g_game.cancelAttack then g_game.cancelAttack() end
        return
    end

    local lista = TD.listarAlvos()
    TD.hpVisto = TD.hpVisto or {}
    for _, item in ipairs(lista) do
        local okI, idI = pcall(function() return item.c:getId() end)
        if okI and TD.hpVisto[idI] == nil then
            local okH, hpI = pcall(function() return item.c:getHealthPercent() end)
            if okH then TD.hpVisto[idI] = hpI end
        end
    end

    local p0 = player:getPosition()
    local presoPorBicho = nil
    if p0 and TD.analisarTile and g_map then
        local livres, melhor, melhorD = 0, nil, 99999
        local destino = wpPos(TD.wp)
        for _, d in ipairs({{0,-1},{1,0},{0,1},{-1,0},{1,-1},{1,1},{-1,1},{-1,-1}}) do
            local tp = {x = p0.x + d[1], y = p0.y + d[2], z = p0.z}
            local info = TD.analisarTile(tp)
            if info.tipo == "livre" then
                livres = livres + 1
            elseif info.tipo == "monstro" and info.criatura then
                -- task trapada por bicho: pode bater em QUALQUER bicho colado que esteja trapando (painel bate
                -- sozinho, sem CaveBot/TargetBot do vBot). Prefere o da task e o que fica pro lado do goto.
                local dd = destino and math.sqrt((tp.x - destino.x) ^ 2 + (tp.y - destino.y) ^ 2) or 0
                if not TD.ehDaTask(info.criatura) then dd = dd + 3 end
                if dd < melhorD then melhor, melhorD = info.criatura, dd end
            end
        end
        if not mesmaPos(p0, TD.posBrain) then
            TD.posBrain = {x = p0.x, y = p0.y, z = p0.z}
            TD.paradoBrainMs = agoraMs()
        end
        local paradoMs = agoraMs() - (TD.paradoBrainMs or agoraMs())
        local alvoNaoResolve = TD.alvo == nil or TD.focoTrap
            or dist(p0, TD.alvo:getPosition()) > TD.alcanceAtual()
            or TD.tagueados[TD.alvo:getId()] ~= nil
        if melhor and (livres == 0 or (paradoMs >= 1500 and alvoNaoResolve)) then
            presoPorBicho = melhor
        end
    end

    if presoPorBicho then
        if TD.alvo ~= presoPorBicho then
            TD.alvo = presoPorBicho
            TD.alvoDesde = agora
            TD.ultimoAtaque = 0
            TD.log("Trapado por bichos! Matando " .. presoPorBicho:getName() .. " para abrir caminho.")
        end
        TD.focoTrap = true
    elseif TD.focoTrap then
        TD.focoTrap = false
        -- saiu do "trapado": se o bicho que ele estava matando e da task, CONTINUA nele (antes largava e
        -- voltava pra rota no meio da luta: "targeta, anda, perde target")
        local okT, daTask = pcall(function() return TD.alvo and TD.ehDaTask(TD.alvo) end)
        if not (okT and daTask) then
            TD.log("Largou o alvo: saiu do modo trapado.")
            TD.alvo = nil
        end
    end

    local alvo = TD.alvo
    if alvo and not TD.focoTrap then
        local valido = false
        for _, item in ipairs(lista) do
            if item.c:getId() == alvo:getId() then valido = true break end
        end
        local distAlvo = dist(player:getPosition(), alvo:getPosition())
        if not valido then
            TD.log("Largou o alvo: saiu da lista (fora da tela, morreu ou pulado).")
            TD.alvo = nil
        elseif distAlvo > TD.alcanceAtual() then
            TD.alvoDesde = agora
            TD.caminhoChecado = TD.caminhoChecado or {}
            local idAlvo = alvo:getId()
            if TD.aproxId ~= idAlvo or distAlvo < (TD.aproxMelhor or 999) then
                TD.aproxId = idAlvo
                TD.aproxMelhor = distAlvo
                TD.aproximandoDesde = agora
            end
            -- tem caminho? Vale chegar num sqm VIZINHO do bicho (bicho voador fica em cima de arvore/agua, sqm onde
            -- eu nao piso: o caminho ate o sqm dele nunca existe). Sem caminho: confere de novo a cada 2s e so
            -- desiste depois de 4s seguidos sem caminho (antes: 1 conta so, guardada pra sempre -> largava na hora).
            local cc = TD.caminhoChecado[idAlvo]
            if type(cc) ~= "table" then cc = nil end
            if not cc or (not cc.ok and agora - cc.t >= 2) then
                local pp, ap = player:getPosition(), alvo:getPosition()
                local ok = calcularCaminho(pp, ap, false, 30) ~= nil
                if not ok and TD.analisarTile then
                    for _, d in ipairs(DELTAS) do
                        local viz = {x = ap.x + d[1], y = ap.y + d[2], z = ap.z}
                        if (mesmaPos(viz, pp) or TD.analisarTile(viz).tipo == "livre") and
                            (mesmaPos(viz, pp) or calcularCaminho(pp, viz, false, 30) ~= nil) then
                            ok = true
                            break
                        end
                    end
                end
                cc = {ok = ok, t = agora, desde = (not ok) and ((cc and cc.desde) or agora) or nil}
                TD.caminhoChecado[idAlvo] = cc
            end
            local semCaminho = not cc.ok and agora - (cc.desde or agora) >= 4
            local limiteAprox = TD.cfgTarget().modo == "1" and TD.APROXIMAR_S or TD.APROXIMAR_MATAR_S
            if semCaminho or agora - (TD.aproximandoDesde or agora) >= limiteAprox then
                TD.log("Largou o alvo: " .. (semCaminho and "sem caminho ate ele" or ("nao chegou perto em " .. limiteAprox .. "s")) ..
                    " (dist " .. distAlvo .. ", alcance " .. TD.alcanceAtual() .. ").")
                TD.pulados[alvo:getId()] = agora + 10
                TD.alvo = nil
                TD.aproximandoDesde = nil
                lista = TD.listarAlvos()
            end
        else
            TD.aproximandoDesde = nil
            local modo = TD.cfgTarget().modo
            local hp = alvo:getHealthPercent() or 100
            -- "Bater ate 50%": bicho com mais de 50% -> bate ate 50% e vai pro proximo.
            --                  bicho com 50% ou menos quando foi escolhido -> finaliza (bate ate morrer).
            local inicial = TD.alvoHpInicial or 100
            if modo == "1" and hp < inicial then
                TD.confirmarHit(alvo, "vida")
                lista = TD.listarAlvos()
            elseif modo == "50" and inicial > 50 and hp <= 50 then
                TD.confirmarHit(alvo, "vida")
                lista = TD.listarAlvos()
            elseif modo ~= "1" then
                if TD.alvoHpId ~= alvo:getId() or hp < (TD.alvoHpUlt or 101) then
                    TD.alvoHpId = alvo:getId()
                    TD.alvoHpUlt = hp
                    TD.alvoDesde = agora
                elseif agora - TD.alvoDesde >= ((g_game.getAttackingCreature() == alvo) and TD.MATAR_SEM_DANO_S or 6) then
                    TD.log("Largou o alvo: vida nao caiu (" .. hp .. "%), atacando=" ..
                        tostring(g_game.getAttackingCreature() == alvo) .. ".")
                    TD.pulados[alvo:getId()] = agora + TD.TEMPO_PULO
                    TD.alvo = nil
                    lista = TD.listarAlvos()
                end
            elseif agora - TD.alvoDesde >= TD.TEMPO_HIT then
                TD.pulados[alvo:getId()] = agora + TD.TEMPO_PULO
                TD.alvo = nil
                lista = TD.listarAlvos()
            end
        end
    end

    local seq = TD.planejarSequencia(lista)

    if not TD.alvo and #seq > 0 then
        TD.alvo = seq[1].c
        TD.alvoDesde = agora
        TD.ultimoAtaque = 0
        TD.alvoHpInicial = TD.alvo:getHealthPercent() or 100
        TD.alvoHpId = nil
    end
    if TD.alvo and g_game.getAttackingCreature() ~= TD.alvo and agoraMs() - (TD.ultimoAtaque or 0) >= 100 then
        local idA = TD.alvo:getId()
        if TD.tentativasId ~= idA then
            TD.tentativasId = idA
            TD.tentativasAtaque = 0
        end
        TD.tentativasAtaque = (TD.tentativasAtaque or 0) + 1
        local soAtaqueBasico = TD.cfgTarget().semMagia
        if TD.tentativasAtaque > 3 and soAtaqueBasico then
            TD.pularAlvo(TD.alvo, "nao da pra atacar")
        else
            TD.ultimoAtaque = agoraMs()
            g_game.attack(TD.alvo)
            if not soAtaqueBasico and TD.tentarMagia then pcall(TD.tentarMagia) end
        end
    elseif not TD.alvo and #seq == 0 then
        local extra = TD.bichoDaTaskMaisPerto(TD.alcanceAtual() + 1)
        if extra and g_game.getAttackingCreature() ~= extra and agoraMs() - (TD.ultimoAtaque or 0) >= 100 then
            TD.ultimoAtaque = agoraMs()
            g_game.attack(extra)
        end
        TD.alvoExtra = extra
    end
    if TD.alvo then TD.alvoExtra = nil end

    local novos, marcados = {}, {}
    local base = TD.progresso()
    local idAlvo = TD.alvo and TD.alvo:getId()
    for n, item in ipairs(seq) do
        if n > 30 then break end
        local id = item.c:getId()
        local texto = (id == idAlvo) and (">> ALVO " .. (base + n) .. " <<") or ("ALVO " .. (base + n))
        local cor = "#FFFFFF"   -- branco: mais visivel (era vermelho no alvo atual e dourado nos outros)
        pcall(function() item.c:setText(texto, cor) end)
        marcados[id] = true
        table.insert(novos, item.c)
    end
    for _, c in ipairs(TD.numerados) do
        local okI, id = pcall(function() return c:getId() end)
        if okI and not marcados[id] then
            if TD.tagueados[id] then
                TD.marcarTexto(c, "ATINGIDO", "#55FF55")
            else
                TD.marcarTexto(c, "", "#FFFFFF")
            end
        end
    end
    TD.numerados = novos
    TD.marcarQuadrado(TD.alvo)
    if #seq > 0 then TD.ultimoAlvoNovo = agora end

    if TD.alvo then
        TD.estado = "TARGETANDO (" .. TD.novosNaTela .. " RESTANTES)"
    else
        TD.estado = "ROTA " .. TD.rota
        if TaskDemon.modoDe() == "MELEE" and g_game.getAttackingCreature() and g_game.cancelAttack then
            g_game.cancelAttack()
        end
    end
end))

-- v6.0: subiu escada sem querer (ex.: Angry Bird, andar 6): vai pro sqm de cima da escada e pisa no lado dela.
-- {x, y, z, lado}. So age se o goto atual da rota NAO for nesse andar (rota que passa no andar 6 de proposito).
TD.DESCIDAS = {
    angrybird = {
        {5148, 5170, 6, "S"}, {5192, 5160, 6, "S"}, {5136, 5225, 6, "S"},
        {5140, 5225, 6, "S"}, {5098, 5214, 6, "E"},
    },
}
TD.DESCIDA_RAIO = 10   -- sqm: so procura escada de descida ate essa distancia
function TD.descerEscada()
    local lista = TD.DESCIDAS[cfg.tarefa]
    local p = lista and player:getPosition()
    if not p then return false end
    local w = rotaAtual()[TD.wp]
    if w and w[3] == p.z then return false end
    local melhor, melhorD = nil, nil
    for _, d in ipairs(lista) do
        local dd = dist(p, {x = d[1], y = d[2], z = d[3]})
        if dd <= TD.DESCIDA_RAIO and (not melhorD or dd < melhorD) then melhor, melhorD = d, dd end
    end
    if not melhor then
        TD.descendo = nil
        return false
    end
    if not TD.descendo then
        TD.descendo = true
        TD.log("Subiu escada sem querer (andar " .. p.z .. "): descendo em " .. melhor[1] .. ", " .. melhor[2] .. ".")
    end
    TD.estado = "DESCENDO ESCADA"
    if melhorD > 0 then
        TD.irPara({x = melhor[1], y = melhor[2], z = melhor[3]})
    elseif not andando() and agoraMs() >= (TD.descidaPassoAte or 0) then
        TD.descidaPassoAte = agoraMs() + 600
        TD.passoProprioAte = agoraMs() + 600
        g_game.walk(TD.LADOS[melhor[4]])
    end
    return true
end

macro(50, TD.protegido("andar", function()
    if not TD.ativo then return end
    if TD.descerEscada() then return end

    if TD.voltando then
        local p = player:getPosition()
        -- v6.0: voltando pela rota DP (Angry Bird): pisou em PZ no percurso = chegou (nao precisa ir ate o fim)
        if dist(p, TD.posDP) <= 1 or os.time() - (TD.voltandoDesde or 0) > 600 or (TD.voltaPeloDP and TD.emPz()) then
            TD.entregarAoBot("TASK CONCLUIDA")
        elseif not TD.emManual() then
            if TD.rota == "VOLTA" and not TD.voltaFeita then
                TD.andarRota()
            else
                TD.irPara(TD.posDP)
            end
        end
        return
    end

    TD.semRota = #(TD.ROTAS and TD.ROTAS.PRINCIPAL or {}) == 0 and #(TD.ROTAS and TD.ROTAS.CAMINHO or {}) == 0
    if TD.rota == "PRINCIPAL" and not TD.fugindo and not TD.semRota and #(TD.ROTAS.PRINCIPAL or {}) > 0 then
        if TD.pertoDaRota("PRINCIPAL", 25) then
            TD.longeDesde = nil
        else
            TD.longeDesde = TD.longeDesde or os.time()
            if os.time() - TD.longeDesde >= 5 then
                TD.longeDesde = nil
                TD.log("Longe da rota PRINCIPAL. Voltando pelo CAMINHO.")
                TD.escolherRotaInicial()
            end
        end
    end

    if TD.fugindo then TD.andarRota() return end

    if TD.alvo then
        -- com alvo a rota fica PAUSADA; quando o alvo acaba (morreu / chegou nos 50%), TD.saiuDaRota faz ela
        -- continuar do goto em que estava (TD.retomarRota) e seguir pros proximos
        TD.saiuDaRota = true
        if TD.emManual() then return end
        if TaskDemon.modoDe() == "MELEE" then
            -- Matar 100% / Bater ate 50%: GRUDA no bicho (anda ate ficar colado) em vez de so confiar no chase
            -- do cliente. 1 hit continua igual (so o chase).
            local okP, apM = pcall(function() return TD.alvo:getPosition() end)
            if TD.cfgTarget().modo ~= "1" and okP and apM and dist(player:getPosition(), apM) > 1 then
                -- vai pro sqm LIVRE colado no bicho mais perto de mim (bicho voador pode estar em arvore/agua)
                local pM, destM, melhorD = player:getPosition(), apM, 999
                for _, d in ipairs(DELTAS) do
                    local viz = {x = apM.x + d[1], y = apM.y + d[2], z = apM.z}
                    local dv = dist(pM, viz)
                    if dv < melhorD and TD.analisarTile(viz).tipo == "livre" then destM, melhorD = viz, dv end
                end
                TD.irPara(destM)
                TD.indoAoAlvo = true
            elseif TD.indoAoAlvo then   -- colou: para o auto walk (nao fica tentando pisar no bicho)
                TD.indoAoAlvo = false
                TD.destinoAtual = nil
                TD.caminho = nil
                if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
            end
            return
        end
        local ap = TD.alvo:getPosition()
        if dist(player:getPosition(), ap) > cfg.alcance then
            TD.irPara(ap)
            TD.indoAoAlvo = true
        elseif TD.indoAoAlvo then

            TD.indoAoAlvo = false
            TD.destinoAtual = nil
            TD.caminho = nil
            if player.stopAutoWalk then player:stopAutoWalk() end
        end
        return
    end

    if TD.saiuDaRota then
        TD.saiuDaRota = false
        TD.retomarRota()
    end
    TD.andarRota()
end))

function TD.nomeLimpo(nome)
    local n = tostring(nome or ""):gsub("%s*%[%d+%]%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return n:lower()
end

function TD.lerMensagemTasks(text)
    local lower = tostring(text or ""):lower()
    if not lower:find("demolisher", 1, true) then return false end
    for k, t in pairs(TD.TAREFAS) do
        if lower:find(t.nome:lower(), 1, true) then
            local feito, meta = lower:match("(%d+)%s*/%s*(%d+)")
            if feito then
                if tonumber(meta) and tonumber(meta) > 0 then cfg.metas[k] = tonumber(meta) end
                local bruto = tonumber(feito)
                if bruto < (cfg.progServidor[k] or 0) then cfg.progBase[k] = 0 end
                cfg.progServidor[k] = bruto
                cfg.prog[k] = math.max(0, bruto - (cfg.progBase[k] or 0))
                feito = tostring(cfg.prog[k])
                if k == cfg.tarefa then
                    TD.log("[TASK] " .. t.titulo .. ": " .. feito .. "/" .. meta)
                end
                return true
            end
        end
    end
    return false
end

function TD.atacantePlayer(text)
    local atacante = text:match("due to an attack by (.-)%.?$") or text:match("devido a um ataque de (.-)%.?$")
    if not atacante then return nil end
    if atacante:lower():match("^an? ") then return false end
    local alvo = TD.nomeLimpo(atacante)
    if alvo == TD.nomeLimpo(player:getName()) then return false end
    for _, spec in ipairs(getSpectators()) do
        if spec:isPlayer() and spec ~= player and TD.nomeLimpo(spec:getName()) == alvo then
            local escudo = spec.getShield and spec:getShield() or 0
            if escudo >= 3 then return false end
            return atacante
        end
    end
    return false
end

-- "[ISLAND OF ELEMENTALS] Os bravos guerreiros derrotaram o mais temido boss Island Death, o evento foi encerrado!"
function TD.lerMensagemEvento(text)
    local ev = TD.evRun
    if not ev then return end
    text = tostring(text or "")
    local baixo = text:lower()
    if ev.tipo == "island" then
        if baixo:find("island death", 1, true) and baixo:find("encerrado", 1, true) and not ev.morteFinal then
            -- nao encerra aqui: ainda esta dentro do Island. Vai pro TP de saida; encerra quando o TP levar
            -- (TD.cicloIsland). Encerrar aqui mandava o CaveBot pro DP de dentro do Island e ele ficava preso.
            ev.morteFinal = os.time()
            TD.logEv("Island Death derrotado: indo pro TP de saida antes de encerrar.")
        end
    elseif ev.tipo == "zombie" and baixo:find("zombie event", 1, true) then
        local eu = TD.nomeLimpo(player:getName())
        local devorado = text:match("%]%s*(.-)%s+foi devorado")
        local vencedor = text:match("%]%s*(.-)%s+venceu")
        -- quantos restam: o numero que vem na MESMA mensagem do "foi devorado", tirando o horario (19:37 / 19:37:33)
        -- e o nome do jogador (nome pode ter numero)
        local restam = nil
        if devorado then
            local resto = text:gsub("%d+:%d+:?%d*", "")
            local i, f = resto:find(devorado, 1, true)
            if i then resto = resto:sub(1, i - 1) .. resto:sub(f + 1) end
            restam = resto:match("(%d+)")
        end
        if restam then ev.restam = tonumber(restam) end
        if baixo:find("teleport foi fechado", 1, true) then
            ev.fase = "FUGA"
            TD.logEv("Zombie Event comecou! Fugindo dos zombies.")
        elseif baixo:find("perdeu", 1, true) or (devorado and TD.nomeLimpo(devorado) == eu) then
            TD.terminarEvento("Zombie: PERDEU (capturado)", true)
        elseif vencedor then
            TD.terminarEvento(TD.nomeLimpo(vencedor) == eu and "Zombie: VENCEU!" or ("Zombie: acabou, " .. vencedor .. " venceu"), true)
        elseif devorado then
            ev.ultimoDevorado = devorado
            TD.logEv(devorado .. " foi devorado." .. (ev.restam and (" Restam " .. ev.restam .. " na arena.") or ""))
        end
    elseif ev.tipo == "firestorm" and baixo:find("firestorm", 1, true) then
        -- "[FireStorm] Você foi atingido e removido do evento!"
        if baixo:find("removido", 1, true) or baixo:find("atingido", 1, true) then
            TD.terminarEvento("FireStorm: atingido", true)
        elseif baixo:find("venceu", 1, true) or baixo:find("vencedor", 1, true) or baixo:find("encerrado", 1, true) then
            -- ponytail: mensagem de fim chutada; trocar pelo texto real quando aparecer
            TD.terminarEvento("FireStorm: acabou", true)
        end
    elseif ev.tipo == "snowball" then
        local restam = baixo:match("restam%s+(%d+)x%s+bolas")
        if restam then ev.bolas = tonumber(restam) end
        if baixo:find("nao possui pontos", 1, true) or baixo:find("não possui pontos", 1, true) then
            ev.geradorAte = agoraMs() + 60000
            TD.logEv("Snowball: sem pontos para trocar no gerador. Tento de novo em 1 min.")
        end
        if baixo:find("snow ball war", 1, true) and baixo:find("encerrado", 1, true) then
            local vencedor, pontos = text:match("[Vv]encedor:%s*(.-)%s+com%s+(%d+)")
            local eu = TD.nomeLimpo(player:getName())
            TD.terminarEvento(vencedor and TD.nomeLimpo(vencedor) == eu and ("Snowball: VENCEU com " .. pontos .. " pontos!")
                or ("Snowball: acabou" .. (vencedor and (", " .. vencedor .. " venceu com " .. pontos) or "")), true)
        end
    end
end

onTextMessage(function(mode, text)
    TD.lerMensagemEvento(text)
    if TD.lerMensagemTasks(text) then return end
    local baixo = tostring(text or ""):lower()
    if baixo:find("exhausted", 1, true) or baixo:find("exaust", 1, true) then
        TD.proximaMagia = agoraMs() + 150
    end
    if TD.ativo and TD.alvo and TD.cfgTarget().semMagia and (baixo:find("target lost", 1, true) or baixo:find("may not attack", 1, true)
        or baixo:find("alvo perdido", 1, true) or baixo:find("nao pode atacar", 1, true)
        or baixo:find("out of range", 1, true)) then
        TD.pularAlvo(TD.alvo, "o jogo recusou o ataque")
    end
    if TD.ativo and (baixo:find("there is no way", 1, true) or baixo:find("nao ha caminho", 1, true)) then
        TD.semSaidaMsg()
    end

    local atacante = TD.atacantePlayer(text)
    if atacante ~= nil then
        if atacante then
            if TD.ativo then TD.fugirPK(atacante) else TD.pkHuntAtacado(atacante) end
        end
        return
    end

    if not TD.ativo then return end
    local msg = text:lower()
    if msg:find("due to your attack", 1, true) or msg:find("devido ao seu ataque", 1, true) then
        TD.ultimoProgresso = agoraMs()
    end
    if TD.alvo and (msg:find("due to your attack", 1, true) or msg:find("devido ao seu ataque", 1, true)
        or msg:find("seu ataque", 1, true)) then
        if msg:find(TD.alvo:getName():lower(), 1, true) then
            TD.confirmarHit(TD.alvo, "mensagem de dano")
        end
    end
end)

TD.mortesContadas = {}
function TD.contarMorte(c)
    local okI, id = pcall(function() return c:getId() end)
    if not okI or TD.mortesContadas[id] then return end
    local okN, nome = pcall(function() return c:getName():lower() end)
    if not okN or nome ~= TD.tarefaAtual().nome:lower() then return end
    local meu = TD.tagueados[id] or (TD.alvo and TD.alvo == c) or (TD.alvoExtra and TD.alvoExtra == c)
    if not meu then return end
    TD.mortesContadas[id] = os.time()
    cfg.prog[cfg.tarefa] = (cfg.prog[cfg.tarefa] or 0) + 1
    TD.ultimaContagemLocal = os.time()
end

if onCreatureHealthPercentChange then
    onCreatureHealthPercentChange(function(creature, hp)
        if not TD.ativo then return end
        if hp and hp <= 0 then TD.contarMorte(creature) end
        if TD.alvo and creature == TD.alvo then TD.ultimoProgresso = agoraMs() end
        if not hp or hp <= 0 or TD.cfgTarget().modo ~= "1" then return end
        local okI, id = pcall(function() return creature:getId() end)
        if not okI then return end
        TD.hpVisto = TD.hpVisto or {}
        local antes = TD.hpVisto[id]
        TD.hpVisto[id] = hp
        local alvo = TD.alvo
        if alvo and creature == alvo then
            if hp < (TD.alvoHpInicial or 100) or (antes and hp < antes) then
                TD.confirmarHit(alvo, "vida")
            end
            return
        end
        if antes and hp < antes and not TD.tagueados[id] then
            local okN, nome = pcall(function() return creature:getName():lower() end)
            if okN and nome == TD.tarefaAtual().nome:lower() and not TD.outroPlayerPerto(creature) then
                TD.tagueados[id] = {nome = creature:getName(), hora = os.time()}
                pcall(function() creature:setText("ATINGIDO", "#55FF55") end)
            end
        end
    end)
end

if onTalk then
    onTalk(function(name, level, mode, text)
        TD.lerMensagemEvento(text)
        TD.lerMensagemTasks(tostring(text or ""))
    end)
end

TD.textoPlayer = nil
function TD.textoAcima(texto, cor)
    local okT = false
    if player.setTitle then
        okT = pcall(function()
            if texto == "" then
                if player.clearTitle then player:clearTitle() else player:setTitle("", "verdana-11px-rounded", cor) end
            else
                player:setTitle(texto, "verdana-11px-rounded", cor)
            end
        end)
    end
    if okT then
        pcall(function() player:setText("", cor) end)
    else
        TD.marcarTexto(player, texto, cor)
    end
end
macro(200, function()
    local texto, cor = "", "#FFFFFF"
    if TD.pkFase == "NO PZ" then
        local resta = (TD.lerTempo(cfg.pkHunt.tempo) or 10) - (os.time() - TD.pkDesde)
        texto, cor = "PZ " .. formatarTempo(math.max(0, resta)), "#7FDBFF"
    elseif TD.ativo then
        texto = "[" .. TD.progresso() .. "/" .. TD.metaDe() .. "]"
    elseif TD.textoContagem then
        -- com evento rodando continua a contagem: a agenda chama 12:57 mas o TP so abre 13:00
        texto, cor = TD.textoContagem(TD.evRun ~= nil)
    end
    if texto ~= TD.textoPlayer then
        TD.textoPlayer = texto
        TD.textoAcima(texto, cor)
    end
end)

TD.EFEITO_SETA = 56

function TD.outroPlayerPerto(c)
    local ok, cp = pcall(function() return c:getPosition() end)
    if not ok or not cp then return true end
    for _, spec in ipairs(getSpectators()) do
        local okP, ehP = pcall(function() return spec:isPlayer() end)
        if okP and ehP and spec ~= player then
            local sp = spec:getPosition()
            if sp and sp.z == cp.z and math.max(math.abs(sp.x - cp.x), math.abs(sp.y - cp.y)) <= 7 then return true end
        end
    end
    return false
end
TD.quadradoEm = nil

function TD.marcarQuadrado(c)
    if TD.quadradoEm == c then return end
    if TD.quadradoEm then
        local antigo = TD.quadradoEm
        pcall(function() antigo:hideStaticSquare() end)
    end
    TD.quadradoEm = c
    if c then pcall(function() c:showStaticSquare("#FF2020") end) end
end

cfg.setaId, cfg.setaAcima = nil, nil
function TD.seta(pos)
    if not pos or not Effect or not g_map then return end
    pcall(function()
        local ef = Effect.create()
        ef:setId(TD.EFEITO_SETA)
        g_map.addThing(ef, pos, -1)
    end)
end

TD.piscaLigado = false
macro(400, function()
    if not TD.ativo or TD.voltando then
        if TD.quadradoEm then TD.marcarQuadrado(nil) end
        return
    end
    local alvo = TD.alvo
    if not alvo then return end
    TD.piscaLigado = not TD.piscaLigado
    local cor = TD.piscaLigado and "#FF0000" or "#FFFF00"
    pcall(function() alvo:showStaticSquare(cor) end)
    TD.quadradoEm = alvo
end)

macro(1000, function()
    if not TD.ativo or TD.voltando then return end
    local alvo = TD.alvo
    local p = player:getPosition()
    if not alvo or not p then return end
    local ok, cp = pcall(function() return alvo:getPosition() end)
    if ok and cp and cp.z == p.z then TD.seta(cp) end
end)

TD.ultimoProgresso = 0
TD.nivelTravado = 0
TD.posVigia = nil

function TD.destravar(nivel)
    TD.caminho = nil
    TD.destinoAtual = nil
    TD.destinoCliente = nil
    TD.semCaminhoAte = nil
    TD.esperaAte, TD.esperaWp = nil, nil
    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
    if nivel == 1 then
        if TD.alvo and not TD.focoTrap then TD.pularAlvo(TD.alvo, "parado") end
        TD.retomarRota()
        TD.log("Parado sem motivo: recalculando o caminho.")
    elseif nivel == 2 then
        if TD.alvo and not TD.focoTrap then TD.pularAlvo(TD.alvo, "parado") end
        if not TD.gotoExato(TD.wp) then TD.proximoWp() end
        TD.log("Continua parado: pulando para o goto " .. TD.wp .. ".")
    else
        TD.entrarNaRota(TD.rota)
        local p = player:getPosition()
        if p and TD.analisarTile and g_map then
            local dirs = {{0,-1,North or 0},{1,0,East or 1},{0,1,South or 2},{-1,0,West or 3}}
            for _, d in ipairs(dirs) do
                if TD.analisarTile({x = p.x + d[1], y = p.y + d[2], z = p.z}).tipo == "livre" then
                    g_game.walk(d[3])
                    break
                end
            end
        end
        TD.log("Travado ha muito tempo: voltando pelo goto mais perto.")
    end
end

macro(500, function()
    if TD.ativo and not TD.voltando and CaveBot and CaveBot.isOn and CaveBot.isOn() then
        CaveBot.setOff()
        TD.log("CaveBot do bot estava ligado junto com a task: desliguei.")
    end
    -- evento rodando: quem anda e ataca e o painel. CaveBot/TargetBot do vBot ligados junto = os dois brigando.
    if TD.evRun then
        if CaveBot and CaveBot.isOn and CaveBot.isOn() then
            CaveBot.setOff()
            TD.logEv("CaveBot do bot estava ligado junto com o evento: desliguei.")
        end
        if TargetBot and TargetBot.isOn and TargetBot.isOn() then
            TargetBot.setOff()
            TD.logEv("TargetBot do bot estava ligado junto com o evento: desliguei.")
        end
    end
end)

macro(200, function()
    if not TD.ativo or TD.fugindo or TD.pkFase or TD.morto then
        TD.nivelTravado = 0
        TD.ultimoProgresso = agoraMs()
        return
    end
    local p = player:getPosition()
    if not p then return end
    local t = agoraMs()
    if not TD.posVigia or not mesmaPos(p, TD.posVigia) then
        TD.posVigia = {x = p.x, y = p.y, z = p.z}
        TD.ultimoProgresso = t
    end
    if TD.esperaAte and t < TD.esperaAte then TD.ultimoProgresso = t end
    if TD.semRota and not TD.alvo then TD.ultimoProgresso = t end
    if TD.emManual and TD.emManual() then TD.ultimoProgresso = t end
    local alvo = TD.alvo
    local comMagia = not TD.cfgTarget().semMagia
    if alvo and (g_game.getAttackingCreature() == alvo or comMagia) then
        local okA, ap = pcall(function() return alvo:getPosition() end)
        local raio = comMagia and math.max(TD.alcanceAtual(), 7) or TD.alcanceAtual()
        if okA and ap and ap.z == p.z and dist(p, ap) <= raio then TD.ultimoProgresso = t end
    end
    local parado = t - (TD.ultimoProgresso or t)
    if parado < 1000 then
        TD.nivelTravado = 0
        return
    end
    local nivel = parado >= 4000 and 3 or (parado >= 2000 and 2 or 1)
    if nivel > TD.nivelTravado then
        TD.nivelTravado = nivel
        TD.destravar(nivel)
        if nivel == 3 then TD.ultimoProgresso = t TD.nivelTravado = 0 end
    end
end)

TD.proximaMagia = 0
TD.idxAtaque = 0
local ATAQUES = {
    {chave = "exoriCon", magia = "exori con", alcance = 7},
    {chave = "exoriSan", magia = "exori san", alcance = 4},
    {chave = "exoriHur", magia = "exori hur", alcance = 5},
    {chave = "exoriMas", magia = "exori mas", area = 1},
    {chave = "exevoMasSan", magia = "exevo mas san", area = 3},
    {chave = "gfb", nome = "GFB", runa = 3191, alcance = 7},
    {chave = "avalanche", nome = "Avalanche", runa = 3161, alcance = 7},
    {chave = "sd", nome = "SD", runas = {13724, 3150}, alcance = 7},
}

function TD.acharItem(id)
    for _, container in pairs(getContainers()) do
        for _, it in ipairs(container:getItems()) do
            if it:getId() == id then return it end
        end
    end
    return nil
end

function TD.usarAtaque(a, alvo)
    if a.magia then
        if say and pcall(function() say(a.magia) end) then return true end
        if g_game.talk and pcall(function() g_game.talk(a.magia) end) then return true end
        return false
    end
    local id = a.runaUsar
    local item = TD.acharItem(id)
    if item and pcall(function() g_game.useWith(item, alvo) end) then return true end
    if pcall(function() g_game.useInventoryItemWith(id, alvo) end) then return true end
    if useWith and pcall(function() useWith(id, alvo) end) then return true end
    return false
end

function TD.tentarMagia()
    if not TD.ativo or TD.fugindo or TD.voltando then return end
    local alvo = TD.alvo
    if not alvo or agoraMs() < TD.proximaMagia then return end
    local tc = TD.cfgTarget()
    if tc.semMagia then return end
    local p = player:getPosition()
    local okA, ap = pcall(function() return alvo:getPosition() end)
    if not p or not okA or not ap or ap.z ~= p.z then return end
    local d = dist(p, ap)
    local lista = {}
    for _, a in ipairs(ATAQUES) do
        if tc[a.chave] then table.insert(lista, a) end
    end
    if #lista == 0 then return end
    for _ = 1, #lista do
        TD.idxAtaque = TD.idxAtaque % #lista + 1
        local a = lista[TD.idxAtaque]
        local pode
        if a.area then
            pode = d <= a.area
        elseif a.magia then
            pode = d <= a.alcance
        else
            local ids = a.runas or {a.runa}
            local runa = nil
            if d <= a.alcance then
                for _, id in ipairs(ids) do
                    if TD.acharItem(id) then runa = id break end
                end
                runa = runa or ids[1]
            end
            pode = runa ~= nil
            a.runaUsar = runa
        end
        if pode then
            local usou = TD.usarAtaque(a, alvo)
            TD.ultimoAtaqueUsado = (a.magia or a.nome or "runa") .. (usou and "" or " (falhou)")
            TD.ultimoAtaqueHora = os.date("%H:%M:%S")
            TD.proximaMagia = agoraMs() + (usou and 100 or 150)
            return
        end
    end
end

macro(100, function() TD.tentarMagia() end)

macro(500, function()
    if not TD.ativo or TD.morto then return end
    local ok, hp = pcall(function() return player:getHealth() end)
    if ok and hp and hp <= 0 then
        TD.morto = true
        TD.log("Morreu durante a task (" .. TD.progresso() .. "/" .. TD.metaDe() .. "). Se ainda estiver no horario, volta no proximo check-in.")
        TD.voltando = false
        cfg.tarefaChamada = nil
        TD.entregarAoBot("MORREU")
    end
end)

macro(3000, function()
    if TD.morto then
        local ok, hp = pcall(function() return player:getHealth() end)
        if ok and hp and hp > 0 then TD.morto = false end
    end
end)

macro(60000, function()
    TD.hpVisto = {}
    local limite = os.time() - 120
    for id, t in pairs(TD.mortesContadas or {}) do
        if t < limite then TD.mortesContadas[id] = nil end
    end
    local hoje, ontem = os.date("%Y-%m-%d"), os.date("%Y-%m-%d", os.time() - 86400)
    for chave in pairs(cfg.concluidas) do
        if chave:sub(1, 10) ~= hoje and chave:sub(1, 10) ~= ontem then cfg.concluidas[chave] = nil end
    end
    TD.caminhoChecado = {}
    TD.textoCache = {}
    local agora = os.time()
    for id, t in pairs(TD.tagueados) do if agora - t.hora > 900 then TD.tagueados[id] = nil end end
    for id, t in pairs(TD.pulados) do if t < agora then TD.pulados[id] = nil end end
end)

local function hm(txt)
    txt = tostring(txt or ""):lower()
    local h, m = txt:match("^(%d%d?)[:%.h](%d%d?)$")
    if not h then h, m = txt:match("^(%d%d?)h?$"), "0" end
    if not h then h, m = txt:match("^(%d%d)(%d%d)$") end
    h, m = tonumber(h), tonumber(m)
    if not h or not m or h > 23 or m > 59 then return nil end
    return h * 60 + m
end

TD.JANELA_SIMPLES = 5

function TD.lerHorarios(texto)
    local janelas = {}
    local limpo = tostring(texto or ""):gsub("%s*%-%s*", "-")
    for t in limpo:gmatch("[^,;%s]+") do
        local a, b = t:match("^([^%-]+)%-([^%-]+)$")
        if a then
            local ini, fim = hm(a), hm(b)
            if not ini or not fim then return nil end
            table.insert(janelas, {ini = ini, fim = fim, txt = t, comFim = true})
        else
            local ini = hm(t)
            if not ini then return nil end
            table.insert(janelas, {ini = ini, fim = (ini + TD.JANELA_SIMPLES) % 1440, txt = t, comFim = false})
        end
    end
    return janelas
end

function TD.janelasPorSemana(k)
    local ag = cfg.agenda[k]
    local total = 0
    for _, d in ipairs(TD.DIAS) do
        local janelas = TD.lerHorarios(ag.horariosDia[d])
        if not janelas then return nil, d end
        total = total + #janelas
    end
    return total
end

function TD.janelasDaTask(k, texto)
    local lista = TD.lerHorarios(texto) or {}
    local dur = TD.TAREFAS[k] and TD.TAREFAS[k].duracao
    if dur then
        for _, j in ipairs(lista) do
            if not j.comFim then
                j.fim = (j.ini + dur) % 1440
                j.comFim = true
            end
        end
    end
    return lista
end

function TD.janelaAgora(k)
    local ag = cfg.agenda[k]
    if not ag or not ag.ativo then return nil end
    local t = os.date("*t")
    local agoraMin = t.hour * 60 + t.min
    local hoje = TD.DIAS[t.wday]
    local ontem = TD.DIAS[(t.wday + 5) % 7 + 1]
    local permitidos = TD.TAREFAS[k] and TD.TAREFAS[k].dias

    for _, j in ipairs((not permitidos or permitidos[hoje]) and TD.janelasDaTask(k, ag.horariosDia[hoje]) or {}) do
        if j.fim >= j.ini then
            if agoraMin >= j.ini and agoraMin <= j.fim then return j end
        elseif agoraMin >= j.ini then
            return j
        end
    end
    for _, j in ipairs((not permitidos or permitidos[ontem]) and TD.janelasDaTask(k, ag.horariosDia[ontem]) or {}) do
        if j.fim < j.ini and agoraMin <= j.fim then return j end
    end
    return nil
end

cfg.concluidas = cfg.concluidas or {}
cfg.janelaProgresso = cfg.janelaProgresso or {}

function TaskDemon.aindaNoHorario(k)
    k = k or cfg.tarefa
    return TD.janelaAgora(k) ~= nil
end

function TaskDemon.falta(k)
    k = k or cfg.tarefa
    return (cfg.prog[k] or 0) < TD.metaDe(k) and TD.janelaAgora(k) ~= nil
end

macro(5000, function()
    if TD.ativo and TD.origemAgenda then
        if TD.janelaOrigem and TD.janelaOrigem.comFim and not TD.janelaAgora(TD.origemAgenda) then
            local k = TD.origemAgenda
            if TD.janelaChave then cfg.concluidas[TD.janelaChave] = true end
            TD.finalizar("Horario da task acabou")
            TD.zerarTarefa(k)
            cfg.janelaProgresso[k] = nil
        end
        return
    end
    if not TD.ativo then
        for k, chave in pairs(cfg.janelaProgresso) do
            if chave and not TD.janelaAgora(k) then
                TD.zerarTarefa(k)
                cfg.janelaProgresso[k] = nil
            end
        end
    end
    if not TD.ativo and cfg.tarefaChamada and not TD.janelaAgora(cfg.tarefaChamada) then
        TD.log("Janela de " .. TD.TAREFAS[cfg.tarefaChamada].titulo .. " acabou antes de chegar no DP.")
        cfg.tarefaChamada = nil
        TD.origemAgenda = nil
    end
    if not TD.evRun and TD.eventoChamado and not TD.janelaAgora(TD.eventoChamado) then
        TD.logEv("Janela de " .. TD.EVENTOS[TD.eventoChamado].titulo .. " acabou antes de chegar na label.")
        TD.eventoChamado = nil
    end
end)

function TD.checkin()
    -- um checkin so no CaveBot: eventos primeiro (horario fixo), depois tasks
    local ev = TaskDemon.checkinEvento()
    if ev ~= true then return ev end
    if not TD.ativo and not TD.evRun and cfg.tarefaChamada then
        local r = TD.reenviarLabel(cfg.tarefaChamada, TD.log)
        if r then return r end
    end
    if TD.ativo or cfg.tarefaChamada or TD.evRun or TD.eventoChamado then return true end
    local hoje = os.date("%Y-%m-%d")
    for _, k in ipairs(TD.AGENDAVEIS) do
        local j = TD.janelaAgora(k)
        if j then
            local chave = hoje .. "|" .. k .. "|" .. j.txt
            if cfg.janelaProgresso[k] ~= chave then
                TD.zerarTarefa(k)
                cfg.janelaProgresso[k] = chave
            end
            if (cfg.prog[k] or 0) >= TD.metaDe(k) then cfg.concluidas[chave] = true end
            if not cfg.concluidas[chave] then
                local ag = cfg.agenda[k]
                if ag.label == "" then
                    TD.log("Check-in: " .. TD.TAREFAS[k].titulo .. " sem label na agenda.")
                    return true
                end
                cfg.disparos[chave] = true
                cfg.tarefaChamada = k
                TD.origemAgenda = k
                TD.janelaOrigem = j
                TD.janelaChave = chave
                TD.log("Check-in: " .. TD.TAREFAS[k].titulo .. " (" .. j.txt .. "). Indo para '" .. ag.label .. "'.")
                CaveBot.gotoLabel(ag.label)
                return "retry"
            end
        end
    end
    return true
end

function TD.chegadaDP()
    -- mesma funcao na label: se quem chamou foi a agenda de eventos, comeca o evento
    if TD.eventoChamado and not cfg.tarefaChamada then return TaskDemon.chegadaEvento() end
    local k = cfg.tarefaChamada
    if not k or TD.ativo then return true end
    cfg.tarefaChamada = nil
    TD.tagueados, TD.pulados = {}, {}
    return TD.iniciar(k, "")
end

function TD.cavebotAtual()
    if CaveBot and CaveBot.getCurrentProfile then
        local ok, nome = pcall(CaveBot.getCurrentProfile)
        if ok and nome then return nome end
    end
    return nil
end

function TD.trocarCaveBot(nome)
    if not nome or nome == "" then return false end
    if not (CaveBot and CaveBot.setCurrentProfile) then
        TD.log("Seu vBot nao permite trocar o CaveBot por script (falta setCurrentProfile).")
        return false
    end
    if TD.cavebotAtual() == nome then return true end
    local ok, err = pcall(CaveBot.setCurrentProfile, nome)
    if not ok then
        TD.log("Erro ao trocar para o CaveBot '" .. nome .. "': " .. tostring(err))
        return false
    end
    TD.log("CaveBot trocado para '" .. nome .. "'.")
    return true
end

function TD.listarCaveBots()
    local lista = {}
    local nomeConfig = nil
    pcall(function()
        nomeConfig = modules.game_bot.contentsPanel.config:getCurrentOption().text
    end)
    if nomeConfig and g_resources and g_resources.listDirectoryFiles then
        local ok, arquivos = pcall(g_resources.listDirectoryFiles, "/bot/" .. nomeConfig .. "/cavebot_configs", false, false)
        if ok and arquivos then
            for _, arq in ipairs(arquivos) do
                local nome = tostring(arq):match("([^/]+)%.cfg$")
                if nome then table.insert(lista, nome) end
            end
        end
    end
    table.sort(lista, function(a, b) return a:lower() < b:lower() end)
    return lista
end

macro(3600000, function()
    local hoje = os.date("%Y-%m-%d")
    for chave in pairs(cfg.disparos) do
        if chave:sub(1, 10) ~= hoje then cfg.disparos[chave] = nil end
    end
end)

g_ui.importStyleFromString([[
TDBtn < UIButton
  font: verdana-11px-rounded
  text-align: center
  background-color: #2A2A2AEE
  border-width: 1
  border-color: #5A5A5A
  color: #DDDDDD
  height: 20
  $hover:
    background-color: #3D3D3DEE
    border-color: #8A8A8A
  $pressed:
    background-color: #151515EE

TDToggle < UIButton
  font: verdana-11px-rounded
  text-align: center
  border-width: 1
  border-color: #4A4A4A
  color: #DDDDDD
  height: 20
  $hover:
    border-color: #E0E0E0

TDDia < TDToggle
  width: 34
  height: 18

TDLinha < TDToggle
  height: 20
  text-align: left
  text-offset: 6 0

TDGoto < TDToggle
  height: 16
  text-align: left
  text-offset: 6 0
  border-width: 0

TDInfo < UILabel
  font: verdana-11px-rounded
  color: #CCCCCC
  height: 16

TDLigacao < Panel
  height: 22
  layout:
    type: horizontalBox
    spacing: 3
  TDInfo
    id: rotulo
    width: 120
    margin-top: 3
  ComboBox
    id: combo
    width: 146
    height: 22

TDCabecalho < UIButton
  height: 20
  font: verdana-11px-rounded
  text-align: left
  text-offset: 6 0
  color: #FFFFFF
  background-color: #4A1414EE
  border-width: 1
  border-color: #7A2A2A
  $hover:
    background-color: #5E1C1CEE

TDCheck < UIButton
  height: 16
  font: verdana-11px-rounded
  color: #CCCCCC
  text-align: left
  text-offset: 20 0
  background-color: alpha
  $hover:
    color: #FFFFFF
  UILabel
    id: box
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 3
    size: 12 12
    border-width: 1
    border-color: #888888
    background-color: #111111
    text-align: center
    font: verdana-11px-rounded
    color: #FFFFFF

TDTitulo < UILabel
  font: verdana-11px-rounded
  color: #FFFFFF
  text-align: center
  height: 16
  background-color: #1F1F1FEE

TDCampo < BotTextEdit
  height: 20
  text-align: center

TDSecao < Panel
  height: 188
  margin-top: 4
  background-color: #111111EE
  border-width: 1
  border-color: #3A3A3A
  padding: 3
  layout:
    type: verticalBox
    spacing: 2

  UILabel
    id: nome
    font: verdana-11px-rounded
    color: #FFB84D
    height: 18
    text-offset: 4 0
    background-color: #0E1A2BEE
  TDToggle
    id: ativo
  TDTitulo
    text: Label do CaveBot
  TDCampo
    id: label
  TDTitulo
    text: Dias
  Panel
    id: dias
    height: 18
    layout:
      type: horizontalBox
      spacing: 2
  TDTitulo
    id: tituloHorarios
    text: Horarios
  TDCampo
    id: horarios
  UILabel
    id: janelas
    font: verdana-11px-rounded
    color: #55DD55
    text-align: center
    height: 16

TaskDemonWindow < UIWindow
  width: 280
  height: 635
  padding: 6
  image-source: ~
  background-color: #0B0B0BF0
  border-width: 1
  border-color: #5A5A5A
  @onEscape: self:hide()

  Panel
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    UILabel
      id: tituloVersao
      text: TASKS
      color: #FF6B6B
      font: verdana-11px-rounded
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text-auto-resize: true

    TDBtn
      id: closeButton
      text: X
      anchors.right: parent.right
      anchors.top: parent.top
      size: 22 18
      color: #FF5555

  Panel
    id: abas
    anchors.top: header.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 60
    layout:
      type: verticalBox
      spacing: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: abaStatus
        text: TASK
        width: 87
      TDBtn
        id: abaEventos
        text: EVENTOS
        width: 87
      TDBtn
        id: abaAgenda
        text: AGENDA
        width: 87
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: abaCaveBot
        text: CAVEBOT
        width: 87
      TDBtn
        id: abaTarget
        text: TARGET
        width: 87
      TDBtn
        id: abaPK
        text: PK
        width: 87
    Panel
      height: 16
      layout:
        type: horizontalBox
        spacing: 3
      TDCheck
        id: mostrarTask
        width: 18
      UILabel
        id: relogioTask
        width: 112
        font: verdana-11px-rounded
        color: #FFD24A
        text-align: left
      TDCheck
        id: mostrarEvento
        width: 18
      UILabel
        id: relogioEvento
        width: 112
        font: verdana-11px-rounded
        color: #7FB2FF
        text-align: left

  Panel
    id: pageStatus
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 6
    layout:
      type: verticalBox
      spacing: 1

    Panel
      id: listaTarefas
      height: 20
      layout:
        type: verticalBox
        spacing: 2
    UILabel
      id: progresso
      text: 0 / 50
      font: verdana-11px-rounded
      color: #FFD24A
      text-align: center
      height: 22
      margin-top: 2
    TDInfo
      id: estado
    TDInfo
      id: rota
    TDInfo
      id: alvo
    TDInfo
      id: tela
    TDInfo
      id: targetados
    TDInfo
      id: volta
    TDInfo
      id: agendaInfo
      color: #7FB2FF
    HorizontalSeparator
      height: 2
      margin-top: 3
    Panel
      height: 20
      margin-top: 3
      layout:
        type: horizontalBox
        spacing: 4
      TDBtn
        id: ligar
        width: 132
      TDBtn
        id: modo
        width: 132
    Panel
      height: 20
      margin-top: 3
      layout:
        type: horizontalBox
        spacing: 4
      TDInfo
        text: Meta:
        width: 34
        margin-top: 2
      TDCampo
        id: meta
        width: 40
      TDInfo
        text: Distancia:
        width: 62
        margin-top: 2
        margin-left: 40
      TDCampo
        id: alcance
        width: 34
      TDInfo
        text: sqm
        width: 26
        margin-top: 2
    TDBtn
      id: zerar
      text: ZERAR ESTA TAREFA
      margin-top: 3
      color: #FF7777
    UILabel
      id: evento
      font: verdana-11px-rounded
      color: #AAAAAA
      text-wrap: true
      height: 42
      margin-top: 3

  Panel
    id: pageAgenda
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 4
    visible: false
    layout:
      type: verticalBox
    Panel
      height: 20
      margin-bottom: 4
      layout:
        type: horizontalBox
        spacing: 3
      TDToggle
        id: agTasks
        text: AGENDA TASKS
        width: 131
      TDToggle
        id: agEventos
        text: AGENDA EVENTOS
        width: 131
    Panel
      id: painelEventos
      height: 392
      visible: false
      ScrollablePanel
        id: secoesEv
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        margin-right: 13
        vertical-scrollbar: secoesEvScroll
        layout:
          type: verticalBox
      VerticalScrollBar
        id: secoesEvScroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        step: 30
        pixels-scroll: true
    Panel
      id: painelTasks
      height: 392
      ScrollablePanel
        id: secoes
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        margin-right: 13
        vertical-scrollbar: secoesScroll
        layout:
          type: verticalBox
      VerticalScrollBar
        id: secoesScroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        step: 30
        pixels-scroll: true
    Panel
      height: 22
      margin-top: 8
      layout:
        type: horizontalBox
        spacing: 136
      TDBtn
        id: restaurar
        text: Restaurar
        width: 66
        color: #FF5555
      TDBtn
        id: fechar
        text: Fechar
        width: 66

  Panel
    id: pageCaveBot
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 6
    visible: false
    layout:
      type: verticalBox
      spacing: 2

    TDTitulo
      text: CaveBot da hunt (volta ao terminar)
    Panel
      height: 22
      layout:
        type: horizontalBox
        spacing: 3
      ComboBox
        id: cbHunt
        width: 196
        height: 22
      TDBtn
        id: cbAtualizar
        text: ATUALIZAR
        width: 67
    TDInfo
      id: cbAgora
      color: #7FB2FF

    HorizontalSeparator
      height: 2
      margin-top: 4

    TDTitulo
      text: CaveBot da task
      margin-top: 2
    Panel
      height: 22
      layout:
        type: horizontalBox
        spacing: 3
      ComboBox
        id: perfilSel
        width: 266
        height: 22
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: perfilNovo
        text: NOVO
        width: 64
        color: #77FF77
      TDBtn
        id: perfilRenomear
        text: RENOMEAR
        width: 64
      TDBtn
        id: cbEditar
        text: EDITAR
        width: 64
        color: #7FB2FF
      TDBtn
        id: perfilExcluir
        text: EXCLUIR
        width: 64
        color: #FF8888

    Panel
      height: 20
      margin-top: 6
      layout:
        type: horizontalBox
        spacing: 3
      TDToggle
        id: rotaPrincipal
        text: CAMINHO
        width: 86
      TDToggle
        id: rotaCidade
        text: PRINCIPAL
        width: 86
      TDToggle
        id: rotaDP
        text: DP (PK)
        width: 86
    Panel
      height: 124
      background-color: #0E0E0EEE
      border-width: 1
      border-color: #3A3A3A
      TextList
        id: listaGotos
        anchors.fill: parent
        margin-right: 12
        padding: 1
        vertical-scrollbar: gotosScroll
      VerticalScrollBar
        id: gotosScroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        step: 16
        pixels-scroll: true
    TDInfo
      id: gotoInfo
      color: #AAAAAA
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: gotoAdd
        text: + POSICAO
        width: 86
        color: #77FF77
      TDBtn
        id: gotoRemover
        text: REMOVER
        width: 86
        color: #FF8888
      TDBtn
        id: gotoClear
        text: CLEAR
        width: 86
        color: #FF5555

    HorizontalSeparator
      height: 2
      margin-top: 4

    TDTitulo
      text: Goto selecionado
      margin-top: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Direcao
        width: 44
        margin-top: 2
      TDBtn
        id: gotoLado
        width: 62
      TDInfo
        text: Wait
        width: 28
        margin-top: 2
      TDBtn
        id: gotoWaitBtn
        width: 62
      TDBtn
        id: gotoWaitAplicar
        text: SALVAR
        width: 58
        color: #77FF77

    HorizontalSeparator
      height: 2
      margin-top: 4

    TDTitulo
      text: Opcoes
      margin-top: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: gotoGravar
        width: 112
      TDInfo
        text: a cada
        width: 42
        margin-top: 2
      TDCampo
        id: gravarSqm
        width: 32
      TDInfo
        text: sqm
        width: 30
        margin-top: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Delay (s):
        width: 60
        margin-top: 2
      TDCampo
        id: gotoWait
        width: 40
      TDInfo
        text: Busca (sqm):
        width: 76
        margin-top: 2
      TDCampo
        id: buscaMax
        width: 40

    Panel
      height: 22
      margin-top: 6
      layout:
        type: horizontalBox
        spacing: 3
      TDToggle
        id: cbTask
        width: 131
        height: 22
      TDToggle
        id: cbEventos
        width: 131
        height: 22

  Panel
    id: pagePK
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 6
    visible: false
    layout:
      type: verticalBox
      spacing: 2
    TDTitulo
      text: PK na hunt
    TDToggle
      id: pkHuntAtivo
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Label fuga:
        width: 80
        margin-top: 2
      TDCampo
        id: pkFuga
        width: 185
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Tempo no PZ:
        width: 80
        margin-top: 2
      TDCampo
        id: pkTempo
        width: 60
      TDInfo
        text: ex: 10s, 5min
        width: 120
        margin-top: 2
        color: #777777
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Label volta:
        width: 80
        margin-top: 2
      TDCampo
        id: pkVolta
        width: 185
    TDInfo
      id: pkStatus
      color: #7FB2FF
    TDTitulo
      text: Fuga inteligente
      margin-top: 6
    TDToggle
      id: fugaBicar
    TDToggle
      id: fugaMW
    TDToggle
      id: fugaEscudo
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Players:
        width: 50
        margin-top: 2
      TDCampo
        id: escudoQtd
        width: 40
      TDInfo
        text: SQM:
        width: 36
        margin-top: 2
      TDCampo
        id: escudoSqm
        width: 40
      TDInfo
        id: escudoAgora
        width: 95
        margin-top: 2
        color: #7FB2FF
    TDInfo
      id: escudoVisto
      color: #AAAAAA
    TDToggle
      id: fugaSkull
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Runa MW:
        width: 60
        margin-top: 2
      TDCampo
        id: fugaRunaMW
        width: 60
      TDInfo
        text: MW VIP:
        width: 56
        margin-top: 2
      TDCampo
        id: fugaRunaVip
        width: 60
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        id: fugaPz
        width: 170
        margin-top: 2
      TDBtn
        id: fugaSalvarPz
        text: SALVAR PZ AQUI
        width: 95
    TDInfo
      id: fugaStatus
      color: #7FB2FF
    TDTitulo
      text: Durante a task
      margin-top: 6
    TDToggle
      id: pkAtivo
    TDInfo
      id: pkFugas
      margin-top: 4
    Panel
      height: 22
      margin-top: 6
      layout:
        type: horizontalBox
        spacing: 4
      TDBtn
        id: pkSalvar
        text: SALVAR PK
        width: 130
        color: #77FF77
      TDBtn
        id: pkResetar
        text: RESETAR PK
        width: 130
        color: #FF7777

  Panel
    id: pageTarget
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 6
    visible: false
    layout:
      type: verticalBox
      spacing: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: tgPrev
        text: <
        width: 24
      UILabel
        id: tgNome
        width: 214
        font: verdana-11px-rounded
        color: #FFD24A
        text-align: center
      TDBtn
        id: tgNext
        text: >
        width: 24
    TDCabecalho
      id: tgSecModo
      margin-top: 4
    Panel
      id: tgPainelModo
      height: 52
      layout:
        type: verticalBox
        spacing: 2
      TDCheck
        id: tgModo100
        text: Matar 100% e ir pro proximo
      TDCheck
        id: tgModo50
        text: Bater ate 50% e ir pro proximo
      TDCheck
        id: tgModo1
        text: 1 hit e ir pro proximo (sequencia de alvos)
    TDCabecalho
      id: tgSecAtaque
      margin-top: 2
    Panel
      id: tgPainelAtaque
      height: 88
      layout:
        type: horizontalBox
        spacing: 2
      Panel
        width: 132
        layout:
          type: verticalBox
          spacing: 2
        TDCheck
          id: tgSemMagia
        TDCheck
          id: tgExoriCon
        TDCheck
          id: tgExoriSan
        TDCheck
          id: tgExoriHur
        TDCheck
          id: tgExoriMas
      Panel
        width: 132
        layout:
          type: verticalBox
          spacing: 2
        TDCheck
          id: tgExevoMasSan
        TDCheck
          id: tgGfb
        TDCheck
          id: tgAvalanche
        TDCheck
          id: tgSd
    TDCabecalho
      id: tgSecCave
      margin-top: 2
    Panel
      id: tgPainelCave
      height: 22
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Usar:
        width: 40
        margin-top: 3
      ComboBox
        id: tgCombo
        width: 222
        height: 22
    TDInfo
      id: tgInfo
      margin-top: 2
      color: #7FB2FF

  Panel
    id: pageEventos
    anchors.top: abas.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 6
    visible: false
    layout:
      type: verticalBox
      spacing: 2
    Panel
      height: 20
      layout:
        type: horizontalBox
        spacing: 3
      TDBtn
        id: evPrev
        text: <
        width: 24
      UILabel
        id: evNome
        width: 214
        font: verdana-11px-rounded
        color: #FFD24A
        text-align: center
      TDBtn
        id: evNext
        text: >
        width: 24
    TDInfo
      id: evPronto
      margin-top: 2
    Panel
      height: 22
      margin-top: 4
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: CaveBot:
        width: 60
        margin-top: 3
      ComboBox
        id: evCombo
        width: 205
        height: 22
    Panel
      height: 20
      margin-top: 2
      layout:
        type: horizontalBox
        spacing: 3
      TDInfo
        text: Label ao terminar:
        width: 110
        margin-top: 2
      TDCampo
        id: evLabelFim
        width: 155
    TDCheck
      id: evDisputar
      margin-top: 4
      text: Disputar (fugir dos zombies pra vencer)
    HorizontalSeparator
      height: 2
      margin-top: 6
    TDInfo
      id: evEstado
      margin-top: 4
      color: #FFD24A
    TDInfo
      id: evFase
    TDInfo
      id: evBoss
    TDInfo
      id: evRota
    TDInfo
      id: evTempo
    TDInfo
      id: evUltimo
      color: #55DD55
    TDToggle
      id: evMaster
      margin-top: 8
      height: 24
    UILabel
      id: evLog
      font: verdana-11px-rounded
      color: #AAAAAA
      text-wrap: true
      height: 42
      margin-top: 3
]])

taskDemonWindow = g_ui.createWidget("TaskDemonWindow", g_ui.getRootWidget())
taskDemonWindow:setRect({x = cfg.pos.x, y = cfg.pos.y, width = 280, height = 635})
taskDemonWindow:hide()
taskDemonWindow.onMove = function(widget, newPos) cfg.pos = {x = newPos.x, y = newPos.y} end

local w = taskDemonWindow
pcall(function() w:recursiveGetChildById("tituloVersao"):setText("TASKS " .. TD.VERSAO) end)
local function el(id) return w:recursiveGetChildById(id) end
local ui = {}
for _, id in ipairs({"closeButton", "relogioTask", "relogioEvento", "mostrarTask", "mostrarEvento", "abaStatus", "abaAgenda", "abaCaveBot", "abaPK", "abaEventos",
    "pageStatus", "pageAgenda", "pageCaveBot", "pagePK", "pageEventos", "pageTarget", "abaTarget",
    "tgPrev", "tgNome", "tgNext", "tgModo100", "tgModo50", "tgModo1", "tgSemMagia", "tgExoriCon",
    "tgExoriSan", "tgExevoMasSan", "tgGfb", "tgAvalanche", "tgSd", "tgInfo",
    "tgExoriHur", "tgExoriMas", "tgSecModo", "tgSecAtaque", "tgSecCave", "tgPainelModo", "tgPainelAtaque", "tgPainelCave", "tgCombo",
    "pkHuntAtivo", "pkFuga", "pkTempo", "pkVolta", "pkStatus",
    "fugaBicar", "fugaMW", "fugaEscudo", "escudoQtd", "escudoSqm", "escudoAgora", "escudoVisto", "pkSalvar", "pkResetar", "fugaSkull", "fugaRunaMW", "fugaRunaVip", "fugaPz", "fugaSalvarPz", "fugaStatus",
    "secoes", "listaTarefas", "progresso", "estado", "rota", "alvo", "tela", "targetados", "volta",
    "agendaInfo", "ligar", "modo", "meta", "alcance", "zerar", "evento", "restaurar", "fechar",
    "cbHunt", "cbAtualizar", "cbAgora", "perfilSel", "perfilNovo", "perfilRenomear",
    "perfilExcluir",
    "rotaPrincipal", "rotaCidade", "rotaDP", "agTasks", "agEventos", "painelEventos", "painelTasks", "secoesEv", "evEstado", "evFase", "evBoss", "evRota", "evTempo", "evUltimo", "evLog", "evLabelFim", "evDisputar", "evPrev", "evNext", "evNome", "evPronto", "evCombo", "evMaster", "cbEventos",
    "listaGotos", "gotoAdd", "gotoRemover", "gotoInfo", "gotoGravar", "gravarSqm", "gotoWait", "gotoWaitAplicar", "buscaMax", "cbEditar", "gotoClear", "gotoLado", "gotoWaitBtn", "cbTask", "gotosScroll",
    "pkAtivo", "pkFugas"}) do
    ui[id] = el(id)
end
w.ui = ui

local VERDE_BG, VERMELHO_BG, CINZA_BG = "#0F4D0FEE", "#4D0F0FEE", "#262626EE"
local SEL_BG = "#3A3000EE"
local NOME_DIA = {dom = "DOMINGO", seg = "SEGUNDA", ter = "TERCA", qua = "QUARTA",
                  qui = "QUINTA", sex = "SEXTA", sab = "SABADO"}

local function pintarToggle(botao, ligado, textoOn, textoOff)
    botao:setText(ligado and textoOn or textoOff)
    botao:setColor(ligado and "#77FF77" or "#FF8888")
    botao:setBackgroundColor(ligado and VERDE_BG or VERMELHO_BG)
end

local ABAS = {STATUS = "pageStatus", AGENDA = "pageAgenda", CAVEBOT = "pageCaveBot", PK = "pagePK", EVENTOS = "pageEventos", TARGET = "pageTarget"}
local BOTOES_ABA = {STATUS = "abaStatus", AGENDA = "abaAgenda", CAVEBOT = "abaCaveBot", PK = "abaPK", EVENTOS = "abaEventos", TARGET = "abaTarget"}
local ALTURAS = {STATUS = 398, AGENDA = 546, CAVEBOT = 636, PK = 675, EVENTOS = 457, TARGET = 398}
function TD.mostrarAba(nome)
    for aba, pagina in pairs(ABAS) do
        if aba == nome then ui[pagina]:show() else ui[pagina]:hide() end
        ui[BOTOES_ABA[aba]]:setColor(aba == nome and "#FFD24A" or "#888888")
    end
    if nome == "TARGET" and TD.alturaTarget then
        w:setHeight(TD.alturaTarget())
    elseif ALTURAS[nome] then
        w:setHeight(ALTURAS[nome])
    end
    TD.abaAtual = nome
    if nome == "TARGET" and TD.atualizarTarget then TD.atualizarTarget() end
end
ui.abaStatus.onClick = function() TD.mostrarAba("STATUS") end
ui.abaAgenda.onClick = function() TD.mostrarAba("AGENDA") end
ui.abaCaveBot.onClick = function() TD.mostrarAba("CAVEBOT") end
ui.abaPK.onClick = function() TD.mostrarAba("PK") end
ui.abaEventos.onClick = function() TD.mostrarAba("EVENTOS") end
cfg.evLabelFimPor = cfg.evLabelFimPor or {}
-- v5.7: Zombie "Disputar": marcado (padrao) = foge pra vencer; desmarcado = entra e fica parado
cfg.evDisputar = cfg.evDisputar or {}
function TD.zombieDisputar() return cfg.evDisputar.ev_zombie ~= false end
cfg.eventosAtivo = false -- sempre comeca desligado (liga clicando ou pela agenda)
cfg.eventoPerfil = cfg.eventoPerfil or {}
TD.evEditando = TD.evEditando or "ev_island"
function TD.labelFimEvento(k) return cfg.evLabelFimPor[k] or cfg.evLabelFim or "inicio" end
function TD.alternarEventos(ligar)
    if ligar == nil then ligar = not cfg.eventosAtivo end
    cfg.eventosAtivo = ligar
    if not ligar and TD.evRun then TD.terminarEvento("eventos desligados", false, true) end
    if not ligar then
        TD.eventoChamado = nil
        TD.marcarJanelasFeitas()
    end
    TD.logEv(ligar and "Eventos LIGADOS." or "Eventos DESLIGADOS.")
    TD.atualizarEventos()
end

-- Botao EVENTOS, igual ao TASK: rodando -> para; parado -> liga e ja sai andando nos gotos.
-- perfil: CaveBot visivel na aba CAVEBOT (nil = evento selecionado na aba EVENTOS).
function TD.botaoEventos(perfil)
    -- ON (rodando OU so ligado esperando) -> OFF. Antes, ligado sem evento rodando caia no "liga de novo":
    -- se o inicio falhava (task rodando, CaveBot sem gotos) o botao ficava ON pra sempre a cada clique.
    if TD.evRun or cfg.eventosAtivo then return TD.alternarEventos(false) end
    local k = TD.evEditando
    if perfil then
        k = nil
        for _, e in ipairs(TD.ORDEM_EVENTOS) do
            if TD.perfilDoEvento(e) == perfil then k = e break end
        end
        k = k or TD.evEditando
    end
    if not k then return end
    -- todo evento entra pela entrada fixa do TP (perfil e opcional): liga ja andando pro TP
    cfg.eventosAtivo = true
    TD.iniciarEventoRota(k, perfil)
    -- nao conseguiu comecar (o motivo ja foi pro log): volta pra OFF em vez de ficar ON parado
    if not TD.evRun then cfg.eventosAtivo = false end
    TD.atualizarEventos()
end

function TD.pintarEventos()
    for _, b in ipairs({ui.evMaster, ui.cbEventos}) do
        pintarToggle(b, TD.evRun ~= nil or cfg.eventosAtivo, "EVENTOS: ON", "EVENTOS: OFF")
    end
end
function TD.atualizarEventos()
    local k = TD.evEditando
    local info = TD.EVENTOS[k]
    ui.evNome:setText(info.titulo)
    ui.evPronto:setText(info.pronto and "Sistema pronto" or "Sistema ainda nao feito (a agenda ignora)")
    ui.evPronto:setColor(info.pronto and "#55DD55" or "#AAAAAA")
    ui.evLabelFim.onTextChange = nil
    ui.evLabelFim:setText(TD.labelFimEvento(k))
    ui.evLabelFim.onTextChange = function(_, t) cfg.evLabelFimPor[TD.evEditando] = tostring(t):gsub("^%s+", ""):gsub("%s+$", "") end
    ui.evCombo.onOptionChange = nil
    ui.evCombo:clearOptions()
    ui.evCombo:addOption("(nenhum)")
    for _, n in ipairs(TD.nomesPerfis()) do ui.evCombo:addOption(n) end
    pcall(function() ui.evCombo:setCurrentOption(cfg.eventoPerfil[k] or "(nenhum)") end)
    ui.evCombo.onOptionChange = function(_, t) cfg.eventoPerfil[TD.evEditando] = (t ~= "(nenhum)") and t or nil end
    if TD.pintarDisputar then TD.pintarDisputar() end
    TD.pintarEventos()
end
local function trocarEvento(passo)
    local idx = 1
    for i, k in ipairs(TD.ORDEM_EVENTOS) do if k == TD.evEditando then idx = i end end
    TD.evEditando = TD.ORDEM_EVENTOS[(idx - 1 + passo) % #TD.ORDEM_EVENTOS + 1]
    TD.atualizarEventos()
end
-- atraso (segundos, opcional): conta ate horario da agenda + atraso (ex.: abertura real do TP do evento)
function TD.proximaJanela(lista, soProntos, atraso)
    local agora = os.time()
    local melhor, melhorK = nil, nil
    for _, k in ipairs(lista) do
        local ag = cfg.agenda[k]
        local ok = ag and ag.ativo and (not soProntos or (TD.EVENTOS[k] and TD.EVENTOS[k].pronto))
        if ok then
            if not atraso and TD.janelaAgora(k) then return 0, k end
            local permitidos = TD.TAREFAS[k] and TD.TAREFAS[k].dias
            for d = atraso and -1 or 0, 7 do
                local t = os.date("*t", agora + d * 86400)
                local dia = TD.DIAS[t.wday]
                if not permitidos or permitidos[dia] then
                    local base = os.time({year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0})
                    for _, j in ipairs(TD.janelasDaTask(k, ag.horariosDia[dia]) or {}) do
                        local inicio = base + j.ini * 60 + (atraso or 0)
                        if inicio > agora and (not melhor or inicio - agora < melhor) then
                            melhor, melhorK = inicio - agora, k
                        end
                    end
                end
            end
        end
    end
    return melhor, melhorK
end

local function tempoCurto(seg)
    if seg >= 86400 then
        return string.format("%dd %02dh%02d", math.floor(seg / 86400), math.floor(seg % 86400 / 3600), math.floor(seg % 3600 / 60))
    end
    if seg >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(seg / 3600), math.floor(seg % 3600 / 60), seg % 60)
    end
    return string.format("%02d:%02d", math.floor(seg / 60), seg % 60)
end

cfg.mostrarTask = cfg.mostrarTask == true
cfg.mostrarEvento = cfg.mostrarEvento == true
TD.prox = {}
TD.EVENTO_ABRE_APOS_MIN = 3   -- o TP do evento abre 3 min depois do horario da agenda
-- horario REAL que o TP de cada evento abre (todos os dias). A contagem em cima do personagem usa esta lista
-- (a agenda continua chamando antes, com os horarios dela).
TD.ABERTURA_TP = {
    ev_snowball  = {"14:30"},
    ev_island    = {"13:00", "19:00", "22:30"},
    ev_firestorm = {"12:30", "18:30", "23:30"},
    ev_zombie    = {"13:30", "19:30", "23:00"},
}
-- proxima abertura de TP entre os eventos com agenda ATIVA: segundos ate ela, evento
function TD.proximaAberturaTp()
    local agora = os.time()
    local melhor, melhorK = nil, nil
    for _, k in ipairs(TD.ORDEM_EVENTOS) do
        local ag = cfg.agenda[k]
        if ag and ag.ativo and TD.ABERTURA_TP[k] then
            for d = 0, 1 do
                local t = os.date("*t", agora + d * 86400)
                for _, h in ipairs(TD.ABERTURA_TP[k]) do
                    local hh, mm = h:match("^(%d+):(%d+)$")
                    local inicio = os.time({year = t.year, month = t.month, day = t.day, hour = tonumber(hh), min = tonumber(mm), sec = 0})
                    if inicio > agora and (not melhor or inicio - agora < melhor) then
                        melhor, melhorK = inicio - agora, k
                    end
                end
            end
        end
    end
    return melhor, melhorK
end
function TD.calcularProximos()
    local agora = os.time()
    local segT, kT = TD.proximaJanela(TD.AGENDAVEIS)
    -- evento: em cima do personagem conta ate a ABERTURA real do TP (TD.ABERTURA_TP)
    local segE, kE = TD.proximaAberturaTp()
    TD.prox = {
        task = segT and {fim = agora + segT, nome = TD.TAREFAS[kT].curto} or nil,
        evento = segE and {fim = agora + segE, nome = TD.EVENTOS[kE].curto} or nil,
    }
end
-- soEvento: evento ja rodando (indo pro TP antes de abrir) -> mostra so a contagem do evento
function TD.textoContagem(soEvento)
    local agora = os.time()
    local vencido = (TD.prox.task and TD.prox.task.fim < agora) or (TD.prox.evento and TD.prox.evento.fim < agora)
    if vencido and agora ~= TD.ultimoCalcProx then
        TD.ultimoCalcProx = agora
        TD.calcularProximos()
    end
    local escolhido, cor = nil, "#FFFFFF"
    local t, e = cfg.mostrarTask and TD.prox.task, cfg.mostrarEvento and TD.prox.evento
    if soEvento or (t and (t.fim - agora > 600 or t.fim - agora <= 0)) then t = nil end
    if e and (e.fim - agora > 600 or e.fim - agora <= 0) then e = nil end
    if t and (not e or t.fim <= e.fim) then escolhido, cor = t, "#FFD24A"
    elseif e then escolhido, cor = e, "#7FB2FF" end
    if not escolhido then return "", "#FFFFFF" end
    local resta = escolhido.fim - agora
    if resta <= 0 then return escolhido.nome .. " agora", cor end
    return escolhido.nome .. " em " .. tempoCurto(resta), cor
end
function TD.pintarMostrar()
    local function caixa(wd, v)
        local ok, box = pcall(function() return wd:getChildById("box") end)
        if ok and box then
            pcall(function()
                box:setText(v and "v" or "")
                box:setBackgroundColor(v and "#1FA83A" or "#111111")
                box:setBorderColor(v and "#35D455" or "#888888")
            end)
        end
    end
    caixa(ui.mostrarTask, cfg.mostrarTask)
    caixa(ui.mostrarEvento, cfg.mostrarEvento)
end
function TD.alternarMostrar(qual)
    if qual == "task" then cfg.mostrarTask = not cfg.mostrarTask else cfg.mostrarEvento = not cfg.mostrarEvento end
    TD.pintarMostrar()
    TD.log((qual == "task" and "Contagem da task" or "Contagem do evento") .. " em cima do personagem: " ..
        (((qual == "task") and cfg.mostrarTask or (qual ~= "task" and cfg.mostrarEvento)) and "LIGADA" or "DESLIGADA") .. ".")
end
ui.mostrarTask.onClick = function() TD.alternarMostrar("task") end
ui.mostrarEvento.onClick = function() TD.alternarMostrar("evento") end
TD.pintarMostrar()
TD.calcularProximos()
macro(1000, function() TD.calcularProximos() end)

macro(1000, function()
    if not w:isVisible() then return end
    local txtT
    if TD.ativo then
        txtT = (TD.TAREFAS[cfg.tarefa] and TD.TAREFAS[cfg.tarefa].curto or "Task") .. " agora"
    else
        local seg, k = TD.proximaJanela(TD.AGENDAVEIS)
        txtT = seg and (TD.TAREFAS[k].curto .. " " .. (seg == 0 and "agora" or tempoCurto(seg))) or "Task --"
    end
    local txtE
    if TD.evRun then
        txtE = (TD.EVENTOS["ev_" .. TD.evRun.tipo] or {curto = "Evento"}).curto .. " agora"
    else
        local seg, k = TD.proximaJanela(TD.ORDEM_EVENTOS, false)
        txtE = seg and (TD.EVENTOS[k].curto .. " " .. (seg == 0 and "agora" or tempoCurto(seg))) or "Evento --"
    end
    ui.relogioTask:setText(txtT)
    ui.relogioEvento:setText(txtE)
    pcall(function() ui.mostrarTask:setTooltip("Mostrar em cima do personagem (Alt+2).\nProxima task: " .. txtT) end)
    pcall(function() ui.mostrarEvento:setTooltip("Mostrar em cima do personagem (Alt+3).\nProximo evento: " .. txtE) end)
    pcall(function() ui.relogioTask:setTooltip("Proxima task: " .. txtT) end)
    pcall(function() ui.relogioEvento:setTooltip("Proximo evento: " .. txtE) end)
end)

ui.evPrev.onClick = function() trocarEvento(-1) end
ui.evNext.onClick = function() trocarEvento(1) end
ui.evMaster.onClick = function() TD.botaoEventos(nil) end
ui.cbEventos.onClick = function() TD.botaoEventos(TD.perfilEditado) end
TD.atualizarEventos()
macro(500, function()
    TD.pintarEventos()
    if not w:isVisible() or TD.abaAtual ~= "EVENTOS" then return end
    local ev = TD.evRun
    local titulo = ev and (TD.EVENTOS["ev_" .. ev.tipo] or {titulo = ev.tipo}).titulo
    ui.evEstado:setText(ev and ("Estado: RODANDO " .. titulo) or
        ("Estado: parado" .. (TD.eventoChamado and (" (agenda chamou " .. TD.EVENTOS[TD.eventoChamado].curto .. ")") or "")))
    ui.evEstado:setColor(ev and "#55FF55" or "#FFD24A")
    local fases = {FORCANDO = "Forcando entrar no TP (esperando abrir)", SALA = "Aguardando na sala", BOSS = "Batendo no boss", TP = "Indo para o TP", ROTA = "Andando nos gotos",
                   FUGA = "Fugindo dos zombies", ESPERA = "Esperando comecar", JOGO = "Atirando bolas de neve"}
    local fase = ev and (fases[ev.fase] or ev.fase) or "-"
    if ev and ev.fase == "ROTA" and TD.estado:find("ESPERANDO", 1, true) then fase = "Esperando o TP do evento abrir" end
    ui.evFase:setText("Fase: " .. fase)
    if ev and ev.tipo == "snowball" then
        ui.evBoss:setText("Bolas: " .. (ev.bolas or "?") .. " | Tiros: " .. (ev.tiros or 0) .. " | Parados: " .. (ev.nParados or 0) .. "/" .. (ev.nPlayers or 0) ..
            " | " .. (ev.snowEstado or "-") .. (ev.alvoSnow and (" " .. ev.alvoSnow) or ""))
    elseif ev and ev.tipo == "zombie" then
        ui.evBoss:setText((ev.restam and ("Restam " .. ev.restam .. " | ") or "") .. "Zombies: " .. (ev.zombies or 0) .. " na tela | perto: " ..
            ((ev.pertoZombie or 99) < 99 and (ev.pertoZombie .. " sqm") or "-") .. " | " .. (ev.fugaEstado or "-") ..
            (ev.calcMs and (" | calc " .. math.floor(ev.calcMs) .. "ms (max " .. math.floor(ev.calcMax or 0) .. ")") or ""))
    else
        ui.evBoss:setText("Boss: " .. (ev and ev.bossNome and (ev.bossIdx .. "/5 " .. ev.bossNome) or "-"))
    end
    local rota = ev and ev.rota and TD.ROTAS and (TD.rota == "VOLTA" and TD.rotaVolta or TD.ROTAS[TD.rota])
    ui.evRota:setText("Rota: " .. (rota and (TD.perfilAtivo .. " / " .. TD.rota .. " (goto " .. TD.wp .. "/" .. #rota .. ")") or "-"))
    -- v5.5: contagem do "!tp thais" (zera toda vez que pisa no sqm do TP)
    local semTp = ev and ev.rota and not ev.dentro and ev.semTpDesde
        and (" | Sem pisar no TP: " .. math.floor((agoraMs() - ev.semTpDesde) / 1000) .. "/" .. TD.TP_THAIS_SEG .. "s") or ""
    ui.evTempo:setText("Tempo: " .. (ev and formatarTempo(os.time() - ev.inicio) or "-") .. semTp)
    ui.evUltimo:setText("Ultimo: " .. (TD.evUltimo or "-"))
    ui.evLog:setText(TD.eventoEv)
end)
ui.abaTarget.onClick = function() TD.mostrarAba("TARGET") end

TD.tgEditando = cfg.tarefa or "infernal"
local OPCOES_ATAQUE = {
    {chave = "semMagia", ui = "tgSemMagia", nome = "Sem magia"},
    {chave = "exoriCon", ui = "tgExoriCon", nome = "Exori con"},
    {chave = "exoriSan", ui = "tgExoriSan", nome = "Exori san"},
    {chave = "exoriHur", ui = "tgExoriHur", nome = "Exori hur"},
    {chave = "exoriMas", ui = "tgExoriMas", nome = "Exori mas"},
    {chave = "exevoMasSan", ui = "tgExevoMasSan", nome = "Exevo mas san"},
    {chave = "gfb", ui = "tgGfb", nome = "GFB"},
    {chave = "avalanche", ui = "tgAvalanche", nome = "Avalanche"},
    {chave = "sd", ui = "tgSd", nome = "SD"},
}

local function marcarCaixa(widget, marcado)
    widget._marcado = marcado
    local ok, box = pcall(function() return widget:getChildById("box") end)
    if ok and box then
        pcall(function()
            box:setText(marcado and "v" or "")
            box:setBackgroundColor(marcado and "#1FA83A" or "#111111")
            box:setBorderColor(marcado and "#35D455" or "#888888")
        end)
    end
    if widget.setChecked then pcall(function() widget:setChecked(marcado) end) end
end

-- v5.7: caixa "Disputar" da aba EVENTOS (so aparece no Zombie)
function TD.pintarDisputar()
    ui.evDisputar:setVisible(TD.evEditando == "ev_zombie")
    marcarCaixa(ui.evDisputar, TD.zombieDisputar())
end
ui.evDisputar.onClick = function()
    cfg.evDisputar.ev_zombie = not TD.zombieDisputar()
    TD.pintarDisputar()
    TD.logEv("Zombie: Disputar " .. (TD.zombieDisputar() and "MARCADO (foge pra vencer)." or "DESMARCADO (entra e fica parado)."))
end
TD.pintarDisputar()

function TD.atualizarTarget()
    if not TD.TAREFAS[TD.tgEditando] then TD.tgEditando = TD.ORDEM[1] end
    local tc = TD.cfgTarget(TD.tgEditando)
    ui.tgNome:setText(TD.TAREFAS[TD.tgEditando].titulo)
    marcarCaixa(ui.tgModo100, tc.modo == "100")
    marcarCaixa(ui.tgModo50, tc.modo == "50")
    marcarCaixa(ui.tgModo1, tc.modo == "1")
    for _, o in ipairs(OPCOES_ATAQUE) do
        ui[o.ui]:setText(o.nome)
        marcarCaixa(ui[o.ui], tc[o.chave] == true)
    end
    ui.tgInfo:setText("")
    TD.pintarSecoesTarget()
    if ui.tgCombo and TD.tgComboPronto then
        ui.tgCombo.onOptionChange = nil
        pcall(function() ui.tgCombo:setCurrentOption(TD.perfilDaTarefa(TD.tgEditando)) end)
        ui.tgCombo.onOptionChange = function(_, texto) cfg.perfilTarefa[TD.tgEditando] = texto end
    end
end

cfg.tgAberto = cfg.tgAberto or {modo = true, ataque = true, cave = true}
local SECOES_TARGET = {
    {chave = "modo", botao = "tgSecModo", painel = "tgPainelModo", titulo = "Quanto bater", altura = 52},
    {chave = "ataque", botao = "tgSecAtaque", painel = "tgPainelAtaque", titulo = "Como atacar", altura = 88},
    {chave = "cave", botao = "tgSecCave", painel = "tgPainelCave", titulo = "CaveBot script", altura = 22},
}
function TD.alturaTarget()
    local h = 218
    for _, sc in ipairs(SECOES_TARGET) do
        if cfg.tgAberto[sc.chave] ~= false then h = h + sc.altura + 2 end
    end
    return h
end
function TD.pintarSecoesTarget()
    for _, sc in ipairs(SECOES_TARGET) do
        local aberto = cfg.tgAberto[sc.chave] ~= false
        ui[sc.botao]:setText((aberto and "[-] " or "[+] ") .. sc.titulo)
        if aberto then ui[sc.painel]:show() else ui[sc.painel]:hide() end
        pcall(function() ui[sc.painel]:setHeight(aberto and sc.altura or 0) end)
    end
    if TD.abaAtual == "TARGET" then w:setHeight(TD.alturaTarget()) end
end
for _, sc in ipairs(SECOES_TARGET) do
    ui[sc.botao].onClick = function()
        cfg.tgAberto[sc.chave] = not (cfg.tgAberto[sc.chave] ~= false)
        TD.pintarSecoesTarget()
    end
end

local function trocarTarget(passo)
    local idx = 1
    for i, k in ipairs(TD.ORDEM) do if k == TD.tgEditando then idx = i end end
    idx = (idx - 1 + passo) % #TD.ORDEM + 1
    TD.tgEditando = TD.ORDEM[idx]
    TD.atualizarTarget()
end
ui.tgPrev.onClick = function() trocarTarget(-1) end
ui.tgNext.onClick = function() trocarTarget(1) end
ui.tgModo100.onClick = function() TD.cfgTarget(TD.tgEditando).modo = "100" TD.atualizarTarget() end
ui.tgModo50.onClick = function() TD.cfgTarget(TD.tgEditando).modo = "50" TD.atualizarTarget() end
ui.tgModo1.onClick = function() TD.cfgTarget(TD.tgEditando).modo = "1" TD.atualizarTarget() end
for _, o in ipairs(OPCOES_ATAQUE) do
    ui[o.ui].onClick = function()
        local tc = TD.cfgTarget(TD.tgEditando)
        for _, x in ipairs(OPCOES_ATAQUE) do tc[x.chave] = (x.chave == o.chave) end
        TD.atualizarTarget()
    end
end
ui.closeButton.onClick = function() w:hide() end
ui.fechar.onClick = function() w:hide() end

TD.linhaTarefa = g_ui.createWidget("TDLinha", ui.listaTarefas)
TD.linhaTarefa.onClick = function()
    if TD.ativo then TD.log("Desligue a task antes de trocar a tarefa.") return end
    local atual = 1
    for i, k in ipairs(TD.ORDEM) do if k == cfg.tarefa then atual = i end end
    cfg.tarefa = TD.ORDEM[atual % #TD.ORDEM + 1]
    TD.tagueados, TD.pulados = {}, {}
    TD.atualizarPainel()
end

function TD.limparEstado()
    TD.morto = false
    TD.voltando, TD.voltaFeita = false, false
    TD.fugindo = false
    TD.alvo, TD.alvoExtra = nil, nil
    TD.focoTrap = false
    TD.alvoHpInicial, TD.alvoHpId, TD.alvoHpUlt = nil, nil, nil
    TD.aproximandoDesde, TD.aproxId, TD.aproxMelhor = nil, nil, nil
    TD.tentativasAtaque, TD.tentativasId = 0, nil
    TD.caminho, TD.caminhoIdx, TD.caminhoAuto = nil, 1, false
    TD.destinoAtual, TD.destinoCliente = nil, nil
    TD.semCaminhoAte, TD.caminhoCalc = nil, 0
    TD.esperaAte, TD.esperaWp, TD.ladoFeito = nil, nil, nil
    TD.passoExatoAte, TD.proxChecaOcupado = 0, 0
    TD.ultimaPosRota, TD.posVigia = nil, nil
    TD.nivelTravado, TD.ultimoProgresso = 0, agoraMs()
    TD.caminhoChecado = {}
    TD.pulados, TD.vezesPulado = {}, {}
    TD.saiuDaRota = false
    TD.semSaida = {}
    if player.stopAutoWalk then pcall(function() player:stopAutoWalk() end) end
end

function TD.ligarManual()
    if TD.ativo then
        TD.desligar("DESLIGADO")
        TD.caveBotEstava = nil
        return
    end
    if TD.evRun then
        TD.log("Task nao ligada: tem um evento rodando (desligue em EVENTOS).")
        return
    end
    TD.origemAgenda, TD.janelaOrigem, TD.janelaChave = nil, nil, nil
    cfg.tarefaChamada = nil
    TD.limparEstado()
    if TD.progresso() >= TD.metaDe() then
        TD.log(TD.tarefaAtual().titulo .. " ja estava completa (" .. TD.progresso() .. "/" .. TD.metaDe() .. "). Comecando do 0.")
        TD.resetarTarefa(cfg.tarefa)
    end
    local p = player:getPosition()
    if p and not TD.posDP then TD.posDP = {x = p.x, y = p.y, z = p.z} end
    TD.ligar()
end
ui.ligar.onClick = function()
    TD.ligarManual()
    TD.atualizarPainel()
end
ui.cbTask.onClick = function()
    TD.ligarManual()
    TD.atualizarPainel()
end
ui.modo.onClick = function()
    cfg.modos[cfg.tarefa] = TaskDemon.modoDe() == "MELEE" and "DISTANCIA" or "MELEE"
    if TD.ativo and g_game.setChaseMode then g_game.setChaseMode(TaskDemon.modoDe() == "MELEE" and 1 or 0) end
    TD.atualizarPainel()
end
function TD.resetarTarefa(k)
    k = k or cfg.tarefa
    TD.zerarTarefa(k)
    cfg.janelaProgresso[k] = nil
    local marca = "|" .. k .. "|"
    for chave in pairs(cfg.concluidas) do
        if chave:find(marca, 1, true) then cfg.concluidas[chave] = nil end
    end
    for chave in pairs(cfg.disparos) do
        if chave:find(marca, 1, true) then cfg.disparos[chave] = nil end
    end
    if cfg.tarefaChamada == k then cfg.tarefaChamada = nil end
    local nomesTask = {}
    for _, t in pairs(TD.TAREFAS) do nomesTask[t.nome:lower()] = true end
    for _, spec in ipairs(getSpectators()) do
        local okN, nome = pcall(function() return spec:getName():lower() end)
        if okN and nomesTask[nome] then pcall(function() spec:setText("", "#FFFFFF") end) end
    end
    for _, c in ipairs(TD.numerados or {}) do pcall(function() c:setText("", "#FFFFFF") end) end
    TD.numerados = {}
    TD.textoCache = {}
    if TD.marcarQuadrado then TD.marcarQuadrado(nil) end
    TD.tagueados, TD.pulados = {}, {}
    TD.hpVisto = {}
    TD.vezesPulado = {}
    TD.mortesContadas = {}
    TD.alvoExtra = nil
    if TD.ativo and g_game.cancelAttack then g_game.cancelAttack() end
    TD.alvo = nil
    TD.alvoHpInicial, TD.alvoHpId, TD.alvoHpUlt = nil, nil, nil
    TD.aproximandoDesde = nil
    TD.focoTrap = false
    TD.caminhoChecado = {}
    TD.morto = false
    if TD.ativo and cfg.tarefa == k then
        cfg.inicioTask = os.time()
        if TD.voltando then
            TD.voltando = false
            TD.escolherRotaInicial()
        end
    else
        cfg.inicioTask = 0
    end
    TD.log("Task " .. TD.TAREFAS[k].titulo .. " resetada: progresso 0 e memoria limpa.")
end

ui.zerar.onClick = function()
    if not TD.zerarConfirmaAte or os.time() > TD.zerarConfirmaAte then
        TD.zerarConfirmaAte = os.time() + 3
        ui.zerar:setText("CONFIRMAR ZERAR " .. TD.tarefaAtual().curto:upper() .. "?")
        return
    end
    TD.zerarConfirmaAte = nil
    ui.zerar:setText("ZERAR ESTA TAREFA")
    TD.resetarTarefa(cfg.tarefa)
    TD.atualizarPainel()
end

macro(1000, function()
    if TD.zerarConfirmaAte and os.time() > TD.zerarConfirmaAte then
        TD.zerarConfirmaAte = nil
        ui.zerar:setText("ZERAR ESTA TAREFA")
    end
end)
local function campoNumero(campo, chave, minimo, maximo)
    campo:setText(tostring(cfg[chave]))
    campo.onTextChange = function(_, t)
        local v = tonumber(t)
        if v and v >= minimo and v <= maximo then cfg[chave] = math.floor(v) end
    end
end
ui.meta:setText(tostring(TD.metaDe()))
TD.metaMostrada = cfg.tarefa
ui.meta.onTextChange = function(_, t)
    local v = tonumber(t)
    if v and v >= 1 and v <= 100000 then cfg.metas[cfg.tarefa] = math.floor(v) end
end
campoNumero(ui.alcance, "alcance", 1, 10)

TD.secoes = {}
local function montarSecao(k, pai)
    local ag = cfg.agenda[k]
    local s = g_ui.createWidget("TDSecao", pai or ui.secoes)
    local sec = {
        nome = s:getChildById("nome"), ativo = s:getChildById("ativo"), label = s:getChildById("label"),
        dias = s:getChildById("dias"), horarios = s:getChildById("horarios"), janelas = s:getChildById("janelas"),
        tituloHorarios = s:getChildById("tituloHorarios"),
        botoesDia = {},
        diaSel = TD.DIAS[os.date("*t").wday],
    }
    sec.nome:setText("*  " .. (TD.TAREFAS[k] or TD.EVENTOS[k]).titulo)
    sec.ativo.onClick = function()
        cfg.agenda[k].ativo = not cfg.agenda[k].ativo
        TD.atualizarAgenda()
    end
    sec.label:setText(ag.label)
    sec.label.onTextChange = function(_, t)
        cfg.agenda[k].label = tostring(t):gsub("^%s+", ""):gsub("%s+$", "")
    end
    sec.horarios:setText(ag.horariosDia[sec.diaSel] or "")
    sec.horarios.onTextChange = function(_, t)
        cfg.agenda[k].horariosDia[sec.diaSel] = t
        TD.atualizarAgenda()
    end
    for _, d in ipairs(TD.DIAS) do
        local b = g_ui.createWidget("TDDia", sec.dias)
        b:setText(d:upper())
        b.onClick = function()
            sec.diaSel = d
            sec.horarios:setText(cfg.agenda[k].horariosDia[d] or "")
            TD.atualizarAgenda()
        end
        sec.botoesDia[d] = b
    end
    TD.secoes[k] = sec
end
for _, k in ipairs(TD.AGENDAVEIS) do montarSecao(k) end
for _, k in ipairs(TD.ORDEM_EVENTOS) do montarSecao(k, ui.secoesEv) end
TD.agendaAba = "TASKS"
function TD.trocarAgenda(aba)
    TD.agendaAba = aba
    if aba == "EVENTOS" then ui.painelTasks:hide() ui.painelEventos:show() else ui.painelEventos:hide() ui.painelTasks:show() end
    pintarToggle(ui.agTasks, aba == "TASKS", "AGENDA TASKS", "AGENDA TASKS")
    pintarToggle(ui.agEventos, aba == "EVENTOS", "AGENDA EVENTOS", "AGENDA EVENTOS")
end
ui.agTasks.onClick = function() TD.trocarAgenda("TASKS") end
ui.agEventos.onClick = function() TD.trocarAgenda("EVENTOS") end
TD.trocarAgenda("TASKS")

ui.restaurar.onClick = function()
    local lista = TD.agendaAba == "EVENTOS" and TD.ORDEM_EVENTOS or TD.AGENDAVEIS
    for _, k in ipairs(lista) do
        cfg.agenda[k] = TD.agendaPadrao(k)   -- eventos: volta pros horarios padrao; tasks: vazio
        local sec = TD.secoes[k]
        sec.label:setText(cfg.agenda[k].label)
        sec.horarios:setText(cfg.agenda[k].horariosDia[sec.diaSel] or "")
    end
    TD.log("Agenda restaurada.")
    TD.atualizarAgenda()
end

function TD.atualizarAgenda()
    for k, sec in pairs(TD.secoes) do
        local ag = cfg.agenda[k]
        pintarToggle(sec.ativo, ag.ativo, "Ativo", "Desativado")

        for _, d in ipairs(TD.DIAS) do
            local b = sec.botoesDia[d]
            local tem = (ag.horariosDia[d] or ""):match("%S") ~= nil
            if d == sec.diaSel then
                b:setBackgroundColor(SEL_BG)
                b:setColor("#FFD700")
            else
                b:setBackgroundColor(tem and VERDE_BG or CINZA_BG)
                b:setColor(tem and "#77FF77" or "#777777")
            end
        end
        sec.tituloHorarios:setText("Horarios de " .. NOME_DIA[sec.diaSel])
        local n, diaErro = TD.janelasPorSemana(k)
        if n then
            sec.janelas:setText(n .. " janelas por semana")
            sec.janelas:setColor(n > 0 and "#55DD55" or "#AAAAAA")
        else
            sec.janelas:setText("Horario invalido em " .. NOME_DIA[diaErro])
            sec.janelas:setColor("#FF5555")
        end
    end
end

local OPCAO_ANTERIOR = "(o atual)"

function TD.preencherCaveBots()
    local lista = TD.listarCaveBots()
    local combo = ui.cbHunt
    combo.onOptionChange = nil
    combo:clearOptions()
    combo:addOption(OPCAO_ANTERIOR)
    local achou = false
    for _, nome in ipairs(lista) do
        combo:addOption(nome)
        if nome == cfg.cb.hunt then achou = true end
    end
    combo:setCurrentOption(achou and cfg.cb.hunt or OPCAO_ANTERIOR)
    combo.onOptionChange = function(_, texto)
        cfg.cb.hunt = (texto == OPCAO_ANTERIOR) and "" or texto
    end
    if #lista == 0 then TD.log("Nenhum CaveBot encontrado na sua config do bot.") end
    return #lista
end
ui.cbAtualizar.onClick = function()
    TD.log(TD.preencherCaveBots() .. " CaveBots do bot encontrados.")
end

TD.perfilEditado = TD.perfilAtivo
TD.rotaEditada = "PRINCIPAL"
TD.gotoSel = nil
TD.combosLigacao = {}
local BOTOES_ROTA = {CAMINHO = "rotaPrincipal", PRINCIPAL = "rotaCidade", DP = "rotaDP"}

function TD.preencherPerfis()
    local nomes = TD.nomesPerfis()
    if not cfg.perfis[TD.perfilEditado] then TD.perfilEditado = nomes[1] end

    ui.perfilSel.onOptionChange = nil
    ui.perfilSel:clearOptions()
    for _, n in ipairs(nomes) do ui.perfilSel:addOption(n) end
    ui.perfilSel:setCurrentOption(TD.perfilEditado)
    ui.perfilSel.onOptionChange = function(_, texto)
        TD.perfilEditado = texto
        TD.gotoSel = nil
        TD.montarListaGotos()
    end

    if ui.tgCombo then
        ui.tgCombo.onOptionChange = nil
        ui.tgCombo:clearOptions()
        for _, n in ipairs(nomes) do ui.tgCombo:addOption(n) end
        local k = TD.tgEditando or cfg.tarefa
        pcall(function() ui.tgCombo:setCurrentOption(TD.perfilDaTarefa(k)) end)
        ui.tgCombo.onOptionChange = function(_, texto) cfg.perfilTarefa[TD.tgEditando or cfg.tarefa] = texto end
        TD.tgComboPronto = true
    end
end

function TD.pedirTexto(titulo, inicial, cb)
    if UI and UI.SinglelineEditorWindow then
        local ok = pcall(function()
            UI.SinglelineEditorWindow(inicial or "", {title = titulo, description = titulo}, function(t) cb(t) end)
        end)
        if ok then return end
    end
    TD.log("Esse bot nao tem a janela de texto.")
end

local function limparNome(t) return tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "") end

ui.perfilNovo.onClick = function()
    TD.pedirTexto("Nome do novo CaveBot", "", function(t)
        local nome = limparNome(t)
        if nome == "" or cfg.perfis[nome] then TD.log("Nome vazio ou ja existe.") return end
        cfg.perfis[nome] = {CAMINHO = {}, PRINCIPAL = {}, DP = {}}
        TD.perfilEditado = nome
        TD.log("CaveBot '" .. nome .. "' criado vazio.")
        TD.preencherPerfis()
        TD.montarListaGotos()
    end)
end

ui.perfilRenomear.onClick = function()
    local antigo = TD.perfilEditado
    TD.pedirTexto("Novo nome do CaveBot", antigo, function(t)
        local nome = limparNome(t)
        if nome == "" or nome == antigo or cfg.perfis[nome] then TD.log("Nome vazio, igual ou ja existe.") return end
        cfg.perfis[nome] = cfg.perfis[antigo]
        cfg.perfis[antigo] = nil
        for k, v in pairs(cfg.perfilTarefa) do if v == antigo then cfg.perfilTarefa[k] = nome end end
        if TD.perfilAtivo == antigo then TD.perfilAtivo = nome end
        TD.perfilEditado = nome
        TD.log("CaveBot '" .. antigo .. "' renomeado para '" .. nome .. "'.")
        TD.preencherPerfis()
        TD.montarListaGotos()
    end)
end

ui.perfilExcluir.onClick = function()
    local nome = TD.perfilEditado
    if #TD.nomesPerfis() <= 1 then TD.log("Precisa ter pelo menos um CaveBot.") return end
    if TD.ativo and TD.perfilAtivo == nome then TD.log("Esse CaveBot esta em uso pela task.") return end
    if not TD.excluirConfirmaAte or os.time() > TD.excluirConfirmaAte then
        TD.excluirConfirmaAte = os.time() + 3
        ui.perfilExcluir:setText("CONFIRM")
        TD.log("Clique de novo em 3s para excluir o CaveBot '" .. nome .. "'.")
        return
    end
    TD.excluirConfirmaAte = nil
    ui.perfilExcluir:setText("EXCLUIR")
    cfg.perfis[nome] = nil
    TD.perfilEditado = TD.nomesPerfis()[1]
    for k, v in pairs(cfg.perfilTarefa) do if v == nome then cfg.perfilTarefa[k] = TD.perfilEditado end end
    TD.log("CaveBot '" .. nome .. "' excluido.")
    TD.preencherPerfis()
    TD.montarListaGotos()
end

local function rotaEditadaTabela() return cfg.perfis[TD.perfilEditado][TD.rotaEditada] end

TD.linhasGoto = {}
local function textoGoto(i, g, atual)
    local w = tonumber(g[4])
    local extras = ""
    if w then extras = extras .. "  " .. (w / 1000) .. "s" end
    if g[5] and TD.NOME_LADO[g[5]] then extras = extras .. "  " .. TD.NOME_LADO[g[5]] end
    return string.format("%s%02d   %d, %d, %d%s", atual and ">> " or "   ", i, g[1], g[2], g[3], extras)
end

-- desce/sobe a lista de gotos ate a linha ficar visivel
local function mostrarLinhaGoto(linha, idx)
    local ok = ui.listaGotos.ensureChildVisible and pcall(function() ui.listaGotos:ensureChildVisible(linha) end)
    if not ok then
        pcall(function()
            local alt = linha:getHeight() + (ui.listaGotos:getLayout():getSpacing() or 0)
            local vis = ui.listaGotos:getHeight()
            local alvo = (idx - 1) * alt - math.floor(vis / 2) + alt
            ui.gotosScroll:setValue(math.max(ui.gotosScroll:getMinimum(), math.min(ui.gotosScroll:getMaximum(), alvo)))
        end)
    end
end

function TD.montarListaGotos()
    local rota = rotaEditadaTabela()
    local rodando = TD.rodandoRota and TD.rodandoRota() and TD.perfilEditado == TD.perfilAtivo and TD.rotaEditada == TD.rota
        and not (TD.evRun and TD.rota == "CAMINHO")
    local chave = TD.perfilEditado .. "|" .. TD.rotaEditada .. "|" .. #rota
    local scroll = nil
    pcall(function() scroll = ui.gotosScroll:getValue() end)
    if TD.chaveLista ~= chave or #TD.linhasGoto ~= #rota then
        ui.listaGotos:destroyChildren()
        TD.linhasGoto = {}
        for i = 1, #rota do
            local linha = g_ui.createWidget("TDGoto", ui.listaGotos)
            linha.onClick = function()
                TD.gotoSel = (TD.gotoSel == i) and nil or i
                TD.carregarEdicao()
                TD.montarListaGotos()
            end
            linha.onDoubleClick = function()
                TD.gotoSel = i
                TD.carregarEdicao()
                TD.montarListaGotos()
                return true
            end
            TD.linhasGoto[i] = linha
        end
        if TD.chaveLista and TD.chaveLista:match("^(.-|.-)|") == chave:match("^(.-|.-)|") and scroll then
            pcall(function() ui.gotosScroll:setValue(scroll) end)
        end
        TD.chaveLista = chave
    end
    local linhaAtual, idxAtual = nil, nil
    for i, g in ipairs(rota) do
        local linha = TD.linhasGoto[i]
        local atual = rodando and i == TD.wp
        local sel = (i == TD.gotoSel) and not rodando   -- rodando: so o goto atual fica amarelo
        linha:setText(textoGoto(i, g, atual))
        if atual or sel then
            linha:setBackgroundColor(SEL_BG)
            linha:setColor("#FFD700")
            if atual then linhaAtual, idxAtual = linha, i end
        else
            linha:setBackgroundColor(i % 2 == 0 and "#151515EE" or "#1B1B1BEE")
            linha:setColor("#CCCCCC")
        end
    end
    -- desce/sobe a lista sozinho pra deixar o goto atual visivel
    if linhaAtual then mostrarLinhaGoto(linhaAtual, idxAtual) end
    local info = #rota .. " gotos"
    if rodando then info = info .. " | rodando no " .. TD.wp end
    if TD.gotoSel then info = info .. " | selecionado: " .. TD.gotoSel end
    ui.gotoInfo:setText(info)
    for nome, id in pairs(BOTOES_ROTA) do
        local on = (nome == TD.rotaEditada)
        ui[id]:setBackgroundColor(on and SEL_BG or CINZA_BG)
        ui[id]:setColor(on and "#FFD700" or "#999999")
    end
    TD.listaMostrada = (rodando and (TD.perfilAtivo .. "|" .. TD.rota .. "|" .. TD.wp)) or ""
end

function TD.rodandoRota() return TD.ativo or (TD.evRun and TD.evRun.rota) end

function TD.seguirGotoAtual()
    -- goto novo (ADD / gravar): desce a lista ate ele. Feito aqui (macro de 500ms) e nao na hora,
    -- porque logo apos criar a linha a lista ainda nao recalculou o tamanho.
    if TD.rolarSel then
        TD.rolarSel = nil
        local linha = TD.gotoSel and TD.linhasGoto[TD.gotoSel]
        if linha then mostrarLinhaGoto(linha, TD.gotoSel) end
    end
    if not TD.rodandoRota() or TD.voltando then return end
    -- evento: a entrada do TP e fixa (nao e de perfil) e o evento pode nao ter perfil -> nao segue na lista
    if not cfg.perfis[TD.perfilAtivo] or (TD.evRun and TD.rota == "CAMINHO") then return end
    if TD.perfilEditado ~= TD.perfilAtivo or TD.rotaEditada ~= TD.rota then
        TD.perfilEditado = TD.perfilAtivo
        TD.rotaEditada = TD.rota
        TD.gotoSel = nil
        TD.preencherPerfis()
    end
    if TD.listaMostrada ~= (TD.perfilAtivo .. "|" .. TD.rota .. "|" .. TD.wp) then
        TD.montarListaGotos()
    end
end

local function escolherRota(nome)
    TD.rotaEditada = nome
    TD.gotoSel = nil
    TD.montarListaGotos()
end
ui.rotaPrincipal.onClick = function() escolherRota("CAMINHO") end
ui.rotaCidade.onClick = function() escolherRota("PRINCIPAL") end
ui.rotaDP.onClick = function() escolherRota("DP") end

ui.gotoAdd.onClick = function()
    local p = player:getPosition()
    if not p then return end
    local rota = rotaEditadaTabela()
    local pos = TD.gotoSel and (TD.gotoSel + 1) or (#rota + 1)
    table.insert(rota, pos, {p.x, p.y, p.z})
    TD.gotoSel = pos
    TD.rolarSel = true
    TD.log("Goto " .. pos .. " adicionado em " .. TD.perfilEditado .. " / " .. TD.rotaEditada .. ".")
    TD.montarListaGotos()
end
ui.gotoRemover.onClick = function()
    local rota = rotaEditadaTabela()
    if not TD.gotoSel or not rota[TD.gotoSel] then TD.log("Selecione um goto para remover.") return end
    table.remove(rota, TD.gotoSel)
    TD.log("Goto " .. TD.gotoSel .. " removido de " .. TD.perfilEditado .. " / " .. TD.rotaEditada .. ".")
    if TD.gotoSel > #rota then TD.gotoSel = (#rota > 0) and #rota or nil end
    if TD.ativo and TD.perfilAtivo == TD.perfilEditado and TD.rota == TD.rotaEditada and TD.wp > #rota then TD.wp = 1 end
    TD.montarListaGotos()
end
cfg.gravarSqm = cfg.gravarSqm or 2
TD.gravando = false
ui.gravarSqm:setText(tostring(cfg.gravarSqm))
ui.gravarSqm.onTextChange = function(_, t)
    local v = tonumber(t)
    if v and v >= 1 and v <= 20 then cfg.gravarSqm = math.floor(v) end
end
function TD.pintarGravar()
    ui.gotoGravar:setText(TD.gravando and "GRAVANDO..." or "GRAVAR: OFF")
    ui.gotoGravar:setColor(TD.gravando and "#FF5555" or "#77FF77")
end
TD.pintarGravar()
ui.gotoGravar.onClick = function()
    TD.gravando = not TD.gravando
    TD.log(TD.gravando and ("Gravando gotos em " .. TD.perfilEditado .. " / " .. TD.rotaEditada .. " a cada " .. cfg.gravarSqm .. " sqm.") or "Gravacao parada.")
    TD.pintarGravar()
end
local VET_DIR = {[0] = {0, -1}, [1] = {1, 0}, [2] = {0, 1}, [3] = {-1, 0}, [4] = {1, -1}, [5] = {1, 1}, [6] = {-1, 1}, [7] = {-1, -1}}
macro(50, function()
    if not TD.gravando then
        TD.gravPos = nil
        return
    end
    local p = player:getPosition()
    if not p then return end
    local rota = rotaEditadaTabela()
    local antes = TD.gravPos
    if antes and (antes.z ~= p.z or math.max(math.abs(antes.x - p.x), math.abs(antes.y - p.y)) > 1) then
        local v = VET_DIR[TD.gravDir or -1]
        if v then
            local fx, fy, fz = antes.x + v[1], antes.y + v[2], antes.z
            local ult = rota[#rota]
            if not ult or ult[1] ~= antes.x or ult[2] ~= antes.y or ult[3] ~= antes.z then
                table.insert(rota, {antes.x, antes.y, antes.z})
            end
            table.insert(rota, {fx, fy, fz})
            TD.log("Gravou o sqm do teleporte: " .. fx .. ", " .. fy .. ", " .. fz .. ".")
        end
        table.insert(rota, {p.x, p.y, p.z})
        TD.gotoSel = #rota
        TD.rolarSel = true
        TD.montarListaGotos()
    else
        local ult = rota[#rota]
        local passo = cfg.gravarSqm or 2
        if not ult or ult[3] ~= p.z or math.max(math.abs(ult[1] - p.x), math.abs(ult[2] - p.y)) >= passo then
            table.insert(rota, {p.x, p.y, p.z})
            TD.gotoSel = #rota
            TD.rolarSel = true
            TD.montarListaGotos()
        end
    end
    TD.gravPos = {x = p.x, y = p.y, z = p.z}
    local okD, d = pcall(function() return player:getDirection() end)
    if okD then TD.gravDir = d end
end)

cfg.waitTodos = nil
cfg.delayGoto = cfg.delayGoto or 0
cfg.buscaMax = cfg.buscaMax or 150
ui.gotoWait:setText(tostring(cfg.delayGoto))
ui.gotoWait.onTextChange = function(_, t)
    local v = tonumber((tostring(t):gsub(",", ".")))
    if v and v >= 0 and v <= 60 then cfg.delayGoto = v end
end
ui.buscaMax:setText(tostring(cfg.buscaMax))
ui.buscaMax.onTextChange = function(_, t)
    local v = tonumber(t)
    if v and v >= 10 and v <= 300 then cfg.buscaMax = math.floor(v) end
end

local LETRA_DIR = {N = "N", E = "E", S = "S", W = "W"}

function TD.textoCaveBot(nome)
    local perfil = cfg.perfis[nome]
    if not perfil then return "" end
    local linhas = {}
    for _, r in ipairs({"CAMINHO", "PRINCIPAL", "DP"}) do
        table.insert(linhas, "[" .. r .. "]")
        for _, g in ipairs(perfil[r] or {}) do
            local l = "goto:" .. g[1] .. "," .. g[2] .. "," .. g[3]
            if g[4] then l = l .. " wait:" .. (g[4] / 1000) end
            if g[5] then l = l .. " dir:" .. g[5] end
            table.insert(linhas, l)
        end
        table.insert(linhas, "")
    end
    return table.concat(linhas, "\n")
end

function TD.lerTextoCaveBot(texto)
    local perfil = {CAMINHO = {}, PRINCIPAL = {}, DP = {}}
    local atual, total, secoes = nil, 0, 0
    for linha in (tostring(texto or "") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local l = linha:gsub("^%s+", ""):gsub("%s+$", "")
        local secao = l:upper():match("^%[?%s*(%u+)%s*%]?:?$")
        if secao == "CIDADE" then secao = "PRINCIPAL" end
        if secao and perfil[secao] then
            atual = secao
            secoes = secoes + 1
        elseif l ~= "" then
            local x, y, z = l:match("^goto:%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
            if x then
                if not atual then return nil, "goto antes de [CAMINHO], [PRINCIPAL] ou [DP]" end
                local w = tonumber(((l:match("wait:%s*([%d%.,]+)") or ""):gsub(",", ".")))
                local d = l:upper():match("DIR:%s*(%u)")
                table.insert(perfil[atual], {tonumber(x), tonumber(y), tonumber(z),
                    w and math.floor(w * 1000) or nil, LETRA_DIR[d or ""]})
                total = total + 1
            end
        end
    end
    if secoes == 0 then return nil, "nenhuma secao [CAMINHO], [PRINCIPAL] ou [DP]" end
    return perfil, total
end

ui.cbEditar.onClick = function()
    local nome = TD.perfilEditado
    local texto = TD.textoCaveBot(nome)
    if not (UI and UI.MultilineEditorWindow) then TD.log("Esse bot nao tem o editor de texto.") return end
    pcall(function()
        UI.MultilineEditorWindow(texto, {title = "CaveBot da task: " .. nome, width = 420,
            description = "[CAMINHO], [PRINCIPAL] e [DP]. Ex.: goto:32350,32225,6 wait:0.5 dir:N"}, function(novo)
            local perfil, total = TD.lerTextoCaveBot(novo)
            if not perfil then TD.log("Editor: " .. total .. ". Nada foi alterado.") return end
            for _, r in ipairs({"CAMINHO", "PRINCIPAL", "DP"}) do cfg.perfis[nome][r] = perfil[r] end
            TD.gotoSel = nil
            TD.montarListaGotos()
            TD.log("CaveBot '" .. nome .. "' salvo pelo editor: " .. total .. " gotos (" ..
                #perfil.CAMINHO .. " caminho, " .. #perfil.PRINCIPAL .. " principal, " .. #perfil.DP .. " DP).")
        end)
    end)
end

TD.ladoEdicao = nil
TD.waitEdicao = nil
local ORDEM_LADOS = {false, "N", "E", "S", "W"}
local ORDEM_WAIT = {false, 0, 500, 1000, 1500, 2000, 3000, 5000}
function TD.pintarLado()
    ui.gotoLado:setText(TD.ladoEdicao and TD.NOME_LADO[TD.ladoEdicao] or "NEUTRO")
    ui.gotoLado:setColor(TD.ladoEdicao and "#FFD24A" or "#AAAAAA")
    ui.gotoWaitBtn:setText(TD.waitEdicao and ((TD.waitEdicao / 1000) .. "s") or "PADRAO")
    ui.gotoWaitBtn:setColor(TD.waitEdicao and "#FFD24A" or "#AAAAAA")
end
function TD.carregarEdicao()
    local r = rotaEditadaTabela()
    local g = TD.gotoSel and r[TD.gotoSel]
    TD.ladoEdicao = g and g[5] or nil
    TD.waitEdicao = g and tonumber(g[4]) or nil
    TD.pintarLado()
end
TD.pintarLado()
ui.gotoLado.onClick = function()
    local idx = 1
    for i, v in ipairs(ORDEM_LADOS) do if (v or nil) == TD.ladoEdicao then idx = i end end
    TD.ladoEdicao = ORDEM_LADOS[idx % #ORDEM_LADOS + 1] or nil
    TD.pintarLado()
end
ui.gotoWaitBtn.onClick = function()
    local idx = 1
    for i, v in ipairs(ORDEM_WAIT) do if (v or nil) == TD.waitEdicao then idx = i end end
    local prox = ORDEM_WAIT[idx % #ORDEM_WAIT + 1]
    TD.waitEdicao = (prox ~= false) and prox or nil
    TD.pintarLado()
end
ui.gotoWaitAplicar.onClick = function()
    local rota = rotaEditadaTabela()
    if not TD.gotoSel or not rota[TD.gotoSel] then TD.log("Selecione um goto para salvar a direcao e o wait.") return end
    local g = rota[TD.gotoSel]
    g[4] = TD.waitEdicao or false   -- false, nunca buraco: lista com buraco trava o save do storage do vBot
    g[5] = TD.ladoEdicao or false
    TD.log("Goto " .. TD.gotoSel .. ": direcao " .. (g[5] and TD.NOME_LADO[g[5]] or "NEUTRO") ..
        ", wait " .. (g[4] and ((g[4] / 1000) .. "s") or ("padrao " .. cfg.delayGoto .. "s")) .. ".")
    TD.montarListaGotos()
end

ui.gotoClear.onClick = function()
    if not TD.clearConfirmaAte or os.time() > TD.clearConfirmaAte then
        TD.clearConfirmaAte = os.time() + 3
        ui.gotoClear:setText("CONFIRM")
        TD.log("Clique de novo em CLEAR em 3s para apagar todos os gotos de " .. TD.perfilEditado .. " / " .. TD.rotaEditada .. ".")
        return
    end
    TD.clearConfirmaAte = nil
    ui.gotoClear:setText("CLEAR")
    local rota = rotaEditadaTabela()
    for i = #rota, 1, -1 do rota[i] = nil end
    TD.gotoSel = nil
    TD.gravando = false
    if TD.pintarGravar then TD.pintarGravar() end
    if TD.ativo and TD.perfilAtivo == TD.perfilEditado and TD.rota == TD.rotaEditada then TD.wp = 1 end
    TD.log("Rota " .. TD.rotaEditada .. " de " .. TD.perfilEditado .. " limpa.")
    TD.montarListaGotos()
end

macro(1000, function()
    if TD.clearConfirmaAte and os.time() > TD.clearConfirmaAte then
        TD.clearConfirmaAte = nil
        ui.gotoClear:setText("CLEAR")
    end
    if TD.excluirConfirmaAte and os.time() > TD.excluirConfirmaAte then
        TD.excluirConfirmaAte = nil
        ui.perfilExcluir:setText("EXCLUIR")
    end
end)

function TD.atualizarCaveBot()
    ui.cbAgora:setText("CaveBot do bot agora: " .. (TD.cavebotAtual() or "?"))
    pintarToggle(ui.cbTask, TD.ativo, "TASK: ON", "TASK: OFF")
end

ui.pkFuga:setText(cfg.pkHunt.labelFuga)
ui.pkFuga.onTextChange = function(_, t) cfg.pkHunt.labelFuga = tostring(t):gsub("^%s+", ""):gsub("%s+$", "") end
ui.pkVolta:setText(cfg.pkHunt.labelVolta)
ui.pkVolta.onTextChange = function(_, t) cfg.pkHunt.labelVolta = tostring(t):gsub("^%s+", ""):gsub("%s+$", "") end
ui.pkTempo:setText(cfg.pkHunt.tempo)
ui.pkTempo.onTextChange = function(_, t)
    cfg.pkHunt.tempo = tostring(t)
    TD.atualizarPK()
end
local function campoId(campo, chave)
    campo:setText(tostring(cfg.fuga[chave] or 0))
    campo.onTextChange = function(_, t)
        local v = tonumber(t)
        if v and v >= 0 then cfg.fuga[chave] = math.floor(v) end
    end
end
campoId(ui.fugaRunaMW, "runaMW")
campoId(ui.fugaRunaVip, "runaVip")
ui.fugaBicar.onClick = function() cfg.fuga.bicar = not cfg.fuga.bicar TD.atualizarPK() end
ui.fugaMW.onClick = function() cfg.fuga.mw = not cfg.fuga.mw TD.atualizarPK() end
ui.fugaEscudo.onClick = function()
    cfg.fuga.escudoAtivo = not cfg.fuga.escudoAtivo
    TD.atualizarPK()
end

local function campoFaixa(campo, chave, minimo, maximo)
    campo:setText(tostring(cfg.fuga[chave]))
    campo.onTextChange = function(_, t)
        local v = tonumber(t)
        if v and v >= minimo and v <= maximo then cfg.fuga[chave] = math.floor(v) end
    end
end
campoFaixa(ui.escudoQtd, "escudoQtd", 1, 20)
campoFaixa(ui.escudoSqm, "escudoSqm", 1, 10)

function TD.salvarPK()
    local erros = {}
    local function num(campo, minimo, maximo)
        local v = tonumber(campo:getText())
        if v and v >= minimo and v <= maximo then return math.floor(v) end
        return nil
    end
    local q, sq = num(ui.escudoQtd, 1, 20), num(ui.escudoSqm, 1, 10)
    if q then cfg.fuga.escudoQtd = q else table.insert(erros, "players") end
    if sq then cfg.fuga.escudoSqm = sq else table.insert(erros, "sqm") end
    local rm, rv = num(ui.fugaRunaMW, 0, 999999), num(ui.fugaRunaVip, 0, 999999)
    if rm then cfg.fuga.runaMW = rm else table.insert(erros, "runa MW") end
    if rv then cfg.fuga.runaVip = rv else table.insert(erros, "MW VIP") end
    if TD.lerTempo(ui.pkTempo:getText()) then cfg.pkHunt.tempo = ui.pkTempo:getText() else table.insert(erros, "tempo PZ") end
    local lf = tostring(ui.pkFuga:getText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lv = tostring(ui.pkVolta:getText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if lf ~= "" then cfg.pkHunt.labelFuga = lf else table.insert(erros, "label fuga") end
    cfg.pkHunt.labelVolta = lv
    if #erros == 0 then
        ui.pkSalvar:setText("SALVO!")
        ui.pkSalvar:setColor("#77FF77")
        TD.log("Configuracao de PK salva.")
    else
        ui.pkSalvar:setText("ERRO: " .. erros[1])
        ui.pkSalvar:setColor("#FF5555")
        TD.log("PK: valor invalido em " .. table.concat(erros, ", ") .. ".")
    end
    TD.pkSalvarAte = os.time() + 2
    TD.atualizarPK()
end

ui.pkSalvar.onClick = function() TD.salvarPK() end
ui.pkResetar.onClick = function()
    TD.resetarPK()
    ui.pkResetar:setText("RESETADO!")
    TD.pkResetarAte = os.time() + 2
    TD.atualizarPK()
end
ui.fugaSkull.onClick = function() cfg.fuga.skull = not cfg.fuga.skull TD.atualizarPK() end
ui.fugaSalvarPz.onClick = function()
    local p = player:getPosition()
    if p then
        cfg.fuga.pz = {x = p.x, y = p.y, z = p.z}
        TD.log("PZ salvo em " .. p.x .. "," .. p.y .. "," .. p.z .. ".")
        TD.atualizarPK()
    end
end

ui.pkHuntAtivo.onClick = function()
    cfg.pkHunt.ativo = not cfg.pkHunt.ativo
    if not cfg.pkHunt.ativo then TD.pkFase = nil end
    TD.atualizarPK()
end

function TD.atualizarPK()
    pintarToggle(ui.pkHuntAtivo, cfg.pkHunt.ativo, "PK NA HUNT: ATIVO", "PK NA HUNT: DESLIGADO")
    local st
    if not TD.lerTempo(cfg.pkHunt.tempo) then
        st = "Tempo invalido (use 10s, 5min, 1:30)"
    elseif TD.pkFase == "FUGINDO" then
        st = "Fugindo para o PZ..."
    elseif TD.pkFase == "NO PZ" then
        local resta = (TD.lerTempo(cfg.pkHunt.tempo) or 0) - (os.time() - TD.pkDesde)
        st = "No PZ: volta em " .. formatarTempo(math.max(0, resta))
    else
        st = "Aguardando"
    end
    ui.pkStatus:setText("Status: " .. st)
    pintarToggle(ui.fugaBicar, cfg.fuga.bicar, "BICAR SE TRAPADO: ATIVO", "BICAR SE TRAPADO: DESLIGADO")
    pintarToggle(ui.fugaMW, cfg.fuga.mw, "MW NA FUGA: ATIVO", "MW NA FUGA: DESLIGADO")
    pintarToggle(ui.fugaEscudo, cfg.fuga.escudoAtivo, "ESCUDO AZUL PERTO: CORRER", "ESCUDO AZUL: DESLIGADO")
    ui.escudoVisto:setText("Perto: " .. TD.escudoVisto)
    local pAgora = player:getPosition()
    local qtdAgora = pAgora and TD.contarGuildAzul(pAgora) or 0
    ui.escudoAgora:setText("Agora: " .. qtdAgora .. "/" .. cfg.fuga.escudoQtd)
    if TD.pkSalvarAte and os.time() >= TD.pkSalvarAte then
        TD.pkSalvarAte = nil
        ui.pkSalvar:setText("SALVAR PK")
        ui.pkSalvar:setColor("#77FF77")
    end
    if TD.pkResetarAte and os.time() >= TD.pkResetarAte then
        TD.pkResetarAte = nil
        ui.pkResetar:setText("RESETAR PK")
    end
    pintarToggle(ui.fugaSkull, cfg.fuga.skull, "FUGIR DE PK NA TELA: ATIVO", "FUGIR DE PK NA TELA: DESLIGADO")
    local pz = cfg.fuga.pz
    ui.fugaPz:setText("PZ: " .. (pz and (pz.x .. "," .. pz.y .. "," .. pz.z) or "pelo CaveBot"))
    local barreiras = 0
    for _ in pairs(TD.barreirasVistas) do barreiras = barreiras + 1 end
    ui.fugaStatus:setText("Fuga: " .. TD.statusFuga .. (barreiras > 0 and (" | " .. barreiras .. " MW/grav na tela") or ""))
    pintarToggle(ui.pkAtivo, cfg.pkAtivo, "FUGA PELO DP NA TASK: ATIVA", "FUGA PELO DP NA TASK: DESLIGADA")
    ui.pkFugas:setText("Fugas nesta sessao: " .. TD.fugas)
end
ui.pkAtivo.onClick = function()
    cfg.pkAtivo = not cfg.pkAtivo
    TD.atualizarPK()
end

function TD.alternarPainel()
    if w:isVisible() then w:hide() else w:show() w:raise() w:focus() end
end
addButton("TaskDemonBtn", "Tasks", TD.alternarPainel)
onKeyPress(function(keys)
    if keys == "Alt+1" then TD.alternarPainel()
    elseif keys == "Alt+2" then TD.alternarMostrar("task")
    elseif keys == "Alt+3" then TD.alternarMostrar("evento") end
end)

function TD.atualizarStatus()
    local prog = TD.progresso()
    do
        local k = cfg.tarefa
        local p = cfg.prog[k] or 0
        TD.linhaTarefa:setText("> " .. TD.tarefaAtual().titulo)
        TD.linhaTarefa:setBackgroundColor(TD.ativo and "#1E3A1EEE" or CINZA_BG)
        TD.linhaTarefa:setColor(p >= TD.metaDe() and "#77FF77" or "#FFD24A")
    end

    if TD.metaMostrada ~= cfg.tarefa then
        TD.metaMostrada = cfg.tarefa
        ui.meta:setText(tostring(TD.metaDe()))
    end
    ui.progresso:setText(prog .. " / " .. TD.metaDe())
    ui.progresso:setColor(prog >= TD.metaDe() and "#55FF55" or "#FFD24A")

    local emEvento = TD.evRun and not TD.ativo
    ui.estado:setText("Estado: " .. (emEvento and "DESLIGADO (evento ativo)" or
        (TD.estado .. (TD.emManual() and " (MANUAL)" or ""))))
    ui.estado:setColor(TD.fugindo and "#FF5555" or (TD.ativo and "#55FF55" or "#FF7777"))

    local rota = rotaAtual()
    local extra = ""
    if TD.ativo and TD.rota == "CAMINHO" then
        extra = " | indo ao local"
    elseif TD.ativo and TD.rota == "VOLTA" then
        extra = " | voltando ao DP"
    end
    ui.rota:setText(emEvento and "Rota: -" or ("Rota: " .. TD.rota .. " (goto " .. TD.wp .. "/" .. (rota and #rota or 0) .. ")" .. extra))

    if TD.alvo then
        ui.alvo:setText("Alvo: " .. TD.alvo:getName() .. " (" .. dist(player:getPosition(), TD.alvo:getPosition()) .. " sqm)")
    else
        ui.alvo:setText("Alvo: -")
    end
    ui.tela:setText("Na tela: " .. TD.naTela .. " | Novos: " .. TD.novosNaTela)
    local qt = 0
    for _ in pairs(TD.tagueados) do qt = qt + 1 end
    ui.targetados:setText("Targetados: " .. qt)
    ui.volta:setText("Volta para: " .. (cfg.labelVolta ~= "" and cfg.labelVolta or "-"))
    ui.agendaInfo:setText(TD.origemAgenda and ("Agenda: " .. TD.TAREFAS[TD.origemAgenda].titulo .. " em andamento") or "Agenda: aguardando")

    ui.ligar:setText(TD.ativo and "TASK: ON" or "TASK: OFF")
    ui.ligar:setColor(TD.ativo and "#55FF55" or "#FF7777")
    ui.modo:setText("MODO: " .. TaskDemon.modoDe())
    ui.evento:setText(TD.evento)
end

function TD.atualizarPainel()
    TD.atualizarStatus()
    TD.atualizarAgenda()
    TD.atualizarCaveBot()
    TD.atualizarPK()
    TD.atualizarTarget()
end

TD.mostrarAba("STATUS")
TD.preencherCaveBots()
TD.preencherPerfis()
TD.montarListaGotos()
TD.atualizarPainel()

macro(500, function()
    if not w:isVisible() then return end
    local aba = TD.abaAtual or "STATUS"
    if aba == "STATUS" then TD.atualizarStatus()
    elseif aba == "PK" then TD.atualizarPK()
    elseif aba == "CAVEBOT" then TD.atualizarCaveBot() TD.seguirGotoAtual()
    elseif aba == "TARGET" then TD.atualizarTarget() end
end)
