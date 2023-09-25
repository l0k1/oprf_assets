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
srand();# seed the random generator with systime
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

var last_type = -1;

var PositionUpdater = func () {
	
	# does a building need an FDM?
	# nawwwwwww
	setprop("sim/multiplay/visibility-range-nm", 750);
	var type = getprop("sim/multiplay/generic/int[17]");
	if (type != last_type) {
		if (damage.hp_max == damage.hp) {
			if (type == 0) {damage.hp_max=900;damage.hp=damage.hp_max;}
			if (type == 1) {damage.hp_max=500;damage.hp=damage.hp_max;}
			if (type == 2) {damage.hp_max=200;damage.hp=damage.hp_max;}
			if (type == 3) {damage.hp_max=300;damage.hp=damage.hp_max;}
			if (type == 4) {damage.hp_max=900;damage.hp=damage.hp_max;}
			if (type == 5) {damage.hp_max=1500;damage.hp=damage.hp_max;}
			if (type == 6) {damage.hp_max=450;damage.hp=damage.hp_max;}
			if (type == 7) {damage.hp_max=0;damage.hp=damage.hp_max;}
			if (type == 8) {damage.hp_max=300;damage.hp=damage.hp_max;}
			if (type == 9) {damage.hp_max=300;damage.hp=damage.hp_max;}
			if (type == 10) {damage.hp_max=500;damage.hp=damage.hp_max;}
			if (type == 11) {damage.hp_max=200;damage.hp=damage.hp_max;}
			if (type == 12) {damage.hp_max=0;damage.hp=damage.hp_max;}
			if (type == 14) {damage.hp_max=600;damage.hp=damage.hp_max;}
			if (type == 15) {damage.hp_max=1400;damage.hp=damage.hp_max;}
			if (type == 16) {damage.hp_max=100;damage.hp=damage.hp_max;}
			if (type == 17) {damage.hp_max=300;damage.hp=damage.hp_max;}
			if (type == 18) {damage.hp_max=50;damage.hp=damage.hp_max;}
			if (type == 19) {damage.hp_max=2500;damage.hp=damage.hp_max;}
			if (type == 20) {damage.hp_max=300;damage.hp=damage.hp_max;}
			last_type = type;
		} else {
			print("Can only switch type when not damaged!!");
			setprop("sim/multiplay/generic/int[17]", last_type);
		}
	}
	settimer( PositionUpdater, 1/frequency );
	
};

PositionUpdater();