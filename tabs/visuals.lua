return function(tab, OrionLib)
    ----------------------------------------------------------------
    -- Services
    local Players    = game:GetService("Players")
    local Workspace  = game:GetService("Workspace")
    local RunService = game:GetService("RunService")

    local LocalPlayer = Players.LocalPlayer
    local Camera      = Workspace.CurrentCamera

    ----------------------------------------------------------------
    -- Config / State
    local STATE = {
        showTeam     = false,
        showName     = false,
        showUsername = false,
        -- showEquipped = false, -- aktuell deaktiviert
        showDistance = false,
        maxDistance  = 750,
        textSize     = 14,
        textOutline  = true,
        colorText    = Color3.fromRGB(230,230,230),
        colorUser    = Color3.fromRGB(200,200,200),
        teamColors   = {}, -- optional: { ["Police"] = Color3.fromRGB(0,170,255) }
    }

    local pool = {} -- [player] = { highlight, texts = {name, user, team, dist} }

    ----------------------------------------------------------------
    -- UI
    tab:AddToggle({ Name="Show Display Name", Default=false, Save=true, Flag="esp_name",
        Callback=function(v) STATE.showName = v end })
    tab:AddToggle({ Name="Show @Username", Default=false, Save=true, Flag="esp_user",
        Callback=function(v) STATE.showUsername = v end })
    tab:AddToggle({ Name="Show Team", Default=false, Save=true, Flag="esp_team",
        Callback=function(v) STATE.showTeam = v end })
    tab:AddToggle({ Name="Show Distance", Default=false, Save=true, Flag="esp_dist",
        Callback=function(v) STATE.showDistance = v end })
    tab:AddSlider({ Name="ESP Range", Min=50, Max=2500, Increment=10, Default=STATE.maxDistance,
        ValueName="studs", Save=true, Flag="esp_range",
        Callback=function(v) STATE.maxDistance = v end })

    ----------------------------------------------------------------
    -- Helpers
    local function createHighlight(char, col)
        local h = Instance.new("Highlight")
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.5
        h.FillColor = col or Color3.fromRGB(0,255,0)
        h.OutlineColor = Color3.new(0,0,0)
        h.Parent = char
        return h
    end

    local function createText()
        local t = Drawing.new("Text")
        t.Visible = false
        t.Size = STATE.textSize
        t.Color = STATE.colorText
        t.Center = true
        t.Outline = STATE.textOutline
        t.Font = 3 -- Gotham
        return t
    end

    local function alloc(plr)
        if pool[plr] then return pool[plr] end
        local entry = {
            highlight = nil,
            texts = {
                name = createText(),
                user = createText(),
                team = createText(),
                dist = createText()
            }
        }
        pool[plr] = entry
        return entry
    end

    local function hideEntry(entry)
        if not entry then return end
        for _,t in pairs(entry.texts) do t.Visible = false end
        if entry.highlight then entry.highlight.Enabled = false end
    end

    local function free(plr)
        local entry = pool[plr]; if not entry then return end
        if entry.highlight then entry.highlight:Destroy() end
        for _,t in pairs(entry.texts) do pcall(function() t:Remove() end) end
        pool[plr] = nil
    end
    Players.PlayerRemoving:Connect(free)

    ----------------------------------------------------------------
    -- Render loop
    RunService.RenderStepped:Connect(function()
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if char and hrp and hum and hum.Health > 0 and myHRP then
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    if dist <= STATE.maxDistance then
                        local entry = alloc(plr)

                        -- Highlight
                        if not entry.highlight or not entry.highlight.Parent then
                            entry.highlight = createHighlight(char, STATE.teamColors[plr.Team and plr.Team.Name] or Color3.fromRGB(0,255,0))
                        end
                        entry.highlight.Enabled = true

                        -- Screen pos
                        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 6, 0))
                        if onScreen then
                            local x,y = pos.X, pos.Y
                            local yOff = 0

                            if STATE.showTeam and plr.Team then
                                entry.texts.team.Text = plr.Team.Name
                                entry.texts.team.Position = Vector2.new(x,y+yOff)
                                entry.texts.team.Color = STATE.teamColors[plr.Team.Name] or STATE.colorText
                                entry.texts.team.Visible = true
                                yOff = yOff + STATE.textSize + 2
                            else entry.texts.team.Visible=false end

                            if STATE.showName then
                                entry.texts.name.Text = plr.DisplayName
                                entry.texts.name.Position = Vector2.new(x,y+yOff)
                                entry.texts.name.Visible = true
                                yOff = yOff + STATE.textSize + 2
                            else entry.texts.name.Visible=false end

                            if STATE.showUsername then
                                entry.texts.user.Text = "@"..plr.Name
                                entry.texts.user.Position = Vector2.new(x,y+yOff)
                                entry.texts.user.Color = STATE.colorUser
                                entry.texts.user.Visible = true
                                yOff = yOff + STATE.textSize + 2
                            else entry.texts.user.Visible=false end

                            if STATE.showDistance then
                                entry.texts.dist.Text = ("[%d studs]"):format(math.floor(dist+0.5))
                                entry.texts.dist.Position = Vector2.new(x,y+yOff)
                                entry.texts.dist.Visible = true
                            else entry.texts.dist.Visible=false end
                        else
                            hideEntry(entry)
                        end
                    else
                        hideEntry(pool[plr])
                    end
                else
                    hideEntry(pool[plr])
                end
            end
        end
    end)
end
