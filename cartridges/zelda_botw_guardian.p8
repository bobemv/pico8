pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- created by bobemv

function _init()
	init_link()
	init_guardian()
	init_laser()
	init_shoot()
	init_explosions()
end

function _update()	
	move_link()
	move_guardian()
	update_guardian_state()
	update_guardian_laser()
	update_shoot()
	update_explosions()
end

function _draw()
	cls()
	map(0,0,0,0,20,20)
	spr(link.p,link.x,link.y)
	spr(guardian.p,guardian.x,guardian.y)

	draw_guardian_laser()
	draw_shoot()
	draw_explosions()
end

-->8
--aux functions

--constants
pi=3.141592
tau=2*pi

-- compute magnitude of v
function v_mag( v )
  return sqrt( ( v.x * v.x ) + ( v.y * v.y ) )
end

-- normalizes v into a unit vector
function v_normalize( v )
  local len = v_mag( v )
  return { x = v.x / len, y = v.y / len }
end

-- flexible function to draw curves
function draw_curve(curves,x,y,p,c,start,ending,precision)	 
	 if (x==nil) x=64
	 if (y==nil) y=64
	 if (p==nil) p=0
	 if (c==nil) c=7
	 if (start==nil) start=0
	 if (ending==nil) ending=128
	 if (precision==nil) precision=1
	 
		for i=start,ending,precision do
			local fx=cos(p)*i-sin(p)*curves.x(i)
			local fy=sin(p)*i+cos(p)*curves.y(i)
			pset(round(x+fx),round(y+fy),c)
		end
end

function fun_strand(x)
	return 5*cos((x/5)/tau)
end

function fun_strand_2(x)
	return 5*sin((x/5)/tau)
end

-- round number to nearest integer
function round(x)
	local basex = flr(x)
	if x - basex > 0.5 then
		return basex + 1
	else
		return basex
 end
end

-- draw a grid for debugging purposes
function draw_grid()
	for i=0,128,10 do
		rect(i,0,i,128)
	end
		for i=0,128,10 do
		rect(0,i,128,i)
	end
end
-->8
--init functions and models
function init_link()
	link={
		p=1,
		x=90,
		y=90,
		dx=0,
		dy=0
	}
end

function init_guardian()
	guardian={
		p=2,
		x=30,
		y=30,
		x_eye=64,
		y_eye=62,
		dx=0,
		dy=0,
		radius=90,
		shoot_time=1,
		is_locked=false,
		is_shooting=false,
		is_attacking=false,
		is_searching=false,
		timer_locked=0,
	}
end

function init_laser()
	laser={
		x=0,
		y=0,
		x_aim=0,
		y_aim=0,
		dx_aim=0,
		dy_aim=0,
		c=8,
		r=2
	}
end

function init_explosions()
	explosions={}
end

function init_shoot()
	shoot= get_shoot_model()
end

function get_shoot_model()
		local shoot={
		x=0,
		y=0,
		frame=0,
		is_animated=false,
		n_strands=5,
		strand={
			start=2,
			ending=2,
			c=12,
			grow_rate=1.0,
			spin=0.005
		},
		strands={},
		aura={
			ext_radius=5,
			int_radius=1,
			dr=1
		},
		n_boom_dirs=3,
		boom_dirs={},
		beam={
 		c=12,
 		r=1,
 		speed=5.0,
 		is_shot=false
 	},
		init_f={
			strands=0,
			aura=0,
			boom=15,
			beam=15
		},
		end_f={
			strands=14,
			aura=24,
			boom=24
		},
		is_hit=false
	}
	local dr=round((shoot.aura.ext_radius+shoot.aura.int_radius)/shoot.aura.dr)
 local frames=shoot.end_f.aura-shoot.init_f.aura
 shoot.aura.f=flr(frames/dr)
	
	return shoot
end

