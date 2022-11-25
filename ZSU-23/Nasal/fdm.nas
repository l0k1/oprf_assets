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
var heading_ps = 20;

var time_last = 0;
var sim_speed = 1;

var distance = 0;

var speed = 15;

setprop("/carrier/sunk",0);
setprop("/orientation/pitch-deg", 0);

#var arrived = 0;
var PositionUpdater = func () {
	
	settimer( PositionUpdater, 1/frequency );
	
	var position = geo.aircraft_position();

	#if ( arrived == 0 and getprop("/carrier/sunk") == 0 and getprop("/autopilot/route-manager/wp-last/dist") != nil and getprop("/autopilot/route-manager/wp-last/dist") < 1 ) {
		#setprop("/sim/multiplay/chat",getprop("sim/multiplay/callsign") ~ " has arrived safely!");
	#	print("arrived");
	#	arrived = 1;
		#return;
	#}
	
	var time_now = getprop("/sim/time/elapsed-sec");
	var dt = (time_now - time_last) * sim_speed;
	if (dt == 0) return;

	time_last = time_now;
	
	
	if ( getprop("/carrier/sunk") == 0 and getprop("/autopilot/route-manager/active") == 1 ) {
	
		
		var cur_waypoint = getprop("/autopilot/route-manager/current-wp");
		if (cur_waypoint > -1) {
			var cur_wp_lon = getprop("/autopilot/route-manager/route/wp[" ~ cur_waypoint ~ "]/longitude-deg");
			var cur_wp_lat = getprop("/autopilot/route-manager/route/wp[" ~ cur_waypoint ~ "]/latitude-deg");
			var rm_destination = geo.Coord.new().set_latlon(cur_wp_lat,cur_wp_lon);
			
			var heading = getprop("/orientation/heading-deg");
			
			var course = position.course_to(rm_destination);
			
			distance = speed * KT2MPS * dt;

			var turn_max = heading_ps * dt;

			var turn = math.clamp(geo.normdeg180(course-heading),-turn_max,turn_max);
			
			heading += turn;

			heading = geo.normdeg(heading);

			position.apply_course_distance(heading, distance);

			
			
			# Set new position
			setprop("/position/latitude-deg", position.lat());
			setprop("/position/longitude-deg", position.lon());
			
			setprop("/orientation/heading-deg", heading);
			setprop("velocities/groundspeed-kt",speed);
		} else {
			setprop("velocities/groundspeed-kt",0);
		}
		var g_alt = geo.elevation(position.lat(),position.lon());#getprop("/position/ground-elev-ft");
		if (g_alt == nil) g_alt = 0;
		g_alt *= M2FT;

		var alt_diff = g_alt - getprop("/position/altitude-ft");

		var pitch = math.atan2(alt_diff, distance*M2FT)*R2D;

		setprop("/orientation/pitch-deg", pitch);

		setprop("/position/altitude-ft",g_alt);
	} else {
		setprop("velocities/groundspeed-kt",0);
	}
	
		
	#set roll
	setprop("/orientation/roll-deg", 0);	
	
};

PositionUpdater();