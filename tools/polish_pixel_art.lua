-- 기존 원본의 실루엣·애니메이션을 보존하며 재질과 구조 연결부를 보강한다.
-- Aseprite batch Lua: 같은 이름의 보정 레이어를 교체하므로 반복 실행할 수 있다.
local script=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local repo=script:match('^(.*)/tools/[^/]+$') or '.'
local pc=app.pixelColor
local function c(h) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local C={ink=c('14212c'),steel=c('8198aa'),silver=c('b8cdcf'),dark=c('344953'),wood=c('93663c'),oak=c('c79a5b'),bark=c('50382b'),gold=c('cda45e'),blue=c('426780')}
local function dot(im,x,y,col) if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,col) end end
local function rect(im,x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,col) end end end
local function line(im,x,y,xx,yy,col) local n=math.max(math.abs(xx-x),math.abs(yy-y),1);for i=0,n do dot(im,math.floor(x+(xx-x)*i/n+.5),math.floor(y+(yy-y)*i/n+.5),col) end end
local function is(im,x,y,col) return x>=0 and y>=0 and x<im.width and y<im.height and im:getPixel(x,y)==col end
local function masked(src,out,x,y,w,h,from,to) for yy=y,y+h-1 do for xx=x,x+w-1 do if is(src,xx,yy,from) then dot(out,xx,yy,to) end end end end
local function helmet(frame)
 local im=Image(24,24);local pose=(frame-1)%12;local side=pose>=8;local back=pose>=4 and pose<8
 local leather=frame<=36;local bob=(pose%4==1 or pose%4==3) and -1 or 0
 local mid=side and 13 or 11;local base=leather and c('89603d') or c('7893a5');local light=leather and c('b58b56') or C.silver
 local spans={{-1,2},{-3,4},{-4,5},{-4,5},{-4,5},{-4,5},{-3,4},{-2,3}}
 for i,span in ipairs(spans) do
  local y=i+1+bob;rect(im,mid+span[1],y,span[2]-span[1]+1,1,C.ink)
  if i>1 and i<8 then rect(im,mid+span[1]+1,y,span[2]-span[1]-1,1,base) end
 end
 line(im,mid-2,4+bob,mid,3+bob,light);line(im,mid-3,5+bob,mid-3,6+bob,light)
 if back then line(im,mid+2,4+bob,mid+2,8+bob,leather and C.bark or C.dark)
 else
  local x=side and mid+1 or mid-2;local w=side and 3 or 6
  rect(im,x,7+bob,w,2,C.ink)
  if leather then rect(im,x,8+bob,w,1,c('c8a17b'));dot(im,x+w-1,8+bob,C.ink)
  else line(im,mid,3+bob,mid,6+bob,light);dot(im,x,7+bob,C.steel) end
 end
 if not leather then rect(im,mid,1+bob,2,2,c('a05c4a')) end
 return im