function get_explosion_model()
	return {
		frame=0,
		x=shoot.beam.x,
		y=shoot.beam.y,
		dome={
			r_max=6,
			r=2,
			dr=2,
			c_int=7,
			c_ext=9
		},
		after={
			n=10,
			r_fast=3,
			r_slow=1,
			s_fast=0.6,
			s_slow=0.1,
			c=9,
			c_smoke=5,
			decay=1.0
		},
		after_particles={},
		init_f={
			dome=0,
			after=0
		},
		end_f={
			dome=16,
			after=30
		},
		last_f=31
	}
end
-->8
--attack guardian animation

function create_shoot(x,y)
	shoot=get_shoot_model()
	shoot.x=x
	shoot.y=y
 --strands directions
	for i=1,shoot.n_strands do
		local strand={
			p= (1/shoot.n_strands)*i+rnd(1/shoot.n_strands)
		}
		add(shoot.strands,strand)
	end
	
	--boom directions
	for i=1,shoot.n_boom_dirs do
		local direction={
			dx=2+rnd(10),
			dy=2+rnd(10)
		}
		if (rnd(1)>0.5) direction.dx*=-1
		if (rnd(1)>0.5) direction.dy*=-1
		add(shoot.boom_dirs,direction)
	end
end

function stop_shoot()
	shoot.is_animated=false
end

function resume_shoot()
	shoot.is_animated=true
end

function update_shoot()
	if (shoot.is_animated==false) return
	
	shoot.x=guardian.x_eye
	shoot.y=guardian.y_eye
	
	if shoot.is_hit then
		stop_shoot()
		create_explosion()
		return
	end
	
	if shoot.init_f.strands <= shoot.frame and
				shoot.end_f.strands >= shoot.frame then

				update_strands()
	end
	
	if shoot.init_f.aura <= shoot.frame and
				shoot.end_f.aura >= shoot.frame then
				
				update_aura()
	end
	
	if shoot.frame==shoot.init_f.beam then
		start_beam()
	end
	
	if shoot.beam.is_shot then
		update_beam()
	end
 shoot.frame+=1
	
end

function update_strands()
	for strand in all(shoot.strands) do
		strand.p+=rnd(shoot.strand.spin)
	end
	shoot.strand.ending+=shoot.strand.grow_rate
end

function update_aura()
	if (shoot.frame-shoot.init_f.aura)%shoot.aura.f==0 then
 	if shoot.aura.int_radius>=shoot.aura.ext_radius then
 		shoot.aura.dr*=-1
 		shoot.aura.int_radius=-1
 	end
 	if shoot.aura.dr > 0 then
 		shoot.aura.int_radius+=shoot.aura.dr
 	else
 		shoot.aura.ext_radius+=shoot.aura.dr
 	end
	end
end

function start_beam()
	shoot.beam.x=shoot.x
	shoot.beam.y=shoot.y
	shoot.beam.x_aim=laser.x_aim
	shoot.beam.y_aim=laser.y_aim
	local d_aim=v_normalize({x=laser.x_aim-shoot.x,y=laser.y_aim-shoot.y})
	shoot.beam.dx=d_aim.x*shoot.beam.speed
	shoot.beam.dy=d_aim.y*shoot.beam.speed
	shoot.beam.is_shot=true
end

function clear_beam()
	shoot.beam.x=0
	shoot.beam.y=0
	shoot.beam.x_aim=0
	shoot.beam.y_aim=0
	shoot.beam.dx=0
	shoot.beam.dy=0
	shoot.beam.is_shot=false
end

function update_beam()
		shoot.beam.x+=shoot.beam.dx
		shoot.beam.y+=shoot.beam.dy
		local d=v_mag({x=shoot.beam.x_aim-shoot.beam.x,y=shoot.beam.y_aim-shoot.beam.y} )
		if (d < 3) shoot.is_hit=true
end

