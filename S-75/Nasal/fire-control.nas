################### GLOBALS

var false = 0;
var true = 1;

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

var radar_update_time = 2;
var launch_update_time = 0.3;
var reloading = 0;
var missile_delay_time = 0;#time when last track was initiated
var missile_release_time = 0;#time when last missile was fired
var ciws_delay_time = 0;#time when CIWS was last fired
var launch_in_progress = 0;# if a firing solution is currently being calculated
var reload_starting = 0;
var ACTIVE_MISSILE = 0;
var semi_active_track = nil;# with multiple missiles flying in semi-active-radar mode, this can change rather fast. Which means pilots wont get a steady tone, but disrupted tones. (tradeoff)
var mutexLock = thread.newlock();

################### SAM INFO

var setupTime = 300;#minimum 'launcher_tilt_time' secs no matter what, due to anim and stuff.
var reload_time = 400;
var launcher_final_tilt_deg  = 35;
var launcher_start_tilt_deg  = 35;
var launcher_tilt_time       =  0;
var sam_align_to_target      =  0;
var launcher_align_to_target =  1;
var align_speed_dps          = 20;
var radar_elevation_above_terrain_m = 25;
var radar_lowest_pitch       = -5;# 0.5 degs = roughly 925 feet at 20 nm, 25 feet at half a nm. # 0.35 = roughly 925 feet at 20 nm, 25 feet at half a nm.

#reaction tme for s-300p is 28 secs acording to http://www.astronautix.com/s/s-300p.html
# sounds a bit high for pmu, as its 4 secs for s-400

################### CIWS INFO

var ciws_installed =   0;
var ciws_domain_nm = 1.50; #range where it can kill
var ciws_chance    = 0.20; #chance to get a kill at 0nm distance
var ciws_burst_rounds = 60;#how many rounds in a burst
var ciws_shell = 15;#from lookup table in damage.nas
var ROUNDS_init       = 30;
var ROUNDS = ROUNDS_init;#CIWS bursts remaining

################### MISSILE INFO

var NUM_MISSILES = 5; # total carried minus 1
var missile_name = "Volga-M";
var missile_brevity = "5Ya23";
var missile_max_distance = 36; #max distance of target in nm when it will fire
var missile_min_distance = 3.5; #minimum distance in nm when it will fire
var lockon_time = 12; #time in seconds it takes to lock on and get a firing solution on a target
var fire_minimum_interval = 7;# time since last track was initiated till a new can be initiated
var same_target_max_missiles = 2;# max number of missiles in air against same target

var isInEngagementEnvelope = func (target_radial_airspeed, target_ground_distance, target_relative_altitude) {
	return 1;
}

var midflight = nil;


##########################################################################
######################## Common SAM code       ###########################
##########################################################################

################### VARIOUS

setprop("sim/multiplay/generic/float[5]", 0);# launcher vert rotation
setprop("sim/multiplay/generic/float[6]", 0);# launcher horiz rotation
var start_time = systime();

var opfor_switch = "enemies/opfor-switch";
setprop(opfor_switch,0);
var friend_switch = "enemies/friend-switch";
setprop(friend_switch,0);

################### IFF

var target = {
	new: func (callsign) {
		var m = { parents: [target] };
		m.callsign = callsign;
		m.in_air = 0;
		m.tracking = 0;
		m.missiles = [];
		return m;
	},
};

var base = props.globals.getNode("/");
base.getNode("instrumentation/transponder/id-code",1).setIntValue(-9999);
base.getNode("instrumentation/transponder/transmitted-id",1).setIntValue(-9999);# transponder off

###################################################################

var targetsV2 = nil;

