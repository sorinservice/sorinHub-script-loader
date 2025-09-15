-- tabs/misc.lua
-- SorinHub - Sell Value Scanner (Misc / Various)
-- Auto-refresh: always ON, every 15s

return function(tab, OrionLib)
    local CATEGORY_KEYWORDS = { "Verschiedene", "Misc", "Various" } -- matches "Verschiedene Verkaufswerte"
    local PREFERRED_SIDE    = "FrontSellValue"
    local SORT_DEFAULT      = "Value (desc)"
    local REFRESH_SECONDS   = 15

    local RunService = game:GetService("RunService")

    local sortMode = SORT_DEFAULT
    local hbConn, acc = nil, 0

    local sections = {
        summary = tab:AddSection({ Name = "Summary" }),
        results = tab:AddSection({ Name = "Board Items" }),
        best    = tab:AddSection({ Name = "Per-Product Best Price" }),
        debug   = tab:AddSection({ Name = "Debug" }),
    }

    local summaryPara = sections.summary:AddParagraph("Status", "Initializing…")
    local resultsPara = sections.results:AddParagraph("Items", "No data yet.")
    local bestPara    = sections.best:AddParagraph("Best", "No data yet.")
    local debugPara   = sections.debug:AddParagraph("Details", "—")

    local function containsKeywordAny(s, keys)
        if typeof(s) ~= "string" then return false end
        s = string.lower(s)
        for _, k in ipairs(keys) do if string.find(s, string.lower(k)) then return true end end
        return false
    end

    local function parseNumber(t) return tonumber((tostring(t or "")):gsub("[^%d]", "")) end
    local function colorToHex(c) if typeof(c)~="Color3" then return "#FFFFFF" end return string.format("#%02X%02X%02X", c.R*255, c.G*255, c.B*255) end

    local function rowTint(frame)
        local g = frame and frame:FindFirstChildOfClass("UIGradient")
        if g and g.Color and g.Color.Keypoints and #g.Color.Keypoints>0 then
            local mid = math.clamp(math.floor(#g.Color.Keypoints/2)+1,1,#g.Color.Keypoints)
            return g.Color.Keypoints[mid].Value
        end
        if frame and frame.BackgroundColor3 then return frame.BackgroundColor3 end
        local v = frame and frame:FindFirstChild("ValueLabel")
        if v and v:IsA("TextLabel") then return v.TextColor3 end
        return nil
    end

    local function pickSide(board)
        local f = board:FindFirstChild("FrontSellValue")
        local b = board:FindFirstChild("BackSellValue")
        return (PREFERRED_SIDE=="FrontSellValue" and (f or b)) or (b or f)
    end

    local function findBoards()
        local root = workspace:FindFirstChild("SellValueBoards"); if not root then return {} end
        local out = {}
        for _, board in ipairs(root:GetChildren()) do
            local side = pickSide(board)
            local frame = side and side:FindFirstChild("Frame")
            local title = frame and frame:FindFirstChild("Title")
            local t = title and title.Text or ""
            if containsKeywordAny(t, CATEGORY_KEYWORDS) then table.insert(out, board) end
        end
        return out
    end

    local function readBoard(board)
        local items = {}
        local side  = pickSide(board)
        local frame = side and side:FindFirstChild("Frame")
        local list  = frame and frame:FindFirstChild("List")
        if not list then return items end
        for _, row in ipairs(list:GetChildren()) do
            if row:IsA("Frame") then
                local n = row:FindFirstChild("NameLabel")
                local v = row:FindFirstChild("ValueLabel")
                if n and v and n:IsA("TextLabel") and v:IsA("TextLabel") then
                    table.insert(items, {
                        product = tostring(n.Text or ""),
                        value   = parseNumber(v.Text) or 0,
                        colorHex= colorToHex(rowTint(row) or Color3.new(1,1,1)),
                    })
                end
            end
        end
        return items
    end

    local function refreshOnce()
        local boards = findBoards()
        local rows, best = {}, {}
        for i, b in ipairs(boards) do
            for _, it in ipairs(readBoard(b)) do
                table.insert(rows, { boardIndex=i, product=it.product, value=it.value or 0, colorHex=it.colorHex })
                local cur = best[it.product]
                if (it.value or -1) > ((cur and cur.value) or -1) then
                    best[it.product] = { value=it.value or 0, colorHex=it.colorHex, boardIndex=i }
                end
            end
        end

        table.sort(rows, function(a,b)
            if sortMode=="Value (asc)" then return (a.value or 0)<(b.value or 0)
            elseif sortMode=="Name (A→Z)" then return tostring(a.product)<tostring(b.product)
            else return (a.value or 0)>(b.value or 0) end
        end)

        summaryPara:Set(string.format("Boards matched: %d | Rows: %d | Sort: %s", #boards, #rows, sortMode))

        if #rows==0 then resultsPara:Set("No items found.")
        else
            local lines={}
            for _, r in ipairs(rows) do
                table.insert(lines, string.format("[%d] %s — %s  <font color=\"%s\">■</font>", r.boardIndex, r.product, tostring(r.value or 0), r.colorHex))
            end
            resultsPara:Set(table.concat(lines, "\n"))
        end

        if next(best)==nil then bestPara:Set("No data.") else
            local tmp, lines = {}, {}
            for k,v in pairs(best) do table.insert(tmp,{product=k,value=v.value,colorHex=v.colorHex,boardIndex=v.boardIndex}) end
            table.sort(tmp,function(a,b) return (a.value or 0)>(b.value or 0) end)
            for _, r in ipairs(tmp) do
                table.insert(lines, string.format("%s — %s (board %d) <font color=\"%s\">■</font>", r.product, tostring(r.value or 0), r.boardIndex, r.colorHex))
            end
            bestPara:Set(table.concat(lines, "\n"))
        end

        local dbg={}
        for i,b in ipairs(boards) do
            local side=pickSide(b); local t=side and side:FindFirstChild("Frame") and side.Frame:FindFirstChild("Title")
            table.insert(dbg, string.format("[%d] %s", i, (t and t.Text) or ""))
        end
        debugPara:Set(table.concat(dbg, "\n"))
    end

    sections.summary:AddButton({ Name="Scan Boards", Callback=function() refreshOnce(); OrionLib:MakeNotification({Name="Scan", Content="Misc scan completed.", Time=3}) end })
    sections.summary:AddDropdown({ Name="Sort by", Options={"Value (desc)","Value (asc)","Name (A→Z)"}, Default=SORT_DEFAULT, Callback=function(opt) sortMode=opt; refreshOnce() end })

    refreshOnce()

    if hbConn then hbConn:Disconnect() end
    hbConn = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc >= REFRESH_SECONDS then acc = 0; refreshOnce() end
    end)
end
