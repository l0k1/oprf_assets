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
var frequency = 60.0;

# Change in heading per second at full rudder deflection
var heading_ps = 0.5;

time_last = 0;
sim_speed = 1;

setprop("/carrier/pitch-deg",0);
setprop("/carrier/pitch-offset",0);
setprop("/carrier/roll-deg",0);
setprop("/carrier/roll-offset",0);
setprop("/carrier/sunk",0);

var last_type = getprop("sim/multiplay/generic/int[17]");

var PositionUpdater = func () {
	
	# does a building need an FDM?
	# nawwwwwww
	setprop("sim/multiplay/visibility-range-nm", 750);
	var type = getprop("sim/multiplay/generic/int[17]");
	if (type != last_type) {
		if (damage.hp_max == damage.hp) {
			if (type == 0) {damage.hp_max=900;damage.hp=900;}
			if (type == 1) {damage.hp_max=1000;damage.hp=1000;}
			if (type == 2) {damage.hp_max=200;damage.hp=200;}
			if (type == 3) {damage.hp_max=300;damage.hp=300;}
			if (type == 4) {damage.hp_max=900;damage.hp=900;}
			if (type == 5) {damage.hp_max=1500;damage.hp=1500;}
			if (type == 6) {damage.hp_max=450;damage.hp=450;}
			if (type == 7) {damage.hp_max=0;damage.hp=0;}
			last_type = type;
		} else {
			print("Can only switch type when not damaged!!");
			setprop("sim/multiplay/generic/int[17]", last_type);
		}
	}
	settimer( PositionUpdater, 1/frequency );
	
};

PositionUpdater();