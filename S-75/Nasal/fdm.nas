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
	settimer( PositionUpdater, 1/frequency );

	var position = geo.aircraft_position();
	var elev0 = geo.elevation(position.lat(),position.lon());

	if (elev0 == nil) return;

	var geodPos = aircraftToCart({x:0, y:40, z: 0});
	var co = geo.Coord.new();
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	var elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sam/a", elev-elev0);
		setprop("controls/armament/station[1]/offsets/z-m", elev-elev0+3.4);
	} else {
		setprop("sam/a", 0);
		setprop("controls/armament/station[1]/offsets/z-m", 3.4);
	}
	geodPos = aircraftToCart({x:0, y:-40, z: 0});
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sam/b", elev-elev0);
		setprop("controls/armament/station[2]/offsets/z-m", elev-elev0+3.4);
	} else {
		setprop("sam/b", 0);
		setprop("controls/armament/station[2]/offsets/z-m", 3.4);
	}
	geodPos = aircraftToCart({x:-40, y:0, z: 0});
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sam/c", elev-elev0);
		setprop("controls/armament/station[3]/offsets/z-m", elev-elev0+3.4);
	} else {
		setprop("sam/c", 0);
		setprop("controls/armament/station[3]/offsets/z-m", 3.4);
	}
	geodPos = aircraftToCart({x:40, y:0, z: 0});
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sam/d", elev-elev0);
		setprop("controls/armament/station[4]/offsets/z-m", elev-elev0+3.4);
	} else {
		setprop("sam/d", 0);
		setprop("controls/armament/station[4]/offsets/z-m", 3.4);
	}
	geodPos = aircraftToCart({x:0, y:0, z: 0});
	co.set_xyz(geodPos.x, geodPos.y, geodPos.z);
	elev = geo.elevation(co.lat(),co.lon());
	if (elev != nil) {
		setprop("sam/e", elev-elev0);
		setprop("controls/armament/station[5]/offsets/z-m", elev-elev0+3.4);
	} else {
		setprop("sam/e", 0);
		setprop("controls/armament/station[5]/offsets/z-m", 3.4);
	}
};

PositionUpdater();