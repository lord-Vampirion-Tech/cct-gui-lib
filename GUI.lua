local GUI = {}
GUI.Manager = { groups = {} }

function GUI.Manager:add(element, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if not self.groups[name] then
            self.groups[name] = {}
        end
        table.insert(self.groups[name], element)
    end
end

function GUI.Manager:removeAll(name)
    self.groups[name] = nil
end

function GUI.Manager:removeIf(name, predicate)
    local group = self.groups[name]
    if not group or type(predicate) ~= "function" then return end

    local i = 1
    while i <= #group do
        if predicate(group[i]) then
            table.remove(group, i)
        else
            i = i + 1
        end
    end
end

function GUI.Manager:setColors(name, colors)
    local group = self.groups[name]
    if not group or type(colors) ~= "table" then return end

    for _, element in ipairs(group) do
        if type(element.colors) == "table" then
            for k, v in pairs(colors) do
                element.colors[k] = v
            end
        end
    end
end

function GUI.Manager:setProperty(name, prop, value)
    local group = self.groups[name]
    if not group then return end
    for _, el in ipairs(group) do
        el[prop] = value
    end
end

function GUI.Manager:callAll(name, action, ...)
    local group = self.groups[name]
    if not group then return end

    if type(action) == "string" then
        action = { action }
    end

    for _, element in ipairs(group) do
        if type(action) == "function" then
            action(element, ...)
        elseif type(action) == "table" then
            for _, method in ipairs(action) do
                local fn = element[method]
                if type(fn) == "function" then
                    fn(element, ...)
                end
            end
        end
    end
end

math.checkRange = function(x, min, max)
    if x then
        return (x >= min and x <= max) and x or
            error(("\nthe number is out of bounds [%d,%d] (received %s)"):format(min, max, x), 2)
    else
        error("\n elemetn is nil", 2)
    end
end

math.round = function(x)
    if type(x) == "number" then
        return (x % 1 >= 0.5) and math.ceil(x) or math.floor(x)
    elseif type(x) == "table" then
        local r = {}
        for i, v in ipairs(x) do
            r[i] = (type(v) == "number") and ((v % 1 >= 0.5) and math.ceil(v) or math.floor(v)) or v
        end
        return r
    end
    return x
end

function Write(mon, pos, text)
    local x, y = pos[1], pos[2]
    for line in tostring(text):gmatch("[^\n]+") do
        mon.setCursorPos(x, y)
        mon.write(line)
        y = y + 1
    end
end

local function createClass()
    return setmetatable({}, {
        __index = GUI.Base,
        __call = function(cls, ...)
            return cls:new(...)
        end
    })
end

local function safeCall(fn, self)
    if not fn then return end
    local ok, err = pcall(fn, self)
    if not ok then pcall(fn) end
end

GUI.Base = createClass()
function GUI.Base:new(mon)
    local self = setmetatable({}, { __index = GUI.Base })

    local mon = mon or term
    self.colors = {
        -- mon --
        Base_Back = mon.getBackgroundColor(),
        Base_Text = mon.getTextColor(),
        -- label --
        back = mon.getBackgroundColor(),
        text = mon.getTextColor(),
        -- frame --
        frame = colors.gray,
        frame_text = colors.white,
        frame_back = colors.black,
        -- buttons --
        true_Bt = colors.green,
        locked_Bt = colors.red,
        idle_Bt = colors.gray,
        -- progress bar --
        used_Pb = colors.green,
        dot_Pb = colors.white,
        free_Pb = colors.gray,
        false_Pb = colors.red,
    }
    return self
end

function GUI.Base:setMonColor(text, back)
    self.mon.setTextColor(text)
    self.mon.setBackgroundColor(back)
end

function GUI.Base:setColor(text, back)
    self.colors.text = text or self.colors.text
    self.colors.back = back or self.colors.back

    if self.mon then
        self.mon.setTextColor(self.colors.text)
        self.mon.setBackgroundColor(self.colors.back)
    end
end

-- === Label ===
GUI.Label = createClass()
function GUI.Label:new(mon, pos, text, align, ...)
    local self = setmetatable(GUI.Base:new(mon),
        { __index = GUI.Label })
    self.type = "Label"

    self.visible = true
    self.mon = mon or term
    self.pos = pos or { 1, 1 }
    self.text = text or " "
    self.oldText = self.text

    self.align = align and {
        math.checkRange(align[1], 1, 3),
        math.checkRange(align[2], 1, 2),
    } or { 1, 1 }

    self.owner = nil
    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.Label:print(text)
    if not self.visible then return end

    self:setColor(
        self.owner and self.owner.colors.text or self.colors.text,
        self.owner and self.owner.colors.back or self.colors.back
    )

    local x, y = self.pos[1], self.pos[2]

    local function alignPos(len)
        return self.align[1] == 2 and math.round(x - len / 2)
            or self.align[1] == 3 and x - len + 1
            or x
    end

    self.text = text or self.text

    if self.oldText ~= self.text then
        local oldLen = #self.oldText or 0
        if self.align[2] == 1 then
            Write(self.mon, { alignPos(oldLen), y }, (" "):rep(oldLen))
        else
            local alignedY = self.align[1] == 2 and math.round(y - oldLen / 2)
                or self.align[1] == 3 and y - oldLen + 1
                or y
            for i = 0, oldLen - 1 do
                Write(self.mon, { x, alignedY + i }, " ")
            end
        end
    end

    if self.align[2] == 1 then
        Write(self.mon, { alignPos(#self.text), y }, self.text)
    else
        local alignedY = self.align[1] == 2 and math.round(y - #self.text / 2)
            or self.align[1] == 3 and y - #self.text + 1
            or y
        for i = 1, #self.text do
            Write(self.mon, { x, alignedY + i - 1 }, self.text:sub(i, i))
        end
    end

    self.oldText = self.text

    self:setMonColor(
        self.owner and self.owner.colors.Base_Text or self.colors.Base_Text,
        self.owner and self.owner.colors.Base_Back or self.colors.Base_Back
    )
end

-- === Frame ===
GUI.Frame = createClass()
function GUI.Frame:new(mon, column, row, Labels, ...)
    local self   = setmetatable(GUI.Base(mon), { __index = GUI.Frame })
    self.type    = "Frame"

    self.visible = true
    self.mon     = mon or term
    self.row     = row or { 2, 5, 10, 18 }
    self.column  = column or { 2, 5, 10, 18 }

    table.sort(self.row)
    table.sort(self.column)

    self.Labels = {}
    self.Text = {}
    if Labels then
        for row = 1, #self.row - 1 do
            for col = 1, #self.column - 1 do
                local i = (row - 1) * (#self.column - 1) + col
                if Labels[i] then
                    local h, v
                    if Labels[i][2] then
                        h, v = Labels[i][2][1], Labels[i][2][2]
                    else
                        h, v = 1, 1
                    end

                    local c1, c2 = self.column[col], self.column[col + 1]
                    local r1, r2 = self.row[row], self.row[row + 1]

                    local lbl_x = (v <= 2)
                        and (h == 1 and c1 + 2 or h == 2 and math.round((c1 + c2) / 2) or c2 - 2)
                        or (v == 3 and c1 or c2)

                    local lbl_y = (v == 1 and r1) or (v == 2 and r2)
                        or (h == 1 and r1 + 2 or h == 2 and math.round((r1 + r2) / 2) or r2 - 2)

                    self.Text[i] = Labels[i][1]
                    self.Labels[i] = GUI.Label(self.mon, { lbl_x, lbl_y }, self.Text[i],
                        { h, (v <= 2) and 1 or 2 })
                    self.Labels[i].owner = self
                end
            end
        end
    end
    self.owner = nil
    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.Frame:print()
    if not self.visible then return end

    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    local rowSet, colSet = {}, {}
    for _, y in ipairs(self.row) do rowSet[y] = true end
    for _, x in ipairs(self.column) do colSet[x] = true end

    for y = self.row[1], self.row[#self.row] do
        for x = self.column[1], self.column[#self.column] do
            Write(self.mon, { x, y },
                (
                    rowSet[y] and colSet[x]) and "+"
                or rowSet[y] and "-"
                or colSet[x] and "|"
                or " "
            )
        end
    end
    for i = 1, (#self.row - 1) * (#self.column - 1) do
        if self.Labels[i] then
            self.Labels[i].text = "+" .. self.Text[i] .. "+"
            self.Labels[i]:print()
        end
    end

    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )
end

-- === Button ===
GUI.Button = createClass()
function GUI.Button:new(mon, pos, text, align, func, ...)
    local self   = setmetatable(GUI.Base:new(mon), { __index = GUI.Button })
    self.type    = "Button"

    self.visible = true
    self.mon     = mon
    self.monId   = (mon == term) and "term" or peripheral.getName(mon)
    self.pos     = pos or { 1, 1 }
    self.text    = text or nil
    self.align   = align or { 1, 1 }

    self.locked  = false
    self.checked = false

    self.func    = func
    self.offset  = { left = 0, right = 0, up = 0, down = 0 }

    if type(self.align[2]) == "number" then
        local o = self.align[2]
        self.offset = { left = o, right = o, up = o, down = o }
    elseif type(self.align[2]) == "table" then
        local a = self.align[2]
        if #a == 2 then
            self.offset = { left = a[1], right = a[1], up = a[2], down = a[2] }
        elseif #a == 4 then
            self.offset = { left = a[1], right = a[2], up = a[3], down = a[4] }
        end
    end

    if self.align[1] == 1 then
        self.offset.right = self.offset.right + #self.text - 1
    elseif self.align[1] == 2 then
        self.offset.left = self.offset.left + math.floor(#self.text / 2)
        self.offset.right = self.offset.right + math.ceil(#self.text / 2) - 1
    elseif self.align[1] == 3 then
        self.offset.left = self.offset.left + #self.text - 1
    end

    self.Label       = GUI.Label(self.mon, { self.pos[1], self.pos[2] }, self.text, { self.align[1], 1 })
    self.Label.owner = self

    self.colors.back = self.colors.idle_Bt
    self.owner       = nil
    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.Button:print()
    if not self.visible then return end

    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    for i = 0, self.offset.up + self.offset.down, 1 do
        Write(self.mon, { self.pos[1] - self.offset.left, self.pos[2] - self.offset.up + i },
            (" "):rep(self.offset.left + self.offset.right + 1))
    end
    self.Label:print()

    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )
end

function GUI.Button:onClick(mon, x, y)
    if
        not self.locked and mon == self.monId
        and x >= self.pos[1] - self.offset.left
        and x <= self.pos[1] + self.offset.right
        and y >= self.pos[2] - self.offset.up
        and y <= self.pos[2] + self.offset.down
    then
        self.colors.back = self.colors.true_Bt
        self:print()
        safeCall(self.func, self)
        sleep(0.1)
        self.colors.back = self.colors.idle_Bt
        self:print()
    end
end

-- === Check Box ===
GUI.CheckBox = createClass()
function GUI.CheckBox:new(mon, pos, text, align, func, ...)
    local self   = setmetatable(GUI.Base:new(mon or term), { __index = GUI.CheckBox, })
    self.type    = "CheckBox"

    self.visible = true
    self.mon     = mon
    self.monId   = (mon == term) and "term" or peripheral.getName(mon)
    self.pos     = pos or { 1, 1 }
    self.text    = text or nil
    math.checkRange(align or 1, 1, 2)
    self.align = align == 2 and 3 or 1

    self.locked = false
    self.checked = false

    self.isOn = { "[x]", "[ ]" }
    self.func = func

    if self.text then
        self.Label = GUI.Label(self.mon,
            { self.align == 1 and self.pos[1] + 3 or self.align == 3 and self.pos[1] - 1, self.pos[2] }, self.text,
            { self.align, 1 })
        self.Label.owner = self
    end

    self.colors.back = self.colors.idle_Bt
    self.owner = nil
    if ... then
        GUI.Manager:add(self, ...)
    end
    return self
end

function GUI.CheckBox:swichLock()
    self.locked = not self.locked
    self:print()
end

function GUI.CheckBox:print()
    if not self.visible then return end

    self.colors.back = self.locked and self.colors.locked_Bt or
        (self.checked and self.colors.true_Bt or self.colors.idle_Bt)

    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    Write(self.mon, self.pos, self.checked and self.isOn[1] or self.isOn[2])
    if self.Label then
        self.Label.text = (self.align == 1 and " " .. self.text or self.align == 3 and self.text .. " ")
        self.Label:print()
    end

    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )
end

function GUI.CheckBox:onClick(mon, x, y)
    local length = self.text and #self.text + 1 or 0
    if not self.locked and mon == self.monId
        and x >= (self.align == 1 and self.pos[1] or self.pos[1] - length)
        and x <= (self.align == 1 and self.pos[1] + 2 + length or self.pos[1] + 2)
        and y == self.pos[2]
    then
        self.checked = not self.checked
        self:print()
        safeCall(self.func, self)
    end
end

-- === Radion Button ===
GUI.RadioButton = createClass()
GUI.RadioButton.groups = {}
function GUI.RadioButton:new(mon, pos, text, align, func, ...)
    local self = setmetatable(GUI.CheckBox:new(mon, pos, text, align, func, ...), { __index = GUI.RadioButton, })
    self.type  = "RadioButton"
    local name = { ... }
    self.name  = name[1] or "default"
    self.isOn  = { "{x}", "{ }" }
    self.func  = func

    if self.text then
        self.Label = GUI.Label(self.mon,
            { self.align == 1 and self.pos[1] + 3 or self.align == 3 and self.pos[1] - 1, self.pos[2] }, self.text,
            { self.align, 1 })
        self.Label.owner = self
    end

    if not GUI.RadioButton.groups[self.name] then
        GUI.RadioButton.groups[self.name] = {}
    end
    table.insert(GUI.RadioButton.groups[self.name], self)

    self.colors.back = self.colors.idle_Bt
    self.owner = nil

    if ... then
        GUI.Manager:add(self, self.name)
    end
    return self
end

function GUI.RadioButton:print()
    if not self.visible then return end

    self.colors.back = self.locked and self.colors.locked_Bt or
        (self.checked and self.colors.true_Bt or self.colors.idle_Bt)

    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    Write(self.mon, self.pos, self.checked and self.isOn[1] or self.isOn[2])
    if self.Label then
        self.Label.text = (self.align == 1 and " " .. self.text or self.align == 3 and self.text .. " ")

        self.Label:print()
    end

    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )
end

function GUI.RadioButton:swichLock()
    self.locked = not self.locked
    self:print()
end

function GUI.RadioButton:onClick(mon, x, y)
    local length = self.text and #self.text + 1 or 0

    if not self.locked and mon == self.monId
        and x >= (self.align == 1 and self.pos[1] or self.pos[1] - length)
        and x <= (self.align == 1 and self.pos[1] + 2 + length or self.pos[1] + 2)
        and y == self.pos[2]
    then
        for _, check in ipairs(GUI.RadioButton.groups[self.name]) do
            if check.checked == true and check.locked == true then
                return
            end
        end


        for _, check in ipairs(GUI.RadioButton.groups[self.name]) do
            check.checked = check.locked and check.checked or false
            check:print()
        end

        self.checked = true
        self:print()
        safeCall(self.func, self)
    end
end

-- === Progress Bar ===
GUI.ProgressBar = createClass()
function GUI.ProgressBar:new(mon, pos, val, align, func, ...)
    local self   = setmetatable(GUI.Base:new(mon), { __index = GUI.ProgressBar })
    self.type    = "ProgressBar"
    self.visible = true

    self.mon     = mon or term
    self.monId   = (mon == term) and "term" or peripheral.getName(mon)

    ----------------------------------------------------------------
    -- pos: { x1, x2, y }   для align=1,2  (горизонталь)
    --      { x, y1, y2 }   для align=3,4  (вертикаль)
    ----------------------------------------------------------------
    self.pos     = pos or { 2, 12, 2 }
    self.text    = text or nil
    self.align   = math.checkRange(align or 1, 1, 4)
    self.length  = (self.align <= 2) and math.abs(self.pos[2] - self.pos[1]) or math.abs(self.pos[3] - self.pos[2])

    self.locked  = false
    self.val     = {}
    if type(val) == "table" then
        local min  = val[1] or 1
        local max  = val[2] or (self.length + 1)
        local curr = val[3] or min

        self.val   = { min, max, curr }
    elseif type(val) == "number" then
        self.val = {
            1,
            self.length + 1,
            math.checkRange(val, 1, self.length + 1)
        }
    else
        self.val = { 1, self.length + 1, 1 }
    end

    self.func = func
    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.ProgressBar:swichLock()
    self.locked = not self.locked
    self:print()
end

function GUI.ProgressBar:print()
    if not self.visible then return end

    local target = self.mon or term
    local old = term.current()
    if self.mon ~= term then
        term.redirect(target)
    end

    local used = math.round((self.val[3] - self.val[1]) / (self.val[2] - self.val[1]) * self.length)
    local free = self.length - used

    local lineUsed
    local lineFree
    local dot


    if self.align == 1 then
        lineUsed = { self.pos[1], self.pos[3], self.pos[1] + used, self.pos[3],
            self.locked == false and self.colors.used_Pb or self.colors.false_Pb }
        lineFree = { self.pos[1] + used, self.pos[3], self.pos[2], self.pos[3],
            self.locked == false and self.colors.free_Pb or self.colors.false_Pb }
        dot = { self.pos[1] + used, self.pos[3], self.colors.dot_Pb }
    elseif self.align == 2 then
        lineUsed = { self.pos[1], self.pos[3], self.pos[1] + free, self.pos[3],
            self.locked == false and self.colors.free_Pb or self.colors.false_Pb }
        lineFree = { self.pos[1] + free, self.pos[3], self.pos[2], self.pos[3],
            self.locked == false and self.colors.used_Pb or self.colors.false_Pb }
        dot = { self.pos[1] + free, self.pos[3], self.colors.dot_Pb }
    elseif self.align == 3 then
        lineUsed = { self.pos[1], self.pos[2], self.pos[1], self.pos[2] + free,
            self.locked == false and self.colors.free_Pb or self.colors.false_Pb }
        lineFree = { self.pos[1], self.pos[2] + free, self.pos[1], self.pos[3],
            self.locked == false and self.colors.used_Pb or self.colors.false_Pb }
        dot = { self.pos[1], self.pos[2] + free, self.colors.dot_Pb }
    elseif self.align == 4 then
        lineUsed = { self.pos[1], self.pos[2], self.pos[1], self.pos[2] + used,
            self.locked == false and self.colors.used_Pb or self.colors.false_Pb }
        lineFree = { self.pos[1], self.pos[2] + used, self.pos[1], self.pos[3],
            self.locked == false and self.colors.free_Pb or self.colors.false_Pb }
        dot = { self.pos[1], self.pos[2] + used, self.colors.dot_Pb }
    end

    paintutils.drawLine(lineUsed[1], lineUsed[2], lineUsed[3], lineUsed[4], lineUsed[5])
    paintutils.drawLine(lineFree[1], lineFree[2], lineFree[3], lineFree[4], lineFree[5])
    paintutils.drawPixel(dot[1], dot[2], dot[3])

    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )

    term.redirect(old)
end

function GUI.ProgressBar:setVal(delta)
    if not self.locked and type(delta) == "number" then
        if delta >= self.val[1] and delta <= self.val[2] then
            self.val[3] = delta
            if self.func then
                local ok = pcall(self.func, self)
                if not ok then pcall(self.func) end
            end
            self:print()
        end
    end
end

function GUI.ProgressBar:setMaxVal(delta)
    if not self.locked and type(delta) == "number" then
        if delta >= self.val[3] then
            self.val[2] = delta
            if self.func then
                local ok = pcall(self.func, self)
                if not ok then pcall(self.func) end
            end
            self:print()
        end
    end
end

function GUI.ProgressBar:setMinVal(delta)
    if not self.locked and type(delta) == "number" then
        if delta <= self.val[3] then
            self.val[1] = delta
            if self.func then
                local ok = pcall(self.func, self)
                if not ok then pcall(self.func) end
            end
            self:print()
        end
    end
end

function GUI.ProgressBar:onClick(mon, x, y)
    if self.locked or mon ~= self.monId then return end

    if
        (self.align == 1 or self.align == 2)
        and x >= self.pos[1]
        and x <= self.pos[2]
        and y == self.pos[3]
    then
        local percent = (x - self.pos[1]) / self.length
        if self.align == 2 then
            percent = 1 - percent
        end
        self.val[3] = (math.round(self.val[1] + percent * (self.val[2] - self.val[1])))
        if self.func then
            local ok = pcall(self.func, self)
            if not ok then pcall(self.func) end
        end
        self:print()
    elseif
        (self.align == 3 or self.align == 4)
        and x == self.pos[1]
        and y >= self.pos[2]
        and y <= self.pos[3]
    then
        local percent = (self.align == 3)
            and (1 - ((y - self.pos[2]) / self.length))
            or ((y - self.pos[2]) / self.length)
        self.val[3] = (math.round(self.val[1] + percent * (self.val[2] - self.val[1])))
        if self.func then
            local ok = pcall(self.func, self)
            if not ok then pcall(self.func) end
        end
        self:print()
    end
end

-- === Text Input ===
GUI.TextInput = createClass()
function GUI.TextInput:new(mon, pos, text, ...)
    local self       = setmetatable(GUI.Base:new(mon), { __index = GUI.TextInput })
    self.type        = "TextInput"

    self.visible     = true
    self.mon         = mon
    self.monId       = (mon == term) and "term" or peripheral.getName(mon)
    self.pos         = pos or { 2, 12, 2 } -- x1, x2, y

    self.maxLength   = self.pos[2] - self.pos[1] + 1
    self.text        = tostring(text or "")
    self.func        = nil

    self.locked      = false
    self.active      = false

    self.colors.back = colors.gray
    self.owner       = nil
    self.Label       = GUI.Label:new(self.mon, { self.pos[1], self.pos[3] }, self.text, { 1, 1 })
    self.Label.owner = self

    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.TextInput:clear()
    self.text = ""
    self:print()
end

function GUI.TextInput:print(text)
    if not self.visible then return end
    self.text = text or self.text

    local target = self.mon or term
    local old = term.current()
    if self.mon ~= term then
        term.redirect(target)
    end

    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    paintutils.drawLine(self.pos[1], self.pos[3], self.pos[2], self.pos[3],
        self.owner == nil and self.colors.back or self.owner.colors.back)

    self.Label:print(self.text)

    if not self.locked and self.active and #self.text < self.maxLength then
        paintutils.drawPixel(#self.text + self.pos[1], self.pos[3], colors.lightGray)
    end


    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )

    term.redirect(old)
end

function GUI.TextInput:onClick(mon, x, y)
    if not self.locked and mon == self.monId
        and x >= self.pos[1]
        and x <= self.pos[2]
        and y == self.pos[3]
    then
        self.active = true
        self:print()
        return true
    else
        self.active = false
        self:print()
        return false
    end
end

function GUI.TextInput:keyPress(key)
    if not self.active then return end

    if key == keys.backspace then
        if #self.text + self.pos[1] > 2 then
            self:print(self.text:sub(1, #self.text - 1))
        end
    elseif key == keys.enter then
        safeCall(self.func, self)
    elseif type(key) == "string" and #key == 1 and #self.text < self.maxLength then
        self:print(self.text .. key)
    end
end

-- === Text Area ===
GUI.TextArea = createClass()
function GUI.TextArea:new(mon, pos, text, ...)
    local self       = setmetatable(GUI.Base:new(mon), { __index = GUI.TextArea })
    self.type        = "TextInput"

    self.visible     = true
    self.mon         = mon
    self.monId       = (mon == term) and "term" or peripheral.getName(mon)
    self.pos         = pos or { 2, 2, 12, 12 } -- x1, y1, x2, y2,

    self.size        = { self.pos[3] + 1 - self.pos[1], self.pos[4] - self.pos[2] + 1 }
    self.text        = tostring(text or "")
    self.func        = nil

    self.locked      = false
    self.active      = false

    self.colors.back = colors.gray
    self.owner       = nil

    if ... then GUI.Manager:add(self, ...) end
    return self
end

function GUI.TextArea:clear()
    self.text = ""
    self:print()
end

-- Разбивает текст на ровные участки по interval символов
local function wrapByChars(text, interval)
    interval    = math.max(1, math.floor(interval or 1))
    text        = text or ""
    local parts = {}
    for i = 1, #text, interval do
        parts[#parts + 1] = text:sub(i, i + interval - 1)
    end
    return parts -- возвращаем уже не одну строку, а массив строк
end

function GUI.TextArea:print(text)
    if not self.visible then return end
    self.text = text or self.text

    local target = self.mon or term
    local old = term.current()
    if self.mon ~= term then
        term.redirect(target)
    end

    -- 1) разбиваем на строки по ширине
    local lines = wrapByChars(self.text, self.size[1])

    -- 2) рисуем фон ровно в рамках area
    self:setColor(
        self.owner == nil and self.colors.text or self.owner.colors.text,
        self.owner == nil and self.colors.back or self.owner.colors.back
    )

    local x1, y1, x2, y2 = table.unpack(self.pos)
    paintutils.drawFilledBox(x1, y1, x2, y2, self.owner == nil and self.colors.back or self.owner.colors.back)

    -- 3) выводим текст **построчно**, не выходя за y2
    for i = 1, #lines do
        local lineY = y1 + i - 1
        if lineY > y2 then break end
        -- обрежем строку по ширине на всякий случай
        local fragment = lines[i]:sub(1, self.size[1])
        Write(self.mon, { x1, lineY }, fragment)
    end

    -- 4) рисуем курсор в нужном месте (как в предыдущем ответе)
    if not self.locked and self.active then
        local ci = math.min(math.max(#self.text + 1, 1), #self.text + 1)
        local width = self.size[1]
        local row = math.floor((ci - 1) / width)
        local col = (ci - 1) % width
        local cx, cy = x1 + col, y1 + row
        if cx <= x2 and cy <= y2 then
            paintutils.drawPixel(cx, cy, colors.lightGray)
        end
    end

    -- 5) сброс цвета
    self:setMonColor(
        self.owner == nil and self.colors.Base_Text or self.owner.colors.Base_Text,
        self.owner == nil and self.colors.Base_Back or self.owner.colors.Base_Back
    )

    term.redirect(old)
end

function GUI.TextArea:onClick(mon, x, y)
    if not self.locked and mon == self.monId
        and x >= self.pos[1]
        and y >= self.pos[2]
        and x <= self.pos[3]
        and y <= self.pos[4]
    then
        self.active = true
        self:print()
        return true
    else
        self.active = false
        self:print()
        return false
    end
end

function GUI.TextArea:keyPress(key)
    if not self.active then return end

    if key == keys.backspace then
        if #self.text + self.pos[1] > 2 then
            self:print(self.text:sub(1, #self.text - 1))
        end
    elseif key == keys.enter then
        safeCall(self.func, self)
    elseif type(key) == "string" and #key == 1 and #self.text < self.size[1] * self.size[2] then
        self:print(self.text .. key)
    end
end

return GUI
