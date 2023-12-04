

################### SAM INFO ###################

var setupTime = 300;#minimum 'launcher_tilt_time' secs no matter what, due to anim and stuff.
var reload_time = 300;
var launcher_final_tilt_deg  = 33;
var launcher_start_tilt_deg  =  0;
var launcher_tilt_time       = 15;
var sam_align_to_target      =  0;
var launcher_align_to_target =  1;
var align_speed_dps          = 20;
var radar_elevation_above_terrain_m = 6.9;#estimate - Low Blow is around 25 ft (CIA)
var radar_lowest_pitch       = 0.4;# 0.5 degs = roughly 925 feet at 20 nm, 25 feet at half a nm. # 0.35 = roughly 925 feet at 20 nm, 25 feet at half a nm.
var radar_off_time_min         = 4;# When turning off to lure enemies into engagement zone, and to not make the SAM too easy to find, minimum turn off this duration.
var radar_off_time_max         = 8;# Bigger missile_max_distance give crew incentive to keep this a bit longer
var radar_on_time              = 45;# Minimum the time it would take to scan whole sky
var radar_on_after_detect_time = 180;# Crew is alert after spotting an aircraft, how long should they stay that way?
var can_detect_anti_rad        = 0.15;# 0.5 very good, 0 not at all.

#reaction tme for s-300p is 28 secs acording to http://www.astronautix.com/s/s-300p.html
# sounds a bit high for pmu, as its 4 secs for s-400

################### CIWS INFO ###################

var ciws_installed =   0;
var ciws_domain_nm = 1.50; #range where it can kill
var ciws_chance    = 0.20; #chance to get a kill at 0nm distance
var ciws_burst_rounds = 60;#how many rounds in a burst
var ciws_shell = 15;#from lookup table in damage.nas
var ROUNDS_init       = 30;
var ROUNDS = ROUNDS_init;#CIWS bursts remaining

################### MISSILE INFO - http://www.astronautix.com/k/kub.html ###################

var NUM_MISSILES = 3; # total carried minus 1
var missile_name = "V601";
var missile_brevity = damage.id2warhead[getprop("payload/armament/"~string.lc(missile_name)~"/type-id")][4];
var missile_max_distance = getprop("payload/armament/"~string.lc(missile_name)~"/max-fire-range-nm"); #max distance of target in nm when it will fire
var missile_min_distance = getprop("payload/armament/"~string.lc(missile_name)~"/min-fire-range-nm"); #minimum distance in nm when it will fire
var lockon_time = 12; #time in seconds it takes to lock on and get a firing solution on a target
var fire_minimum_interval = 7;# time since last track was initiated till a new can be initiated
var same_target_max_missiles = 1;# max number of missiles in air against same target

var isInEngagementEnvelope = func (target_radial_airspeed, target_ground_distance, target_relative_altitude) {
	return 1;
}

var midflight = func (struct) {
	if (struct.guidance == "semi-radar") {
		# This makes the SAM system keep lock on target when missile in-flight and no longer tracking the target.
		# Usage is to make the RWR lock sound go off in targets cockpit.
		thread.lock(mutexLock);
		semi_active_track = struct.callsign;
		thread.unlock(mutexLock);
	}
	return {};
};