var buildTargetList = func {
	# rather crappy code, but is not ran so often, so dont really matter.
	if (getprop(opfor_switch) == 0 and getprop(friend_switch) == 0) {
		for(var i = 1; i<=12;i+=1) {
			# add new callsign to list
			var sign = getprop("enemies/e"~i);
			var tgt = lookup(sign);
			if (tgt == nil) {
				targetsV2.append(target.new(sign));
				print("added callsign: "~sign);
			}
		}
	}
	var removeList = [];
	foreach(tgt ; targetsV2.vector) {
		# schedule removed callsigns to be removed
		if (getprop(opfor_switch) == 0 and getprop(friend_switch) == 0) {
			if (tgt.callsign != getprop("enemies/e1") and tgt.callsign != getprop("enemies/e2") and tgt.callsign != getprop("enemies/e3") and tgt.callsign != getprop("enemies/e4") and tgt.callsign != getprop("enemies/e5") and tgt.callsign != getprop("enemies/e6") and tgt.callsign != getprop("enemies/e7") and tgt.callsign != getprop("enemies/e8") and tgt.callsign != getprop("enemies/e9") and tgt.callsign != getprop("enemies/e10") and tgt.callsign != getprop("enemies/e11") and tgt.callsign != getprop("enemies/e12")) {
				append(removeList, tgt);
				print("will remove callsign: "~tgt.callsign);
			}
		}
	}
	foreach(tgt ; removeList) {
		# remove callsigns
		call(func {targetsV2.remove(tgt);}, nil, var err = []);
	}
};

var lookup = func (sign) {
	
	foreach (tgt ; targetsV2.vector) {
		if (tgt.callsign == sign) {
			return tgt;
		}
	}
	if ( getprop(opfor_switch) == 1 and (left(sign, 5) != "OPFOR" and left(sign,5) != "opfor")) {
		print("creating new target in: " ~ sign);
		tgt = target.new(sign);
		targetsV2.append(tgt);
		return tgt;
	}
	if ( getprop(friend_switch) == 1 and ( left(sign, 5) == "OPFOR" or left(sign,5) == "opfor" )) {
		print("creating new target in: " ~ sign);
		tgt = target.new(sign);
		targetsV2.append(tgt);
		return tgt;
	}
	return nil;
}


var PRIO_NORM  = 0;
var PRIO_HIGH  = 1;
var PRIO_LOW   = 2;
var PRIO_FAST  = 3;
var PRIO_SLOW  = 4;
var PRIO_CLOSE = 5;
var PRIO_FAR   = 6;


################### MAIN LOOP

