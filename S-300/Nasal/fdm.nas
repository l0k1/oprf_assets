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

# Number of iterations per second
var frequency = 10.0;

# Change in heading per second at full rudder deflection
var heading_ps = 0.5;

time_last = 0;
sim_speed = 1;

setprop("/carrier/pitch-deg",0);
setprop("/carrier/pitch-offset",0);
setprop("/carrier/roll-deg",0);
setprop("/carrier/roll-offset",0);
setprop("/carrier/sunk",0);

var PositionUpdater = func () {
	var position = geo.aircraft_position();
	var elev0 = geo.elevation(position.lat(),position.lon());

	if (elev0 == nil) elev0 = 0;

	var geodPos = aircraftToCart({x:0, y:50, z: 0});
	var co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	var elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sim/multiplay/generic/float[10]", elev-elev0);
		setprop("controls/armament/station[1]/offsets/z-m", elev-elev0+3.8);
		setprop("controls/armament/station[2]/offsets/z-m", elev-elev0+3.8);
		setprop("controls/armament/station[3]/offsets/z-m", elev-elev0+3.8);
		setprop("controls/armament/station[4]/offsets/z-m", elev-elev0+3.8);
	} else {
		setprop("sim/multiplay/generic/float[10]", 0);
		setprop("controls/armament/station[1]/offsets/z-m", 3.8);
		setprop("controls/armament/station[2]/offsets/z-m", 3.8);
		setprop("controls/armament/station[3]/offsets/z-m", 3.8);
		setprop("controls/armament/station[4]/offsets/z-m", 3.8);
	}

	geodPos = aircraftToCart({x:40, y:-40, z: 0});
	co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sim/multiplay/generic/float[11]", elev-elev0);
	} else {
		setprop("sim/multiplay/generic/float[11]", 0);
	}

	# not used:
	geodPos = aircraftToCart({x:0, y:-40, z: 0});
	co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sim/multiplay/generic/float[12]", elev-elev0);
	} else {
		setprop("sim/multiplay/generic/float[12]", 0);
	}

	geodPos = aircraftToCart({x:-40, y:-40, z: 0});
	co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sim/multiplay/generic/float[13]", elev-elev0);
	} else {
		setprop("sim/multiplay/generic/float[13]", 0);
	}

	# not used:
	geodPos = aircraftToCart({x:40, y:40, z: 0});
	co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sim/multiplay/generic/float[14]", elev-elev0);
	} else {
		setprop("sim/multiplay/generic/float[14]", 0);
	}


	settimer( PositionUpdater, 1/frequency );
	return;

	
	var position = geo.aircraft_position();
	
	var time_now = getprop("/sim/time/elapsed-sec");
	var dt = (time_now - time_last) * sim_speed;
	if (dt == 0) {settimer( PositionUpdater, 1/frequency ); return;}

	time_last = time_now;
	
	var heading = getprop("/orientation/heading-deg");
	var speed   = getprop("/velocities/groundspeed-kt");
	var rudder  = getprop("/surface-positions/rudder-pos-norm");
	
	var distance = speed * globals.KT2MPS * dt;
	position.apply_course_distance(heading, distance);
	
	# Set new position
	setprop("/position/latitude-deg", position.lat());
	setprop("/position/longitude-deg", position.lon());
	setprop("/position/altitude-ft", getprop("/position/ground-elev-ft"));

	
	if ( getprop("/carrier/sunk") == 0 ) {

	# Update heading
		var course = heading + rudder * heading_ps * dt;
		setprop("/orientation/heading-deg", course);
	
	} else { 
		return;
	}
	
	#set pitch
	setprop("/orientation/pitch-deg",getprop("/carrier/pitch-deg") + getprop("/carrier/pitch-offset"));
	
	#set roll
	setprop("/orientation/roll-deg",getprop("/carrier/roll-deg") + getprop("/carrier/roll-offset"));	
	
	settimer( PositionUpdater, 1/frequency );
	
};

PositionUpdater();