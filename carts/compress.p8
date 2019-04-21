pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
function _init()
 cls()
 
 -- sample image
 circfill(32,32,16,7)
 
 -- clear gfx data
 memset(0x0,0,128*128)
 
 -- compress to gfx
 comp(0,0,64,64,0x0,pget)
 
 -- display back from gfx
 decomp(0x0,0,64,sget,pset)
 
 local t=0
 repeat
  print("press ❎",67,2,t%4>2 and 8 or 10)
  flip()
  t+=1
 until btn(❎)
 
end
-->8
-- px8 by zep
-- gfx,sfx,map compression

-- compression parameters
p={}
p.cbits  = 4  -- max:7
p.remap = false

-----------------------------
-- decompression
-----------------------------

function remap(i,w,h)
 local sx=flr((i/64)%(w/8))
 local sy=flr((i/64)/(w/8))
 local x=(i%8)
 local y=flr(flr(i%64)/8)
 return (sx*8+x)+(sy*8+y)*w
end


function decomp(src, px,py,xget,xset)

 local pn={}
 src-=1 
 local bit=256
 local b=0
 
 function getval(bits)
  val=0
  for i=0,bits-1 do

   --get next bit from stream
   if (bit==256) then
    bit=1
    src+=1
    byte=peek(src)
   end
   if band(byte,bit)>0 then
    val+=shl(1,i)
   end
   bit*=2
   
  end
  return val
 end
 
 -- read header
 
 local w = getval(8)
 local h = getval(8)
 local cbits = getval(3)
 local rmp = getval(1) 
 local maxci = getval(8)
 local bpp = getval(3)+1
 local clist={}
 for i=0,maxci do
  clist[i]=getval(bpp)
 end
 
 -- spans
 
 local i = 0
 local span = 0
 
 while (i < w*h) do

  -- span length 
  local bl = 1
  while getval(1)==0 do
   bl += 1 end
  
  local minv=shl(1,bl-1)
  if (bl==1) minv=0
  
  local len=
   getval(max(1,bl-1))+minv+1

  for j=0,len-1 do
  
   local i1 = i
   
   if (rmp==1) i1=remap(i,w,h)
   
   x = px+(i1)%w
   y = py+flr(i1/w)
   
   -- predict colour
   
   local t=xget(x+0,y-1)/16
   local l=xget(x-1,y+0)*16
   if (y==py) t=0
   if (x==px) l=0
   
   pc=pn[t+l] or pn[t] or pn[l]
   
   if (span%2 == 0) then
    -- raw literal
    
    local index=0
    
    repeat
     v=getval(cbits)
     index += v
    until (v < shl(1,cbits)-1)
    
    local pindex=999
    for i=0,maxci do
     if (pc==clist[i]) pindex=i
    end
    
    if (pindex <= index) index+=1
    
    col = clist[index]
    
    -- move to front
    for i=index,1,-1 do
     clist[i]=clist[i-1]
    end
    clist[0] = col
    
   else
    -- predicted

    col = pc
    
   end
   
   xset(x,y,col)
      
   -- adjust predictions
   
   pn[t]=col
   pn[l]=col
   pn[t+l]=col
   
   i += 1
  end
  span += 1
  
 end
 

end


-----------------------------
-- compression
-----------------------------

