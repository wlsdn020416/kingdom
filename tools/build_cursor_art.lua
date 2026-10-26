-- 왕국 테마 메뉴 화살표·버튼 장갑·전투 조준점을 같은 픽셀 팔레트로 만든다.
local source=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local repo=source:match('^(.*)/tools/[^/]+$') or '.'
local pc=app.pixelColor
local function c(h) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local ink=c('101c27');local shade=c('405563');local ivory=c('eff4df');local gold=c('d4b16c');local light=c('ffe3a4');local cyan=c('8bd5d1')
local function make(id,paint)
 local s=Sprite(32,32,ColorMode.RGB);s.layers[1].name='외곽선·금속·조준';local im=Image(32,32,ColorMode.RGB)
 local function dot(x,y,col) if x>=0 and y>=0 and x<32 and y<32 then im:drawPixel(x,y,col) end end
 local function rect(x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(xx,yy,col) end end end
 local function line(x,y,xx,yy,col,w) local n=math.max(math.abs(xx-x),math.abs(yy-y),1);for i=0,n do rect(math.floor(x+(xx-x)*i/n+.5),math.floor(y+(yy-y)*i/n+.5),w or 1,w or 1,col) end end
 local function poly(points,col)
  for y=0,31 do for x=0,31 do local inside=false;local j=#points
   for i=1,#points do local a,b=points[i],points[j];if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i end
   if inside then dot(x,y,col) end
  end end
 end
 paint(dot,rect,line,poly)
 s:newCel(s.layers[1],1,im,Point(0,0));s:saveAs(repo..'/assets/ui/cursor_'..id..'.aseprite');im:saveAs(repo..'/assets/ui/cursor_'..id..'.png');s:close()
end
make('menu',function(dot,rect,line,poly)
 poly({{3,2},{4,25},{10,20},{15,29},{20,26},{15,17},{25,16}},ink)
 poly({{5,6},{6,21},{10,17},{16,26},{17,25},{12,15},{20,15}},gold)
 poly({{5,5},{6,18},{10,14},{19,14}},ivory)
 line(5,5,6,18,light);line(7,7,16,13,ivory);line(11,17,16,26,light)
 rect(9,13,4,4,shade);rect(10,13,2,3,cyan);dot(10,13,ivory)
end)
make('hand',function(dot,rect,line,poly)
 poly({{9,3},{13,3},{15,6},{15,12},{18,12},{21,14},{24,14},{27,17},{26,25},{22,29},{12,29},{7,23},{4,18},{5,15},{8,15},{9,16}},ink)
 poly({{10,5},{12,5},{13,7},{13,15},{17,14},{20,16},{23,16},{25,18},{24,24},{21,27},{13,27},{9,22},{6,18},{7,17},{11,21}},shade)
 rect(10,5,2,12,ivory);line(13,16,13,22,ivory);line(17,16,17,22,ivory);line(21,18,21,22,gold)
 line(7,18,13,25,ivory);rect(13,24,9,3,gold);rect(16,24,3,2,cyan);dot(16,24,ivory)
end)
make('aim',function(dot,rect,line,poly)
 -- 중앙과 표적 사이 여백을 남기고 밝고 어두운 지형 모두에서 1px 내곽선이 보이게 한다.
 for _,p in ipairs({{14,2,5,8},{14,23,5,8},{2,14,8,5},{23,14,8,5}}) do rect(p[1],p[2],p[3],p[4],ink) end
 rect(16,3,1,6,ivory);rect(16,24,1,6,ivory);rect(3,16,6,1,ivory);rect(24,16,6,1,ivory)
 for _,p in ipairs({{8,8,11,8},{8,8,8,11},{21,8,24,8},{24,8,24,11},{8,21,8,24},{8,24,11,24},{24,21,24,24},{21,24,24,24}}) do
  line(p[1]-1,p[2]-1,p[3]+1,p[4]+1,ink,2);line(p[1],p[2],p[3],p[4],cyan)
 end
 rect(15,15,3,3,ink);dot(16,16,light)
end)
print('CURSOR ART PASS menu + hand + aim (32x32)')
