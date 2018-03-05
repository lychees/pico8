pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- simplex noise example
-- by anthony digirolamo

local perms = {
   151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
   140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
   247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
   57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68,   175,
   74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111,   229, 122,
   60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
   65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
   200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
   52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
   207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
   119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
   129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
   218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
   81,   51, 145, 235, 249, 14, 239,   107, 49, 192, 214, 31, 181, 199, 106, 157,
   184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
   222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}

-- make perms 0 indexed
for i = 0, 255 do
   perms[i]=perms[i+1]
end
-- perms[256]=nil

-- the above, mod 12 for each element --
local perms12 = {}

for i = 0, 255 do
   local x = perms[i] % 12
   perms[i + 256], perms12[i], perms12[i + 256] = perms[i], x, x
end

-- gradients for 2d, 3d case --
local grads3 = {
   { 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 },
   { 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 },
   { 0, 1, 1 }, { 0, -1, 1 }, { 0, 1, -1 }, { 0, -1, -1 }
}

for row in all(grads3) do
   for i=0,2 do
      row[i]=row[i+1]
   end
   -- row[3]=nil
end

for i=0,11 do
   grads3[i]=grads3[i+1]
end
-- grads3[12]=nil

function getn2d (bx, by, x, y)
   local t = .5 - x * x - y * y
   local index = perms12[bx + perms[by]]
   return max(0, (t * t) * (t * t)) * (grads3[index][0] * x + grads3[index][1] * y)
end

---
-- @param x
-- @param y
-- @return noise value in the range [-1, +1]
function simplex2d (x, y)
   -- 2d skew factors:
   -- f = (math.sqrt(3) - 1) / 2
   -- g = (3 - math.sqrt(3)) / 6
   -- g2 = 2 * g - 1
   -- skew the input space to determine which simplex cell we are in.
   local s = (x + y) * 0.366025403 -- f
   local ix, iy = flr(x + s), flr(y + s)
   -- unskew the cell origin back to (x, y) space.
   local t = (ix + iy) * 0.211324865 -- g
   local x0 = x + t - ix
   local y0 = y + t - iy
   -- calculate the contribution from the two fixed corners.
   -- a step of (1,0) in (i,j) means a step of (1-g,-g) in (x,y), and
   -- a step of (0,1) in (i,j) means a step of (-g,1-g) in (x,y).
   ix, iy = band(ix, 255), band(iy, 255)
   local n0 = getn2d(ix, iy, x0, y0)
   local n2 = getn2d(ix + 1, iy + 1, x0 - 0.577350270, y0 - 0.577350270) -- g2
   -- determine other corner based on simplex (equilateral triangle) we are in:
   -- if x0 > y0 then
   --    ix, x1 = ix + 1, x1 - 1
   -- else
   --    iy, y1 = iy + 1, y1 - 1
   -- end
   -- local xi = shr(flr(y0 - x0), 31) -- x0 >= y0
   local xi = 0
   if x0 >= y0 then xi = 1 end
   local n1 = getn2d(ix + xi, iy + (1 - xi), x0 + 0.211324865 - xi, y0 - 0.788675135 + xi) -- x0 + g - xi, y0 + g - (1 - xi)
   -- add contributions from each corner to get the final noise value.
   -- the result is scaled to return values in the interval [-1,1].
   return 70 * (n0 + n1 + n2)
end

-- main

function smoothstep(t)
	t=mid(t,0,1)
	return t*t*(3-2*t)
end


local isdirty=true
local plyr={
	x=0,
	y=0}
local clouds={}
local cache={}
function _init()
		grayvid()
  local noisedx = rnd(32)
  local noisedy = rnd(32)
  for x=0,127 do
    for y=0,127 do
      local octaves = 5
      local freq = .007
      local max_amp = 0
      local amp = 1
      local value = 0
      local persistance = .65
      for n=1,octaves do

        value = value + simplex2d(noisedx + freq * x,
                                  noisedy + freq * y)
        max_amp += amp
        amp *= persistance
        freq *= 2
      end
      value /= max_amp
      value=mid(value+1,0,2)/2
      add(clouds,value)
    end
  end
  
	for x=0,127 do
  for y=0,127 do
  	add(cache,flags(x,y))
  end
 end