function comp(x0,y0,w,h,dest,xget)

 local dest0 = dest
 local pn={}
 local dat={}
 local dat2={}
 local i=0
 
 local byte=0
 local bit=1
 
 function putbit(bval)
  if (bval) byte+=bit
  poke(dest, byte)
  bit*=2
  if (bit==256) then
   bit=1 byte=0
   dest += 1			
  end
 end
 
 function putval(val, bits)
  if (bits == 0) return
  for i=0,bits-1 do
   putbit(band(val,shl(1,i))>0)
  end
 end
 
 function putsplen(len)
  -- how many bits?
  blen=1				
  while (shl(1,blen) <= len) 
   do blen+=1 end
  putval(0,(blen-1))
  putval(1,1)
  
  minv=shl(1,blen-1)
  if (blen==1) minv=0
  			
  putval(len-minv,
   max(1,blen-1))
 
 end
 
 -- 1. generate list of
 -- colour values and predictions
 
 for i=0,w*h-1 do
 
   i1=i
   if (p.remap) i1=remap(i,w,h)
   
   x = x0+(i1%w)
   y = y0+flr(i1/w)
   
   local t=xget(x+0,y-1)/16
   local l=xget(x-1,y+0)*16
   if (y==y0) t=0
   if (x==x0) l=0
   c = xget(x,y)
   
   -- predict
   
   pc=nil

   if (pc==nil) pc=pn[t+l]
   if (pc==nil) pc=pn[t]
   if (pc==nil) pc=pn[l]
  
   -- first value never predicted
   if (i==0) pc=nil
     	
  	-- if could predict, set
  	-- flag 0x100
  	
  	if (pc == c) then
  	 dat[i] = c + 0x100
  	else
  	 dat[i] = c
  	end
  	
  	-- store prediction
  	dat2[i] = pc
  	
  	-- add predictions
   
   pn[t]=c
   pn[l]=c
   pn[t+l]=c
  
 end
 
 -- 3. starting indexes
 
 
 -- 3.1 write header
 
 putval(w,8)
 putval(h,8)
 putval(p.cbits,3)  
 
 if (p.remap) then
  putval(1,1)
 else
  putval(0,1)
 end
 
 
 -- 3.2 starting colour list
 -- (in order encountered)
 local clist={}
 local found={}
 local cols=0
 
 local maxcol=0
 
 for i=0,w*h-1 do
  local i1 = remap(i, w,h)
  local x = x0+(i1%w)
  local y = y0+flr(i1/w)
  local col=xget(x,y)
  if (not found[col]) then
   clist[cols]=col
   found[col]=true
   cols+=1
   maxcol=max(maxcol,col)
  end
 end
 
 -- calc bpp needed to store
 -- maxcol
 
 local bpp=1
 while (shl(1,bpp) <= maxcol) do
  bpp += 1
 end
 
 -- write colour list
 
 putval(cols-1,8) -- max 256
 putval(bpp-1,3) -- max 8
 for i=0,cols-1 do
  putval(clist[i],bpp)
 end
 
 -- 3.3 write spans
 
 len = w*h
 pos = 0
 
 p.spans=0
 p.indexes=0
 
 while (pos < len) do
  p.spans+=1
  
  -- calculate length of span
  
  slen=0 p2=pos
  
  if (dat[pos] >= 0x100) then
  
   -- span of predictions
   -- every item must be correct
   -- prediction
   
   while (p2 < len and
          dat[p2] >= 0x100) do
    p2 += 1
   end
   
   slen = p2-pos
  
  else
  
   -- span of non-predicted
   -- colour list indexes
   
   while (
          p2 < len and
          (
           dat[p2] < 0x100 or
           p2 == len-1 
          )) do
    p2 += 1
   end
   
   slen = p2-pos
   
  end
  
  		
  -- write span length
  putsplen(slen-1)
  
  				
  if (dat[pos] < 0x100) then
  
   -- span of colour indices
   
   for j=0,slen-1 do
   
    local col=dat[pos+j]%256
    local pcol=dat2[pos+j]
    
    -- find position in clist
    local index
    local pindex=100
    for i=0,cols-1 do
     if(clist[i]==col) index=i
     if(clist[i]==pcol) pindex=i
    end
    
    -- move to front
    for i=index,1,-1 do
     clist[i]=clist[i-1]
    end
    clist[0]=col
    
    -- if predicted colour
    -- was earlier in list, can
    -- subtract one
    
    if (pindex < index) index-=1
    
    -- write the index	
    
    v=index -- amount to write
    
    local maxval=shl(1,p.cbits)-1
    
    while(v>=0) do
     w=min(maxval, v)
     putval(w, p.cbits)
     v -= maxval
    end
    
    p.indexes += 1
   end
   
  end
  
  pos += slen
 end
 
 return dest-dest0 + 1

end

__gfx__
04044102c3000e6010b004a300a200fd008e004610c800c43004a004310cb004f108420891082208b108e3001400b300d700af00a700f300d700af004f108e30
0d700af006f000b7008e3004e004f10cf100ee00028100a600681006e000e8100ad00029100a500691006d0002a10024002b100d3008e60045002d1084000a67
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000aaa0aaa0aaa00aa00aa000000aaaaa0000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000a0a0a0a0a000a000a0000000aa0a0aa000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000aaa0aa00aa00aaa0aaa00000aaa0aaa000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000a000a0a0a00000a000a00000aa0a0aa000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000a000a0a0aaa0aa00aa0000000aaaaa0000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000077777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000077777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000077777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000077777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000077777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000077777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000077777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000077777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000700000000000077777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777707777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000070000000000000000000000777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777000000000000000000000000077777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000077777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777000000000000000000000000000000077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777770000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777770777777777777777777777777777777707777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777077777777777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777077777777777777777777777777777077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777707777777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000070000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000700000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000700000000000000000000000077777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777077777777777777777777777077777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777077777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000070000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000700000000000077777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777077777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