end
local function polish(path,cols,rows,paint)
 local s=app.open(repo..'/assets/'..path..'.aseprite')
 local old;for _,layer in ipairs(s.layers) do if layer.name=='구조·재질 보정' then old=layer end end
 if old then s:deleteLayer(old) end
 if path=='characters/equipment_worn' then
  local body=app.open(repo..'/assets/characters/player.aseprite')
  for row=0,9 do for pose=0,11 do
   local f=row*12+pose+1;local im=Image(24,24);local bob=(pose%4==1 or pose%4==3) and -1 or 0
   if row==2 or row==3 then im=helmet(f)
   elseif row>=4 and row<=7 then
    -- 갑옷·신발은 실제 몸 레이어의 윤곽과 발 디딤을 그대로 따른다.
    local source_layer=body.layers[row==7 and 2 or 3]
    local cel=source_layer:cel(pose+1);im:drawImage(cel.image,cel.position)
    for it in im:pixels() do local v=it()
     if pc.rgbaA(v)>0 and v~=c('151b2a') then
      local bright=pc.rgbaR(v)+pc.rgbaG(v)+pc.rgbaB(v)>380
      if row==7 then it(bright and c('c3b99a') or c('8c7355'))
      elseif row==6 then it(bright and c('cf8d66') or c('894b42'))
      elseif row==5 then it(bright and C.silver or c('617d91'))
      else it(bright and c('91acb7') or c('4f8299')) end
     end
    end
    if pose<4 and row~=7 then
     if row==5 then for y=12+bob,16+bob,2 do for x=9,14,2 do dot(im,x,y,C.silver) end end
     else rect(im,11,12+bob,2,3,row==6 and c('dc8253') or C.gold) end
    end
   else
    -- 기존 원본의 짝수 걸음은 몸과 반대로 내려갔다. 기준 자세에서 재구성해 누적 이동을 막는다.
    local base=pose-(bob==-1 and 1 or 0);local cel=s.layers[1]:cel(row*12+base+1)
    im:drawImage(cel.image,Point(cel.position.x,cel.position.y+bob))
   end
   local cel=s.layers[1]:cel(f);cel.image=im;cel.position=Point(0,0)
  end end
  body:close()
 end
 local source={};for f=1,#s.frames do source[f]=Image(s.width,s.height);source[f]:drawSprite(s,f) end
 local layer=s:newLayer();layer.name='구조·재질 보정'
 for f=1,#s.frames do local im=Image(s.width,s.height);paint(source[f],im,f);s:newCel(layer,f,im,Point(0,0)) end
 local sheet=Image(s.width*cols,s.height*rows)
 for f=1,#s.frames do local im=Image(s.width,s.height);im:drawSprite(s,f);local x,y
  if path=='kingdom/buildings_expanded' then x=math.floor((f-1)/4);y=(f-1)%4
  else x=(f-1)%cols;y=math.floor((f-1)/cols) end
  sheet:drawImage(im,Point(x*s.width,y*s.height))
 end
 s:saveAs(repo..'/assets/'..path..'.aseprite');sheet:saveAs(repo..'/assets/'..path..'.png');s:close()
 print('POLISHED '..path)
