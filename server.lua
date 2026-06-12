-- ============================================================
--  kq_ymap_exporter  |  server.lua
--  Exporte les props de kq_propplacer vers un fichier .ymap.xml
-- ============================================================

-- ── Config ───────────────────────────────────────────────────
local CONFIG = {
    outputDir      = "exports/",   -- relatif au dossier de la ressource
    streamMargin   = 200.0,        -- marge streamingExtents
    defaultLodDist = 100,          -- lodDist de chaque entité
    acePermission  = "command.exportymap", -- "" = tout le monde
}

-- ── Helpers maths ────────────────────────────────────────────

local function eulerToQuaternion(ex, ey, ez)
    local rx = math.rad(ex * 0.5)
    local ry = math.rad(ey * 0.5)
    local rz = math.rad(ez * 0.5)
    local sx, cx = math.sin(rx), math.cos(rx)
    local sy, cy = math.sin(ry), math.cos(ry)
    local sz, cz = math.sin(rz), math.cos(rz)
    return
        sx*cy*cz - cx*sy*sz,
        cx*sy*cz + sx*cy*sz,
        cx*cy*sz - sx*sy*cz,
        cx*cy*cz + sx*sy*sz
end

local function fmt(v)
    return string.format("%.6g", math.floor(v * 1e6 + 0.5) / 1e6)
end

-- ── Extents ──────────────────────────────────────────────────

local function computeExtents(entities)
    local minX, minY, minZ =  math.huge,  math.huge,  math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, e in ipairs(entities) do
        if e.x < minX then minX = e.x end ; if e.x > maxX then maxX = e.x end
        if e.y < minY then minY = e.y end ; if e.y > maxY then maxY = e.y end
        if e.z < minZ then minZ = e.z end ; if e.z > maxZ then maxZ = e.z end
    end
    local m = CONFIG.streamMargin
    return
        {x=minX,   y=minY,   z=minZ},
        {x=maxX,   y=maxY,   z=maxZ},
        {x=minX-m, y=minY-m, z=minZ-m},
        {x=maxX+m, y=maxY+m, z=maxZ+m}
end

-- ── Génération XML ────────────────────────────────────────────

local function buildItemXml(e)
    local qx, qy, qz, qw = eulerToQuaternion(e.rx, e.ry, e.rz)
    return string.format(
[[  <Item type="CEntityDef">
   <archetypeName>%s</archetypeName>
   <flags value="32" />
   <guid value="0" />
   <position x="%s" y="%s" z="%s" />
   <rotation x="%s" y="%s" z="%s" w="%s" />
   <scaleXY value="1" />
   <scaleZ value="1" />
   <parentIndex value="-1" />
   <lodDist value="%d" />
   <childLodDist value="0" />
   <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>
   <numChildren value="0" />
   <priorityLevel>PRI_REQUIRED</priorityLevel>
   <extensions />
   <ambientOcclusionMultiplier value="255" />
   <artificialAmbientOcclusion value="255" />
   <tintValue value="0" />
  </Item>]],
        e.model,
        fmt(e.x), fmt(e.y), fmt(e.z),
        fmt(qx), fmt(qy), fmt(qz), fmt(qw),
        CONFIG.defaultLodDist
    )
end

