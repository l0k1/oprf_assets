
################### SAM INFO

var setupTime = 300;#minimum 'launcher_tilt_time' secs no matter what, due to anim and stuff.
var reload_time = 900;
var launcher_final_tilt_deg  = 24;
var launcher_start_tilt_deg  = 24;
var launcher_tilt_time       =  0;
var sam_align_to_target      =  1;
var launcher_align_to_target =  0;
var align_speed_dps          = 20;
var radar_elevation_above_terrain_m = 3;
var radar_lowest_pitch       = 0.5;# 0.5 degs = roughly 925 feet at 20 nm, 25 feet at half a nm. # 0.35 = roughly 925 feet at 20 nm, 25 feet at half a nm.
var radar_off_time_min         = 30;# When turning off to lure enemies into engagement zone, and to not make the SAM too easy to find, minimum turn off this duration.
var radar_off_time_max         = 90;# Bigger missile_max_distance give crew incentive to keep this a bit longer
var radar_on_time              = 45;# Minimum the time it would take to scan whole sky
var radar_on_after_detect_time = 180;# Crew is alert after spotting an aircraft, how long should they stay that way?
var can_detect_anti_rad        = 0.35;# 0.5 very good, 0 not at all.

#reaction tme for s-300p is 28 secs acording to http://www.astronautix.com/s/s-300p.html
# sounds a bit high, as its 4 secs for s-400

################### CIWS INFO

var ciws_installed =   0;
var ciws_domain_nm = 1.50; #range where it can kill
var ciws_chance    = 0.20; #chance to get a kill at 0nm distance
var ciws_burst_rounds = 60;#how many rounds in a burst
var ciws_shell = 15;#from lookup table in damage.nas
var ROUNDS_init       = 30;
var ROUNDS = ROUNDS_init;#CIWS bursts remaining

################### MISSILE INFO

var NUM_MISSILES = 3; # total carried minus 1
var missile_name = "M317";
var missile_brevity = damage.id2warhead[getprop("payload/armament/"~string.lc(missile_name)~"/type-id")][4];
var missile_max_distance = getprop("payload/armament/"~string.lc(missile_name)~"/max-fire-range-nm"); #max distance of target in nm when it will fire
var missile_min_distance = getprop("payload/armament/"~string.lc(missile_name)~"/min-fire-range-nm"); #minimum distance in nm when it will fire
var lockon_time = 12; #time in seconds it takes to lock on and get a firing solution on a target
var fire_minimum_interval = 7;# time since last track was initiated till a new can be initiated
var same_target_max_missiles = 1;# max number of missiles in air against same target

var isInEngagementEnvelope = func (target_radial_airspeed, target_ground_distance, target_relative_altitude) {
	# is the plane within the engagement envelope?
	# the numbers after target_radial_airspeed are ( offset_of_engagement_envelope / speed_to_apply_that_offset )
	# larger offset means it wont fire until the plane is closer.
	# for visualization: https://www.desmos.com/calculator/gw570fa9km
	var vren = nil;
	if ( target_radial_airspeed < 0 ) {
		vren = 1 + target_radial_airspeed * ( 0.4 / 750 );
	} else {
		vren = 1 + target_radial_airspeed * ( -0.25 / 750 );
	}
	target_ground_distance = target_ground_distance * M2NM;
	var engagement_altitude = ((1 + vren) * (-.008 * math.pow(target_ground_distance,2)) + 0.5 * target_ground_distance + 5) * 6076.12;
	return target_relative_altitude <= engagement_altitude;
}

var midflight = nil;


