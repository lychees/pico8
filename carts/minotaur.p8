pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function rspr(sx,sy,x,y,a,w)
 local ca,sa=cos(a),sin(a)
 local srcx,srcy
 local ddx0,ddy0=ca,sa
 local mask=shl(0xfff8,(w-1))
 w*=4	
 ca*=w-0.5
 sa*=w-0.5 
local dx0,dy0=sa-ca+w,-ca-sa+w
 w=2*w-1
 for ix=0,w do
  srcx,srcy=dx0,dy0
  for iy=0,w do
   if band(bor(srcx,srcy),mask)==0 then
   	local c=sget(sx+srcx,sy+srcy)
   	if(c!=14) pset(x+ix,y+iy,c)
  	end
   srcx-=ddy0
  	srcy+=ddx0
  end
  dx0+=ddx0
  dy0+=ddy0
 end
end

local time_t=0
local plyr={
	x=0,y=0,
	angle=0,
	da=0,
	v=0,
	update=function(self)
		local dx,dy=cos(self.angle),sin(self.angle)
		self.x+=self.v*dx
		self.y+=self.v*dy
					
	end	
}

function _init()
 plyr.angle=0.25
 plyr.v=0.1
end

function _update60()
	time_t+=1

	plyr:update()
end

function _draw()
	cls(0)
		
	rspr(8,0,64+plyr.x,64-plyr.y,plyr.angle,1)
end

__gfx__
00000000eeeeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000e777777e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007007777dd7e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770007767dd7e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770007767dd7e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007007777dd7e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000e777777e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000eeeeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
