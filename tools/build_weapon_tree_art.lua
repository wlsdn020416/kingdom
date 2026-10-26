-- 무기 트리의 고유 외형·투사체·효과·스킬 아이콘을 Aseprite에서 재현한다.
local script=debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local repo=script:match('^(.*)/tools/[^/]+$') or '.'
local root=repo..'/assets/combat/'
local pc=app.pixelColor
local function c(h,a) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),a or 255) end
local C={ink=c('12212d'),dark=c('344957'),steel=c('8199a6'),silver=c('c9dcd6'),white=c('fff1c3'),wood=c('936940'),oak=c('c29b62'),leather=c('57402f'),gold=c('cba461'),pale=c('f0d08d'),blue=c('5897bd'),cyan=c('92dcdb'),ice=c('d4f2ec'),red=c('c35b43'),fire=c('ed8a40'),violet=c('9376bc'),pink=c('d8b3ed'),green=c('83ad75'),coal=c('30303e')}
local function dot(im,x,y,col) x=math.floor(x+.5);y=math.floor(y+.5);if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,col) end end
local function rect(im,x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,col) end end end
local function line(im,x,y,xx,yy,col,w) local n=math.max(math.abs(xx-x),math.abs(yy-y),1);for i=0,n do rect(im,math.floor(x+(xx-x)*i/n+.5),math.floor(y+(yy-y)*i/n+.5),w or 1,w or 1,col) end end
local function poly(im,p,col)
 local x0,y0,x1,y1=im.width,im.height,0,0
 for _,v in ipairs(p) do x0=math.min(x0,v[1]);y0=math.min(y0,v[2]);x1=math.max(x1,v[1]);y1=math.max(y1,v[2]) end
 for y=math.max(0,math.floor(y0)),math.min(im.height-1,math.ceil(y1)) do for x=math.max(0,math.floor(x0)),math.min(im.width-1,math.ceil(x1)) do local inside=false;local j=#p
  for i=1,#p do local a,b=p[i],p[j];if(a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i end
  if inside then dot(im,x,y,col) end
 end end
end
local function ellipse(im,x,y,rx,ry,col) for yy=math.floor(y-ry),math.ceil(y+ry) do for xx=math.floor(x-rx),math.ceil(x+rx) do if ((xx-x)/rx)^2+((yy-y)/ry)^2<=1 then dot(im,xx,yy,col) end end end end
local function stroke(im,p,col,w) for i=1,#p-1 do line(im,p[i][1],p[i][2],p[i+1][1],p[i+1][2],col,w) end end
local function plate(im,p,base,lit) poly(im,p,base);for i=1,#p do local a,b=p[i],p[i%#p+1];line(im,a[1],a[2],b[1],b[2],C.ink) end;if lit then local a,b=p[1],p[2];line(im,a[1]+1,a[2]+1,b[1]-1,b[2]+1,lit) end end
local function crystal(im,x,y,w,h,base,lit) plate(im,{{x,y},{x+w,y+h/2},{x,y+h},{x-w,y+h/2}},base,lit);line(im,x,y+2,x,y+h-2,lit) end
local function spark(im,x,y,col) line(im,x-2,y,x+2,y,col);line(im,x,y-2,x,y+2,col);dot(im,x,y,C.white) end
local function stamp(src,dst,ax,ay,x,y,angle,scale)
 scale=scale or 1;local cs,sn=math.cos(angle),math.sin(angle)
 for yy=0,dst.height-1 do for xx=0,dst.width-1 do local dx,dy=(xx-x)/scale,(yy-y)/scale;local sx=math.floor(ax+dx*cs+dy*sn+.5);local sy=math.floor(ay-dx*sn+dy*cs+.5);if sx>=0 and sy>=0 and sx<src.width and sy<src.height then local p=src:getPixel(sx,sy);if pc.rgbaA(p)>0 then dst:drawPixel(xx,yy,p) end end end end