end


--local dither={0,1,5,6,7}
local dither={
  0b1111111111111111,
  0b0111111111111111,
  0b0111111111011111,
  0b0101111111011111,
  0b0101111101011111,
  0b0101101101011111,
  0b0101101101011110,
  0b0101101001011110,
  0b0101101001011010,
  0b0001101001011010,
  0b0001101001001010,
  0b0000101001001010,
  0b0000101000001010,
  0b0000001000001010,
  0b0000001000001000,
  0b0000000000000000
}
function solid(i,j)
	-- wrap around
	i%=128
	j%=128
	if(i<0) i+=128
	if(j<0) j+=128
	return clouds[i+128*j+1]>0.7 and 1 or 0
end

function flags(i,j)
	return
		solid(i,j)+
		shl(solid(i+1,j),1)+
		shl(solid(i+1,j+1),2)+
		shl(solid(i,j+1),3)
end

function flags_cache(i,j)
	-- wrap around
	i%=128
	j%=128
	if(i<0) i+=128
	if(j<0) j+=128
	return cache[i+128*j+1]
end

local ramp={[0]=7,7,7,7,7,6,6,6,13,13,13,5,5,1,1,0}
function grayvid()
	for i=0,15 do
		pal(i,i,0)
		pal(i,ramp[i],1)
	 palt(i,false)
	end
end
function normvid()
	for i=0,15 do
		pal(i,i,0)
		pal(i,i,1)
		palt(i,false)
	end
end
function aaline(x0,y0,x1,y1)
	local w,h=abs(x1-x0),abs(y1-y0)
	
	-- to calculate dist properly,
	-- do this, but we'll use an
	-- approximation below instead.
 -- local d=sqrt(w*w+h*h)
 
 if h>w then
 	-- order points on y
 	if y0>y1 then
 		x0,y0,x1,y1=x1,y1,x0,y0
 	end
 
 	local dx=x1-x0
 	
 	-- apply the bias to the 
 	-- line's endpoints:
 	y0+=0.5
 	y1+=0.5
 
 	--x0+=0.5 --nixed by -0.5 in loop
 	--x1+=0.5 --don't need x1 anymore

		-- account for diagonal thickness
		-- thanks to freds72 for neat trick from https://oroboro.com/fast-approximate-distance/
  -- 	local k=h/d
		local k=h/(h*0.9609+w*0.3984)
		 	
 	for y=flr(y0)+0.5-y0,flr(y1)+0.5-y0 do	
 		local x=x0+dx*y/h
 		-- originally flr(x-0.5)+0.5
 		-- but now we don't x0+=0.5 so not needed
 		local px=flr(x)
 		pset(px,  y0+y,pget(px,  y0+y)*k*(x-px  ))
 		pset(px+1,y0+y,pget(px+1,y0+y)*k*(px-x+1))
 	end
 elseif w>0 then
 	-- order points on x
 	if x0>x1 then
 		x0,y0,x1,y1=x1,y1,x0,y0
 	end
 
 	local dy=y1-y0
 	
 	-- apply the bias to the 
 	-- line's endpoints:
 	x0+=0.5
 	x1+=0.5
 
 	--y0+=0.5 --nixed by -0.5 in loop
 	--y1+=0.5 --don't need y1 anymore
	
		-- account for diagonal thickness
		-- thanks to freds72 for neat trick from https://oroboro.com/fast-approximate-distance/
  -- local k=w/d
		local k=w/(w*0.9609+h*0.3984)

 	for x=flr(x0)+0.5-x0,flr(x1)+0.5-x0 do	
 		local y=y0+dy*x/w
 		-- originally flr(y-0.5)+0.5
 		-- but now we don't y0+=0.5 so not needed
 		local py=flr(y)
 		pset(x0+x,py,  pget(x0+x,py  )*k*(y-py  ))
 		pset(x0+x,py+1,pget(x0+x,py+1)*k*(py-y+1))
 	end
	end
