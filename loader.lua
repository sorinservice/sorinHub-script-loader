-- Orion laden
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/sorinservice/orion-lib/refs/heads/main/orion.lua"))()

-- Fenster erstellen
local Window = OrionLib:MakeWindow({
    SaveConfig   = true,
    ConfigFolder = "SorinConfig"
})

-- Tabs-Mapping
local TABS = {
    Shop = "https://raw.githubusercontent.com/sorinservice/dein-repo/main/tabs/shop.lua",
}

-- Loader-Helfer
local function safeRequire(url)
    local ok, loaderOrErr = pcall(function()
        local src = game:HttpGet(url)
        return loadstring(src)
    end)
    if not ok or type(loaderOrErr) ~= "function" then
        return nil, "Konnte Modul nicht laden: " .. tostring(url)
    end
    local ok2, modOrErr = pcall(loaderOrErr)
    if not ok2 then
        return nil, "Fehler beim Ausführen: " .. tostring(modOrErr)
    end
    return modOrErr, nil
end

-- WICHTIG: iconKey wird jetzt angenommen und an MakeTab übergeben
local function attachTab(name, url, iconKey)
    local Tab = Window:MakeTab({ Name = name, Icon = iconKey })
    local mod, err = safeRequire(url)
    if not mod then
        Tab:AddParagraph("Fehler", err or "Unbekannter Fehler")
        return
    end
    local ok, msg = pcall(mod, Tab, OrionLib)
    if not ok then
        Tab:AddParagraph("Fehler", "Tab-Init fehlgeschlagen:\n" .. tostring(msg))
    end
end

-- Tabs laden
attachTab("Shop", TABS.Shop, "main")

-- UI starten
OrionLib:Init()