end
local function rune(im,x,y,col) line(im,x,y-3,x,y+4,col);line(im,x-3,y-1,x+3,y+1,col);line(im,x-2,y+2,x+2,y-2,col) end
local function palette(branch,tier)
 local base,lit,accent=C.steel,C.silver,C.gold
 if tier==1 then base=C.steel;lit=C.silver;accent=C.oak elseif tier==2 then base=C.blue;lit=C.ice;accent=C.gold end
 if branch=='great' and tier==3 then base=C.coal;lit=C.violet;accent=C.pink
 elseif branch=='twin' then accent=tier==3 and C.violet or C.cyan;if tier==3 then base=C.coal;lit=C.violet end
 elseif branch=='guard' then base=tier==3 and C.silver or C.blue;lit=C.ice;accent=C.gold
 elseif branch=='long' then base=tier==3 and C.pale or C.wood;lit=tier==3 and C.white or C.oak;accent=tier==2 and C.green or C.gold
 elseif branch=='rapid' then base=C.wood;lit=C.oak;accent=tier==3 and C.cyan or C.green
 elseif branch=='siege' and tier==3 then base=C.coal;lit=C.violet;accent=C.fire
 elseif branch=='scatter' and tier==3 then base=C.red;lit=C.gold;accent=C.fire
 elseif branch=='fire' then base=C.red;lit=C.fire;accent=C.white
 elseif branch=='frost' then base=C.blue;lit=C.cyan;accent=C.ice
 elseif branch=='thunder' then base=C.gold;lit=C.pale;accent=C.white
 elseif branch=='basic_staff' then base=C.violet;lit=C.pink;accent=C.silver end
 return base,lit,accent
