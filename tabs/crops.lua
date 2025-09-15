-- tabs/crops.lua
-- SorinHub - Sell Value Scanner (Crops)
-- All UI strings/comments are in English per Wyatt's preference.

return function(tab, OrionLib)
    ----------------------------------------------------------------
    -- CONFIG
    ----------------------------------------------------------------
    local CATEGORY_KEYWORDS = { "Crop", "Crops", "Crop Sell Values" } -- matches Title.Text on the board
    local PREFERRED_SIDE = "FrontSellValue"       -- fallback to BackSellValue if missing
    local AUTOREFRESH_DEFAULT = false
    local AUTOREFRESH_INTERVAL_DEFAULT = 15        -- seconds
    local SORT_DEFAULT = "Value (desc)"           -- default sorting

    ----------------------------------------------------------------
    -- SERVICES
    ----------------------------------------------------------------
    local Players      = game:GetService("Players")
    local RunService   = game:GetService("RunService")

    ----------------------------------------------------------------
    -- STATE
    ----------------------------------------------------------------
    local autoRefresh = AUTOREFRESH_DEFAULT
    local refreshConn = nil
    local refreshInterval = AUTOREFRESH_INTERVAL_DEFAULT
    local sortMode = SORT_DEFAULT

    local sections = {
        summary = tab:AddSection({ Name = "Summary" }),
        results = tab:AddSection({ Name = "Board Items" }),
        best    = tab:AddSection({ Name = "Per-Product Best Price" }),
        debug   = tab:AddSection({ Name = "Debug" }),
    }

    local summaryPara = sections.summary:AddParagraph("Status", "Ready.")
    local resultsPara = sections.results:AddParagraph("Items", "No data yet.")
    local bestPara    = sections.best:AddParagraph("Best", "No data yet.")
    local debugPara   = sections.debug:AddParagraph("Details", "—")

    ----------------------------------------------------------------
    -- HELPERS
    ----------------------------------------------------------------
    local function containsKeywordAny(str, keywords)
        if not (typeof(str) == "string") then return false end
        for _, k in ipairs(keywords) do
            if string.find(string.lower(str), string.lower(k)) then
                return true
            end
        end
        return false
    end

    local function parseNumber(txt)
        -- Remove spaces, currency, and grouping chars. Accept 1,234 or 1.234
        txt = tostring(txt or "")
        -- keep digits only
        local cleaned = txt:gsub("[^%d]", "")
        local n = tonumber(cleaned)
        return n
    end

    local function colorToHex(c3)
        if typeof(c3) ~= "Color3" then return "#FFFFFF" end
        local r = math.floor(c3.R * 255)
        local g = math.floor(c3.G * 255)
        local b = math.floor(c3.B * 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end

    local function getRowTint(frame)
        -- Try to extract a representative color for the row (value tier).
        -- Priority: UIGradient mid keypoint -> Frame.BackgroundColor -> ValueLabel.TextColor
        if not frame or not frame:IsA("Frame") then return nil end

        local grad = frame:FindFirstChildOfClass("UIGradient")
        if grad and grad.Color and grad.Color.Keypoints and #grad.Color.Keypoints > 0 then
            local midIndex = math.clamp(math.floor(#grad.Color.Keypoints/2)+1, 1, #grad.Color.Keypoints)
            local kc = grad.Color.Keypoints[midIndex].Value
            return kc
        end

        if frame.BackgroundColor3 then
            return frame.BackgroundColor3
        end

        local val = frame:FindFirstChild("ValueLabel")
        if val and val:IsA("TextLabel") then
            return val.TextColor3
        end
        return nil
    end

    local function getBoardSide(board)
        if not board or not board:IsA("BasePart") then return nil end
        local front = board:FindFirstChild("FrontSellValue")
        local back  = board:FindFirstChild("BackSellValue")
        if PREFERRED_SIDE == "FrontSellValue" then
            return front or back
        else
            return back or front
        end
    end

    local function collectBoardsMatchingCategory()
        local ws = workspace
        local holder = ws:FindFirstChild("SellValueBoards")
        if not holder then return {} end
        local matched = {}

        for _, board in ipairs(holder:GetChildren()) do
            local side = getBoardSide(board)
            if side and side:FindFirstChild("Frame") then
                local frame = side.Frame
                local title = frame:FindFirstChild("Title")
                local t = title and title:IsA("TextLabel") and title.Text or ""
                if containsKeywordAny(t, CATEGORY_KEYWORDS) then
                    table.insert(matched, board)
                end
            end
        end
        return matched
    end

    local function readItemsFromBoard(board)
        local items = {}
        local side = getBoardSide(board)
        if not side or not side:FindFirstChild("Frame") then return items end

        local list = side.Frame:FindFirstChild("List")
        if not list then return items end

        for _, row in ipairs(list:GetChildren()) do
            if row:IsA("Frame") then
                local nameLabel  = row:FindFirstChild("NameLabel")
                local valueLabel = row:FindFirstChild("ValueLabel")
                if nameLabel and valueLabel and nameLabel:IsA("TextLabel") and valueLabel:IsA("TextLabel") then
                    local name = tostring(nameLabel.Text or "")
                    local value = parseNumber(valueLabel.Text)
                    local tint  = getRowTint(row)
                    table.insert(items, {
                        product = name,
                        value   = value,
                        color   = tint,
                        colorHex= colorToHex(tint or Color3.new(1,1,1)),
                    })
                end
            end
        end
        return items
    end

    local function summarizeBoards()
        local matchedBoards = collectBoardsMatchingCategory()
        local allRows = {}
        local perProductBest = {} -- product -> { value, colorHex, boardIndex }

        for i, board in ipairs(matchedBoards) do
            local items = readItemsFromBoard(board)
            for _, it in ipairs(items) do
                table.insert(allRows, {
                    boardIndex = i,
                    product    = it.product,
                    value      = it.value or 0,
                    colorHex   = it.colorHex or "#FFFFFF",
                })
                local best = perProductBest[it.product]
                if (it.value or -1) > ((best and best.value) or -1) then
                    perProductBest[it.product] = {
                        value = it.value or 0,
                        colorHex = it.colorHex or "#FFFFFF",
                        boardIndex = i,
                    }
                end
            end
        end

        -- Sorting
        table.sort(allRows, function(a, b)
            if sortMode == "Value (asc)" then
                return (a.value or 0) < (b.value or 0)
            elseif sortMode == "Name (A→Z)" then
                return tostring(a.product) < tostring(b.product)
            else -- "Value (desc)"
                return (a.value or 0) > (b.value or 0)
            end
        end)

        -- Build UI text
        local sumTxt = string.format("Boards matched: %d | Rows: %d | Sort: %s", #matchedBoards, #allRows, sortMode)
        summaryPara:Set(sumTxt)

        if #allRows == 0 then
            resultsPara:Set("No items found.")
        else
            local lines = {}
            for _, r in ipairs(allRows) do
                table.insert(lines, string.format("[%d] %s — %s  <font color=\"%s\">■</font>",
                    r.boardIndex, r.product, tostring(r.value or 0), r.colorHex))
            end
            resultsPara:Set(table.concat(lines, "\n"))
        end

        if next(perProductBest) == nil then
            bestPara:Set("No data.")
        else
            local lines = {}
            -- sort keys by value desc
            local tmp = {}
            for k, v in pairs(perProductBest) do
                table.insert(tmp, { product = k, value = v.value, colorHex = v.colorHex, boardIndex = v.boardIndex })
            end
            table.sort(tmp, function(a,b) return (a.value or 0) > (b.value or 0) end)
            for _, r in ipairs(tmp) do
                table.insert(lines, string.format("%s — %s (board %d) <font color=\"%s\">■</font>",
                    r.product, tostring(r.value or 0), r.boardIndex, r.colorHex))
            end
            bestPara:Set(table.concat(lines, "\n"))
        end

        -- debug: list board names/titles
        local dbg = {}
        for i, board in ipairs(matchedBoards) do
            local side = getBoardSide(board)
            local t = ""
            if side and side:FindFirstChild("Frame") then
                local title = side.Frame:FindFirstChild("Title")
                t = title and title.Text or ""
            end
            table.insert(dbg, string.format("[%d] %s", i, t))
        end
        debugPara:Set(table.concat(dbg, "\n"))

        return #matchedBoards, #allRows
    end

    ----------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------
    sections.summary:AddButton({
        Name = "Scan Boards",
        Callback = function()
            summarizeBoards()
            OrionLib:MakeNotification({ Name = "Scan", Content = "Crops scan completed.", Time = 3 })
        end
    })

    sections.summary:AddToggle({
        Name = "Auto-Refresh",
        Default = AUTOREFRESH_DEFAULT,
        Callback = function(on)
            autoRefresh = on
            if refreshConn then refreshConn:Disconnect(); refreshConn = nil end
            if on then
                local acc = 0
                refreshConn = RunService.Heartbeat:Connect(function(dt)
                    acc += dt
                    if acc >= refreshInterval then
                        acc = 0
                        summarizeBoards()
                    end
                end)
            end
        end
    })

    sections.summary:AddSlider({
        Name = "Interval (s)",
        Min = 1, Max = 30, Increment = 1,
        Default = AUTOREFRESH_INTERVAL_DEFAULT,
        Callback = function(v) refreshInterval = v end
    })

    sections.summary:AddDropdown({
        Name = "Sort by",
        Options = { "Value (desc)", "Value (asc)", "Name (A→Z)" },
        Default = SORT_DEFAULT,
        Callback = function(opt)
            sortMode = opt
            summarizeBoards()
        end
    })

    -- initial scan
    summarizeBoards()
end
