-- 왕국의 황동 지도 프레임·가죽 가방·지도 표식을 Aseprite 원본과 PNG로 만든다.
local src=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local repo=src:match('^(.*)/tools/[^/]+$') or '.'
local pc=app.pixelColor
local function c(h) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local ink=c('101c27');local dark=c('273c49');local steel=c('647c84');local gold=c('bb985c');local pale=c('ead19a');local leather=c('78583d');local light=c('ad8052')
local s=Sprite(256,128,ColorMode.RGB);s.layers[1].name='지도 프레임·황동 장식';local im=Image(256,128,ColorMode.RGB)
local function rect(x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do if xx>=0 and yy>=0 and xx<256 and yy<128 then im:drawPixel(xx,yy,col) end end end end
local function box(x,y,w,h,col) rect(x,y,w,1,col);rect(x,y+h-1,w,1,col);rect(x,y,1,h,col);rect(x+w-1,y,1,h,col) end
local function line(x,y,xx,yy,col) local n=math.max(math.abs(xx-x),math.abs(yy-y),1);for i=0,n do rect(math.floor(x+(xx-x)*i/n+.5),math.floor(y+(yy-y)*i/n+.5),1,1,col) end end
rect(2,2,92,108,ink);box(1,1,94,110,ink);box(2,2,92,108,steel);box(3,3,90,106,gold);box(4,4,88,104,dark)
-- 빈 지도 영역은 게임이 실시간 탐험 텍스처로 채운다.
rect(5,5,86,14,dark);rect(5,99,86,8,dark);box(6,18,84,84,ink);box(7,19,82,82,gold)
for _,p in ipairs({{2,2},{86,2},{2,102},{86,102}}) do local x,y=p[1],p[2];rect(x,y,8,8,ink);box(x+1,y+1,6,6,gold);rect(x+3,y+3,2,2,pale) end
line(20,11,84,11,steel);line(20,12,84,12,ink);rect(37,9,22,5,dark)
-- 북쪽을 향한 작은 나침반.
line(11,5,11,16,pale);line(6,11,16,11,gold);line(11,5,8,10,pale);line(11,5,14,10,pale);rect(10,10,3,3,pale)
for state=0,2 do local x=96+state*48;local accent=state==2 and c('db7559') or state==1 and c('dfb867') or c('94b99a')
 rect(x+17,4,14,3,ink);rect(x+15,7,4,12,ink);rect(x+29,7,4,12,ink);rect(x+18,7,12,3,light)
 rect(x+9,14,30,42,ink);rect(x+7,21,34,28,ink);rect(x+10,16,28,38,leather);rect(x+12,17,24,35,light)
 rect(x+7,25,5,21,dark);rect(x+36,25,5,21,dark);rect(x+8,27,3,15,leather);rect(x+37,27,3,15,leather)
 rect(x+12,14,24,15,ink);rect(x+13,15,22,12,leather);line(x+15,16,x+32,16,pale);rect(x+14,26,20,3,light)
 rect(x+20,15,8,18,ink);rect(x+22,16,4,14,gold);box(x+20,25,8,7,pale);rect(x+23,26,2,5,ink)
 rect(x+11,35,26,16,ink);rect(x+12,36,24,14,dark);box(x+12,36,24,14,accent);rect(x+14,38,20,3,steel);rect(x+14,42,20,6,ink)
 for yy=32,52,5 do rect(x+13,yy,1,2,pale);rect(x+34,yy,1,2,pale) end
 rect(x+11,54,26,3,ink);rect(x+13,54,22,1,gold)
 if state==2 then rect(x+35,5,8,10,ink);rect(x+38,7,2,4,accent);rect(x+38,13,2,1,pale) end
end
-- 성·플레이어·침공·순간이동 탑·핑·북쪽. 16px 슬롯에 1px 외곽 여백.
for i=0,5 do local x=96+i*16;local y=72
 if i==0 then rect(x+3,y+5,10,8,ink);rect(x+3,y+4,3,8,gold);rect(x+10,y+4,3,8,gold);rect(x+6,y+7,4,5,pale);rect(x+7,y+9,2,4,ink);rect(x+4,y+2,1,3,pale);rect(x+11,y+2,1,3,pale);rect(x+2,y+13,12,1,ink)
 elseif i==1 then for k=0,5 do rect(x+7-k,y+2+k,2+k*2,1,ink) end;for k=0,3 do rect(x+7-k,y+4+k,2+k*2,1,c('e8f4dc')) end;rect(x+6,y+7,4,6,ink);rect(x+7,y+8,2,4,c('8ee3b4'))
 elseif i==2 then for k=0,5 do rect(x+7-k,y+2+k,2+k*2,1,ink);rect(x+7-k,y+12-k,2+k*2,1,ink) end;rect(x+5,y+5,6,6,c('c94e4f'));rect(x+7,y+4,2,5,pale);rect(x+7,y+10,2,1,pale)
 elseif i==3 then rect(x+5,y+3,6,10,ink);rect(x+6,y+4,4,8,c('79c7e3'));rect(x+7,y+5,2,6,c('d4f5ed'));rect(x+3,y+12,10,2,gold);rect(x+4,y+2,8,2,gold)
 elseif i==4 then box(x+3,y+2,10,10,ink);box(x+4,y+3,8,8,pale);line(x+7,y+11,x+5,y+14,pale);rect(x+7,y+5,2,4,c('e8bb65'))
 else line(x+8,y+2,x+8,y+13,pale);line(x+3,y+8,x+13,y+8,gold);line(x+8,y+2,x+4,y+8,pale);line(x+8,y+2,x+12,y+8,pale) end
end
s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(repo..'/assets/ui/minimap_ui.aseprite');im:saveAs(repo..'/assets/ui/minimap_ui.png');s:close();print('MINIMAP ART PASS frame + 3 bags + 6 markers')
