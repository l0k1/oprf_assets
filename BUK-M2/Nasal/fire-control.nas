################### GLOBALS

var false = 0;
var true = 1;

var radar_update_time = 2;
var launch_update_time = 0.3;

var missile_delay_time = 0;
var ciws_delay_time = 0;

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

var ACTIVE_MISSILE = 0;
var NUM_MISSILES = 3; # total carried minus 1
var ROUNDS = 30;
var RELOAD_TIME = 600;

################### MISSILE INFO

var missile_name = "M317";
var missile_brevity = "Grizzly";
var missile_max_distance = 31; #max distance in nm
var missile_min_distance = 2; #minimum distance in nm
var lockon_time = 12; #time in seconds it takes to lock on to a target
var launch_in_progress = 0;

################### IFF

var target = {
	new: func (callsign) {
		var m = { parents: [target] };
		m.callsign = callsign;
		m.fired = false;
		return m;
	},
};
	
var targets = {
	"pinto": target.new("pinto"),
	"Leto": target.new("Leto"),
	"YV-187": target.new("YV-187"),
	"swamp": target.new("swamp"),
	"S": target.new("S"),
	"G-UNTER": target.new("G-UNTER"),
	"J-Mav16": target.new("J-Mav16"),
	"Raider1": target.new("Raider1"),
	"AF-MA13": target.new("AF-MA13"),
	"KOL24M": target.new("KOL24M"),
	"SNOWY1": target.new("SNOWY1"),
	"Evading-target": target.new("Evading-target"),# for testing with AI targets
	"Slow-evading-target": target.new("Slow-evading-target"),
};

################### MAIN LOOP

var scan = func() {
	if ( getprop("/carrier/sunk") == 1 ) {
		return;
	}
	
	#### ITERATE THROUGH MP LIST ####
	var my_pos = geo.aircraft_position();
	foreach(var mp; props.globals.getNode("/ai/models").getChildren("multiplayer")){#change to "aircraft" to shoot at scenario AI planes.
		#### DO WE HAVE FIRING SOLUTION... ####
		# is plane in range, do we still have missiles, and is a missile already inbound, and has it been 4 seconds since the last missile launch?
		var trigger = fire_control(mp, my_pos);
		#print("dist to target = " ~ dist_to_target);
		#### ... FOR THE MISSILE ####
		if ( launch_in_progress == 0 and trigger == true and targets[mp.getNode("callsign").getValue()].fired == false and ACTIVE_MISSILE <= NUM_MISSILES and ( systime() - missile_delay_time > 7 ) ) { #
			#print("callsign " ~ cs ~ " found at " ~ dist_to_target);
			missile_delay_time = systime();
			targets[mp.getNode("callsign").getValue()].fired = true;
			mp.getNode("unique",1).setValue(rand());
			armament.contact = radar_logic.Contact.new(mp, AIR);
			missile_launch(mp, systime(), my_pos);
			launch_in_progress = 1;
		#### ... FOR THE CIWS 
		# disabled
		}
	}
	settimer(scan,radar_update_time);
}

################## FIRE CONTROL
################## ALL AI LOGIC RELATED TO FIGURING OUT IF A TARGET SHOULD BE SHOT AT SHOULD GO HERE.

var fire_control = func(mp, my_pos) {
	#gather some data about the target
	var ufo_pos = geo.Coord.new().set_latlon(mp.getNode("position/latitude-deg").getValue(),mp.getNode("position/longitude-deg").getValue(),(mp.getNode("position/altitude-ft").getValue() * 0.3048));
	var target_distance = my_pos.direct_distance_to(ufo_pos) * .000539957; #in nautical miles
	var target_heading = mp.getNode("orientation/true-heading-deg").getValue();
	var target_bearing = my_pos.course_to(ufo_pos);
	var relative_bearing = math.abs(ufo_pos.course_to(my_pos) - target_heading);
	var target_altitude = mp.getNode("position/altitude-ft").getValue();
	var target_airspeed = mp.getNode("velocities/true-airspeed-kt").getValue();

	# can the radar see it?
	if ( mp.getNode("valid").getValue() == false ) { return false; }
	if ( radar_logic.isNotBehindTerrain(mp) == false ) { return false; }
	if ( target_airspeed < 40 ) { return false; }
	if ( target_altitude - props.globals.getNode("/position/altitude-ft").getValue() < 150 ) { return false; }
	if ( target_altitude > 70000 ) { return false; }
	if ( target_distance > missile_max_distance ) { return false; }
	# is this plane a friend or foe?
	if ( targets[mp.getNode("callsign").getValue()] == nil ) { return false; }
	
	#should we shoot? using linear interpolation, with minimum probability of 0.01 to 0.10 and maximum probability of 1
	var distance_probability = 1 + (0.01 - 1) * (( target_distance - missile_min_distance ) / ( missile_max_distance - missile_min_distance ));
	var bearing_probability = 1 + (0.05 - 1) * (( relative_bearing ) / ( 180 ));
	var altitude_probability = 1 + (0.05 - 1) * (( target_altitude - 150 ) / ( 70000 - 150 ));
	var speed_probability = distance_probability / 2.5 + (1 - distance_probability / 2.5) * (( target_airspeed - 1000 ) / ( 40 - 1000 ));
	
	var distance_weight = 0.4;
	var bearing_weight = 0.3;
	var altitude_weight = 0.2;
	var speed_weight = 0.1;
	
	var fire_probability = (distance_probability * distance_weight) + (bearing_probability * bearing_weight) + (altitude_probability * altitude_weight) + (speed_probability * speed_weight);
	var the_dice = rand();
	
	print("probability for " ~ mp.getNode("callsign").getValue() ~ ": "~fire_probability);
	
	if ( fire_probability > 0.60 and fire_probability > the_dice ) {
		return true;
	} else {
		return false;
	}
}

