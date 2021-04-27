# Copyright (C) 2015  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#io.include("Aircraft/ExpansionPack/Nasal/init.nas");

#with("updateloop");

print("loading fdm");

# Number of iterations per second
var frequency = 60.0;

# Change in heading per second at full rudder deflection
var heading_ps = 0.5;

time_last = 0;
sim_speed = 1;

var speed = 25;
var last_type = 0;

setprop("/carrier/pitch-deg",0);
setprop("/carrier/pitch-offset",0);
setprop("/carrier/roll-deg",0);
setprop("/carrier/roll-offset",0);
setprop("/carrier/sunk",0);
var arrived = 0;
var PositionUpdater = func () {
	
	settimer( PositionUpdater, 1/frequency );
	
	var position = geo.aircraft_position();

	if ( arrived == 0 and getprop("/carrier/sunk") == 0 and getprop("/autopilot/route-manager/wp-last/dist") != nil and getprop("/autopilot/route-manager/wp-last/dist") < 1 ) {
		setprop("/sim/multiplay/chat",getprop("sim/multiplay/callsign") ~ " has arrived safely!");
		print("arrived");
		arrived = 1;
		#return;
	}
	
	var time_now = getprop("/sim/time/elapsed-sec");
	var dt = (time_now - time_last) * sim_speed;
	if (dt == 0) return;

	time_last = time_now;
	
	#var heading = getprop("/orientation/heading-deg");
	#var speed   = getprop("/velocities/groundspeed-kt");
	var rudder  = getprop("/surface-positions/rudder-pos-norm");
	
	if ( getprop("/carrier/sunk") == 0 and getprop("/autopilot/route-manager/active") == 1 ) {
	
		#for event
		
		var cur_waypoint = getprop("/autopilot/route-manager/current-wp");
		var cur_wp_lon = getprop("/autopilot/route-manager/route/wp[" ~ cur_waypoint ~ "]/longitude-deg");
		var cur_wp_lat = getprop("/autopilot/route-manager/route/wp[" ~ cur_waypoint ~ "]/latitude-deg");
		var rm_destination = geo.Coord.new().set_latlon(cur_wp_lat,cur_wp_lon);
		
		
		var heading = position.course_to(rm_destination);
		
		var distance = speed * globals.KT2MPS * dt;
		position.apply_course_distance(heading, distance);
		
		# Set new position
		setprop("/position/latitude-deg", position.lat());
		setprop("/position/longitude-deg", position.lon());
		var g_alt = getprop("/position/ground-elev-ft")+1;
		setprop("/position/altitude-ft",g_alt);

		
		

		# Update heading
		var course = heading + rudder * heading_ps * dt;
		setprop("/orientation/heading-deg", course);
		setprop("velocities/groundspeed-kt",speed);
	} else {
		setprop("velocities/groundspeed-kt",0);
	}
	
	#set pitch
	setprop("/orientation/pitch-deg",getprop("/carrier/pitch-deg") + getprop("/carrier/pitch-offset"));
	
	#set roll
	setprop("/orientation/roll-deg",getprop("/carrier/roll-deg") + getprop("/carrier/roll-offset"));	


	var type = getprop("sim/multiplay/generic/int[17]");
	if (type != last_type) {
		if (damage.hp_max == damage.hp) {
			if (type == 0) {damage.hp_max=5;damage.hp=5;speed=25;}#humvee
			if (type == 1) {damage.hp_max=100;damage.hp=100;speed=15;}#tank
			if (type == 2) {damage.hp_max=75;damage.hp=75;speed=10;}#rocket launcher
			if (type == 3) {damage.hp_max=85;damage.hp=85;speed=20;}#small tank
			if (type == 4) {damage.hp_max=80;damage.hp=80;speed=20;}#APC (mine proected)
			if (type == 5) {damage.hp_max=75;damage.hp=75;speed=20;}#APC
			last_type = type;
		} else {
			print("Can only switch type when not damaged!!");
			setprop("sim/multiplay/generic/int[17]", last_type);
		}
	}
	
};

PositionUpdater();