var scan = func() {
	setprop("sim/multiplay/visibility-range-nm", 250);
	buildTargetList();

	if ( getprop("/carrier/sunk") == 1 or getprop("/carrier/disabled") == 1) {
		return;
	}
	
	if (systime() - start_time < setupTime ) {
		printf("Seconds till activation: %.1f", setupTime - (systime() - start_time));
		setprop("sam/timeleft", setupTime - (systime() - start_time));
		setprop("sam/missiles",(NUM_MISSILES+1-ACTIVE_MISSILE));
		setprop("sam/bursts", ROUNDS);
		setprop("sam/info", "Preparing launch system");
		settimer(scan,radar_update_time);
		if (launcher_tilt_time > 0) {
			setprop("sim/multiplay/generic/float[5]", launcher_final_tilt_deg*math.max(0,(systime() - start_time)-(setupTime-launcher_tilt_time))/launcher_tilt_time);#raise the tubes in last 15 secs of activation
		} else {
			setprop("sim/multiplay/generic/float[5]", launcher_final_tilt_deg);
		}
		setprop("sim/multiplay/generic/float[6]", 0);
		setprop("sim/multiplay/generic/string[6]", "");
		setprop("/sim/multiplay/generic/int[2]", 1);
		return;
	}
	setprop("sim/multiplay/generic/float[5]", launcher_final_tilt_deg);
	#### ITERATE THROUGH MP LIST ####
	var radarOn = 0;
	var my_pos = geo.aircraft_position();
	var radarAlt = my_pos.alt()+radar_elevation_above_terrain_m;
	my_pos.set_alt(radarAlt);
	var mvec = props.globals.getNode("/ai/models").getChildren("multiplayer");
	var tvec = props.globals.getNode("/ai/models").getChildren("tanker");
	var avec = props.globals.getNode("/ai/models").getChildren("aircraft");
	if (mvec!=nil and tvec != nil) {
		mvec = mvec ~ tvec;
	}
	if (mvec!=nil and avec != nil) {
		mvec = mvec ~ avec;
	}
	var prio_vector = [];#0:node,1:trigger,2:prio value
	foreach(var mp; mvec){
		if (mp.getNode("valid") == nil or mp.getNode("valid").getValue() != 1) continue;
		var prio = fire_control(mp, my_pos);
		append(prio_vector, prio);
		if (prio[3] == 1) {
			radarOn = 1;#this target is within envelope, we turn on radar.
		}
	}
	prio_vector = sort(prio_vector, func (a,b) {if (a[2]>b[2]){return -1;} elsif (a[2]<b[2]) {return 1;} else {return 0;}});
	foreach(var mp; prio_vector) {
		
		#### DO WE HAVE FIRING SOLUTION... ####
		# is plane in range, do we still have missiles, and is a missile already inbound, and has it been 4 seconds since the last missile launch?
		var trigger = mp[1];
		#print("dist to target = " ~ dist_to_target);
		
		var lu = lookup(mp[0].getNode("callsign").getValue());
		if ( launch_in_progress == 0 and trigger == true and lu != nil and lu.in_air < same_target_max_missiles and !lu.tracking and ACTIVE_MISSILE <= NUM_MISSILES and ( systime() - missile_delay_time > fire_minimum_interval ) ) { #
			#### ... FOR THE MISSILE ####
			#print("callsign " ~ cs ~ " found at " ~ dist_to_target);
			missile_delay_time = systime();
			mp[0].getNode("unique",1).setValue(rand());
			armament.contact = radar_logic.Contact.new(mp[0], AIR);
			launch_in_progress = 1;
			missile_launch(mp[0], systime(), my_pos);
			
		} elsif ( ciws_installed and trigger == -1 and ROUNDS > 0 and ( systime() - ciws_delay_time > 1.0 ) and lu != nil) {
			#### ... FOR THE CIWS ####
			var contact = radar_logic.Contact.new(mp[0], AIR);
			var cord = contact.get_Coord();
			var dist_nm = my_pos.direct_distance_to(cord)*M2NM;
			var probabilityOfBurstKill = 0.50;
			if (mp[0].getNode("velocities/true-airspeed-kt").getValue() > 50) {
				probabilityOfBurstKill = extrapolate(dist_nm, 0, ciws_domain_nm, ciws_chance, 0);
			}
			var hits = math.max(0,int(extrapolate(rand(), 0, probabilityOfBurstKill, ciws_burst_rounds, 3)));#3 is a kill approx
			var target_bearing = my_pos.course_to(cord);
			setprop("sim/multiplay/generic/float[0]", -(target_bearing-getprop("orientation/heading-deg")));#CIWS horiz (inverted)
			setprop("sim/multiplay/generic/float[1]", vector.Math.getPitch(my_pos, cord));#CIWS vert
			setprop("sim/multiplay/generic/bool[0]",1);settimer(func {setprop("sim/multiplay/generic/bool[0]",0);}, 1);# for sound
			if (hits > 0) {
				var msg = notifications.ArmamentNotification.new("mhit", 4, -1*(ciws_shell+1));
	                msg.RelativeAltitude = 0;
	                msg.Bearing = 0;
	                msg.Distance = hits;
	                msg.RemoteCallsign = mp[0].getNode("callsign").getValue();
		        notifications.hitBridgedTransmitter.NotifyAll(msg);
	    		damage.damageLog.push("CIWS fired | rounds remaining: " ~ ROUNDS ~ " | hit on: " ~ mp[0].getNode("callsign").getValue());
	    	}
			print("CIWS fired | bursts remaining: " ~ ROUNDS ~ " | "~hits~" hits on: " ~ mp[0].getNode("callsign").getValue() ~ " @ "~ sprintf("%.1f",dist_nm) ~" nm");
			ciws_delay_time = systime();
			ROUNDS = ROUNDS - 1;
			setprop("sam/bursts", ROUNDS);
			if (ROUNDS == 0) {
				print("Launcher out of shell ammo.");
				settimer(autoreload, reload_time);
				reloading = 1;
				reload_starting = systime();
			}
		} 
		if (lu != nil and lu.tracking) {
			radarOn = 1;
		}
	}

	setprop("/sim/multiplay/generic/int[2]",!radarOn);

	if (launcher_align_to_target and ACTIVE_MISSILE > NUM_MISSILES and systime()-missile_release_time > 2) {
		# rotate launcher back to forward:
		var tgt_dir = 0;
		var cur_dir = getprop("sim/multiplay/generic/float[6]");
		var move_dir = geo.normdeg180(tgt_dir-cur_dir);
		var max_dir = radar_update_time*align_speed_dps*0.25;
		move_dir = math.clamp(move_dir, -max_dir, max_dir);
		setprop("sim/multiplay/generic/float[6]", cur_dir+move_dir);
	}
	if (launch_in_progress == 0) {
		if (reloading) {
			setprop("sam/info", "Reloading");
			setprop("sam/timeleft", reload_time - (systime() - reload_starting));
		} else {
			setprop("sam/info", "");
			setprop("sam/timeleft", 0);
		}
		clearSingleLock();
		thread.lock(mutexLock);
		semi_active_track = nil;
		thread.unlock(mutexLock);
	} else {
		setprop("sam/timeleft", 0);
	}
	if (getprop(getprop("payload/armament/MP-alt-ft")) == 0.0) {
		# reset 'Follow view' to look at launcher
		setprop(getprop("payload/armament/MP-lat"),getprop("position/latitude-deg"));
		setprop(getprop("payload/armament/MP-lon"),getprop("position/longitude-deg"));
		setprop(getprop("payload/armament/MP-alt-ft"),getprop("position/altitude-ft"));
	}
	setprop("sam/missiles",(NUM_MISSILES+1-ACTIVE_MISSILE));
	settimer(scan,radar_update_time);
}

