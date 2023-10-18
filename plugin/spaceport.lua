-- local dir = ""
local dataPath = vim.fn.stdpath("data")
local dataDir = dataPath .. "/spaceport.json"
--- Check if a file or directory exists in this path
local function exists(file)
    local ok, _, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    if ok == nil then
        return false
    end
    return ok
end

local function readData()
    if not exists(dataDir) then
        local file = io.open(dataDir, "w")
        if file == nil then
            print("Can not create file at " .. dataDir .. "")
            return {}
        end
        file:write(vim.fn.json_encode({}))
        file:close()
        return {}
    end
    local file = io.open(dataDir, "r")
    if file == nil then
        return {}
    end
    local data = file:read("*all")
    file:close()
    local ret = vim.fn.json_decode(data)
    for k, _ in pairs(ret) do
        if ret[k].pinNumber == nil then
            ret[k].pinNumber = 0
        end
        if ret[k].pinned ~= nil then
            ret[k].pinned = nil
        end
    end
    if ret == nil then
        print("Error getting spaceport data")
        return {}
    end
    return ret
end

local function writeData(data)
    local file = io.open(dataDir, "w")
    if file == nil then
        print("Can not create file at " .. dataDir .. "")
        return
    end
    file:write(vim.fn.json_encode(data))
    file:close()
end

--- Check if a directory exists in this path
local function isdir(path)
    -- "/" works on both Unix and Windows
    return exists(path .. "/")
end

local function getSeconds()
    return vim.fn.localtime()
end

local function isToday(time)
    local today = vim.fn.strftime("%Y-%m-%d")
    local t = vim.fn.strftime("%Y-%m-%d", time)
    return today == t
end

local function isYesterday(time)
    local yesterday = vim.fn.strftime("%Y-%m-%d", vim.fn.localtime() - 24 * 60 * 60)
    local t = vim.fn.strftime("%Y-%m-%d", time)
    return yesterday == t
end

local function isPastWeek(time)
    return time > getSeconds() - 7 * 24 * 60 * 60
end

local function isPastMonth(time)
    return time > getSeconds() - 30 * 24 * 60 * 60
end

-- local topSection =
--     "  ____   _____    ___    ____   ____   _____    __    ____   _____ \n" ..
--     " |  __| |  _  |  / _ \\  |  __| | ___| |  _  |  /  \\  |  _ \\ |__  _|\n" ..
--     " | |__  | |_| | | /_\\ | | |    | |_   | |_| | | /\\ | | |_| |  | |  \n" ..
--     " |__  | | ____| |  _  | | |    |  _|  | ____| | || | | __  |  | |  \n" ..
--     "  __| | | |     | | | | | |__  | |__  | |     | \\/ | | | \\ \\  | |  \n" ..
--     " |____| |_|     |_| |_| |____| |____| |_|      \\__/  |_| |_|  |_|  \n"
--

local topSection =
    "### ###  #  ### ### ### ### ###  ###\n" ..
    "#   # # # # #   #   # # # # #  #  # \n" ..
    "### ### ### #   ##  ### # # ###   # \n" ..
    "  # #   # # #   #   #   # # #  #  # \n" ..
    "### #   # # ### ### #   ### #  #  # \n"
