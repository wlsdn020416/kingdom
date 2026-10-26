-- 보스 7종의 편집 원본·8프레임 시트. Aseprite batch Lua에서 실행한다.
local script = debug.getinfo(1,'S').source:gsub('^@',''):gsub('\\','/')
local root = (script:match('^(.*)/tools/[^/]+$') or '.')..'/assets/enemies/'
local pc = app.pixelColor
local function c(h,a) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),a or 255) end
local ink=c('101820');local deep=c('17212b');local white=c('fff0cc');local gold=c('c8a164');local pale=c('edd49a')
local oy=0;local glowimg
local function dot(im,x,y,col) x=math.floor(x+.5);y=math.floor(y+oy+.5);if x>=0 and x<128 and y>=0 and y<128 then im:drawPixel(x,y,col) end end
local function rect(im,x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,col) end end end
local function line(im,x,y,xx,yy,col,w) local n=math.max(math.abs(xx-x),math.abs(yy-y),1);for i=0,n do rect(im,math.floor(x+(xx-x)*i/n+.5),math.floor(y+(yy-y)*i/n+.5),w or 1,w or 1,col) end end
local function poly(im,p,col)
 local minx,miny,maxx,maxy=128,128,0,0
 for _,v in ipairs(p) do minx=math.min(minx,v[1]);miny=math.min(miny,v[2]);maxx=math.max(maxx,v[1]);maxy=math.max(maxy,v[2]) end
 for y=math.floor(miny),math.ceil(maxy) do for x=math.floor(minx),math.ceil(maxx) do local inside=false;local j=#p
  for i=1,#p do local a,b=p[i],p[j];if(a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i end
  if inside then dot(im,x,y,col) end
 end end
