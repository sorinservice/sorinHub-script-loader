-- tabs/shop.lua
-- Scannt workspace.SellValueBoards -> FrontSellValue/BackSellValue
-- Listet Items + Farbe. Auto-Refresh optional. Englisch UI.

return function(tab, OrionLib)
    local Results = {}              -- boardId -> paragraph handle {para=..., frame=...}
    local autoTask = nil
    local autoOn   = false
    local interval = 5

    -- Hilfen
    local function toHex(c3)
        local r = math.floor(c3.R * 255)
        local g = math.floor(c3.G * 255)
        local b = math.floor(c3.B * 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end

    local function pickSide(board)
        return board:FindFirstChild("FrontSellValue") or board:FindFirstChild("BackSellValue")
    end

    local function collectLabels(root)
        local out = {}
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") then
                table.insert(out, d)
            end
        end
        table.sort(out, function(a,b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
        return out
    end

    local function ensureParaForBoard(section, key)
        if Results[key] then return Results[key] end
        local p = section:AddParagraph("Board "..tostring(key), "Scanning…")
        Results[key] = { para = p }
        return Results[key]
    end

    local function scanOnce(section)
        local boardsFolder = workspace:FindFirstChild("SellValueBoards")
        if not boardsFolder then
            section:AddParagraph("Error", "Folder `SellValueBoards` not found in workspace.")
            return
        end

        local boards = boardsFolder:GetChildren()
        table.sort(boards, function(a,b) return a.Name < b.Name end)

        for idx, board in ipairs(boards) do
            local side = pickSide(board)
            local handle = ensureParaForBoard(section, idx)

            if not side then
                handle.para:Set("No side found (Front/Back missing).")
            else
                local labels = collectLabels(side)
                if #labels == 0 then
                    handle.para:Set("No TextLabels on this board.")
                else
                    local lines = {}
                    for _, lbl in ipairs(labels) do
                        local txt  = lbl.Text or ""
                        local hex  = toHex(lbl.TextColor3 or Color3.new(1,1,1))
                        table.insert(lines, string.format("%s  |  %s", txt, hex))
                    end
                    handle.para:Set(table.concat(lines, "\n"))
                end
            end
        end
    end

    -- UI
    local sec = tab:AddSection({ Name = "Sell Value Boards" })

    sec:AddButton({
        Name = "Scan Once",
        Callback = function()
            scanOnce(sec)
        end
    })

    sec:AddToggle({
        Name = "Auto Refresh",
        Default = false,
        Callback = function(v)
            autoOn = v
            if autoOn then
                if autoTask then task.cancel(autoTask) end
                autoTask = task.spawn(function()
                    while autoOn do
                        scanOnce(sec)
                        task.wait(interval)
                    end
                end)
            else
                if autoTask then task.cancel(autoTask); autoTask = nil end
            end
        end
    })

    sec:AddSlider({
        Name = "Refresh Interval (s)",
        Min = 2, Max = 30, Increment = 1, Default = interval,
        Callback = function(v) interval = math.max(2, math.floor(v)) end
    })

    print("[sell_scanner] v1.0 loaded")
end