function draw_shoot()
	if (shoot.is_animated==false) return
	
	if shoot.init_f.aura <= shoot.frame and
				shoot.end_f.aura >= shoot.frame then
				
				draw_aura()
	end
	if shoot.init_f.strands <= shoot.frame and
				shoot.end_f.strands >= shoot.frame then
				
				draw_strands()
	end
	
	
	if shoot.init_f.boom <= shoot.frame and
				shoot.end_f.boom >= shoot.frame then
				
				draw_boom()
	end
	
	if shoot.beam.is_shot then
				draw_beam()
	end
end

function draw_strands()
	local curves={
		x=fun_strand_2,
		y=fun_strand_2
	}
	for strand in all(shoot.strands) do		
		draw_curve(curves,shoot.x,shoot.y,strand.p,shoot.strand.c,shoot.strand.start,shoot.strand.ending)	
	end
end

function draw_aura()
	local x =shoot.x
 local y =shoot.y
 
 if shoot.aura.dr > 0 then
 	circfill(x,y,shoot.aura.int_radius,7)
	end
 circ(x,y,shoot.aura.ext_radius,12)
end


function draw_boom()
	local x =shoot.x
 local y =shoot.y
 
	circfill(x,y,1,7)
	for direction in all(shoot.boom_dirs) do
		line(x,y,x+direction.dx,y+direction.dy,7)
	end
end

function draw_beam()
	
 local x =shoot.x
 local y =shoot.y

	line(x,y,shoot.beam.x,shoot.beam.y,12)
	line(x,y+1,shoot.beam.x,shoot.beam.y+1,12)
	circfill(shoot.beam.x,shoot.beam.y,shoot.beam.r,shoot.beam.c)
	circ(shoot.beam.x,shoot.beam.y,shoot.beam.r+4,7)
end
-->8
--explosion animation

function create_explosion()
	local explosion=get_explosion_model()
 
 local frames_dome=explosion.end_f.dome-explosion.init_f.dome
 local frames_after=explosion.end_f.after-explosion.init_f.after
 local changes_dome=flr((((explosion.dome.r_max-explosion.dome.r)/explosion.dome.dr)*2)+1)
 local changes_after=max(explosion.after.r_fast, explosion.after.r_slow)
 explosion.dome.f=flr(frames_dome/changes_dome)
 explosion.after.f=flr(frames_after/changes_after)
	
	for i=1,flr(explosion.after.n/3) do
		local p={
			x=explosion.x,
			y=explosion.y,
			dx=explosion.after.s_fast-rnd(2*explosion.after.s_fast),
			dy=explosion.after.s_fast-rnd(2*explosion.after.s_fast),
			r=explosion.after.r_fast,
			smoke={}
		}
		add(explosion.after_particles, p)
 end
 for i=1,explosion.after.n-ceil(explosion.after.n/3) do
		local p={
			x=explosion.x,
			y=explosion.y,
			dx=explosion.after.s_slow-rnd(2*explosion.after.s_slow),
			dy=explosion.after.s_slow-rnd(2*explosion.after.s_slow),
			r=explosion.after.r_slow,
			smoke={}
		}
		add(explosion.after_particles, p)
 end
	add(explosions,explosion)
end

function update_explosions()
	for e in all(explosions) do
		if e.last_f==e.frame then
			del(explosions,e)
		else
  	if e.init_f.dome <= e.frame and
  				e.end_f.dome >= e.frame then
  				
  				update_explosion_dome(e)
  	end
  	
  	if e.init_f.after <= e.frame and
  				e.end_f.after >= e.frame then
  				
  				update_explosion_after(e)
  	end
  end
  e.frame+=1
	end
end

function update_explosion_dome(e)
	if (e.frame-e.init_f.dome)%e.dome.f==0 then
		if e.dome.r == e.dome.r_max then
			e.dome.dr*=-1
		end
		e.dome.r+=e.dome.dr
	end
end

function update_explosion_after(e)
 for p in all(e.after_particles) do
 	local new_p_smoke={
 		x=p.x,
 		y=p.y,
 		r=1,
 		c=e.after.c_smoke
 	}
 	add(p.smoke, new_p_smoke)
 	
 	p.x+=p.dx
 	p.y+=p.dy
 	
 	if (e.frame-e.init_f.after)%e.after.f==0 then
 		p.r=max(ceil(p.r-e.after.decay),1.0)
 	end
 end