end
local function ellipse(im,x,y,rx,ry,col) for yy=math.floor(y-ry),math.ceil(y+ry) do for xx=math.floor(x-rx),math.ceil(x+rx) do if ((xx-x)/rx)^2+((yy-y)/ry)^2<=1 then dot(im,xx,yy,col) end end end end
local function plate(im,p,base,lit)
 poly(im,p,base)
 for i=1,#p do local a,b=p[i],p[i%#p+1];line(im,a[1],a[2],b[1],b[2],ink,2) end
 if lit then for i=1,math.min(2,#p-1) do local a,b=p[i],p[i+1];line(im,a[1]+2,a[2]+2,b[1]-2,b[2]+2,lit) end end
end
local function orb(im,x,y,rx,ry,base,lit) ellipse(im,x,y,rx,ry,ink);ellipse(im,x,y,rx-2,ry-2,base);if lit then ellipse(im,x-rx*.25,y-ry*.25,rx*.5,ry*.4,lit) end end
local function crystal(im,x,y,w,h,base,lit)
 plate(im,{{x,y},{x+w/2,y+h*.3},{x+w/2-1,y+h*.8},{x,y+h},{x-w/2,y+h*.8},{x-w/2,y+h*.3}},base,lit)
 poly(im,{{x,y+3},{x,y+h-3},{x-w/2+3,y+h*.7},{x-w/2+3,y+h*.3}},lit);line(im,x,y+4,x,y+h-5,white)
end
local function eye(x,y,w,col) rect(glowimg,x-1,y-1,w+2,4,c('1a2531'));rect(glowimg,x,y,w,2,col);dot(glowimg,x,y,white) end
local function spark(im,x,y,col) line(im,x-2,y,x+2,y,col);line(im,x,y-2,x,y+2,col);dot(im,x,y,white) end
local function rune(im,x,y,col) line(im,x,y-5,x,y+6,col,2);line(im,x-4,y-2,x+4,y+2,col);line(im,x-3,y+3,x+4,y-3,col) end
local function chain(im,x,y,n) for i=0,n do ellipse(im,x+(i%2),y+i*4,2,3,gold);dot(im,x,y+i*4,ink) end end
local function flame(im,x,y,w,h,phase)
 local j=phase%3
 poly(im,{{x-w/2,y},{x-w*.6,y-h*.4},{x-w*.3,y-h*.8-j},{x-w*.2,y-h*.4},{x+1,y-h-2+j},{x+w*.15,y-h*.5},{x+w*.4,y-h*.8},{x+w*.5,y-h*.2},{x+w*.35,y+3}},c('9d3d39'))
 poly(im,{{x-w*.3,y},{x-w*.25,y-h*.5},{x,y-h*.8+j},{x+w*.1,y-h*.4},{x+w*.25,y-h*.6},{x+w*.3,y},{x,y+4}},c('f08839'))
 poly(im,{{x-w*.12,y},{x,y-h*.5},{x+w*.15,y-2},{x,y+3}},c('ffe5a0'))
end
local function guardian(im,f,d)
 local steel=c('59616f');local lit=c('9299a1');local dark=c('303541');local violet=c('9870c2');local glow=c('e2b2ff')
 -- 망가진 원광과 찢긴 망토로 왕국 수호자의 흔적을 남긴다.
 for a=205,500,14 do if not(a>305 and a<350) then local r=math.rad(a+f*2);rect(im,math.floor(64+math.cos(r)*22),math.floor(33+math.sin(r)*15),3,2,gold) end end
 plate(im,{{43,48},{87,48},{93,99},{79,96},{76,111},{64,101},{48,112},{43,99},{34,106}},c('4c354f'),c('7d506f'))
 for _,x in ipairs({48,70}) do plate(im,{{x,85},{x+13,85},{x+14,105+d},{x+19,110+d},{x-2,110+d},{x-2,101}},dark,lit);line(im,x+2,91,x+10,91,steel,2) end
 -- 거대한 방패는 어깨가 아니라 아래 손에 고정한다.
 plate(im,{{23,53-d},{39,49-d},{45,61-d},{42,88-d},{31,101-d},{20,87-d},{18,64-d}},steel,lit)
 plate(im,{{25,59-d},{35,55-d},{39,65-d},{36,85-d},{31,92-d},{24,84-d}},dark,gold);rune(im,30,73-d,violet)
 plate(im,{{40,46},{50,42},{53,58},{42,70},{33,62}},steel,lit)
 plate(im,{{79,43},{91,48},{97,65+d},{87,70+d},{77,59}},steel,lit)
 line(im,94,67+d,105,89+d,c('725644'),5);line(im,103,81+d,106,101+d,gold,3)
 plate(im,{{98,76+d},{108,72+d},{116,79+d},{115,90+d},{108,97+d},{99,91+d},{95,83+d}},dark,lit)
 crystal(im,108,76+d,7,13,violet,glow)
 plate(im,{{47,44},{61,40},{80,44},{85,59},{78,82},{71,94},{50,88},{43,64}},steel,lit)
 poly(im,{{62,46},{73,48},{76,61},{69,75},{60,70},{57,58}},ink)
 crystal(im,66,49,13,27,violet,glow)
 line(im,50,80,76,82,gold,3);rect(im,61,79,7,6,pale)
 plate(im,{{49,22},{62,17},{76,22},{79,34},{72,46},{55,45},{47,34}},steel,lit)
 plate(im,{{52,24},{63,20},{74,25},{72,35},{54,35}},dark,lit)
 line(im,53,33,73,33,ink,3);eye(54,32,7,glow);eye(66,32,6,glow)
 plate(im,{{50,23},{39,16},{44,29},{50,32}},gold,pale);plate(im,{{74,24},{84,18},{80,32},{75,33}},gold,pale)
 line(im,61,37,62,44,lit,2);line(im,55,47,50,68,dark);line(im,75,65,79,76,dark)
 for i=0,2 do rect(im,48+i*11,86,5,3,gold) end
 spark(glowimg,85+(f%2),36-f%3,violet)
end
local function wolf(im,f,d)
 local fur=c('768899');local light=c('b2bcc4');local dark=c('3c4e60');local snow=c('e2ded0');local amber=c('f8bb65')
 -- 옆으로 긴 몸·선 귀·앞으로 뻗은 송곳니로 기사형과 다른 실루엣을 만든다.
 plate(im,{{35,64},{23,63},{16,52-d},{10,43-d},{9,58-d},{18,72},{32,77}},dark,fur)
 plate(im,{{35,69},{44,70},{47,96-d},{39,109-d},{25,110-d},{28,103-d},{35,99-d}},dark,light)
 plate(im,{{69,72},{81,71},{82,94+d},{89,105+d},{87,111+d},{73,110+d},{72,94+d}},dark,light)
 orb(im,57,72,31,20,dark,fur)
 plate(im,{{31,62},{45,50},{64,49},{83,58},{87,78},{78,87},{61,83},{40,83},{27,74}},fur,light)
 for i=0,5 do local x=32+i*7;poly(im,{{x,60},{x+5,53-(i%2)*3},{x+10,63},{x+4,66}},dark);line(im,x+2,59,x+6,57,light) end
 plate(im,{{39,80},{50,81},{46,100+d},{48,109+d},{34,112+d},{31,108+d},{37,101+d}},fur,light)
 plate(im,{{77,78},{87,77},{88,96-d},{96,105-d},{94,111-d},{80,110-d},{79,94-d}},fur,light)
 for _,x in ipairs({34,39,82,87}) do line(im,x,108+(x<50 and d or -d),x+3,111+(x<50 and d or -d),snow) end
 plate(im,{{69,50},{79,40},{93,42},{105,53},{104,66},{94,78},{77,75},{67,63}},light,snow)
 for _,p in ipairs({{68,48,59,39},{72,63,59,59},{75,74,65,82}}) do plate(im,{{p[1],p[2]},{p[3],p[4]},{p[3]+4,p[4]+13},{p[1]+8,p[2]+8}},snow,light) end
 plate(im,{{76,45},{77,23},{88,38},{91,45}},dark,light);poly(im,{{80,31},{85,40},{80,39}},c('b08078'))
 plate(im,{{92,43},{99,25},{104,49}},dark,light)
 plate(im,{{90,53},{103,52},{117,61},{116,68},{105,72},{94,65}},fur,snow)
 rect(im,111,60,7,5,ink);line(im,99,69,112,69,ink,2)
 poly(im,{{102,68},{106,68},{104,79}},snow);poly(im,{{111,68},{114,68},{112,76}},snow)
 eye(93,51,6,amber)
 -- 뼈 왕관과 부서진 목걸이가 일반 늑대와의 차이를 만든다.
 for i=0,3 do crystal(im,78+i*6,34-(i%2)*6,5,12,gold,snow) end
 line(im,79,42,100,44,gold,3);orb(im,75,76,7,6,gold,pale);rune(glowimg,75,75,amber)
 plate(im,{{58,62},{66,64},{69,86},{63,82},{59,91},{57,75}},c('92504d'),c('b56f62'))
 spark(glowimg,21,54+f%3,amber)
end
local function scorpion(im,f,d)
 local shell=c('96744b');local lit=c('d3ad65');local dark=c('4b4242');local green=c('9bc96f');local bright=c('d8ef9d')
 -- 꼬리는 몸통 뒤에서 올라와 중앙 독침으로 끝난다.
 local tail={{79,83},{91,74},{99,62},{101,48},{97,34},{88,25},{76,22},{65,25}}
 for i=1,#tail-1 do local a,b=tail[i],tail[i+1];line(im,a[1],a[2],b[1]+d*.3,b[2],ink,11);line(im,a[1]+1,a[2]-1,b[1]+d*.3,b[2]-1,shell,7);line(im,a[1],a[2]-3,b[1]+d*.3,b[2]-3,lit,2) end
 plate(im,{{64,22},{53,25},{49,36+d},{58,33+d},{66,29}},dark,lit);crystal(im,55,27+d,9,16,green,bright)
 for side=-1,1,2 do
  for i=0,2 do local x=64+side*(19+i*2);local y=80+i*8;line(im,x,y,64+side*37,y-2+d*(i%2==0 and 1 or -1),ink,5);line(im,64+side*37,y-2+d,64+side*45,y+6-d,ink,3);line(im,x,y-1,64+side*36,y-3+d,shell,2) end
 end
 orb(im,64,85,26,19,dark,shell)
 for i=0,3 do plate(im,{{44+i*3,72+i*7},{78-i*2,71+i*7},{83-i*3,79+i*7},{45+i*3,80+i*7}},shell,lit) end
 orb(im,53,82,5,9,green,bright);orb(im,75,82,5,9,green,bright)
 plate(im,{{46,60},{63,54},{80,60},{82,71},{72,80},{54,78},{43,69}},shell,lit)
 for x=54,75,7 do plate(im,{{x,61},{x-2,53},{x+5,58}},gold,pale) end
 eye(49,68,6,bright);eye(69,68,6,bright)
 for side=-1,1,2 do
  local x=64+side*34;local dy=side*d
  line(im,64+side*18,72,x,65+dy,ink,10);line(im,64+side*18,70,x,64+dy,shell,6)
  plate(im,{{x-side*4,62+dy},{x+side*9,49+dy},{x+side*19,51+dy},{x+side*20,64+dy},{x+side*9,77+dy},{x-side*2,76+dy}},shell,lit)
  poly(im,{{x+side*9,53+dy},{x+side*10,65+dy},{x+side*3,72+dy},{x+side*15,66+dy}},ink)
  line(im,x+side*10,53+dy,x+side*16,54+dy,lit,2)
 end
 line(im,59,78,56,88,ink,3);line(im,67,78,72,88,ink,3)
 spark(glowimg,47,44+f%3,green)
end
local function frost(im,f,d)
 local stone=c('3a5a72');local blue=c('6aabbc');local ice=c('b7e3df');local whiteice=c('e5f5e9')
 for _,x in ipairs({43,70}) do plate(im,{{x,80},{x+17,81},{x+19,105+d},{x+23,112+d},{x-5,112+d},{x-4,104}},stone,blue);crystal(im,x+7,89,13,21,blue,ice) end
 plate(im,{{38,41},{59,32},{84,39},{93,70},{80,91},{47,94},{32,71}},stone,blue)
 for i=0,3 do plate(im,{{43+i,55+i*9},{80-i,53+i*9},{78-i,61+i*9},{44+i,64+i*9}},blue,ice) end
 crystal(im,64,50,15,35,blue,whiteice);rune(glowimg,64,65,c('f0ffff'))
 for side=-1,1,2 do
  local x=64+side*31;local dy=side*d
  plate(im,{{x-side*10,43},{x+side*9,40},{x+side*17,56},{x+side*14,78+dy},{x-side*3,81+dy},{x-side*12,61}},stone,ice)
  plate(im,{{x-side*3,71+dy},{x+side*16,72+dy},{x+side*20,91+dy},{x+side*14,102+dy},{x-side*7,98+dy},{x-side*9,84+dy}},blue,ice)
  line(im,x,80+dy,x+side*12,89+dy,stone,2)
  crystal(im,x+side*3,21+(side==1 and 3 or -6),18,40,blue,ice)
  crystal(im,x-side*7,31,13,23,blue,whiteice)
 end
 plate(im,{{48,25},{58,18},{74,21},{82,33},{77,48},{51,48},{46,36}},stone,ice)
 plate(im,{{53,29},{61,24},{74,28},{76,35},{54,38}},blue,whiteice)
 eye(53,36,7,whiteice);eye(68,35,7,whiteice)
 for i=0,3 do crystal(im,55+i*6,44,8,18+(i%2)*5,blue,ice) end
 crystal(im,63,7,13,23,blue,whiteice)
 line(im,49,66,54,71,stone,2);line(im,75,78,68,85,stone,2)
 spark(glowimg,21+f%2,50,whiteice);spark(glowimg,106,61-f%3,ice)
end
local function mother(im,f,d)
 local dark=c('304a42');local moss=c('647e4d');local lit=c('a3b578');local flesh=c('748b70');local palegreen=c('d0df9d');local cap=c('9b6560')
 -- 넓은 알집과 여러 뿌리 다리로 무거운 소환수 어미를 만든다.
 for side=-1,1,2 do for i=0,2 do local x=64+side*(15+i*8);local y=88+i*4;plate(im,{{x-side*7,y-7},{x+side*10,y},{x+side*(17-i*2),108+side*d},{x+side*(7-i),114+side*d},{x-side*6,105}},dark,lit) end end
 orb(im,65,77,37,30,dark,moss)
 plate(im,{{35,56},{45,36},{68,30},{87,39},{101,62},{94,87},{79,100},{45,91},{28,77}},moss,lit)
 -- 반투명한 배를 밝은 가장자리와 서로 다른 알의 덩어리로 표현한다.
 orb(im,68,82,24,21,flesh,lit)
 for i,p in ipairs({{55,77},{69,72},{81,79},{59,91},{75,92}}) do orb(im,p[1],p[2]+(f+i)%2,6,7,moss,palegreen);dot(glowimg,p[1],p[2]+1,c('c4e795')) end
 poly(im,{{50,84},{53,70},{61,65},{55,83},{59,94},{54,93}},c('b3c691',180))
 for side=-1,1,2 do local x=64+side*36;plate(im,{{x-side*5,57},{x+side*7,57},{x+side*13,79-d*side},{x+side*19,88-d*side},{x+side*11,95-d*side},{x,86},{x-side*9,72}},dark,moss);line(im,x+side*11,91,x+side*18,98,lit,2) end
 plate(im,{{45,43},{52,32},{72,31},{83,43},{76,61},{52,64},{42,53}},dark,lit)
 plate(im,{{49,39},{61,34},{75,39},{77,49},{68,57},{54,55},{46,48}},flesh,lit)
 eye(49,46,7,palegreen);eye(67,45,7,palegreen)
 line(im,56,55,66,54,ink,2)
 -- 등 위의 거대한 버섯과 작은 갓·갈대·늘어진 이끼.
 for _,p in ipairs({{46,34,17,10},{76,28,15,9},{91,46,11,7},{35,59,10,6}}) do
  line(im,p[1],p[2]+3,p[1]-2,p[2]+16,c('999d77'),3)
  orb(im,p[1],p[2],p[3],p[4],cap,c('c28a70'));rect(im,p[1]-p[3]+4,p[2]+3,p[3]*2-7,3,c('d6b591'))
  for i=-1,1 do rect(im,p[1]+i*7,p[2]-3+(i%2),3,2,palegreen) end
 end
 for i=0,4 do line(im,39+i*11,57+(i%2)*4,37+i*11,69+(i%3)*5,moss,2) end
 line(im,86,28,91,14,dark,2);line(im,91,14,96,10,moss,3);line(im,38,39,30,27,moss,2);rect(im,28,22,4,8,lit)
 spark(glowimg,24+f%3,43,palegreen);dot(glowimg,99,30-f%4,palegreen)
end
local function lord(im,f,d)
 local obs=c('34313e');local slate=c('626173');local red=c('b74739');local lava=c('f39443');local hot=c('ffe8a2')
 -- 공중에 뜬 흑요석 판갑 사이로 불꽃이 이어진다.
 for x=43,84,9 do flame(im,x,110-(x%3)*2,13,28+(x%4)*4,f+x) end
 plate(im,{{45,74},{81,74},{89,97},{78,93},{73,108},{63,95},{51,106},{46,92},{37,96}},obs,slate)
 poly(im,{{52,79},{62,86},{59,101},{53,95}},red);poly(im,{{72,79},{78,89},{72,102},{69,90}},lava)
 for side=-1,1,2 do local x=64+side*34;local dy=side*d
  flame(im,x,60,22,35,f)
  plate(im,{{x-side*11,47},{x+side*8,41},{x+side*18,56},{x+side*11,71+dy},{x-side*5,68+dy}},obs,slate)
  line(im,x,66+dy,x+side*6,83+dy,ink,11);line(im,x,66+dy,x+side*6,83+dy,red,7);line(im,x,66+dy,x+side*6,82+dy,lava,3)
  plate(im,{{x-side*1,77+dy},{x+side*13,76+dy},{x+side*18,91+dy},{x+side*13,98+dy},{x+side*8,88+dy},{x+side*5,101+dy},{x-side*1,94+dy}},obs,slate)
  chain(im,x-side*5,56,3)
 end
 plate(im,{{45,43},{64,37},{84,44},{81,66},{72,83},{50,81},{40,62}},obs,slate)
 poly(im,{{59,44},{67,43},{72,58},{64,74},{57,58}},red)
 crystal(im,65,47,12,25,lava,hot)
 line(im,43,60,53,64,lava,2);line(im,79,56,74,66,lava,2)
 line(im,49,78,78,78,gold,4);orb(im,64,79,5,4,gold,pale)
 flame(im,64,38,36,32,f)
 plate(im,{{49,22},{61,18},{77,24},{80,37},{72,49},{54,46},{46,35}},obs,slate)
 plate(im,{{50,27},{38,15},{38,29},{49,37}},obs,slate);plate(im,{{75,25},{89,13},{87,31},{77,36}},obs,slate)
 eye(51,35,8,hot);eye(67,35,8,hot)
 poly(glowimg,{{57,42},{64,40},{72,43},{66,46},{60,46}},lava)
 spark(glowimg,103,33-f%4,lava);spark(glowimg,23,23+f%3,hot)
end
local function breaker(im,f,d)
 local iron=c('414352');local edge=c('777b87');local black=c('242531');local crimson=c('903d50');local scarlet=c('ed6971');local core=c('ffc488')
 -- 걸어오는 성채: 흉곽이 성문이고 어깨는 무너진 망루다.
 plate(im,{{28,42},{42,40},{49,94},{35,90},{29,105},{24,87},{16,93},{20,68}},crimson,c('bf5862'))
 plate(im,{{85,40},{100,42},{110,72},{105,98},{95,92},{89,105},{80,81}},crimson,c('bf5862'))
 for _,x in ipairs({40,70}) do
  plate(im,{{x,82},{x+18,81},{x+18,103+d},{x+23,113+d},{x-7,115+d},{x-9,107+d},{x-3,100+d}},black,edge)
  plate(im,{{x,86},{x+14,85},{x+12,103+d},{x+1,104+d}},iron,edge);line(im,x-3,109+d,x+15,108+d,gold,2)
 end
 for side=-1,1,2 do local x=64+side*34;local dy=side*d
  plate(im,{{x-side*10,40},{x+side*11,41},{x+side*13,67},{x-side*8,73}},iron,edge)
  rect(im,x-11,34,23,11,ink);rect(im,x-9,36,19,7,iron)
  for i=0,2 do rect(im,x-10+i*8,27+(i%2)*2,7,14,ink);rect(im,x-8+i*8,29+(i%2)*2,3,10,edge) end
  line(im,x,64,x+side*2,80+dy,ink,13);line(im,x,64,x+side*2,80+dy,iron,9)
  plate(im,{{x-side*7,74+dy},{x+side*15,75+dy},{x+side*22,88+dy},{x+side*15,106+dy},{x-side*9,100+dy},{x-side*15,86+dy}},iron,edge)
  for i=0,2 do crystal(im,x+side*(1+i*6),85+dy,5,15,black,edge) end
  line(im,x-side*8,81+dy,x+side*14,84+dy,gold,2)
 end
 plate(im,{{42,41},{64,34},{86,43},{87,71},{77,91},{49,91},{39,69}},black,edge)
 plate(im,{{45,47},{62,41},{82,47},{80,74},{73,86},{52,85},{44,66}},iron,edge)
 -- 성문 형태의 열린 용광로와 격자.
 poly(im,{{53,58},{60,51},{68,51},{76,59},{75,80},{52,80}},ink)
 poly(glowimg,{{56,60},{61,55},{67,55},{72,61},{70,77},{56,77}},crimson)
 flame(glowimg,64,76,13,17,f)
 for x=56,71,5 do line(glowimg,x,61,x,78,black,2) end
 line(im,46,84,80,85,gold,3);orb(im,64,86,6,4,gold,pale)
 plate(im,{{48,18},{61,13},{78,19},{80,34},{71,46},{53,44},{46,31}},black,edge)
 plate(im,{{52,23},{64,18},{75,25},{73,37},{56,38}},iron,edge)
 eye(52,30,9,scarlet);eye(66,30,8,scarlet)
 line(im,61,35,64,43,gold,2)
 -- 왕관의 한쪽은 부서지고 붉은 정수만 남았다.
 plate(im,{{48,20},{45,7},{55,14},{60,4},{65,14},{74,6},{77,19},{67,23}},gold,pale)
 crystal(im,62,10,6,11,crimson,scarlet)
 line(im,35,44,42,60,gold,2);line(im,85,47,80,60,gold,2)
 for _,p in ipairs({{45,51},{81,51},{50,73},{79,73}}) do rect(im,p[1],p[2],3,3,gold);dot(im,p[1],p[2],pale) end
 spark(glowimg,17,45+f%4,scarlet);spark(glowimg,109,64-f%3,scarlet)
end
local ids={'boss','alpha_wolf','venom_tyrant','frost_colossus','bog_mother','flame_lord','kingdom_breaker'}
local draw={guardian,wolf,scorpion,frost,mother,lord,breaker}
local radii={26,24,26,32,30,28,36}
local wave={0,1,2,1,0,-1,-2,-1}
local sprite=Sprite(128,128,ColorMode.RGB)
sprite.layers[1].name='접지 그림자'
local body_layer=sprite:newLayer();body_layer.name='고유 몸체·장갑·장식'
local light_layer=sprite:newLayer();light_layer.name='눈·핵·원소 문양'
local sheet=Image(1024,896,ColorMode.RGB)
local meta={}
for row,id in ipairs(ids) do
 local top=128
 for f=0,7 do
  local frame=(row-1)*8+f+1;if frame>1 then sprite:newEmptyFrame() end
  sprite.frames[frame].duration=.125
  local shadow=Image(128,128,ColorMode.RGB);local im=Image(128,128,ColorMode.RGB);glowimg=Image(128,128,ColorMode.RGB)
  oy=0;ellipse(shadow,64,109,radii[row]+3,7,c('08121a',88));ellipse(shadow,64,109,radii[row]-2,4,c('08121a',50))
  oy=math.floor(wave[f+1]/2);draw[row](im,f,wave[f+1])
  sprite:newCel(sprite.layers[1],frame,shadow,Point(0,0));sprite:newCel(body_layer,frame,im,Point(0,0));sprite:newCel(light_layer,frame,glowimg,Point(0,0))
  local merged=Image(128,128,ColorMode.RGB);merged:drawImage(shadow);merged:drawImage(im);merged:drawImage(glowimg)
  sheet:drawImage(merged,Point(f*128,(row-1)*128))
  for y=0,127 do for x=0,127 do if pc.rgbaA(merged:getPixel(x,y))>0 then top=math.min(top,y) end end end
 end
 local tag=sprite:newTag((row-1)*8+1,row*8);tag.name=id
 meta[#meta+1]=string.format('  "%s": {"row": %d, "top": %d}',id,row-1,top)
 print(id..' row='..(row-1)..' top='..top)
end
sprite:saveAs(root..'bosses.aseprite');sheet:saveAs(root..'bosses.png');sprite:close()
local file=io.open(root..'bosses_layout.json','w');file:write('{\n'..table.concat(meta,',\n')..'\n}\n');file:close()
print('BOSS ART BUILD PASS 7 bosses x 8 frames, 128x128, atlas 1024x896')