var clearSingleLock = func () {
	thread.lock(mutexLock);
	if (semi_active_track == nil) {
		setprop("sim/multiplay/generic/string[6]", "");
	} else {
		setprop("sim/multiplay/generic/string[6]", left(md5(semi_active_track), 4));
	}
	thread.unlock(mutexLock);
}

################## FIRE CONTROL
################## ALL AI LOGIC RELATED TO FIGURING OUT IF A TARGET SHOULD BE SHOT AT SHOULD GO HERE.

var fire_control = func(mp, my_pos) {
	# gather some data about the target

	if ( mp.getNode("valid").getValue() == false ) { return [mp,false,0,0]; }

	var ufo_pos = geo.Coord.new().set_latlon(mp.getNode("position/latitude-deg").getValue(),mp.getNode("position/longitude-deg").getValue(),(mp.getNode("position/altitude-ft").getValue() * FT2M));
	var target_distance = my_pos.direct_distance_to(ufo_pos);
	var target_altitude = mp.getNode("position/altitude-ft").getValue();
	
	# is this plane a friend or foe?
	var lu = lookup(mp.getNode("callsign").getValue());
	if ( lu == nil ) { return [mp,false,0,0]; }

	var target_airspeed = mp.getNode("velocities/true-airspeed-kt").getValue();
	var target_ground_distance = my_pos.distance_to(ufo_pos);
	var target_heading = mp.getNode("orientation/true-heading-deg").getValue();
	var relative_bearing = math.abs(geo.normdeg180(ufo_pos.course_to(my_pos) - target_heading));
	
	var target_relative_altitude = target_altitude - my_pos.alt()*M2FT;
	var target_radial_airspeed = math.abs(math.abs(((relative_bearing / 90 ) - 1) * target_airspeed));#200kt against us = 200kt, 200kt at angle of us = 0kt, 200kt away from us = 200kt
	var target_relative_pitch = vector.Math.getPitch(my_pos, ufo_pos);
	

	# can the radar see it?
	var data_link_match = false;
#	foreach(var cx; gci.data_receive_callsigns) {
#		if (cx[0] == callsign) {
#			data_link_match = true;
#			#print('tgt confirmed via datalink');
#		}
#	}
	
	var visible = radar_logic.isNotBehindTerrain(mp);


	if (ciws_installed and ROUNDS > 0 and target_distance*M2NM < ciws_domain_nm) {
		#CIWS
		var radarSeeTarget = 1;
		if ( data_link_match == false ) {
			if ( visible[0] == false ) {radarSeeTarget = 0 }
			if ( target_relative_pitch < radar_lowest_pitch ) { radarSeeTarget = 0 } # 
			if ( target_distance*M2NM > 1.0 and visible[1] and math.abs(target_radial_airspeed) < 20 ) {radarSeeTarget = 0 } # i.e. notching with terrain behind
		}
		if (radarSeeTarget and rand() > target_distance*M2NM / ciws_domain_nm) {
			var score = 0;
			var priority = getprop("priority");
			if (priority==PRIO_NORM) {
				# nop
			} elsif (priority==PRIO_HIGH) {
				score = target_altitude;
			} elsif (priority==PRIO_LOW) {
				score = -target_altitude;
			} elsif (priority==PRIO_FAST) {
				score = target_radial_airspeed;
			} elsif (priority==PRIO_SLOW) {
				score = -target_radial_airspeed;
			} elsif (priority==PRIO_CLOSE) {
				score = -target_distance;
			} elsif (priority==PRIO_FAR) {
				score = target_distance;
			}
			return [mp,-1,score,1];
		}
	}

	if ( data_link_match == false ) {
		if (target_airspeed < 60) {return [mp,false,0,0];}
		if ( visible[0] == false ) { return [mp,false,0,0]; }
		if ( target_relative_pitch < radar_lowest_pitch ) { return [mp,false,0,0]; } # 
		if ( visible[1] and math.abs(target_radial_airspeed) < 20 ) { return [mp,false,0,0]; } # i.e. notching, landed aircraft
	}
	
	if ( target_distance * M2NM > missile_max_distance ) { return [mp,false,0,0]; }

	
	
	
	# is the plane within the engagement envelope?
	# the numbers after target_radial_airspeed are ( offset_of_engagement_envelope / speed_to_apply_that_offset )
	# larger offset means it wont fire until the plane is closer.
	# for visualization: https://www.desmos.com/calculator/gw570fa9km
	
	if (!isInEngagementEnvelope(target_radial_airspeed, target_ground_distance, target_relative_altitude) ) { return [mp,false,0,0]; }	

	

	var the_dice = rand();
	
	if ( the_dice > 0.20 ) {
		var score = 0;
		var priority = getprop("priority");
		if (priority==PRIO_NORM) {
			# nop
		} elsif (priority==PRIO_HIGH) {
			score = target_altitude;
		} elsif (priority==PRIO_LOW) {
			score = -target_altitude;
		} elsif (priority==PRIO_FAST) {
			score = target_radial_airspeed;
		} elsif (priority==PRIO_SLOW) {
			score = -target_radial_airspeed;
		} elsif (priority==PRIO_CLOSE) {
			score = -target_distance;
		} elsif (priority==PRIO_FAR) {
			score = target_distance;
		}
		return [mp,true,score,1];
	} else {
		return [mp,false,0,1];
	}
}