local function buildYmapXml(mapName, entities)
    local entMin, entMax, strMin, strMax = computeExtents(entities)
    local items = {}
    for _, e in ipairs(entities) do items[#items+1] = buildItemXml(e) end

    return string.format(
[[<?xml version="1.0" encoding="UTF-8"?>
<CMapData>
 <name>%s</name>
 <parent />
 <flags value="0" />
 <contentFlags value="1" />
 <streamingExtentsMin x="%s" y="%s" z="%s" />
 <streamingExtentsMax x="%s" y="%s" z="%s" />
 <entitiesExtentsMin x="%s" y="%s" z="%s" />
 <entitiesExtentsMax x="%s" y="%s" z="%s" />
 <entities>
%s
 </entities>
 <containerLods itemType="rage__fwContainerLodDef" />
 <boxOccluders itemType="BoxOccluder" />
 <occludeModels itemType="OccludeModel" />
 <physicsDictionaries />
 <instancedData>
  <ImapLink />
  <PropInstanceList itemType="rage__fwPropInstanceListDef" />
  <GrassInstanceList itemType="rage__fwGrassInstanceListDef" />
 </instancedData>
 <timeCycleModifiers itemType="CTimeCycleModifier" />
 <carGenerators itemType="CCarGen" />
 <LODLightsSOA>
  <direction itemType="FloatXYZ" />
  <falloff />
  <falloffExponent />
  <timeAndStateFlags />
  <hash />
  <coneInnerAngle />
  <coneOuterAngleOrCapExt />
  <coronaIntensity />
 </LODLightsSOA>
 <DistantLODLightsSOA>
  <position itemType="FloatXYZ" />
  <RGBI />
  <numStreetLights value="0" />
  <category value="0" />
 </DistantLODLightsSOA>
 <block>
  <version value="0" />
  <flags value="0" />
  <name>%s</name>
  <exportedBy>kq_ymap_exporter</exportedBy>
  <owner></owner>
  <time>%s</time>
 </block>
</CMapData>]],
        mapName,
        fmt(strMin.x), fmt(strMin.y), fmt(strMin.z),
        fmt(strMax.x), fmt(strMax.y), fmt(strMax.z),
        fmt(entMin.x), fmt(entMin.y), fmt(entMin.z),
        fmt(entMax.x), fmt(entMax.y), fmt(entMax.z),
        table.concat(items, "\n"),
        mapName,
        os.date("%d %B %Y %H:%M")
    )
end

-- ── Écriture fichier ──────────────────────────────────────────

local function writeFile(path, content)
    local f = io.open(path, "w")
    if not f then return false, "Impossible d'ouvrir : " .. path end
    f:write(content)
    f:close()
    return true
end

-- ── Parse vec3 JSON ───────────────────────────────────────────

local function parseVec3(v)
    -- oxmysql peut renvoyer la colonne déjà décodée en table Lua
    -- ou en string JSON selon la version — on gère les deux cas.
    local t = (type(v) == "table") and v or json.decode(v)
    if not t then return nil end
    return tonumber(t.x) or 0.0,
           tonumber(t.y) or 0.0,
           tonumber(t.z) or 0.0
end

-- ── État en attente de nom par source ────────────────────────
-- true = le joueur a lancé /exportymap sans argument, attend le nom
local pendingExport = {}  -- attend nom de fichier
local pendingClear   = {}  -- attend confirmation clear

-- ── Helpers notify ────────────────────────────────────────────
local function notify(source, msg, color)
    color = color or {180, 220, 255}
    if source == 0 then
        print("[kq_ymap_exporter] " .. msg)
    else
        TriggerClientEvent("chat:addMessage", source, {
            color = color,
            args  = {"[YmapExport]", msg}
        })
    end
end

-- ── Fonction export principale ────────────────────────────────
local function doExport(source, mapName)
    notify(source, "Lecture DB kq_propplacer...")

    -- ── Requête DB ────────────────────────────────────────────
    exports['oxmysql']:query("SELECT `model`, `coords`, `rotation` FROM `kq_propplacer`", {}, function(rows)
        if not rows or #rows == 0 then
            notify(source, "Aucun prop trouve dans la base de donnees.", {255, 180, 80})
            return
        end

        local entities = {}
        local skipped  = 0

        for _, row in ipairs(rows) do
            local cx, cy, cz = parseVec3(row.coords)
            local rx, ry, rz = parseVec3(row.rotation)

            if cx then
                entities[#entities+1] = {
                    model = row.model,
                    x=cx, y=cy, z=cz,
                    rx=rx or 0, ry=ry or 0, rz=rz or 0,
                }
            else
                skipped = skipped + 1
                print(("[kq_ymap_exporter] WARN ligné ignorée model=%s coords=%s"):format(
                    tostring(row.model), tostring(row.coords)))
            end
        end

        if #entities == 0 then
            notify(source, "Aucune entite valide apres parsing.", {255, 80, 80})
            return
        end

        local xml     = buildYmapXml(mapName, entities)
        local resPath = GetResourcePath(GetCurrentResourceName())

        -- Normalise les separateurs (Windows renvoie des backslashes)
        resPath = resPath:gsub("\\", "/")

        local outDir  = resPath .. "/" .. CONFIG.outputDir
        local outFile = outDir .. mapName .. ".ymap.xml"

        -- Creation dossier : Windows (mkdir) + Linux (mkdir -p)
        local winDir = outDir:gsub("/", "\\")
        os.execute('mkdir "' .. winDir .. '" 2>nul')
        os.execute('mkdir -p "' .. outDir .. '" 2>/dev/null')

        local ok, err = writeFile(outFile, xml)
        if ok then
            notify(source, ("Export OK : %d entites -> %s.ymap.xml (%d ignorees)"):format(
                #entities, mapName, skipped), {80, 220, 120})
            print("[kq_ymap_exporter] Fichier : " .. outFile)
            -- Propose le clear
            pendingClear[source] = true
            notify(source, "Vider le prop placer ? /ymapconfirm  |  /ymapcancel", {255, 200, 50})
        else
            notify(source, "Erreur fichier : " .. tostring(err), {255, 80, 80})
        end
    end)
end

-- ── /ymapconfirm ─────────────────────────────────────────────
RegisterCommand("ymapconfirm", function(source)

    if source ~= 0 and CONFIG.acePermission ~= "" then
        if not IsPlayerAceAllowed(source, CONFIG.acePermission) then
            notify(source, "Permission refusee.", {255, 80, 80})
            return
        end
    end

    if not pendingClear[source] then
        notify(source, "Aucun export en attente de confirmation.", {255, 180, 80})
        return
    end

    pendingClear[source] = nil
    notify(source, "Suppression en cours...", {180, 180, 255})

    exports['oxmysql']:query("DELETE FROM `kq_propplacer`", {}, function(affected)
        notify(source, ("Prop placer vide ! %d entree(s) supprimee(s)."):format(affected or 0), {80, 220, 120})
        print(("[kq_ymap_exporter] Clear DB par source %d — %d lignes supprimees"):format(source, affected or 0))
    end)

end, false)

-- ── /ymapcancel ───────────────────────────────────────────────
RegisterCommand("ymapcancel", function(source)

    if not pendingClear[source] then
        notify(source, "Rien a annuler.", {180, 180, 180})
        return
    end

    pendingClear[source] = nil
    notify(source, "Annule. Le prop placer est conserve.", {180, 180, 180})

end, false)

-- ── Commande /exportymap ──────────────────────────────────────
RegisterCommand("exportymap", function(source, args)

    -- Permissions
    if source ~= 0 and CONFIG.acePermission ~= "" then
        if not IsPlayerAceAllowed(source, CONFIG.acePermission) then
            notify(source, "Permission refusee.", {255, 80, 80})
            return
        end
    end

    local rawName = args[1] and args[1]:match("^%s*(.-)%s*$") or ""

    -- Pas d'argument : demande le nom
    if rawName == "" then
        pendingExport[source] = true
        notify(source, "Quel nom pour le fichier ? Tape : /exportymap <nom>", {255, 220, 80})
        return
    end

    -- Argument fourni : on nettoie et on lance l'export
    pendingExport[source] = nil
    local mapName = rawName:gsub("[^%w_%-]", "_")

    if mapName == "" then
        notify(source, "Nom invalide. Utilise uniquement lettres, chiffres, _ ou -", {255, 80, 80})
        return
    end

    doExport(source, mapName)

end, false)

print("[kq_ymap_exporter] Pret — /exportymap [nomfichier]")
