return function(tab, OrionLib)
    ----------------------------------------------------------------
    -- Services
    local Players     = game:GetService("Players")
    local RunService  = game:GetService("RunService")
    local Workspace   = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local Camera      = Workspace.CurrentCamera

    ----------------------------------------------------------------
    -- Config / State
    local STATE = {
        showName       = true,
        showUsername   = false,
        showDistance   = true,
        highlightEnabled = true,

        maxDistance    = 750,  -- studs

        textSize       = 14,
        textOutline    = true,
        colorText      = Color3.fromRGB(230,230,230),
        colorUsername  = Color3.fromRGB(180,180,255),
    }

    -- Teamfarben optional
    local TEAM_COLORS = {
        -- ["Police"]    = Color3.fromRGB(0,170,255),
        -- ["Criminals"] = Color3.fromRGB(255,80,80),
    }
    local function colorForTeam(plr)
        if plr.Team and TEAM_COLORS[plr.Team.Name] then
            return TEAM_COLORS[plr.Team.Name]
        elseif plr.Team then
            local ok, c = pcall(function() return plr.Team.TeamColor.Color end)
            if ok then return c end
        end
        return Color3.fromRGB(0,255,0)
    end

    ----------------------------------------------------------------
    -- UI Controls
    tab:AddToggle({ Name="Show Display Name", Default=STATE.showName, Flag="esp_name",
        Callback=function(v) STATE.showName=v end })
    tab:AddToggle({ Name="Show @Username", Default=STATE.showUsername, Flag="esp_user",
        Callback=function(v) STATE.showUsername=v end })
    tab:AddToggle({ Name="Show Distance", Default=STATE.showDistance, Flag="esp_dist",
        Callback=function(v) STATE.showDistance=v end })
    tab:AddToggle({ Name="Enable Highlight ESP", Default=STATE.highlightEnabled, Flag="esp_highlight",
        Callback=function(v) STATE.highlightEnabled=v end })

    tab:AddSlider({ Name="ESP Range", Min=50, Max=2500, Increment=10, Default=STATE.maxDistance,
        ValueName="studs", Flag="esp_range", Callback=function(v) STATE.maxDistance=v end })

    ----------------------------------------------------------------
    -- Drawing API for text
    local function NewText(size, color)
        local t = Drawing.new("Text")
        t.Visible = false
        t.Size = size or STATE.textSize
        t.Color = color or STATE.colorText
        t.Center = true
        t.Outline = STATE.textOutline
        t.Transparency = 1
        t.Font = 2 -- besser lesbar
        return t
    end

    ----------------------------------------------------------------
    -- Highlight helper
    local function createHighlight(char, color)
        local hl = Instance.new("Highlight")
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.FillColor = color
        hl.OutlineColor = color
        hl.Parent = char
        return hl
    end

    ----------------------------------------------------------------
    -- Per-player pool
    local pool = {} -- [plr] = { textName, textUser, textDist, highlight }

    local function alloc(plr)
        if pool[plr] then return pool[plr] end
        local obj = {
            textName = NewText(STATE.textSize, STATE.colorText),
            textUser = NewText(STATE.textSize-1, STATE.colorUsername),
            textDist = NewText(STATE.textSize-1, STATE.colorText),
            highlight = nil
        }
        pool[plr] = obj
        return obj
    end
    local function hideObj(obj)
        if not obj then return end
        if obj.textName then obj.textName.Visible=false end
        if obj.textUser then obj.textUser.Visible=false end
        if obj.textDist then obj.textDist.Visible=false end
        if obj.highlight then obj.highlight.Enabled=false end
    end
    local function free(plr)
        local o = pool[plr]; if not o then return end
        for _,t in ipairs({o.textName,o.textUser,o.textDist}) do
            pcall(function() t:Remove() end)
        end
        if o.highlight then pcall(function() o.highlight:Destroy() end) end
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
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and myHRP then
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    if dist <= STATE.maxDistance then
                        local obj = alloc(plr)
                        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 6, 0))
                        if onScreen then
                            -- Text stack
                            local yOff = 0
                            if STATE.showName then
                                obj.textName.Text = plr.DisplayName or plr.Name
                                obj.textName.Position = Vector2.new(pos.X, pos.Y + yOff)
                                obj.textName.Visible = true
                                yOff = yOff + obj.textName.Size + 2
                            else obj.textName.Visible=false end

                            if STATE.showUsername then
                                obj.textUser.Text = "@"..plr.Name
                                obj.textUser.Position = Vector2.new(pos.X, pos.Y + yOff)
                                obj.textUser.Visible = true
                                yOff = yOff + obj.textUser.Size + 2
                            else obj.textUser.Visible=false end

                            if STATE.showDistance then
                                obj.textDist.Text = ("[%d studs]"):format(dist)
                                obj.textDist.Position = Vector2.new(pos.X, pos.Y + yOff)
                                obj.textDist.Visible = true
                            else obj.textDist.Visible=false end

                            -- Highlight
                            if STATE.highlightEnabled then
                                if not obj.highlight or not obj.highlight.Parent then
                                    obj.highlight = createHighlight(char, colorForTeam(plr))
                                end
                                obj.highlight.Enabled = true
                                obj.highlight.FillColor = colorForTeam(plr)
                                obj.highlight.OutlineColor = colorForTeam(plr)
                            else
                                if obj.highlight then obj.highlight.Enabled=false end
                            end
                        else
                            hideObj(obj)
                        end
                    else
                        hideObj(pool[plr])
                    end
                else
                    hideObj(pool[plr])
                end
            end
        end
    end)
end
