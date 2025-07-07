local gui = {}

gui.Manager = {
    obj = {},
    groups = {}
}
gui.defColor = {
    B_Back = colors.black, -- базовый цвет
    B_Text = colors.white, -- базовый цвет
    -- label
    l_back = colors.gray,
    l_text = colors.white,

    -- frame
    f_back = colors.black,
    f_text = colors.white,
    f_frame_back = colors.gray,
    f_frame_text = colors.white,

    ---- triggers
    tg_base_back = colors.gray,
    tg_base_text = colors.white,
    tg_active_back = colors.green,
    tg_active_text = colors.black,
    tg_locked_back = colors.red,
    tg_locked_text = colors.yellow,

    ---- progress bar
    r_back = colors.gray,
    r_used = colors.green,
    r_locked = colors.red,
    r_dot = colors.white,

    -- text area
    t_base_back = colors.gray,
    t_base_text = colors.lightGray,
    t_locked_back = colors.red,
    t_locked_text = colors.black,
    t_active_back = colors.gray,
    t_active_text = colors.white,
    t_dot = colors.white,
}
------------------------------------
function gui.Manager:callAll(name, action, ...)
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

function gui.Manager:get(name)
    return self.obj[name] or nil
end

------------------------------------

math.round = function(val)
    return (val % 1 >= 0.5) and math.ceil(val) or math.floor(val)
end

function createClass(base)
    local cls = {}
    cls.__index = cls
    cls.super = base

    function cls:new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
            instance:init(...)
        end
        return instance
    end

    setmetatable(cls, {
        __index = base,
        __call = function(c, ...)
            return c:new(...)
        end
    })

    return cls
end

function Write(mon, pos, text, align)
    local align = align or 1

    if align == 1 then
        mon.setCursorPos(pos[1], pos[2])
        mon.write(text)
    elseif align == 2 then
        for i = 1, #text, 1 do
            mon.setCursorPos(pos[1], pos[2] + i - 1)
            mon.write(text:sub(i, i))
        end
    end
end

function gui.setcolors(colorsTable)
    for key, value in pairs(colorsTable) do
        gui.defColor[key] = value
    end
end

local function safeCall(fn, self)
    if not fn then return end
    local ok, err = pcall(fn, self)
    if not ok then pcall(fn) end
end

local function setColors(table, colorsTable)
    for key, value in pairs(colorsTable) do
        if table[key] then
            table[key] = value
        end
    end
end

------------------------------------
gui.Base = createClass()
function gui.Base:init(mon, pos, owner)
    self.mon = mon or term

    if self.mon == term then
        self.monID = term
    else
        self.monID = peripheral.getName(self.mon)
    end
    self.pos = pos or { 1, 1 }
    self.type = "Base"

    self.visible = true
    self.owner = owner or nil
end

function gui.Base:add(name, ...)
    if type(name) == "string" then
        if gui.Manager.obj[name] then
            error("GUI object with name { " .. name .. " } already exists.", 2)
        end
        gui.Manager.obj[name] = self
    else
        table.insert({ ... }, 1, name)
    end

    for i = 1, select("#", ...) do
        local groupname = select(i, ...)
        if type(groupname) == "string" then
            gui.Manager.groups[groupname] = gui.Manager.groups[groupname] or {}
            table.insert(gui.Manager.groups[groupname], self)
        end
    end
    return self
end

function gui.Base:setproperty(prop, val)
    self[prop] = val
    return self
end

function gui.Base:setFunc(func)
    if type(func) == "function" then
        self.func = func
    end
    return self
end

function gui.Base:setMonColor(back, text)
    if text then self.mon.setTextColor(text) end
    if back then self.mon.setBackgroundColor(back) end
end

function gui.Base:print()
    Write(self.mon, self.pos, "lol")
end