################### MISSILE CONTROL

### missile reload

var reload = func() {
	#figure out how many to add
	for ( var i = 0; i <= NUM_MISSILES; i = i + 1 ) {
		if (armament.AIM.new(i,missile_name,missile_brevity) != -1) {
			#if statement just in case reload was called before all missiles were fired. Cause avoid calling search() on same missile twice.
			armament.AIM.active[i].status = 0;
			armament.AIM.active[i].search();
		}
	}
	ACTIVE_MISSILE = 0;
	print("SAM reloaded with "~(NUM_MISSILES+1)~" missiles.");
}

### missile launch

var missile_launch = func(mp, launchtime, my_pos) {
	var ufo_pos = geo.Coord.new().set_latlon(mp.getNode("position/latitude-deg").getValue(),mp.getNode("position/longitude-deg").getValue(),(mp.getNode("position/altitude-ft").getValue() * 0.3048));
	var target_bearing = my_pos.course_to(ufo_pos);
	setprop("/orientation/heading-deg",target_bearing);
	if ( armament.AIM.active[ACTIVE_MISSILE].status == 1 and systime() - launchtime > lockon_time and radar_logic.isNotBehindTerrain(mp) == true ) {
		var brevity = armament.AIM.active[ACTIVE_MISSILE].brevity;
		armament.AIM.active[ACTIVE_MISSILE].release();
		defeatSpamFilter(brevity ~ " at: " ~ mp.getNode("callsign").getValue());
		ACTIVE_MISSILE = ACTIVE_MISSILE + 1;
		print("Fired "~missile_name~" #" ~ ACTIVE_MISSILE ~ " at: " ~ mp.getNode("callsign").getValue());
		launch_in_progress = 0;
		return;
	} elsif ((systime() - launchtime) > (lockon_time*3) or radar_logic.isNotBehindTerrain(mp) == false) {
		# launch cancelled so it dont forever goes in this loop and dont allow for other firings.
		launch_in_progress = 0;
		return;
	}
	settimer( func { missile_launch(mp, launchtime, my_pos); },launch_update_time);
}

### missile set launched to false for target

var incoming_listener = func {
	var history = getprop("/sim/multiplay/chat-history");
	var hist_vector = split("\n", history);
	if (size(hist_vector) > 0) {
		var last = hist_vector[size(hist_vector)-1];
		var last_vector = split(":", last);
		var author = last_vector[0];
		var callsign = getprop("sim/multiplay/callsign");
		if (size(last_vector) > 1 and author == callsign) {
			var last1 = split(" ", last_vector[1]);
			print(last1);
			if(size(last1) > 2 and (last1[size(last1)-1] == "exploded" or last1[size(last1)-1] == "disarmed") ) {
				print("missile hit");
				if (size(last_vector) > 3) {
					#print("that someone is me!");
					var type = last1[1];
					#callsign = target, type = missile
					last_vector[3] = right(last_vector[3],size(last_vector[3]) - 1);
					if ( targets[last_vector[3]] != nil and type == missile_name ) {
						targets[last_vector[3]].fired = false;
					}
				}
			} elsif(size(last1) > 2 and last1[size(last1)-2] == "missed" ) {
				print("missile missed");
				var target = last1[size(last1)-1];
				var type = last1[1];
				#callsign = target, type = missile
				last_vector[3] = right(last_vector[3],size(last_vector[3]) - 1);
				if (targets[target] != nil and type == missile_name) {
					targets[target].fired = false;
				}
			} 
		}
	}
}


################### MISC

var spams = 0;
var spamList = [];

var defeatSpamFilter = func (str) {
  spams += 1;
  if (spams == 15) {
    spams = 1;
  }
  str = str~":";
  for (var i = 1; i <= spams; i+=1) {
    str = str~".";
  }
  var newList = [str];
  for (var i = 0; i < size(spamList); i += 1) {
    append(newList, spamList[i]);
  }
  spamList = newList;  
}

var spamLoop = func {
  var spam = pop(spamList);
  if (spam != nil) {
    setprop("/sim/multiplay/chat", spam);
  }
  settimer(spamLoop, 1.20);
}

spamLoop();

reload();
scan();
setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);