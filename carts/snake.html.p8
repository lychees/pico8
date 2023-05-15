pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- global
game_over = false
-- snake
body_x = {16}
body_y = {16}
body_d = 20
dir = 2
dx = {-1, 1, 0, 0}
dy = {0, 0, -1, 1}
map = {}

function _init()
    for i = 1, 127 do 
        map[i] = {}
    end
    map[body_x[1]][body_y[1]] = 1
end

function is_dead()
    n = #body_x
    x = body_x[n]
    y = body_y[n]
    if x < 0 or y < 0 or x > 127 or y > 127 then 
        return true
    end

    if map[x][y] == 1 then 
        return true
    end

    return false
end

function _update()
    if game_over then 
        return
    end
    if btnp(0) and dir != 2 then 
        dir = 1
    elseif btnp(1) and dir != 1 then 
        dir = 2
    elseif btnp(2) and dir != 3 then 
        dir = 3
    elseif btnp(3) and dir != 4 then
        dir = 4
    end
    n = #body_x
    if body_d > 0 then 
        body_x[n+1] = body_x[n] + dx[dir] 
        body_y[n+1] = body_y[n] + dy[dir]
        body_d -= 1
    else
        map[body_x[1]][body_y[1]] = 0
        for i = 1, n-1 do 
            body_x[i] = body_x[i+1]
            body_y[i] = body_y[i+1]
        end 
        body_x[n] += dx[dir] 
        body_y[n] += dy[dir]
    end
    n = #body_x
    if is_dead() then 
        game_over = true
        return
    end
    map[body_x[n]][body_y[n]] = 1
end

function _draw()
    if game_over then 
        print("game over", 60, 62, 8)
        return
    end
    cls()
    n = #body_x
    rect(0, 0, 127, 127, 7)
    for i = 1, n do 
        rectfill(body_x[i], body_y[i], body_x[i], body_y[i], 3)
    end
end