gui.Label = createClass(gui.Base)
function gui.Label:init(mon, pos, value, align, owner)
    gui.Label.super.init(self, mon, pos, owner)

    self.type = "Label"
    self.value = value
    self.align = align or { 1, 1 }

    local function al(axis)
        return (self.align[1] == 3) and (axis - #tostring(self.value[1]) + 1) or
            (self.align[1] == 2) and math.round(axis - #tostring(self.value[1]) / 2) or
            axis
    end

    self.pos[1] = self.align[2] == 1 and al(self.pos[1]) or self.pos[1]
    self.pos[2] = self.align[2] == 2 and al(self.pos[2]) or self.pos[2]

    self.colors = {
        back = gui.defColor.l_back,
        text = gui.defColor.l_text
    }
end

function gui.Label:print()
    if not self.visible then return end
    if self.owner then setColors(self.colors, self.owner.colors) end
    self:setMonColor(self.colors.back, self.colors.text)
    Write(self.mon, self.pos, tostring(self.value[1]), self.align[2])
    self:setMonColor(gui.defColor.B_Back, gui.defColor.B_Text)
end

gui.Table = createClass(gui.Base)
function gui.Table:init(mon, column, row, name, owner)
    gui.Table.super.init(self, mon, { x = row[1] or 1, y = column[1] or 1 }, owner)
    self.type   = "Table"
    self.char   = { c = "#", v = "|", h = "-" }

    self.column = column or { 1, 3, 5 }
    self.row    = row or { 1, 3, 5 }

    table.sort(self.column)
    table.sort(self.row)

    self.labels = {}

    self.colors = {
        back = gui.defColor.f_back,
        text = gui.defColor.f_text,
        f_back = gui.defColor.f_frame_back,
        f_text = gui.defColor.f_frame_text,
    }

    if name then
        for r = 1, #self.row - 1 do
            for c = 1, #self.column - 1 do
                local i = (r - 1) * (#self.column - 1) + c

                if name[i] then
                    local h, v = name[i][2] and name[i][2][1] or 1, name[i][2] and name[i][2][2] or 1

                    local c1, c2 = self.column[c], self.column[c + 1]
                    local r1, r2 = self.row[r], self.row[r + 1]

                    local x = (v == 3 and c1) or (v > 3 and c2) or
                        (h == 1 and c1 + 2) or (h == 2 and math.round((c1 + c2) / 2)) or (c2 - 2)
                    local y = (v == 1 and r1) or (v == 2 and r2) or
                        (h == 1 and r1 + 2) or (h == 2 and math.round((r1 + r2) / 2)) or (r2 - 2)

                    self.labels[i] = gui.Label(self.mon, { x, y }, { "+" .. name[i][1] .. "+" },
                        { h, (v <= 2) and 1 or 2 })
                    self.labels[i].colors = { back = self.colors.f_back, text = self.colors.f_text }
                end
            end
        end
    end
end

function gui.Table:print()
    if not self.visible then return end
    if self.owner then setColors(self.colors, self.owner.colors) end
    self:setMonColor(self.colors.back)

    for c = self.column[1], self.column[#self.column], 1 do
        for r = self.row[1], self.row[#self.row], 1 do
            Write(self.mon, { c, r }, " ")
        end
    end

    self:setMonColor(self.colors.f_back, self.colors.f_text)

    for c = self.column[1], self.column[#self.column], 1 do
        for _, r in pairs(self.row) do
            Write(self.mon, { c, r }, self.char.h)
        end
    end

    for r = self.row[1], self.row[#self.row], 1 do
        for _, c in pairs(self.column) do
            Write(self.mon, { c, r }, self.char.v)
        end
    end

    for _, c in pairs(self.column) do
        for _, r in pairs(self.row) do
            Write(self.mon, { c, r }, self.char.c)
        end
    end

    for _, v in pairs(self.labels) do
        v:print()
    end

    self:setMonColor(gui.defColor.B_Back, gui.defColor.B_Text)
end

gui.Frame = createClass(gui.Table)
function gui.Frame:init(mon, pos, name, align)
    gui.Frame.super.init(self, mon, { pos[1], pos[3] }, { pos[2], pos[4] }, { name, align })

    self.type = "Frame"
end

local function actionColor(self)
    return {
        (self.locked and self.colors.locked_back) or
        (self.active and self.colors.active_back) or
        self.colors.back,
        (self.locked and self.colors.locked_text) or
        (self.active and self.colors.active_text) or
        self.colors.text
    }
end

local function actionText(obg)
    return ((obg.align[1] == 1) and (obg.char[obg.active and 1 or 2]) or
        (obg.align[1] == 2) and (obg.char[obg.active and 1 or 2] .. " " .. obg.text) or
        (obg.align[1] == 3) and (obg.text .. " " .. obg.char[obg.active and 1 or 2]) or
        (obg.align[1] == 4) and (obg.text))
end

gui.Button = createClass(gui.Base)
function gui.Button:init(mon, pos, text, align, func, owner)
    gui.Button.super.init(self, mon, pos, owner)
    self.type   = "Button"

    self.align  = align or { 1, 1 }
    self.text   = text or " "

    self.func   = func or nil
    self.locked = false
    self.active = false

    self.offset = { left = 0, right = 0, up = 0, down = 0 }

    if type(self.align[2]) == "number" then
        self.offset = { left = self.align[2], right = self.align[2], up = self.align[2], down = self.align[2] }
    elseif type(self.align[2]) == "table" then
        local a = self.align[2]
        if #a == 2 then
            self.offset = { left = a[1], right = a[1], up = a[2], down = a[2] }
        elseif #a == 4 then
            self.offset = { left = a[1], right = a[2], up = a[3], down = a[4] }
        end
    end

    self.offset.right = self.offset.right + #self.text - 1

    self.colors = {
        back = gui.defColor.tg_base_back,
        text = gui.defColor.tg_base_text,
        active_back = gui.defColor.tg_active_back,
        active_text = gui.defColor.tg_active_text,
        locked_back = gui.defColor.tg_locked_back,
        locked_text = gui.defColor.tg_locked_text,
    }

    self.label = gui.Label(self.mon, self.pos, { self.text }, { self.align[1], 1 })
    self.label.colors = { table.unpack(actionColor(self)) }
end

function gui.Button:print()
    if not self.visible then return end

    if self.owner then setColors(self.colors, self.owner.colors) end
    if self.char then self.label.value = { actionText(self) } end
    self:setMonColor(table.unpack(actionColor(self)))

    for i = 0, self.offset.up + self.offset.down, 1 do
        Write(self.mon, { self.pos[1] - self.offset.left, self.pos[2] - self.offset.up + i },
            (" "):rep(self.offset.left + self.offset.right + 1))
    end

    self.label:print()
    self:setMonColor(gui.defColor.B_Back, gui.defColor.B_Text)
end

function gui.Button:onClick(mon, x, y)
    if
        not self.locked and (self.mon.setTextScale and tostring(peripheral.getName(self.mon)) == tostring(mon) or tostring(self.mon) == tostring(mon))
        and x >= self.pos[1] - self.offset.left
        and x <= self.pos[1] + self.offset.right
        and y >= self.pos[2] - self.offset.up
        and y <= self.pos[2] + self.offset.down
    then
        self.active = true
        self:print()
        safeCall(self.func, self)
        sleep(0.1)
        self.active = false
        self:print()
    end
end

gui.CheckBox = createClass(gui.Button)
function gui.CheckBox:init(mon, pos, text, align, func, owner)
    gui.CheckBox.super.init(self, mon, pos, text, align, func, owner)
    self.type = "CheckBox"

    self.char = { "[x]", "[ ]" }
    self.label.value = { actionText(self) }

    if type(self.align[2]) == "number" then
        self.offset = { left = self.align[2], right = self.align[2], up = self.align[2], down = self.align[2] }
    elseif type(self.align[2]) == "table" then
        local a = self.align[2]
        if #a == 2 then
            self.offset = {
                left = a[1],
                right = a[1],
                up = a[2],
                down = a[2]
            }
        elseif #a == 4 then
            self.offset = {
                left = a[1],
                right = a[2],
                up = a[3],
                down = a[4]
            }
        end
    end

    self.pos[1] = self.align[1] == 2 and self.pos[1] + 1 or
        self.align[1] == 3 and self.pos[1] + #self.label.value[1] / 2 - 1 or self.pos[1] - 1


    self.offset.right = self.offset.right + #self.label.value[1] - 1
end

function gui.CheckBox:onClick(mon, x, y)
    if
        not self.locked and (self.mon.setTextScale and tostring(peripheral.getName(self.mon)) == tostring(mon) or tostring(self.mon) == tostring(mon))
        and x >= self.pos[1] - self.offset.left
        and x <= self.pos[1] + self.offset.right
        and y >= self.pos[2] - self.offset.up
        and y <= self.pos[2] + self.offset.down
    then
        self.active = not self.active
        self.label.value = { actionText(self) }
        self:print()
        safeCall(self.func, self)
    end
end

gui.RadioButton = createClass(gui.CheckBox)
gui.RadioButton.groups = {}
function gui.RadioButton:init(mon, pos, text, align, name, func)
    gui.RadioButton.super.init(self, mon, pos, text, align, func)
    self.char = { "{x}", "{ }" }
    self.type = "RadioButton"
    self.name = name or "base"

    self.label.value = { actionText(self) }

    if not self.groups[self.name] then
        self.groups[self.name] = {}
    end
    table.insert(self.groups[self.name], self)
end

function gui.RadioButton:onClick(mon, x, y)
    if
        not self.locked and (self.mon.setTextScale and tostring(peripheral.getName(self.mon)) == tostring(mon) or tostring(self.mon) == tostring(mon))
        and x >= self.pos[1] - self.offset.left
        and x <= self.pos[1] + self.offset.right
        and y >= self.pos[2] - self.offset.up
        and y <= self.pos[2] + self.offset.down
    then
        for _, check in ipairs(gui.RadioButton.groups[self.name]) do
            if check.active == true and check.locked == true then
                return
            end
        end

        for _, check in ipairs(gui.RadioButton.groups[self.name]) do
            check.active = check.locked and check.active or false
            check.label.value = { actionText(check) }

            check:print()
        end
        self.active = true
        self.label.value = { actionText(self) }
        self:print()
        safeCall(self.func, self)
    end
end

gui.Range = createClass(gui.Base)
function gui.Range:init(mon, pos, val, align, func, owner)
    gui.Range.super.init(self, mon, pos, owner)

    self.align = align or 1

    self.locked = false
    self.func = func

    self.length = self.pos[3] - 1

    self.val = val or { 0, self.length, 0 }

    self.colors = {
        back = gui.defColor.r_back,
        used = gui.defColor.r_used,
        locked = gui.defColor.r_locked,
        dot = gui.defColor.r_dot,
    }
end

function gui.Range:print()
    if not self.visible then return end
    if self.owner then setColors(self.colors, self.owner.colors) end
    local old = term.current()
    if self.mon ~= term then term.redirect(self.mon) end
    self:setMonColor(self.colors.back, self.colors.text)

    local used = math.round((self.val[3] - self.val[1]) / (self.val[2] - self.val[1]) * self.length)
    local free = self.length - used

    local fillColor = self.locked and self.colors.locked or self.colors.used
    local backColor = self.locked and self.colors.locked or self.colors.back

    local n1, n2 = table.unpack(self.pos)
    local len = self.length
    local lineUsed, lineFree, dot

    if self.align == 1 then
        lineUsed = { n1, n2, n1 + used, n2, fillColor }
        lineFree = { n1 + used, n2, n1 + len, n2, backColor }
        dot = { n1 + used, n2, self.colors.dot }
    elseif self.align == 2 then
        lineUsed = { n1 + free, n2, n1 + len, n2, fillColor }
        lineFree = { n1, n2, n1 + free, n2, backColor }
        dot = { n1 + free, n2, self.colors.dot }
    elseif self.align == 3 then
        lineUsed = { n1, n2, n1, n2 + used, fillColor }
        lineFree = { n1, n2 + used, n1, n2 + len, backColor }
        dot = { n1, n2 + used, self.colors.dot }
    else
        lineUsed = { n1, n2 + free, n1, n2 + len, fillColor }
        lineFree = { n1, n2, n1, n2 + free, backColor }
        dot = { n1, n2 + free, self.colors.dot }
    end

    paintutils.drawLine(table.unpack(lineUsed))
    paintutils.drawLine(table.unpack(lineFree))
    paintutils.drawPixel(table.unpack(dot))

    self:setMonColor(gui.defColor.B_Back, gui.defColor.B_Text)
    term.redirect(old)
end

function gui.Range:setVal(val)
    if self.locked then return end
    if val <= self.val[1] then val = self.val[1] end
    if val >= self.val[2] then val = self.val[2] end
    self.val[3] = math.round(val)
end

function gui.Range:setMinVal(val)
    if self.locked then return end
    if val >= self.val[3] then val = self.val[3] end
    self.val[1] = val
end

function gui.Range:setMaxVal(val)
    if self.locked then return end
    if val <= self.val[3] then val = self.val[3] end
    self.val[2] = val
end

function gui.Range:onClick(mon, x, y)
    if
        not self.locked and (self.mon.setTextScale and tostring(peripheral.getName(self.mon)) == tostring(mon) or tostring(self.mon) == tostring(mon))
    then
        local n1, n2 = table.unpack(self.pos)
        local len = self.length
        if
            (self.align == 1 or self.align == 2)
            and x >= n1 and x <= n1 + len and y == n2
        then
            local percent = (x - self.pos[1]) / self.length
            if self.align == 2 then percent = 1 - percent end
            self:setVal((math.round(self.val[1] + percent * (self.val[2] - self.val[1]))))
            safeCall(self.func, self)
            self:print()
        elseif
            (self.align == 3 or self.align == 4)
            and x == n1 and y >= n2 and y <= n2 + len
        then
            local percent = (self.align == 4) and (1 - ((y - self.pos[2]) / self.length)) or
                ((y - self.pos[2]) / self.length)
            self:setVal((math.round(self.val[1] + percent * (self.val[2] - self.val[1]))))
            safeCall(self.func, self)
            self:print()
        end
    end
end

gui.TextArea = createClass(gui.Base)
function gui.TextArea:init(mon, pos, text, owner)
    gui.TextArea.super.init(self, mon, pos, owner)

    self.text = text or "qwe1213rty"
    self.type = "TextArea"
    self.func = nil

    self.size = { self.pos[3] + 1 - self.pos[1], self.pos[4] - self.pos[2] + 1 }

    if #self.text > self.size[1] * self.size[2] then
        self.text = self.text:sub(1, self.size[1] * self.size[2])
    end

    self.locked = false
    self.active = false

    self.colors = {
        back = gui.defColor.t_base_back,
        text = gui.defColor.t_base_text,
        active_back = gui.defColor.t_active_back,
        active_text = gui.defColor.t_active_text,
        locked_back = gui.defColor.t_locked_back,
        locked_text = gui.defColor.t_locked_text,
        dot = gui.defColor.t_dot,
    }
end

local function wraryChars(text, interval)
    interval    = math.max(1, math.floor(interval or 1))
    text        = text or ""
    local parts = {}
    for i = 1, #text, interval do
        parts[#parts + 1] = text:sub(i, i + interval - 1)
    end
    return parts
end

function gui.TextArea:print()
    if not self.visible then return end
    if self.owner then setColors(self.colors, self.owner.colors) end
    local old = term.current()
    if self.mon ~= term then term.redirect(self.mon) end
    self:setMonColor(table.unpack(actionColor(self)))

    local lines = wraryChars(self.text, self.size[1])

    local x1, y1, x2, y2 = table.unpack(self.pos)
    paintutils.drawFilledBox(x1, y1, x2, y2, self.colors.back)

    for i = 1, #lines do
        local lineY = y1 + i - 1
        if lineY > y2 then break end
        local fragment = lines[i]:sub(1, self.size[1])
        Write(self.mon, { x1, lineY }, fragment)
    end

    if not self.locked and self.active then
        local ci = math.min(math.max(#self.text + 1, 1), #self.text + 1)
        local width = self.size[1]
        local row = math.floor((ci - 1) / width)
        local col = (ci - 1) % width
        local cx, cy = x1 + col, y1 + row
        if cx <= x2 and cy <= y2 then
            paintutils.drawPixel(cx, cy, self.colors.dot)
        end
    end

    self:setMonColor(gui.defColor.B_Back, gui.defColor.B_Text)
    term.redirect(old)
end

function gui.TextArea:onClick(mon, x, y)
    if not self.locked and (self.mon.setTextScale and tostring(peripheral.getName(self.mon)) == tostring(mon) or tostring(self.mon) == tostring(mon))
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

function gui.TextArea:ketPress(key)
    if not self.active and not self.locked then return end

    if key == keys.backspace then
        if #self.text + self.pos[1] > 2 then
            self.text = self.text:sub(1, #self.text - 1)
            self:print()
        end
    elseif key == keys.enter then
        safeCall(self.func, self)
    elseif type(key) == "string" and #key == 1 and #self.text < self.size[1] * self.size[2] then
        self.text = self.text .. key
        self:print()
    end
end

gui.TextInput = createClass(gui.TextArea)
function gui.TextInput:init(mon, pos, text, owner)
    pos[4] = pos[2]
    gui.TextInput.super.init(self, mon, pos, text, owner)
end

-- Укороченные названия для удобства
gui.M  = gui.Manager
gui.L  = gui.Label
gui.F  = gui.Frame
gui.T  = gui.Table
gui.B  = gui.Button
gui.CB = gui.CheckBox
gui.RB = gui.RadioButton
gui.R  = gui.Range
gui.TI = gui.TextInput
gui.TA = gui.TextArea

return gui
