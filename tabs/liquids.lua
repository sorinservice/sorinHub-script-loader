-- tabs/liquids.lua
-- SorinHub - Sell Value Scanner (Liquids)

return function(tab, OrionLib)
    local CATEGORY_KEYWORDS = { "Flüssig", "Liquid", "Liquids" }
    local PREFERRED_SIDE = "FrontSellValue"
    local AUTOREFRESH_DEFAULT = false
    local AUTOREFRESH_INTERVAL_DEFAULT = 5
    local SORT_DEFAULT = "Value (desc)"

    local Players    = game:GetService("Players")
    local RunService = game:GetService("RunService")

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
        local cleaned = tostring(txt or ""):gsub("[^%d]", "")
        return tonumber(cleaned)
    end

    local function colorToHex(c3)
        if typeof(c3) ~= "Color3" then return "#FFFFFF" end
        return string.format("#%02X%02X%02X", math.floor(c3.R*255), math.floor(c3.G*255), math.floor(c3.B*255))
    end

    local function getRowTint(frame)
        local grad = frame and frame:FindFirstChildOfClass("UIGradient")
        if grad and grad.Color and grad.Color.Keypoints and #grad.Color.Keypoints > 0 then
            local mid = math.clamp(math.floor(#grad.Color.Keypoints/2)+1, 1, #grad.Color.Keypoints)
            return grad.Color.Keypoints[mid].Value
        end
        if frame and frame.BackgroundColor3 then return frame.BackgroundColor3 end
        local val = frame and frame:FindFirstChild("ValueLabel")
        if val and val:IsA("TextLabel") then return val.TextColor3 end
        return nil
    end

    local function getBoardSide(board)
        local front = board:FindFirstChild("FrontSellValue")
        local back  = board:FindFirstChild("BackSellValue")
        if PREFERRED_SIDE == "FrontSellValue" then
            return front or back
        else
            return back or front
        end
    end

    local function collectBoards()
        local holder = workspace:FindFirstChild("SellValueBoards")
        if not holder then return {} end
        local out = {}
        for _, board in ipairs(holder:GetChildren()) do
            local side = getBoardSide(board)
            if side and side:FindFirstChild("Frame") then
                local title = side.Frame:FindFirstChild("Title")
                local t = title and title.Text or ""
                if containsKeywordAny(t, CATEGORY_KEYWORDS) then
                    table.insert(out, board)
                end
            end
        end
        return out
    end

    local function readItems(board)
        local side = getBoardSide(board)
        if not side or not side:FindFirstChild("Frame") then return {} end
        local list = side.Frame:FindFirstChild("List")
        if not list then return {} end
        local items = {}
        for _, row in ipairs(list:GetChildren()) do
            if row:IsA("Frame") then
                local name = row:FindFirstChild("NameLabel")
                local val  = row:FindFirstChild("ValueLabel")
                if name and val and name:IsA("TextLabel") and val:IsA("TextLabel") then
                    local tint = getRowTint(row)
                    table.insert(items, {
                        product = tostring(name.Text or ""),
                        value   = parseNumber(val.Text),
                        colorHex= colorToHex(tint or Color3.new(1,1,1)),
                    })
                end
            end
        end
        return items
    end

    local function refresh()
        local boards = collectBoards()
        local rows = {}
        local best = {}
        for i, b in ipairs(boards) do
            for _, it in ipairs(readItems(b)) do
                table.insert(rows, { boardIndex=i, product=it.product, value=it.value or 0, colorHex=it.colorHex })
                local cur = best[it.product]
                if (it.value or -1) > ((cur and cur.value) or -1) then
                    best[it.product] = { value=it.value or 0, colorHex=it.colorHex, boardIndex=i }
                end
            end
        end

        table.sort(rows, function(a,b)
            if sortMode == "Value (asc)" then
                return (a.value or 0) < (b.value or 0)
            elseif sortMode == "Name (A→Z)" then
                return tostring(a.product) < tostring(b.product)
            else
                return (a.value or 0) > (b.value or 0)
            end
        end)

        summaryPara:Set(string.format("Boards matched: %d | Rows: %d | Sort: %s", #boards, #rows, sortMode))

        if #rows == 0 then
            resultsPara:Set("No items found.")
        else
            local lines = {}
            for _, r in ipairs(rows) do
                table.insert(lines, string.format("[%d] %s — %s  <font color=\"%s\">■</font>",
                    r.boardIndex, r.product, tostring(r.value or 0), r.colorHex))
            end
            resultsPara:Set(table.concat(lines, "\n"))
        end

        if next(best) == nil then
            bestPara:Set("No data.")
        else
            local lines, tmp = {}, {}
            for k, v in pairs(best) do table.insert(tmp, {product=k, value=v.value, colorHex=v.colorHex, boardIndex=v.boardIndex}) end
            table.sort(tmp, function(a,b) return (a.value or 0) > (b.value or 0) end)
            for _, r in ipairs(tmp) do
                table.insert(lines, string.format("%s — %s (board %d) <font color=\"%s\">■</font>",
                    r.product, tostring(r.value or 0), r.boardIndex, r.colorHex))
            end
            bestPara:Set(table.concat(lines, "\n"))
        end

        local dbg = {}
        for i, b in ipairs(boards) do
            local side = getBoardSide(b)
            local t = side and side.Frame and side.Frame:FindFirstChild("Title")
            table.insert(dbg, string.format("[%d] %s", i, (t and t.Text) or ""))
        end
        debugPara:Set(table.concat(dbg, "\n"))
    end

    sections.summary:AddButton({ Name="Scan Boards", Callback=function() refresh(); OrionLib:MakeNotification({Name="Scan", Content="Liquids scan completed.", Time=3}) end })
    sections.summary:AddToggle({
        Name="Auto-Refresh", Default=false,
        Callback=function(on)
            if refreshConn then refreshConn:Disconnect(); refreshConn=nil end
            if on then
                local acc=0
                refreshConn = RunService.Heartbeat:Connect(function(dt)
                    acc += dt
                    if acc >= refreshInterval then acc=0; refresh() end
                end)
            end
        end
    })
    sections.summary:AddSlider({ Name="Interval (s)", Min=1, Max=30, Increment=1, Default=5, Callback=function(v) refreshInterval=v end })
    sections.summary:AddDropdown({ Name="Sort by", Options={"Value (desc)","Value (asc)","Name (A→Z)"}, Default="Value (desc)", Callback=function(opt) sortMode=opt; refresh() end })

    refresh()
end