################### MISSILE CONTROL


### missile reload

var reload = func(force = 1) {
	#figure out how many to add
	if (ACTIVE_MISSILE > NUM_MISSILES or force == 1) {
		for ( var i = 0; i <= NUM_MISSILES; i = i + 1 ) {

			if (armament.AIM.new(i,missile_name,missile_brevity, midflight) != -1) {
				#if statement just in case reload was called before all missiles were fired. Cause avoid calling search() on same missile twice.
				armament.AIM.active[i].start();
			}
		}
		ACTIVE_MISSILE = 0;setprop("active", 0);
		print("Launcher reloaded with "~(NUM_MISSILES+1)~" missiles.");
		setprop("/sim/messages/copilot", "Launcher reloaded with "~(NUM_MISSILES+1)~" missiles.");
	}
	if (ROUNDS == 0 or force == 1) {
		ROUNDS = ROUNDS_init;
		print("Reloaded with "~(ROUNDS)~" bursts.");
	}	
	setprop("sam/missiles",(NUM_MISSILES+1-ACTIVE_MISSILE));
	setprop("sam/bursts", ROUNDS);
	reloading = 0;
}

var autoreload = func() {
	if (reloading) {
		reloading = 0;
		if (ACTIVE_MISSILE > NUM_MISSILES or ROUNDS == 0) {
			reload(0);
			print("Auto reloading completed.")
		}
	} else {
		print("Auto reloading cancelled due to manual reload.")
	}
}