end

local cam_x,cam_y,cam_z
function cam_track(x,y,z)
	cam_x,cam_y,cam_z=x,y,z
end

local cam_cb,cam_sb=-1,0--cos(0.6),sin(0.6)
local cam_focal=128
function cam_project(x,y,z)
	local y=y-cam_y
	local z=z-cam_z
	local ze=-(y*cam_cb+z*cam_sb)
	-- invalid projection?
	--if(ze<cam_zfar or ze>=0) return nil,nil,z,nil
	--if(ze<cam_zfar) printh("too far") return nil,nil,z,nil
	if(ze>=0) printh("too close") return nil,nil,z,nil
	
	local w=-cam_focal/ze
	local xe=x-cam_x
	local ye=-y*cam_sb+z*cam_cb
	return 64+xe*w,64-ye*w,ze,w
end

function draw_ground(self)
	color(7)
	local scale=2
	local dx,dy=cam_x%scale,cam_y%scale
 local i0,j0=flr(cam_x/scale),flr(cam_y/scale)
	local i=i0
	for ii=-16,16,scale do
 	local j=j0
 	local cx=(i%128+128)%128
 	for jj=-56,-24,scale do
 		local cy=(j%128+128)%128
			local f=8*clouds[cx+128*cy+1]
			local x,y=cam_project(ii-dx+cam_x,jj-dy+cam_y,f)
			pset(x,y)
			j+=1
		end
		i+=1
 end
end

local time_t=0
function _update60()
	time_t+=1
	if(btn(0)) plyr.x-=0.1
	if(btn(1)) plyr.x+=0.1
	if(btn(2)) plyr.y-=0.1
	if(btn(3)) plyr.y+=0.1
	
	--cam_cb,cam_sb=cos(plyr.y/10),sin(plyr.y/10)
	cam_track(plyr.x,12+plyr.y,-8)
end

function _draw()
	cls(15)
	draw_ground({})	
	
	local pts={
		{0,0,0},
		{0,5,0},
		{5,5,0},
		{5,0,0}}
	local x0,y0=cam_project(pts[1][1],pts[1][2],pts[1][3])
	for i=1,#pts do
		local k=(i%#pts)+1
		local x1,y1=cam_project(pts[k][1],pts[k][2],pts[k][3])
		line(x0,y0,x1,y1,7)
		x0,y0=x1,y1
	end
	
	rectfill(0,0,127,8,1)
 print("mem:"..stat(0).." cpu:"..stat(1).."("..stat(7)..")",2,2,7)
	print(plyr.x.."/"..plyr.y,2,12,7)
end

__gfx__
0000000000000000000000000000000000dddddd0000dddd0000dddd0000ddddddddd000dddd0000dddd0000dddd0000dddddddddddddddddddddddddddddddd
00000000000000000000000000000000000ddddd00000ddd0000dddd000ddddddddd0000dddd0000ddd00000ddddd000dddddddddddddddddddddddddddddddd
00000000d00000000000000d000000000000dddd000000dd0000dddd00ddddddddd00000dddd0000dd000000dddddd00dddddddddddddddddddddddddddddddd
00000000dd000000000000dd0000000000000ddd0000000d0000dddd0ddddddddd000000dddd0000d0000000ddddddd0dddddddddddddddddddddddddddddddd
00000000ddd0000000000ddddddddddd000000ddd00000000000ddddddddddddd0000000dddd00000000000ddddddddd00000000ddddddd00ddddddddddddddd
00000000dddd00000000dddddddddddd0000000ddd0000000000dddddddddddd00000000dddd0000000000dddddddddd00000000dddddd0000dddddddddddddd
00000000ddddd000000ddddddddddddd00000000ddd000000000dddddddddddd00000000dddd000000000ddddddddddd00000000ddddd000000ddddddddddddd
00000000dddddd0000dddddddddddddd00000000dddd00000000dddddddddddd00000000dddd00000000dddddddddddd00000000dddd00000000dddddddddddd