local function addLine(lines, line, width)
    local padding = math.floor((width - #line) / 2)
    local paddingStr = string.rep(" ", padding)
    table.insert(lines, paddingStr .. line)
end
local function cd(data, pinnedData, count, rawData)
    local dir = ""
    if count <= #pinnedData then
        dir = pinnedData[count]
    else
        dir = data[count - #pinnedData]
    end
    if dir == nil then
        return
    end
    if dir.isDir then
        vim.cmd("cd " .. dir.dir)
        vim.cmd("Ex")
    else
        vim.cmd("edit " .. dir.dir)
    end
    rawData[dir.dir].time = getSeconds()
    writeData(rawData)
end

local function render(data, pinnedData, linesToDir, buf)
    local lines = {}
    -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Yo sdf", "" })
    local width = vim.o.columns
    local header = vim.fn.split(topSection, "\n")
    addLine(lines, "", width)
    -- addLine(lines, "", width)
    for _, v in pairs(header) do
        addLine(lines, v, width)
    end
    addLine(lines, "", width)
    addLine(lines, "Select project" .. string.rep(" ", 25) .. "p", width)
    addLine(lines, "Toggle pin" .. string.rep(" ", 29) .. "t", width)
    addLine(lines, "Move pin down" .. string.rep(" ", 26) .. "J", width)
    addLine(lines, "Move pin up" .. string.rep(" ", 28) .. "K", width)

    local index = 1
    local maxNameLen = 0
    for _, v in pairs(data) do
        if #v.dir > maxNameLen then
            maxNameLen = #v.dir + 10
        end
    end
    for _, v in pairs(pinnedData) do
        if #v.dir > maxNameLen then
            maxNameLen = #v.dir + 10
        end
    end
    if #pinnedData ~= 0 then
        addLine(lines, "", width)
        addLine(lines, "Pinned", width)
        for _, v in pairs(pinnedData) do
            local line = v.dir
            local indexStr = "" .. index
            linesToDir[#lines + 1] = index
            addLine(lines, line .. string.rep(" ", 0 - #line + maxNameLen + 2 - #indexStr) .. index, width)
            index = index + 1
        end
    end
    local currentTime = ""
    for _, v in pairs(data) do
        if isToday(v.time) then
            if currentTime ~= "Today" then
                currentTime = "Today"
                addLine(lines, "", width)
                addLine(lines, currentTime, width)
            end
        elseif isYesterday(v.time) then
            if currentTime ~= "Yesterday" then
                currentTime = "Yesterday"
                addLine(lines, "", width)
                addLine(lines, currentTime, width)
            end
        elseif isPastWeek(v.time) then
            if currentTime ~= "Past Week" then
                currentTime = "Past Week"
                addLine(lines, "", width)
                addLine(lines, currentTime, width)
            end
        elseif isPastMonth(v.time) then
            if currentTime ~= "Past Month" then
                currentTime = "Past Month"
                addLine(lines, "", width)
                addLine(lines, currentTime, width)
            end
        else
            if currentTime ~= "A long time ago" then
                currentTime = "A long time ago"
                addLine(lines, "", width)
                addLine(lines, currentTime, width)
            end
        end
        local line = v.dir
        local indexStr = "" .. index
        linesToDir[#lines + 1] = index
        addLine(lines, line .. string.rep(" ", 0 - #line + maxNameLen + 2 - #indexStr) .. index, width)
        index = index + 1
    end
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function remap(data, pinnedData, linesToDir, rawData, buf)
    vim.keymap.set("n", "J", function()
        local line = vim.fn.line('.')
        local count = linesToDir[line]
        if count == nil or count == 0 then
            return
        end
        if count > #pinnedData then
            return
        end
        local inc = vim.v.count
        if inc == nil or inc == 0 then
            inc = 1
        end
        local startNumber = pinnedData[count].pinNumber + 0
        pinnedData[count].pinNumber = pinnedData[count].pinNumber + inc
        rawData[pinnedData[count].dir].pinNumber = pinnedData[count].pinNumber
        if pinnedData[count].pinNumber > #pinnedData then
            pinnedData[count].pinNumber = #pinnedData
            rawData[pinnedData[count].dir].pinNumber = pinnedData[count].pinNumber
        end
        for _, v in pairs(pinnedData) do
            if v.pinNumber >= startNumber and v.pinNumber <= pinnedData[count].pinNumber and v.dir ~= pinnedData[count].dir then
                rawData[v.dir].pinNumber = v.pinNumber - 1
                v.pinNumber = v.pinNumber - 1
            end
        end
        table.sort(pinnedData, function(a, b)
            return a.pinNumber < b.pinNumber
        end)
        writeData(rawData)
        render(data, pinnedData, linesToDir, buf)
    end)
    vim.keymap.set("n", "K", function()
        local line = vim.fn.line('.')
        local count = linesToDir[line]
        if count == nil or count == 0 then
            return
        end
        if count > #pinnedData then
            return
        end
        local inc = vim.v.count
        if inc == nil or inc == 0 then
            inc = 1
        end
        local startNumber = pinnedData[count].pinNumber + 0
        pinnedData[count].pinNumber = pinnedData[count].pinNumber - inc
        rawData[pinnedData[count].dir].pinNumber = pinnedData[count].pinNumber
        if pinnedData[count].pinNumber < 1 then
            pinnedData[count].pinNumber = 1
            rawData[pinnedData[count].dir].pinNumber = pinnedData[count].pinNumber
        end
        for _, v in pairs(pinnedData) do
            if v.pinNumber <= startNumber and v.pinNumber >= pinnedData[count].pinNumber and v.dir ~= pinnedData[count].dir then
                rawData[v.dir].pinNumber = v.pinNumber + 1
                v.pinNumber = v.pinNumber + 1
            end
        end
        table.sort(pinnedData, function(a, b)
            return a.pinNumber < b.pinNumber
        end)
        writeData(rawData)
        render(data, pinnedData, linesToDir, buf)
    end)
    vim.keymap.set("n", "t", function()
        local count = vim.v.count
        if count == 0 then
            local line = vim.fn.line('.')
            count = linesToDir[line]
            print(count)
        end
        if count == nil or count == 0 then
            count = 1
        end
        if count <= #pinnedData then
            local pinNumber = pinnedData[count].pinNumber
            rawData[pinnedData[count].dir].pinNumber = 0
            table.insert(data, pinnedData[count])
            table.remove(pinnedData, count)
            table.sort(data, function(a, b)
                return a.time > b.time
            end)
            for _, v in pairs(pinnedData) do
                if v.pinNumber > pinNumber then
                    rawData[v.dir].pinNumber = v.pinNumber - 1
                end
            end
            writeData(rawData)
        else
            local maxPinNumber = 0
            for _, v in pairs(pinnedData) do
                if v.pinNumber > maxPinNumber then
                    maxPinNumber = v.pinNumber
                end
            end
            rawData[data[count - #pinnedData].dir].pinNumber = maxPinNumber + 1
            table.insert(pinnedData, data[count - #pinnedData])
            table.remove(data, count - #pinnedData + 1)
            writeData(rawData)
        end
        linesToDir = {}
        render(data, pinnedData, linesToDir, buf)
    end, {
        buffer = buf,
    })
    vim.keymap.set("n", "p", function()
        local count = vim.v.count
        if count == nil or count == 0 then
            local line = vim.fn.line('.')
            count = linesToDir[line]
        end
        cd(data, pinnedData, count, rawData)
    end, {
        buffer = buf,
    })
end
vim.api.nvim_create_autocmd({ "UiEnter" }, {
    callback = function()
        if vim.fn.argc() == 0 then
            local linesToDir = {}
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
            vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
            vim.api.nvim_buf_set_option(buf, "swapfile", false)
            -- vim.api.nvim_buf_set_option(buf, "number", false)
            vim.api.nvim_set_current_buf(buf)
            vim.cmd("setlocal norelativenumber nonumber")
            local rawData = readData()
            if rawData == nil then
                return
            end
            local data = {}
            local pinnedData = {}
            for k, v in pairs(rawData) do
                local insert = {
                    dir = k,
                    time = v.time,
                    isDir = v.isDir,
                    pinNumber = v.pinNumber,
                }
                if v.pinNumber == 0 then
                    table.insert(data, insert)
                else
                    table.insert(pinnedData, insert)
                end
            end
            table.sort(data, function(a, b)
                return a.time > b.time
            end)

            table.sort(pinnedData, function(a, b)
                return a.pinNumber < b.pinNumber
            end)

            remap(data, pinnedData, linesToDir, rawData, buf)
            render(data, pinnedData, linesToDir, buf)
        elseif vim.fn.argc() > 0 then
            -- dir = vim.fn.argv()[1]
            local data = readData()
            local time = getSeconds()
            local argv = vim.fn.argv() or {}
            if type(argv) == "string" then
                argv = { argv }
            end
            for _, v in pairs(argv) do
                local isDir = isdir(v)
                if not isdir(v) then
                    v = vim.fn.fnamemodify(v, ":p") or ""
                end
                if data[v] == nil then
                    data[v] = {
                        time = time,
                        isDir = isDir,
                    }
                else
                    data[v].time = time
                    data[v].isDir = isDir
                end
            end
            writeData(data)
        end
    end
})