end
local function base_weapon(sp,f)
 local im=Image(48,48,ColorMode.RGB);local b,t=sp.branch,sp.tier;local base,lit,accent=palette(b,t)
 local function hilt(y,ornate)
  rect(im,2,y-2,11,5,C.ink);rect(im,3,y-1,9,3,C.leather);line(im,4,y-1,10,y-1,C.oak)
  line(im,12,y-7,12,y+7,C.ink,3);line(im,13,y-6,13,y+6,C.gold);ellipse(im,3,y,2,2,C.gold)
  if ornate then crystal(im,13,y-2,2,4,accent,lit) end
 end
 if b=='basic_sword' or b=='great' or b=='guard' then
  local w=b=='great' and (5+t) or b=='guard' and 4 or 3
  local tip=b=='great' and 38 or b=='guard' and 39 or 35
  hilt(24,t>1)
  local p={{14,24-w},{tip-7,24-w},{tip,24},{tip-7,24+w},{14,24+w}}
  plate(im,p,base,lit);line(im,16,24,tip-3,24,lit)
  if b=='great' then line(im,17,26,tip-7,26,C.dark);rect(im,16,21,2,6,accent);if t==3 then for x=20,32,6 do poly(im,{{x,20},{x+3,18},{x+2,24},{x+5,26},{x,26}},C.violet) end end
  elseif b=='guard' then
   plate(im,{{10,18},{19,18},{20,26},{15,32},{10,27}},C.blue,C.gold);line(im,15,20,15,28,C.pale);line(im,12,24,18,24,C.pale)
   if t==3 then poly(im,{{19,19},{22,15},{24,19},{27,16},{29,20}},C.gold);rune(im,28,24,C.gold) end
  else rect(im,26,22,3,2,C.wood);rect(im,18,25,4,1,C.wood) end
 elseif b=='twin' then
  for i=0,1 do
   local y=18+i*12;hilt(y,t>1)
   plate(im,{{14,y-2},{27,y-3-i},{36-i*3,y-8},{34-i*2,y+1},{25,y+4},{14,y+3}},base,lit)
   line(im,16,y,29,y-1,accent)
  end
  if t==3 then spark(im,37,12+(f%3),C.pink);rect(im,5,31,6,2,C.violet) end
 elseif b=='basic_bow' or b=='long' or b=='rapid' then
  local h=b=='long' and 18 or b=='rapid' and 14 or 16
  local x=b=='long' and 20 or 18;local bulge=b=='rapid' and 5 or 3
  local p={{x-5,24-h},{x+2,24-h+4},{x+bulge+3,18},{x+bulge+4,24},{x+bulge+3,30},{x+2,24+h-4},{x-5,24+h}}
  stroke(im,p,C.ink,3);stroke(im,p,base,2);stroke(im,{{x-3,25-h},{x+2,27-h},{x+bulge+2,19}},lit)
  local pull=({11,18,14,10,9,9,10,11})[f+1];stroke(im,{{x-5,24-h},{pull,24},{x-5,24+h}},C.silver)
  rect(im,x+bulge+1,21,5,7,C.ink);rect(im,x+bulge+2,22,3,5,C.leather)
  if f==0 or f>=5 then line(im,pull,24,39,24,C.oak);poly(im,{{37,21},{43,24},{37,27}},C.silver);line(im,pull+2,22,pull+5,25,accent) end
  if t>0 then for side=-1,1,2 do
   if b=='long' then plate(im,{{x-5,24+side*(h-2)},{x-9,24+side*(h+2)},{x-7,24+side*(h-7)},{x-1,24+side*(h-5)}},accent,lit)
   else stroke(im,{{x+1,24+side*(h-3)},{x-3,24+side*(h-5)},{x-5,24+side*(h-10)}},accent,2) end
  end end
  if t==2 then rect(im,x+2,18,3,2,C.gold);rect(im,x+2,30,3,2,C.gold) elseif t==3 then crystal(im,x+3,21,3,6,accent,C.white);spark(im,34,12+f%3,accent) end
  return im,x+4,24
 elseif b=='basic_crossbow' or b=='scatter' or b=='siege' then
  local p={{2,21},{14,19},{36,20},{41,24},{37,28},{15,28},{4,34},{1,31}}
  plate(im,p,b=='basic_crossbow' and C.wood or base,lit);rect(im,11,22,28,3,C.dark);line(im,13,22,37,22,C.silver)
  local hx=b=='siege' and 25 or 22;local h=b=='siege' and 18 or 14
  stroke(im,{{hx-7,24-h},{hx+2,24-h+5},{hx+5,24},{hx+2,24+h-5},{hx-7,24+h}},C.ink,3)
  stroke(im,{{hx-6,25-h},{hx+1,25-h+5},{hx+4,24},{hx+1,23+h-5},{hx-6,23+h}},accent)
  local pull=({12,22,18,14,11,11,12,12})[f+1];stroke(im,{{hx-7,24-h},{pull,24},{hx-7,24+h}},C.silver)
  if b=='scatter' then
   rect(im,28,19,11,4,C.ink);rect(im,29,20,8,2,accent);rect(im,27,26,12,4,C.ink);rect(im,28,27,9,2,accent)
   if t==3 then for x=29,36,4 do poly(im,{{x,17},{x+3,14},{x+4,20}},C.gold) end end
  elseif b=='siege' then
   ellipse(im,15,30,5,5,C.ink);ellipse(im,15,30,3,3,accent);rect(im,28,18,8,3,C.ink);rect(im,30,14,4,5,accent)
   if t==3 then crystal(im,34,20,4,8,C.violet,C.pink) end
  end
  rect(im,17,21,5,7,C.gold);rect(im,18,22,3,5,C.pale)
  if f==1 or f==2 then spark(im,42,24,accent) end
 elseif b=='basic_staff' or b=='fire' or b=='frost' or b=='thunder' then
  line(im,2,24,31,24,C.ink,4);line(im,3,25,29,25,C.wood,2);line(im,4,24,26,24,C.oak)
  for x=7,25,7 do rect(im,x,23,2,5,t>1 and C.gold or C.steel) end
  if b=='frost' then
   crystal(im,34,12-t,6+t,22+t,base,lit)
   if t>1 then crystal(im,26,15,3,12,base,accent);crystal(im,41,18,3,10,base,accent) end
   if t==3 then stroke(im,{{27,11},{25,7},{23,10}},C.silver);spark(im,40,10+(f%3),C.ice) end
  elseif b=='thunder' then
   plate(im,{{28,11},{37,9-t},{42,17},{40,32},{31,36},{25,30},{26,17}},C.gold,C.pale)
   ellipse(im,34,23,6,9,C.coal)
   poly(im,{{35,12},{29,24},{34,23},{31,34},{41,20},{35,21},{39,12}},accent)
   if t>1 then line(im,27,15,23,11,C.gold,2);line(im,39,14,43,10,C.gold,2) end
   if t==3 then spark(im,43,30-f%4,C.white);rect(im,19,23,3,3,C.cyan) end
  elseif b=='fire' then
   stroke(im,{{28,15},{25,21},{27,30},{34,34},{41,29},{42,19},{38,13}},C.ink,3)
   stroke(im,{{29,16},{27,21},{28,29},{34,32},{39,28},{40,20},{37,15}},C.gold)
   poly(im,{{29,27},{28,20},{32,14-f%3},{33,21},{37,12-t},{39,22},{39,28},{34,31}},base)
   poly(im,{{32,27},{32,20},{35,23},{36,17},{38,26},{34,29}},lit);dot(im,35,25,C.white)
   if t>1 then line(im,29,14,28,10,C.gold,2);line(im,39,14,40,9,C.gold,2) end
   if t==3 then spark(im,43,16+f%4,C.fire);rune(im,18,24,C.fire) end
  else
   crystal(im,34,15,6,18,base,lit);stroke(im,{{27,18},{24,22},{26,30},{32,34},{40,30}},C.steel,2)
  end
  if f>0 and f<5 then spark(im,43,23+(f%3),accent) end
 end
 return im,8,24