end

function draw_explosions()
	for e in all(explosions) do
	 if e.init_f.after <= e.frame and
 				e.end_f.after >= e.frame then
 				
 				draw_explosion_after(e)
 	end
 	if e.init_f.dome <= e.frame and
 				e.end_f.dome >= e.frame then
 				
 				draw_explosion_dome(e)
 	end
	end
end

function draw_explosion_dome(e)
	circfill(e.x,e.y,e.dome.r,e.dome.c_int)
	circ(e.x,e.y,e.dome.r,e.dome.c_ext)
end

function draw_explosion_after(e)
	for p in all(e.after_particles) do
		for p_smoke in all(p.smoke) do
			circfill(p_smoke.x,p_smoke.y,p_smoke.r,p_smoke.c)
		end
		circfill(p.x,p.y,p.r,e.after.c)
	end
end
-->8
-- guardian
function move_guardian()
	guardian.dx=0
	guardian.dy=0
	if (btn(0,1)) guardian.dx=-1
	if (btn(1,1)) guardian.dx=1
	if (btn(2,1)) guardian.dy=-1
	if (btn(3,1)) guardian.dy=1
	
	guardian.x+=guardian.dx
	guardian.y+=guardian.dy
	guardian.x_eye=guardian.x+4
	guardian.y_eye=guardian.y+2
end

function update_guardian_state()
	if guardian.is_attacking and
				shoot.is_hit then
				guardian.is_attacking=false
				guardian.p=2
	end
	
	local d=v_mag({x=link.x-guardian.x,y=link.y-guardian.y})
	if d > guardian.radius then
		guardian.is_searching=true
		guardian.is_locked=false
		guardian.is_attacking=false
		stop_shoot()
		guardian.timer_locked=0
		guardian.p=2
		return
	else
		if (guardian.is_attacking) return
		if guardian.is_locked == false then
			guardian.is_locked=true
 		guardian.timer_locked=time()
 		guardian.is_attacking=false
 		guardian.is_searching=false
		end
	end
	
	if guardian.is_locked and
	   (time() - guardian.timer_locked) > guardian.shoot_time then
		--guardian_attack()
		create_shoot(guardian.x_eye,guardian.y_eye)
		resume_shoot()
		guardian.p=3
		guardian.is_attacking=true
		guardian.is_locked=false
		guardian.is_searching=false
		guardian.timer_locked=0
		return
	end
end

-->8
--laser animation

function update_guardian_laser()
	if (guardian.is_locked==false) return
	
	laser.x=guardian.x_eye
	laser.y=guardian.y_eye
	laser.x_aim=link.x
	laser.y_aim=link.y
	
	local ddx=0
	local ddy=0
	repeat
		ddx=flr(rnd(2))
		ddy=flr(rnd(2))
		if (rnd(1) > 0.5) ddx*=-1
		if (rnd(1) > 0.5) ddy*=-1

	until (laser.dx_aim+ddx >= 0 and
								laser.dx_aim+ddx < 8 and
								laser.dy_aim+ddy >= 0 and
								laser.dy_aim+ddy < 8)
	
		laser.dx_aim+=ddx
		laser.dy_aim+=ddy
		laser.x_aim+=laser.dx_aim
		laser.y_aim+=laser.dy_aim
end

function draw_guardian_laser()
	if (guardian.is_locked==false) return
	
	line(laser.x,laser.y,laser.x_aim,laser.y_aim,laser.c)
	circ(laser.x_aim,laser.y_aim,laser.r,laser.c)

end
-->8
-- link

function move_link()
	link.dx=0
	link.dy=0
	if (btn(0,0)) link.dx=-1
	if (btn(1,0)) link.dx=1
	if (btn(2,0)) link.dy=-1
	if (btn(3,0)) link.dy=1
	
	link.x+=link.dx
	link.y+=link.dy
end

