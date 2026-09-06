local minimum_total = nil
local maximum_total = 0
local minimum_block = nil
local maximum_block = 0
local average_total = nil
local average_block = nil

local function kb(bytes)
    return math.floor(bytes / 1024)
end

local function reset(total, block)
    minimum_total = total
    maximum_total = total
    minimum_block = block
    maximum_block = block
    average_total = total
    average_block = block
end

function draw()
    local total, block = system.free_memory()

    if not minimum_total or input.pressed("SELECT") then
        reset(total, block)
    else
        minimum_total = math.min(minimum_total, total)
        maximum_total = math.max(maximum_total, total)
        minimum_block = math.min(minimum_block, block)
        maximum_block = math.max(maximum_block, block)
        average_total = average_total * 0.95 + total * 0.05
        average_block = average_block * 0.95 + block * 0.05
    end

    overlay.rect(8, 8, 246, 105, 4, 7, 12, 215)
    overlay.rect(8, 8, 246, 3, 65, 210, 255, 255)
    overlay.text("PSP MEMORY MONITOR", 18, 18, 1, 100, 220, 255, 255)
    overlay.text(string.format("FREE TOTAL: %d KB", kb(total)), 18, 37, 1, 240, 240, 240, 255)
    overlay.text(string.format("MAX BLOCK:  %d KB", kb(block)), 18, 52, 1, 255, 220, 100, 255)
    overlay.text(string.format("AVERAGE:    %d/%d KB", kb(average_total), kb(average_block)), 18, 67, 1, 190, 200, 215, 255)
    overlay.text(string.format("RANGE: %d-%d/%d-%d", kb(minimum_total), kb(maximum_total), kb(minimum_block), kb(maximum_block)), 18, 82, 1, 190, 200, 215, 255)
    overlay.text("SELECT: RESET", 18, 98, 1, 150, 165, 185, 255)
end
