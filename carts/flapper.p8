pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

bird = {}
stage = {}

grav = 0.4
boost = 4

level = 1
speed = 3
gap = 80

stage.highscore=0

function newtube()
    local tube={}
    tube.x=180
    tube.gap = gap
    tube.y=rnd(128-stage.floorheight-tube.gap)
    tube.width=20
    tube.speed = speed
    tube.passed = false
    return tube
end
 
function _init()
    bird.x=40
    bird.y=40
    bird.w=10
    bird.h=10
    bird.v=0
    stage.floorheight=10
    stage.tubes={}
    stage.tubetime = 10
    stage.tminus = 0
    stage.score = 0
    stage.level = 1
    speed = 11
    gap = 50
    stage.running = false
end

function _update()
    if(stage.running) then
        for k,v in pairs(stage.tubes) do
            if(not(bird.x > v.x+v.width or bird.x+bird.w < v.x)) and not(bird.y>v.y and bird.y+bird.h < v.y+v.gap) then
                die() end
            end

        -- spawn tube
        if(stage.tminus <= 0) then
            add(stage.tubes, newtube())
            stage.tminus=stage.tubetime
            else stage.tminus-=1 end

        -- jump
        if btnp(4) or btnp(5) then
            bird.v = -boost
            sfx(0)
        end

        -- grav
        if bird.v < 5 then
            bird.v += grav
        end

        -- level up, max to 5, decrease gap and increase speed
        if not (stage.level > 5) and stage.level < stage.score / 5 then
            stage.level += 1
            gap -= 6
            speed += 0.3
        end

        -- fall
        if bird.y+bird.h> 128-stage.floorheight then die() end

        -- goes up and down
        bird.y += bird.v

        -- move tubes
        for k,v in pairs(stage.tubes) do
            if v.x < bird.x+bird.w and not v.passed then
                stage.score+=1
                v.passed = true
                sfx(1)
            end
            v.x -= v.speed
            if v.x < -v.width then v=nil end
        end
    else
        if stage.score > stage.highscore then
            stage.highscore = stage.score
        end
        if btnp(4) or btnp(5) then
            _init()
            stage.running=true
        end
    end
end

function _draw()
    if(stage.running) then
        cls(12)
        -- draw floor
        rectfill(0,128,128,128-stage.floorheight,15)
        -- draw bird
        rectfill(bird.x, bird.y, bird.x+bird.w, bird.y+bird.h,10)
        -- draw tubes
        for k,v in pairs(stage.tubes) do
            rectfill(v.x,127-stage.floorheight,v.x+v.width, v.y+v.gap,11)
            rectfill(v.x,0,v.x+v.width,v.y,11)
        end
        -- draw score
        print(stage.score, 30, 5, 7)
    else
        title()
    end
end

function title()
    cls()
    print("flappy", 44, 30, 9)
    print("bird",   68, 30, 10)
    print("last score: " .. stage.score,     36, 54, 6)
    print("high score: " .. stage.highscore, 36, 60, 7)
    print("use z or x", 28, 72, 10)
    print("to flaps the bird", 28, 78, 11)
    print("and starts game", 28, 88, 12)
end

function die()
    stage.running=false
    sfx(2)
end