__gfx__
00000000009993330085580000855800bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb66bbbbbbbbbb000000000000000000000000000000000000000000000000
00000000009993330055550000555500bbbbbbb3bbbbbbbbbbbbbbbbbbbbbbbbbbb6666bbbbbbbbb000000000000000000000000000000000000000000000000
0070070000f5ff30005cc50000577500bb3bbbbbbbbbbbbbbbbb3bbbbbb66bbbbbb66666bbbbbbbb000000000000000000000000000000000000000000000000
00077000000fff000085850000877500bbbbbbbbbbbbbbbbb33b3333bb6666bbb6666666bb55bbb5000000000000000000000000000000000000000000000000
000770000f33333f0058580000585800bbbbbbbbbbbbbbbbbb3333bbbb66666b66666666b5bb55b5000000000000000000000000000000000000000000000000
00700700000050005555555555555555bbbbbebbbbbbbbbbbbb333bbb666666666666666b555bbb5000000000000000000000000000000000000000000000000
00000000003333305505050555050505bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb66666bbb5bbb5555000000000000000000000000000000000000000000000000
00000000004000405505050555050505bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb55b555bb000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbb511115b11111111bb5111bbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb55555bbbb551155b11111111551111bbbb555555555bbbbbbbbbbbbb00000000000000000000000000000000000000000000000000000000
555555555bbbbbbb1111555bb551155b11111111111111bbbb5111111155bbbbbbbbbbbb00000000000000000000000000000000000000000000000000000000
11111111555bbbbb1111115bb555155b11111111111111bbb55111111115555555555bbb00000000000000000000000000000000000000000000000000000000
111111111155bbbb1111115bb555155b111111111111155bb5111111111111111111555b00000000000000000000000000000000000000000000000000000000
111111111115bbbb5551115bb5551555111111115551155bb5111111111111111111115b00000000000000000000000000000000000000000000000000000000
555511111111bbbbbb5111bbb551155511111111bbbbb5bbb5111111111111111111115500000000000000000000000000000000000000000000000000000000
bbbbbb1111111bbbb511115bb511115511111111bbbbbbbbb5111111111111111111111500000000000000000000000000000000000000000000000000000000
bbbbbbbb11111bbbbbbbbbbbb511115bbbbbbbbbb511155bb5111111111111111111111500000000000000000000000000000000000000000000000000000000
bbbbbbb5111111bbbbbbb555b511115b55555555bb11115b55111111111111111111111500000000000000000000000000000000000000000000000000000000
bbbbbbb5111111bbbb111551b511115b11111111bb11111111111111111111111111111500000000000000000000000000000000000000000000000000000000
bbbbbbb55111111bbb111111b511115b11111111bb11111111111111111111111111115500000000000000000000000000000000000000000000000000000000
bbbbbbbb5511111bbb111111b511115b11111111b551111111111111111111111111155500000000000000000000000000000000000000000000000000000000
bbbbbbbbb5511115b5111551b511115b11111111bb55511155111111111111111111115500000000000000000000000000000000000000000000000000000000
bbbbbbbbbb511115b511155bb511115b55555555bb555555b5111111111111111111111500000000000000000000000000000000000000000000000000000000
bbbbbbbbbb511115b51115bbb511115bbbbbbbbbbbbbbbbbb5111111111111111111111500000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000b5111111111111111111115500000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000b5555551111111111111115b00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbbb51111111111111115b00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbb551111111111111155b00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbb51111111111111155bb00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbb5511111115555555bbb00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbbbb55511115bbbbbbbbb00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000bbbbbbbbb511115bbbbbbbbb00000000000000000000000000000000000000000000000000000000
__map__
0505050605050505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050805050505050505040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505040505050505050605050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0504050505040505050505050905050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2412070505060505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0513050505050505050505050506050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0513051617180505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0525242627280505060505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505053637380505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050523050505050809050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0522120523050505090505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0513252415050505050505050505060500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0525241205050505050405050505222400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505051305050505050505052224150500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
