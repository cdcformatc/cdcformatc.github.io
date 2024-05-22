pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- cats!
local version=0.2

function _init()
	debug=true

	-- set beige transparent
	palt(15, true)
	-- set black not transparent
	palt(0, false)

	-- set game state
	game_over=false

	-- make cats
	cat1=make_cat(1)
	cat2=make_cat(2)

	main_cat=cat1
	other_cat=cat2
end


function _update()
	if (not game_over) then
		check_swap()
		move_cat(main_cat)
		move_cat(other_cat)
	else
		if (btnp(5,0) or btnp(5,1)) _init()
	end
end


function _draw()
	cls(5)

	local vstr="v"..version
	print(vstr,128-(#vstr-1)*char_width,0,12)

	draw_cats()

	if debug then
		debug_cat(cat1)
		debug_cat(cat2)
	end

	if (game_over) then
		print("game over!",44,44,7)
		print("press ❎ to play again!",18,72,7)
	end
end


-->8
-- cat logic

-- movement constants
dy_gravity=0.2

dy_jump=-18*dy_gravity
dy_down=dy_gravity

dx_move=2
ddx_air=0.888
ddx_slow=.625

max_dx=4
max_dy=8

min_dx=0.25

-- timer constants
sit_time=0.5*60
loaf_time=3*60
sleep_time=6*60

-- cat_states
state_init=1
state_unknown=2
state_dead=3
state_standing=4
state_jumping=5
state_falling=6
state_running=7
state_sitting=8
state_loafing=9
state_sleeping=10

function is_idle_state(state)
	return (state==state_sitting or state==state_loafing or state==state_sleeping)
end

local sprite_tbl = {
	3, 	--state_init
	3,	--state_unknown
	3,	--state_dead
	0,	--state_standing
	5,	--state_jumping
	6,	--state_falling
	0,	--state_running
	1,	--state_sitting
	2,	--state_loafing
	4,	--state_sleeping
}

function do_unswap_pal(s)
	printh("unswap "..s[1].." "..s[1])
	pal(s[1],s[1])
end

function do_swap_pal(s)
	printh("swap "..s[1].." "..s[2])
	pal(s[1],s[2])
end

function unswap_pal(swaps)
	if (swaps) foreach(swaps,do_unswap_pal)
end

function swap_pal(swaps)
	if (swaps) foreach(swaps,do_swap_pal)
end

function cat_speed(cat)
	return sqrt(cat.dx^2+cat.dy^2)
end

function get_sprite(cat)
	return sprite_tbl[cat.state]+(cat.n*16)
end

function make_cat(n)
	c={}
	c.n=n-1
	c.p=c.n
	c.x=24
	c.y=60
	c.dy=0
	c.dx=0
	c.t=0
	c.state=state_init
	c.pal_swaps=nil

	if (c.n==1) then
		-- move cat1 on init
		c.x+=12
		c.flip_h=true
		c.lazy_factor=1
	else
		-- this cat has pallet swaps
		c.pal_swaps={{4,0},{7,0},{9,0}}
		c.lazy_factor=1.25
	end
	return c
end

function check_btns(cat)
	local p=cat.p
	local d={}
	d.x=0
	d.y=0

	if (btn(⬅️,p)) then
		d.x-=dx_move
	end
	if (btn(➡️,p)) then
		d.x+=dx_move
	end
	if (btnp(⬆️,p) and not cat.falling) then
		sfx(0)
		d.y+=dy_jump
	end
	if (btnp(⬇️,p)) then
		d.y+=dy_down
	end
	if d.x>10 then
		d.x=10
	end
	if d.x<-10 then
		d.x=-10
	end
	return d
end

function is_on_floor(cat)
	return cat.y >= 120
end

function move_cat(cat)
	-- do gravity
	cat.dy+=dy_gravity

	-- check user input
	d=check_btns(cat)

	-- apply user input
	cat.dy+=d.y
	cat.dx+=d.x

	-- apply x friction
	if (is_on_floor(cat)) then
		cat.dx*=ddx_slow
	else
		cat.dx*=ddx_air
	end

	-- cap speed
	if (abs(cat.dx)<min_dx) cat.dx=0

	if (cat.dx>max_dx) cat.dx=max_dx
	if (cat.dx<-max_dx) cat.dx=-max_dx
	if (cat.dy>max_dy) cat.dy=max_dy
	if (cat.dy<-max_dy) cat.dy=-max_dy

	-- finally apply speed
	cat.y+=cat.dy
	cat.x+=cat.dx

	-- cat is on the ceiling
	if (cat.y <= 0) then
		cat.y=0
		cat.dy=0
	end

	-- set cat on the floor
	if (is_on_floor(cat)) then
		cat.dy=0
		cat.y=120
	end

	-- left bound
	if (cat.x < 0) then
		cat.dx=0
		cat.x=0
	end

	-- right bound
	if (cat.x > 120) then
		cat.dx=0
		cat.x=120
	end

	set_cat_state(cat)
end

function set_cat_state(cat)
	local old_state=cat.state
	local new_state=state_unknown

	if (is_on_floor(cat)) then
		--printh("n: "..cat.n.."is_on_floor")
		if (cat.dx!=0) then
			new_state=state_running
		else
			local idle_time = cat.t*cat.lazy_factor
			if (idle_time>=sit_time) new_state=state_sitting
			if (idle_time>=loaf_time) new_state=state_loafing
			if (idle_time>=sleep_time) new_state=state_sleeping
		end
	else
		--printh("n: "..cat.n.."is in air")
		-- cat is in the air
		if (cat.dy>0) then
			new_state=state_falling
		else
			new_state=state_jumping
		end
	end

	--printh("n: "..cat.n.." dx"..cat.dx.." dy"..cat.dy)
	--printh("old: "..old_state.." new "..new_state)

	if (new_state!=old_state and new_state!=state_unknown) then
		-- set state
		cat.state=new_state

		if (not is_idle_state(new_state)) then
			-- reset idle timer
			cat.t=0
		end
	else
		-- increment idle timer
		cat.t+=1
	end
end

function draw_cat(cat)
	--printh("draw "..cat.n)
	-- maybe flip cat
	if (cat.dx<0) cat.flip_h=true
	if (cat.dx>0) cat.flip_h=false

	-- swap palette, draw sprite, unswap palette
	--swap_pal(cat.pal_swaps)
	spr(get_sprite(cat),cat.x,cat.y,1,1,cat.flip_h)
	--unswap_pal(cat.pal_swaps)
end

function draw_cats()
	draw_cat(other_cat)
	draw_cat(main_cat)
end


-->8
-- cat swap control

function swap_cats(what,player)
	-- swap cats
	if (what==0) then
		main_cat=cat1
		other_cat=cat2
	else
		main_cat=cat2
		other_cat=cat1
	end

	-- play cat sfx
	if (player==0) then
	 sfx(2+main_cat.n)
	else
	 sfx(2+other_cat.n)
	end

	main_cat.p=0
	other_cat.p=1
end

function check_swap()
	-- check if swap button pressed
	if (btnp(🅾️,0)) then
		swap_cats(0,0)
	end
	if (btnp(❎,0)) then
		swap_cats(1,0)
	end
	if (btnp(🅾️,1)) then
		swap_cats(0,1)
	end
	if (btnp(❎,1)) then
		swap_cats(1,1)
	end
end
-->8
--debug and printing
char_width=5
char_height=6

function round(x)
	return flr(x+.5)
end

function printn(s,n,x,y)
	print(sub(s,0,n),x,y)
end

function debug_cat(cat)
	x=cat.n*7*char_width
	y=0

	print(cat.n,x,y)
	y+=char_height
	print(cat.state,x,y)
	y+=char_height
	printn(cat.x,7,x,y)
	y+=char_height
	printn(cat.y,7,x,y)
	y+=char_height
	printn(cat.dx,7,x,y)
	y+=char_height
	printn(cat.dy,7,x,y)
	y+=char_height
	printn(cat.t,7,x,y)
end
__gfx__
f0ff0ff0ffff0ff0fff0fff000fff00ffffffffff0ff0ff00fff0ff0000000000000000000000000000000000000000000000000000000000000000000000000
0fff0000f0ff0000fff00f000ffff0ffffffffff00ff00000fff0000000000000000000000000000000000000000000000000000000000000000000000000000
0fff0a0a00ff0a0af0f00000000000fffff0fff00fff0a0a00ff0a0a000000000000000000000000000000000000000000000000000000000000000000000000
0fff00000fff0000f0f0a0a0000000fffff00f000fff0000f0ff0000000000000000000000000000000000000000000000000000000000000000000000000000
000000ff0f0000ff00f000000fff0000fff000000000000ff00000ff000000000000000000000000000000000000000000000000000000000000000000000000
000000ff000000ff0fff00ff0fff0a0a00000000f0000000f000000f000000000000000000000000000000000000000000000000000000000000000000000000
0ffff0fff000f0ff000000ff0fff000000000000f0fffff0f0fffff0000000000000000000000000000000000000000000000000000000000000000000000000
00fff00ff000f00f00000000f0ff0ff0000000000ffffffff00ffff0000000000000000000000000000000000000000000000000000000000000000000000000
f4ff9ff4ffff9ff4fff9fff447fff47ffffffffff4ff9ff44fff9ff4000000000000000000000000000000000000000000000000000000000000000000000000
4fff4444f4ff4444fff99f444ffff4ffffffffff44ff44444fff4444000000000000000000000000000000000000000000000000000000000000000000000000
4fff4a4a4fff4a4af4f44444994449fffff4fff94fff4a4a44ff4a4a000000000000000000000000000000000000000000000000000000000000000000000000
4fff44444fff4444f4f4a4a4944944fffff44f994fff4444f4ff4444000000000000000000000000000000000000000000000000000000000000000000000000
444944ff4f4944ff4ff444444fff4444fff444444449444ff94944ff000000000000000000000000000000000000000000000000000000000000000000000000
994449fff44449ff4fff44ff4fff4a4a44444444f9444944f944494f000000000000000000000000000000000000000000000000000000000000000000000000
9ffff4fff944f4ff944494ff4fff444494449444f4fffff7f4fffff4000000000000000000000000000000000000000000000000000000000000000000000000
47fff47ff994f47f99444447f4ff9ff4994444447ffffffff47ffff7000000000000000000000000000000000000000000000000000000000000000000000000
__label__
66655555555555555555555555555555665555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555565555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555565555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555565555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655555555555555555555555555555666555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66556665555555555555555555555555665566655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56556565555555555555555555555555565565655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56556565555555555555555555555555565565655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56556565555555555555555555555555565565655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66656665555555555555555555555555666566655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66656665555565556665666565555555666565555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65555565555565556565556565555555556565555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655565555566656565566566655555566566655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55655565555565656565556565655555556565655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655565565566656665666566655555666566655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66556665666555555555555555555555665566656665555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56555565656555555555555555555555565555656565555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56556665656555555555555555555555565566656565555555555555555555555555555555555555555555555555555555555555555555555555555555555555
56556555656555555555555555555555565565556565555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66656665666555555555555555555555666566656665555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655555555555555555555555555555666555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655555555555555555555555555555666555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655555555555555555555555555555666555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
65655555555555555555555555555555656555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655555555555555555555555555555666555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
66656565655566655555555555555555666565556665666555555555555555555555555555555555555555555555555555555555555555555555555555555555
55656565655565555555555555555555556565556565556555555555555555555555555555555555555555555555555555555555555555555555555555555555
66656665666566655555555555555555666566656665556555555555555555555555555555555555555555555555555555555555555555555555555555555555
65555565656555655555555555555555655565655565556555555555555555555555555555555555555555555555555555555555555555555555555555555555
66655565666566655555555555555555666566655565556555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555545559555555555555555505550555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544599555555555555555500500555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444555555555555555500000555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444444555555555555500000000555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544494449555555555555500000000555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555544444499555555555555500000000555555555555555555555555555555555555555555555555555555555555555

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400000c0500e0501110020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
00100000290501d0001f0500000019050000000804008030080300803008020080200802008010080100801000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000027150291502b1500000000000000000000000000000000000000000000000000000000000000000033100000000000000000000000000000000000000000000000000000000000000000000000000000
0008000015150181501c15020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
0008000015100181001c10020100231002c1002e1003010023200232002220022200202001e2001d2001d2002cd002cd002bd002bd002bd002bd002bd001ab002bd002ad002bd002cd002cd002cd002cd0000000