### missile launch

var missile_launch = func(mp, launchtime, my_pos) {
	if ( getprop("/carrier/sunk") == 1 or getprop("/carrier/disabled") == 1) {
		var lu = lookup(mp.getNode("callsign").getValue());
		if (lu != nil) {
			lu.tracking = 0;
		}
		launch_in_progress = 0;
		clearSingleLock();
		return;
	}
	var ufo_pos = geo.Coord.new().set_latlon(mp.getNode("position/latitude-deg").getValue(),mp.getNode("position/longitude-deg").getValue(),(mp.getNode("position/altitude-ft").getValue() * 0.3048));
	var target_bearing = my_pos.course_to(ufo_pos);
	var info = mp.getNode("callsign").getValue();
	var lu = lookup(mp.getNode("callsign").getValue());
	if (getprop("sam/timeleft") != 0) {
		launch_in_progress = 0;
		if (lu != nil) {
			lu.tracking = 0;
		}
		return;
	} elsif ( armament.AIM.active[ACTIVE_MISSILE].status == 1 and systime() - launchtime > lockon_time and radar_logic.isNotBehindTerrain(mp)[0] == 1 ) {
		var theMissile = armament.AIM.active[ACTIVE_MISSILE];
		var brevity = theMissile.brevity;
		#armament.defeatSpamFilter(brevity ~ " at: " ~ mp.getNode("callsign").getValue());
		damage.damageLog.push(brevity ~ " at: " ~ mp.getNode("callsign").getValue());
		if (launcher_align_to_target) {
			setprop("sim/multiplay/generic/float[6]", target_bearing-getprop("orientation/heading-deg"));
			theMissile.rail_head_deg = getprop("sim/multiplay/generic/float[6]");
		}
		if (sam_align_to_target) {
			setprop("/orientation/heading-deg",target_bearing);
		}
		theMissile.release();
		missile_release_time = systime();
		ACTIVE_MISSILE = ACTIVE_MISSILE + 1;setprop("active", ACTIVE_MISSILE);
		print("Fired "~missile_name~" #" ~ ACTIVE_MISSILE ~ " at: " ~ mp.getNode("callsign").getValue());
		setprop("/sim/messages/copilot", "Launch at "~mp.getNode("callsign").getValue());
		if (ACTIVE_MISSILE > NUM_MISSILES) {
			setprop("/sim/messages/copilot", "Launcher out of ammo");
			print("Launcher out of missile ammo.");
			settimer(autoreload, reload_time);
			reloading = 1;
			reload_starting = systime();
		}		
		if (lu != nil) {
			append(lu.missiles, theMissile);
			lu.in_air += 1;
			lu.tracking = 0;
		}
		launch_in_progress = 0;
		info = info~" (launched)";
		setprop("sam/info", info);
		setprop("sam/missiles",(NUM_MISSILES+1-ACTIVE_MISSILE));
		clearSingleLock();
		return;
	} elsif ((systime() - launchtime) > (lockon_time*2) or radar_logic.isNotBehindTerrain(mp)[0] == 0) {
		# launch cancelled so it dont forever goes in this loop and dont allow for other firings.
		if (lu != nil) {
			lu.tracking = 0;
		}
		setprop("/sim/messages/copilot", "SAM Canceled launch at "~mp.getNode("callsign").getValue());
		launch_in_progress = 0;
		info = info~" (cancelled)";
		setprop("sam/info", info);
		setprop("sam/missiles",(NUM_MISSILES+1-ACTIVE_MISSILE));
		clearSingleLock();
		return;
	} else {
		info = info~" (tracking)";
		if (systime()-missile_release_time > 1.5) {
			if (launcher_align_to_target) {
				# now smoothly rotate launcher:
				var tgt_dir = target_bearing-getprop("orientation/heading-deg");
				var cur_dir = getprop("sim/multiplay/generic/float[6]");
				var move_dir = geo.normdeg180(tgt_dir-cur_dir);
				var max_dir = launch_update_time*align_speed_dps;
				move_dir = math.clamp(move_dir, -max_dir, max_dir);
				setprop("sim/multiplay/generic/float[6]", cur_dir+move_dir);
			}
			if (sam_align_to_target) {
				var tgt_dir = target_bearing;
				var cur_dir = getprop("orientation/heading-deg");
				var move_dir = geo.normdeg180(tgt_dir-cur_dir);
				var max_dir = launch_update_time*align_speed_dps;
				move_dir = math.clamp(move_dir, -max_dir, max_dir);
				setprop("orientation/heading-deg", cur_dir+move_dir);
			}
		}

		setprop("sam/info", info);
		if (mp.getNode("callsign") != nil and mp.getNode("callsign").getValue() != nil and mp.getNode("callsign").getValue() != "") {
	        setprop("sim/multiplay/generic/string[6]", left(md5(mp.getNode("callsign").getValue()), 4));
	    } else {
	        clearSingleLock();
	    }
	    if (lu != nil) {
			lu.tracking = 1;
		}
	}
	settimer( func { missile_launch(mp, launchtime, my_pos); },launch_update_time);
}