end
polish('characters/player',12,1,function(src,im,f)
 local side=f>8;local back=f>4 and f<=8
 -- 머리·어깨의 강한 흰 점을 넓은 중간톤과 짧은 반사광으로 정돈한다.
 masked(src,im,0,0,24,24,c('c4d1d3'),C.silver)
 masked(src,im,14,3,6,14,c('8198aa'),c('627b90'))
 masked(src,im,14,10,5,9,c('46659a'),c('354f7c'))
 -- 몸통을 가로지르는 금색 십자 대신 허리띠와 작은 버클로 갑옷 관절을 구분한다.
 for y=11,17 do for x=9,15 do local p=src:getPixel(x,y)
  if p==c('edc976') or p==c('c49049') then dot(im,x,y,back and c('2d487a') or c('4b6077')) end
 end end
 local bob=(f%4==2 or f%4==0) and -1 or 0
 local left=side and 10 or 8;local right=side and 16 or 15
 for x=left,right do if pc.rgbaA(src:getPixel(x,17+bob))>0 then dot(im,x,17+bob,C.bark) end end
 rect(im,side and 15 or 11,17+bob,2,1,C.gold)
end)
polish('characters/equipment_worn',12,10,function(src,im,f)
 local row=math.floor((f-1)/12);local pose=(f-1)%12;local side=pose>=8;local back=pose>=4 and pose<8
 if row==2 or row==3 then return end
 -- 같은 밝기로 채운 판에 1px 가장자리와 우측 음영을 줘 몸의 곡면에 맞춘다.
 for y=0,23 do for x=0,23 do local p=src:getPixel(x,y)
  if pc.rgbaA(p)>0 and p~=C.ink then
   local edge=(x==23 or pc.rgbaA(src:getPixel(x+1,y))==0 or y==23 or pc.rgbaA(src:getPixel(x,y+1))==0)
   if edge then dot(im,x,y,C.ink)
   elseif x>=(side and 15 or 13) then
    if p==c('91acb7') then dot(im,x,y,c('617d91'))
    elseif p==c('9b7045') then dot(im,x,y,c('795638'))
    elseif p==c('4f8299') then dot(im,x,y,c('355971'))
    elseif p==c('af614c') then dot(im,x,y,c('834638')) end
   end
  end
 end end
 -- 천 신발은 아이콘과 같은 천·가죽 색이며 금속 장화처럼 빛나지 않는다.
 if row==7 then
  masked(src,im,0,0,24,24,c('91acb7'),c('8c8677'))
  masked(src,im,0,0,24,24,c('dbe1d5'),c('c3b99a'))
 end
 if row>=4 and row<=6 and back then
  masked(src,im,9,11,6,6,c('d1ac65'),row==6 and c('834638') or C.dark)
  masked(src,im,9,11,6,6,c('dc8253'),c('af614c'))
 end
end)
polish('ui/equipment_items',5,3,function(src,im,f)
 if f<=5 then return end
 -- 재료별 하단 음영을 분리하고, 금속 반사광을 한 방향으로 통일한다.
 local maps={{'8da8b5','627f90'},{'9b7045','795234'},{'c29355','946a3f'},{'739ec4','507a9b'},{'cf7966','a75748'}}
 for _,pair in ipairs(maps) do masked(src,im,24,8,20,34,c(pair[1]),c(pair[2])) end
 if f==7 then -- 나무 방패: 가로 장식 뒤로 이어지는 판재와 금속 리벳
  for _,x in ipairs({19,25,30}) do masked(src,im,x,17,1,17,c('9b7045'),C.bark) end
  for _,p in ipairs({{17,18},{30,18},{19,30},{28,30}}) do if pc.rgbaA(src:getPixel(p[1],p[2]))>0 then dot(im,p[1],p[2],C.silver) end end
 elseif f==8 then -- 가죽 모자: 봉제선
  for y=16,24,3 do if pc.rgbaA(src:getPixel(23,y))>0 then dot(im,23,y,C.oak) end end
 elseif f==13 then -- 천 신발을 강철 장화와 구분
  masked(src,im,0,0,48,48,c('8da8b5'),c('8c8677'))
  masked(src,im,0,0,48,48,c('e1e4ce'),c('c3b99a'))
 end
end)
polish('kingdom/buildings_expanded',23,4,function(src,im,f)
 local col=math.floor((f-1)/4)
 -- 우측 면·처마 아래의 고유 색만 바꿔 문양과 발광부는 보존한다.
 for _,pair in ipairs({{'697f89','4d6572'},{'93663c','715032'},{'c79a5b','a77a46'},{'443958','332d46'}}) do
  masked(src,im,36,28,19,59,c(pair[1]),c(pair[2]))
 end
 if col>=14 and col<=17 then
  -- 상판과 다리 사이 3px 투명 틈을 메우고 장부·가로 버팀목을 연결한다.
  for _,x in ipairs({16,43}) do
   rect(im,x,66,7,22,C.ink);rect(im,x+1,67,4,20,C.wood);line(im,x+1,68,x+1,85,C.oak)
   rect(im,x,84,7,3,C.dark);dot(im,x+2,85,C.silver)
  end
  rect(im,22,68,22,4,C.bark);line(im,23,69,42,69,C.wood)
  rect(im,22,80,22,4,C.bark);line(im,23,80,42,80,C.wood)
  line(im,14,60,52,60,C.oak);line(im,14,65,52,65,C.bark)
  for _,x in ipairs({18,46}) do rect(im,x,63,2,2,C.dark);dot(im,x,63,C.silver) end
 elseif col==13 then
  -- 상자 뚜껑과 몸통의 접합선·경첩. 오른쪽 면은 한 단계 어둡다.
  masked(src,im,17,69,32,2,C.wood,C.bark)
  for _,x in ipairs({20,43}) do masked(src,im,x,61,2,18,C.oak,C.steel) end
 elseif col==8 then
  -- 발리스타 활대가 떠 보이지 않게 중심 축과 고정쇠를 연결한다.
  rect(im,29,61,6,17,C.bark);rect(im,30,62,3,14,C.wood);rect(im,28,66,8,4,C.dark);line(im,29,66,34,66,C.silver)
 elseif col==9 then
  -- 포신 무게를 지탱하는 받침 축, 금속 밴드.
  rect(im,27,72,12,7,C.dark);rect(im,29,73,8,3,C.steel);line(im,28,78,39,78,C.ink)
 elseif col==7 or col==10 or col==11 or col==12 then
  -- 기단 윗면·그림자선으로 수직 기둥과 바닥을 구분한다.
  masked(src,im,18,80,30,2,c('697f89'),C.silver)
  masked(src,im,20,86,25,2,c('697f89'),C.dark)
 end
end)
