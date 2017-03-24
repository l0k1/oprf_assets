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

var PositionUpdater = func () {
	
	# does a building need an FDM?
	# nawwwwwww
	
	settimer( PositionUpdater, 1/frequency );
	
};

PositionUpdater();