### missile set launched to false for target

var missile_listener = func {
	foreach(var tgt ; targetsV2.vector) {
		var missilesNew = [];
		foreach(var missile ; tgt.missiles) {
			if (missile != nil) {
				if (missile.deleted) {
					tgt.in_air -= 1;
				} else {
					append(missilesNew, missile);
				}
			}
		}
		tgt.missiles = missilesNew;
	}
	settimer(missile_listener, 2.5);
}

var extrapolate = func (x, x1, x2, y1, y2) {
   	return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
}

################### MISC

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	print("fdm-initialized");
	targetsV2 = std.Vector.new();# OO vector (to make removing item easier)
	reload();
	scan();
	aircraft.data.save(0.5);# save the target list every 30 seconds
	removelistener(main_init_listener);
	setlistener(opfor_switch, func {
		targetsV2 = std.Vector.new();# OO vector (to make removing item easier)
	 	}, 0, 0);
	setlistener(friend_switch, func {
		targetsV2 = std.Vector.new();# OO vector (to make removing item easier)
	 	}, 0, 0);
	missile_listener();
	setprop(getprop("payload/armament/MP-lat"),getprop("position/latitude-deg"));
	setprop(getprop("payload/armament/MP-lon"),getprop("position/longitude-deg"));
	setprop(getprop("payload/armament/MP-alt-ft"),getprop("position/altitude-ft"));
	view.setViewByIndex(200);#follow view
}, 0, 0);

setlistener("sim/signals/reinit", func {
	print("reinit");
	start_time = systime();
});