end
local specs={
 {id="rusty_sword",branch="basic_sword",tier=0},
 {id="greatsword",branch="great",tier=1},
 {id="steel_greatsword",branch="great",tier=2},
 {id="obsidian_blade",branch="great",tier=3},
 {id="twin_blades",branch="twin",tier=1},
 {id="steel_twin_blades",branch="twin",tier=2},
 {id="shadow_blades",branch="twin",tier=3},
 {id="guard_sword",branch="guard",tier=1},
 {id="knight_sword",branch="guard",tier=2},
 {id="royal_guard_sword",branch="guard",tier=3},
 {id="old_bow",branch="basic_bow",tier=0},
 {id="longbow",branch="long",tier=1},
 {id="yew_longbow",branch="long",tier=2},
 {id="dragonbone_longbow",branch="long",tier=3},
 {id="rapid_bow",branch="rapid",tier=1},
 {id="hunter_bow",branch="rapid",tier=2},
 {id="storm_bow",branch="rapid",tier=3},
 {id="wooden_crossbow",branch="basic_crossbow",tier=0},
 {id="scatter_crossbow",branch="scatter",tier=1},
 {id="heavy_scatter_crossbow",branch="scatter",tier=2},
 {id="dragon_scatter_crossbow",branch="scatter",tier=3},
 {id="siege_crossbow",branch="siege",tier=1},
 {id="iron_siege_crossbow",branch="siege",tier=2},
 {id="obsidian_siege_crossbow",branch="siege",tier=3},
 {id="apprentice_staff",branch="basic_staff",tier=0},
 {id="fire_staff",branch="fire",tier=1},
 {id="blaze_staff",branch="fire",tier=2},
 {id="inferno_staff",branch="fire",tier=3},
 {id="frost_staff",branch="frost",tier=1},
 {id="glacier_staff",branch="frost",tier=2},
 {id="winter_staff",branch="frost",tier=3},
 {id="thunder_staff",branch="thunder",tier=1},
 {id="storm_staff",branch="thunder",tier=2},
 {id="tempest_staff",branch="thunder",tier=3},
}
local function export_sheet(path,w,h,ids,frames,painter,seconds)
 local s=Sprite(w,h,ColorMode.RGB);s.layers[1].name='고유 실루엣·재질·움직임'
 local sheet=Image(w*frames,h*#ids,ColorMode.RGB)
 for row,id in ipairs(ids) do
  for f=0,frames-1 do
   local n=(row-1)*frames+f+1;if n>1 then s:newEmptyFrame() end
   s.frames[n].duration=(seconds or .3)/frames
   local im=Image(w,h,ColorMode.RGB);painter(im,id,f,row)
   if w==32 then local reduced=Image(w,h,ColorMode.RGB);stamp(im,reduced,16,16,16,16,0,.88);im=reduced end
   s:newCel(s.layers[1],n,im,Point(0,0));sheet:drawImage(im,Point(f*w,(row-1)*h))
  end
  local tag=s:newTag((row-1)*frames+1,row*frames);tag.name=type(id)=='table' and id.id or id
 end
 s:saveAs(path..'.aseprite');sheet:saveAs(path..'.png');s:close()
end
export_sheet(root..'weapon_tree',64,64,specs,8,function(im,sp,f)
 local base,ax,ay=base_weapon(sp,f);local x,y,angle=25,32,0
 if sp.branch=='great' then angle=({-.08,-.5,-.15,.55,.9,.6,.2,0})[f+1]
 elseif sp.branch=='twin' then angle=({0,-.35,.55,-.45,.5,.25,-.1,0})[f+1]
 elseif sp.branch=='guard' or sp.branch=='basic_sword' then angle=({-.06,-.3,.15,.7,.65,.3,.1,0})[f+1]
 elseif sp.branch:find('bow') or sp.branch=='long' or sp.branch=='rapid' or sp.branch=='scatter' or sp.branch=='siege' then x=x+({0,-3,-2,-1,0,0,1,0})[f+1];angle=({0,-.06,.05,-.03,0,0,0,0})[f+1]
 else x=x+({0,-2,1,2,1,0,0,0})[f+1];angle=({0,-.1,-.03,.08,.04,0,0,0})[f+1] end
 stamp(base,im,ax,ay,x,y,angle,(sp.branch:find("staff") or sp.branch=="fire" or sp.branch=="frost" or sp.branch=="thunder") and .83 or 1)
 rect(im,x-3,y-1,5,5,C.ink);rect(im,x-2,y,3,3,C.steel);dot(im,x-2,y,C.silver)
 if sp.branch=='twin' then rect(im,x-4,y+8,5,4,C.ink);rect(im,x-3,y+9,3,2,C.steel) end
end,.24)
local projectile_ids={'long_arrow','yew_arrow','dragon_arrow','swift_arrow','hunter_arrow','storm_arrow','scatter_pellet','heavy_pellet','dragon_pellet','siege_bolt','iron_shell','obsidian_shell','arcane_spark','blaze_ember','inferno_ember','frost_shard','glacier_shard','winter_shard','thunder_spark','storm_spark','tempest_spark','dragon_snipe','charged_arrow','inferno_orb','blaze_orb'}
export_sheet(root..'weapon_tree_projectiles',32,32,projectile_ids,4,function(im,id,f,row)
 local accent=C.silver;local y=16
 if id:find('arrow') or id=='dragon_snipe' then
  local long=id:find('long') or id:find('yew') or id:find('dragon') or id:find('charged')
  if id:find('dragon') then accent=C.pale elseif id:find('storm') then accent=C.cyan elseif id:find('hunter') then accent=C.green elseif id:find('charged') then accent=C.white end
  line(im,5,16,25,16,C.ink,3);line(im,6,17,25,17,id:find('dragon') and C.pale or C.oak)
  poly(im,{{23,12},{30,16},{23,20}},C.ink);poly(im,{{24,14},{28,16},{24,18}},accent)
  for i=0,2 do line(im,5+i*2,13,8+i*2,16,accent);line(im,5+i*2,19,8+i*2,16,accent) end
  if long then line(im,1+f,15,22,15,accent);line(im,1,19,17-f*2,19,c('a4c8dc',100)) end
  if id=='storm_arrow' or id=='dragon_snipe' then spark(im,12-f*2,11+(f%2)*9,accent) end
 elseif id:find('pellet') then
  accent=id=='dragon_pellet' and C.fire or id=='heavy_pellet' and C.pale or C.silver
  poly(im,{{9,12},{23,12},{29,16},{23,20},{9,20},{5,16}},C.ink);rect(im,10,14,15,4,C.steel);line(im,11,14,23,14,accent)
  line(im,2+f,16,10,16,accent);if id=='dragon_pellet' then spark(im,7,12+f,C.fire) end
 elseif id:find('shell') or id=='siege_bolt' then
  accent=id=='obsidian_shell' and C.violet or C.gold
  poly(im,{{7,11},{23,11},{30,16},{23,22},{7,22},{3,16}},C.ink);poly(im,{{8,13},{23,13},{27,16},{23,20},{8,20}},id=='obsidian_shell' and C.coal or C.steel)
  rect(im,10,12,3,9,accent);rect(im,20,13,2,7,accent);line(im,12,14,24,14,C.silver)
  poly(im,{{6,12},{2,8},{5,16},{2,24},{7,21}},accent);if f%2==0 then dot(im,16,17,C.white) end
 elseif id:find('shard') then
  accent=id=='winter_shard' and C.ice or C.cyan
  crystal(im,23,8,6,16,C.blue,accent);line(im,4+f,16,20,16,accent);line(im,2,12,16-f,12,c('92dcdbaa',120))
  if id~='frost_shard' then crystal(im,12,8,3,7,C.blue,C.ice);crystal(im,11,20,3,6,C.blue,C.ice) end
  if id=='winter_shard' then spark(im,7,10+f*2,C.white) end
 elseif id:find('thunder') or id:find('storm_spark') or id:find('tempest') then
  accent=id=='tempest_spark' and C.cyan or C.pale
  stroke(im,{{3,17},{9,11+f},{15,18},{22,11},{29,16}},C.ink,5);stroke(im,{{3,17},{9,11+f},{15,18},{22,11},{29,16}},accent,3);stroke(im,{{5,17},{10,13+f},{16,19},{24,13},{29,16}},C.white)
  if id~='thunder_spark' then line(im,14,16,18,7,C.gold,2);line(im,23,15,26,23,C.gold,2) end
 else
  local fire=id~='arcane_spark';accent=fire and (id:find('inferno') and C.violet or C.fire) or C.violet
  local radius=(id:find('orb') and 10 or 7)
  ellipse(im,21,16,radius,radius,C.ink);ellipse(im,21,16,radius-2,radius-2,accent)
  poly(im,{{3,12-f},{14,13},{18,10},{16,20},{8,22+f},{11,17}},accent)
  ellipse(im,23,14,radius*.55,radius*.55,fire and C.pale or C.pink);ellipse(im,24,13,2,2,C.white)
  if id:find('inferno') then line(im,17,12,21,11,C.fire,2);line(im,18,19,24,20,C.fire,2) elseif not fire then rune(im,21,16,C.white) end
 end
end,.24)
local effect_ids={'great_slash','twin_slash','shadow_slash','guard_slash','royal_slash','slam_wave','dash_cut','shadow_cut','counter_stance','counter_wave','focused_shot','arrow_rain','scatter_muzzle','siege_burst','obsidian_burst','frost_ring','frost_impact','lightning_strike','lightning_link','arcane_impact','piercing_impact','inferno_impact','charged_impact','fire_wave','siege_muzzle'}
local function arc(im,x,y,r,start,finish,col,w) local steps=math.max(20,math.floor((finish-start)*r));for i=0,steps do local a=start+(finish-start)*i/steps;rect(im,math.floor(x+math.cos(a)*r+.5),math.floor(y+math.sin(a)*r+.5),w or 1,w or 1,col) end end
local function impact(im,f,col,kind)
 local r=10+f*6
 for i=0,7 do local a=i*math.pi/4+f*.12;local x=64+math.cos(a)*r;local y=64+math.sin(a)*r
  if kind=='ice' then crystal(im,x,y-5,3,9,C.blue,col) else line(im,x,y,x+math.cos(a)*(7-f*.5),y+math.sin(a)*(7-f*.5),col,2) end
 end
 ellipse(im,64,64,math.max(2,10-f),math.max(2,8-f),col);ellipse(im,64,64,math.max(1,6-f),math.max(1,5-f),C.white)
end
export_sheet(root..'weapon_tree_effects',128,128,effect_ids,6,function(im,id,f)
 local fade=math.floor(235-f*29);local gold=c('e0ba78',fade);local white=c('fff3d0',fade);local blue=c('95dcd9',fade);local purple=c('b69be3',fade)
 if id:find('slash') then
  local col=id=='shadow_slash' and purple or id=='twin_slash' and blue or gold
  local start=-1.3+f*.1;local finish=1.3+f*.1
  if id=='great_slash' then
   arc(im,64,64,56,start,finish,c('7d9aa5',math.floor(fade*.4)),7-f*.5);arc(im,64,64,54,start,finish,col,3);arc(im,64,64,52,start,finish,white,2)
   for i=0,3 do local a=start+(finish-start)*i/3;line(im,64+math.cos(a)*43,64+math.sin(a)*43,64+math.cos(a)*53,64+math.sin(a)*53,col,2) end
  else
   arc(im,64,64,54,start,finish,col,3);arc(im,64,64,51,start,finish,white)
   if id=='twin_slash' or id=='shadow_slash' then arc(im,56,63,42,-1.3-f*.09,1.2-f*.09,col,2);arc(im,58,64,40,-1.3-f*.09,1.2-f*.09,white) end
   if id=='royal_slash' then for i=0,4 do local a=-1+i*.5;crystal(im,29+math.cos(a)*47,64+math.sin(a)*43-3,2,6,C.gold,C.pale) end end
  end
 elseif id=='dash_cut' or id=='shadow_cut' then
  local col=id=='shadow_cut' and purple or blue
  for i=0,2 do line(im,12+i*8+f*2,36+i*23,110-f*2,53+i*8,col,3-i);line(im,29+i*4,37+i*23,108-f*2,53+i*8,white) end
  line(im,63,42,88,87,col,2)
 elseif id=='counter_stance' then
  local p={};for i=0,6 do local a=math.pi/3*i;p[#p+1]={64+math.cos(a)*39,64+math.sin(a)*39} end
  stroke(im,p,gold,2);arc(im,64,64,31,0,math.pi*2,blue,1)
  for i=0,5 do local a=i*math.pi/3;rect(im,math.floor(64+math.cos(a)*39),math.floor(64+math.sin(a)*39),3,3,C.white) end
  rune(im,64,64,gold)
 elseif id=='slam_wave' or id=='counter_wave' or id=='siege_burst' or id=='obsidian_burst' then
  local col=id=='obsidian_burst' and purple or id=='counter_wave' and gold or c('e58c50',fade)
  local r=17+f*6;arc(im,64,64,48,0,math.pi*2,c('ddad75',math.floor(fade*.45)),2);arc(im,64,64,r,0,math.pi*2,col,3)
  for i=0,9 do local a=i*math.pi/5+.17;local inner=12+f*2;local outer=33+f*3
   line(im,64+math.cos(a)*inner,64+math.sin(a)*inner,64+math.cos(a)*outer,64+math.sin(a)*outer,col,2)
   if id~='counter_wave' then local x=64+math.cos(a)*(r+6);local y=64+math.sin(a)*(r+4);plate(im,{{x-3,y},{x,y-5},{x+4,y-2},{x+2,y+3}},id=='obsidian_burst' and C.coal or C.dark,col) end
  end
  if id:find('burst') then ellipse(im,64,64,math.max(2,17-f*2),math.max(2,17-f*2),col);ellipse(im,64,64,math.max(2,9-f),math.max(2,9-f),white) end
 elseif id=='frost_ring' then
  arc(im,64,64,48,0,math.pi*2,blue,2);arc(im,64,64,15+f*6,0,math.pi*2,c('7ebbd7',math.floor(fade*.5)),2)
  for i=0,11 do local a=i*math.pi/6+f*.02;local x=64+math.cos(a)*45;local y=64+math.sin(a)*45;crystal(im,x,y-5,3,10+f%2,C.blue,C.ice) end
  for i=0,5 do local a=i*math.pi/3;line(im,64,64,64+math.cos(a)*34,64+math.sin(a)*34,blue) end
 elseif id=='arrow_rain' then
  arc(im,64,64,48,0,math.pi*2,gold,1)
  for i=0,11 do local a=i*2.4;local r=10+(i*13)%35;local x=64+math.cos(a)*r;local y=64+math.sin(a)*r;local drop=(i+f)%3*6
   line(im,x,y-22+drop,x,y+2,gold,2);poly(im,{{x-4,y-1},{x+4,y-1},{x,y+7}},white);line(im,x-4,y-19+drop,x,y-15+drop,white)
  end
 elseif id=='lightning_strike' or id=='lightning_link' or id=='charged_impact' then
  if id=='lightning_strike' then
   stroke(im,{{74,7},{58+f,23},{72,33},{54,51},{66,61},{64,72}},c('6571ae',math.floor(fade*.55)),8)
   stroke(im,{{74,7},{58+f,23},{72,33},{54,51},{66,61},{64,72}},gold,4);stroke(im,{{74,7},{58+f,23},{72,33},{54,51},{66,61},{64,72}},white)
   arc(im,64,76,36+f*2,0,math.pi*2,gold,2);stroke(im,{{68,33},{90,44},{81,55}},gold,2);impact(im,f,gold)
  elseif id=='lightning_link' then
   local p={{16,64},{33,57+(f%2)*10},{48,69},{65,55},{80,68-f},{98,58+f},{112,64}}
   stroke(im,p,c('6078a0',math.floor(fade*.4)),6);stroke(im,p,gold,3);stroke(im,p,white)
   stroke(im,{{64,57},{72,44},{80,45}},gold);stroke(im,{{83,66},{90,80},{96,78}},gold)
  else impact(im,f,gold);stroke(im,{{40,44},{54,59},{47,66},{64,73},{76,63},{88,72}},white,2) end
 elseif id=='focused_shot' or id=='scatter_muzzle' or id=='siege_muzzle' then
  local col=id=='focused_shot' and blue or gold
  if id=='scatter_muzzle' then for i=-2,2 do local a=i*.22;line(im,40,64,100+math.cos(a)*8-f*3,64+math.sin(a)*70,col,2);spark(im,100-f*2,64+i*12,col) end
  elseif id=='siege_muzzle' then for i=0,7 do local a=i*math.pi/4;line(im,60+math.cos(a)*10,64+math.sin(a)*10,60+math.cos(a)*24,64+math.sin(a)*24,col,3) end;line(im,45,64,108-f*3,64,white,4)
  else line(im,15+f*2,64,111-f*2,64,col,3);line(im,35,63,111-f*2,63,white);arc(im,52,64,16+f*2,-.8,.8,col) end
 elseif id=='fire_wave' or id=='inferno_impact' then
  local col=id=='inferno_impact' and purple or c('ed8a40',fade)
  for i=0,7 do local a=i*math.pi/4+f*.1;local x=64+math.cos(a)*(14+f*4);local y=64+math.sin(a)*(14+f*4);poly(im,{{x-5,y+5},{x-8,y-6},{x-2,y-3},{x+3,y-16+f},{x+5,y-2},{x+9,y+3}},col);line(im,x,y-5,x+2,y+2,white,2) end
 elseif id=='frost_impact' then impact(im,f,blue,'ice')
 elseif id=='arcane_impact' then impact(im,f,purple);rune(im,64,64,purple);arc(im,64,64,20+f*3,0,math.pi*2,purple)
 elseif id=='piercing_impact' then impact(im,f,white);line(im,22+f*3,64,109-f*2,64,white,2);line(im,31,57,83-f,57,gold)
 end
end,.4)
local skill_ids={'slam','dash_slash','counter','snipe','arrow_rain','blast_bolt','frost_ring','lightning'}
export_sheet(repo..'/assets/ui/weapon_skill_icons',32,32,skill_ids,1,function(im,id)
 if id=='slam' then
  line(im,6,6,24,23,C.ink,5);line(im,7,6,24,23,C.silver,3);line(im,19,19,24,14,C.gold,2)
  stroke(im,{{4,24},{13,21},{16,25},{19,22},{28,26}},C.pale,2);line(im,13,25,10,29,C.steel)
 elseif id=='dash_slash' then
  line(im,3,24,25,5,C.cyan,4);line(im,5,27,28,8,C.silver,2);line(im,2,14,14,8,C.blue,2)
 elseif id=='counter' then
  plate(im,{{5,5},{26,5},{25,21},{16,29},{6,21}},C.gold,C.pale);plate(im,{{9,9},{22,9},{21,19},{16,24},{10,19}},C.blue,C.ice);line(im,15,11,15,21,C.pale,2)
 elseif id=='snipe' then
  arc(im,16,16,10,0,math.pi*2,C.cyan,1);line(im,2,25,29,7,C.ink,4);line(im,3,25,27,9,C.pale,2);poly(im,{{22,5},{30,5},{29,13}},C.silver);line(im,16,2,16,8,C.cyan);line(im,23,16,30,16,C.cyan)
 elseif id=='arrow_rain' then
  for i=0,2 do local x=7+i*9;line(im,x,3+i*3,x,21+i*2,C.oak,2);poly(im,{{x-3,19+i*2},{x+4,19+i*2},{x,28+i}},C.silver) end
 elseif id=='blast_bolt' then
  for i=0,7 do local a=i*math.pi/4;line(im,17+math.cos(a)*4,17+math.sin(a)*4,17+math.cos(a)*13,17+math.sin(a)*13,C.fire,2) end
  line(im,2,26,24,7,C.ink,6);line(im,3,26,25,7,C.steel,3);rect(im,10,17,5,3,C.gold);ellipse(im,20,12,5,5,C.pale)
 elseif id=='frost_ring' then
  arc(im,16,16,10,0,math.pi*2,C.cyan,2);for i=0,5 do local a=i*math.pi/3;crystal(im,16+math.cos(a)*10,13+math.sin(a)*10,2,6,C.blue,C.ice) end
 elseif id=='lightning' then
  poly(im,{{18,2},{6,18},{14,18},{11,30},{27,12},{18,13},{23,2}},C.ink);poly(im,{{18,5},{10,16},{18,15},{15,25},{23,15},{16,16},{21,5}},C.pale);line(im,8,27,24,27,C.cyan)
 end
end,.2)
print('WEAPON TREE ART PASS '..#specs..' weapons x 8, '..#projectile_ids..' projectiles x 4, '..#effect_ids..' effects x 6, 8 skill icons')
