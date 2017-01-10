var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var TRUE  = 1;
var FALSE = 0;

var hp = 10000;
var hp_max = hp;

#
# Install: Include this code into an aircraft to make it damagable. (remember to add it to the -set file)
#
# Author: Nikolai V. Chr. (with some improvement by Onox and Pinto)
#
#


var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var TRUE  = 1;
var FALSE = 0;


var cannon_types = {
    " M70 rocket hit":        0.25, #135mm
    " M55 cannon shell hit":  0.10, # 30mm
    " KCA cannon shell hit":  0.10, # 30mm
    " Gun Splash On ":        0.10, # 30mm
    " M61A1 shell hit":       0.05, # 20mm
    " GAU-8/A hit":           0.10, # 30mm
    " BK27 cannon hit":       0.07, # 27mm
    " GSh-30 hit":            0.10, # 30mm
    " 7.62 hit":              0.30, #UH-1
    " 50 BMG hit":            0.20, #p-47
};
    
    
    
var warhead_lbs = {
    "aim-120":              44.00,
    "AIM120":               44.00,
    "AIM-120":              44.00,
    "RB-99":                44.00,
    "aim-7":                88.00,
    "RB-71":                88.00,
    "aim-9":                20.80,
    "AIM9":                 20.80,
    "AIM-9":                20.80,
    "RB-24":                20.80,
    "RB-24J":               20.80,
    "RB-74":                20.80,
    "R74":                  16.00,
    "MATRA-R530":           55.00,
    "Meteor":               55.00,
    "AIM-54":              135.00,
    "Matra R550 Magic 2":   27.00,
    "Matra MICA":           30.00,
    "RB-15F":              440.92,
    "SCALP":               992.00,
    "KN-06":               315.00,
    "GBU12":               190.00,
    "GBU16":               450.00,
    "Sea Eagle":           505.00,
    "AGM65":               200.00,
    "RB-04E":              661.00,
    "RB-05A":              353.00,
    "RB-75":               126.00,
    "M90":                 500.00,
    "M71":                 200.00,
    "MK-82":               192.00,
    "LAU-68":               10.00,
    "M317":                145.00,
    "GBU-31":              945.00,
    "AIM132":               22.05,
    "ALARM":               450.00,
    "STORMSHADOW":         850.00,
    "R-60":                  6.60,
    "R-27R1":               85.98,
    "R-27T1":               85.98,
    "FAB-500":             564.00,
    "M71R":                200.00,
};

var incoming_listener = func {
  var history = getprop("/sim/multiplay/chat-history");
  var hist_vector = split("\n", history);
  if (size(hist_vector) > 0) {
    var last = hist_vector[size(hist_vector)-1];
    var last_vector = split(":", last);
    var author = last_vector[0];
    var callsign = getprop("sim/multiplay/callsign");
    if (size(last_vector) > 1 and author != callsign) {
      # not myself
      #print("not me");
      var m2000 = FALSE;
      if (find(" at " ~ callsign ~ ". Release ", last_vector[1]) != -1) {
        # a m2000 is firing at us
        m2000 = TRUE;
      }
      if (last_vector[1] == " FOX2 at" or last_vector[1] == " Fox 1 at" or last_vector[1] == " Fox 2 at" or last_vector[1] == " Fox 3 at"
          or last_vector[1] == " Greyhound at" or last_vector[1] == " Bombs away at" or last_vector[1] == " Bruiser at" or last_vector[1] == " Rifle at" or last_vector[1] == " Bird away at"
          or last_vector[1] == " aim7 at" or last_vector[1] == " aim9 at"
          or last_vector[1] == " aim120 at"
          or m2000 == TRUE) {
        # air2air being fired
        if (size(last_vector) > 2 or m2000 == TRUE) {
          #print("Missile launch detected at"~last_vector[2]~" from "~author);
          if (m2000 == TRUE or last_vector[2] == " "~callsign) {
            # its being fired at me
            #print("Incoming!");
            var enemy = getCallsign(author);
            if (enemy != nil) {
              #print("enemy identified");
              var bearingNode = enemy.getNode("radar/bearing-deg");
              if (bearingNode != nil) {
                #print("bearing to enemy found");
                var bearing = bearingNode.getValue();
                var heading = getprop("orientation/heading-deg");
                var clock = bearing - heading;
                while(clock < 0) {
                  clock = clock + 360;
                }
                while(clock > 360) {
                  clock = clock - 360;
                }
                #print("incoming from "~clock);
                if (clock >= 345 or clock < 15) {
                  playIncomingSound("12");
                } elsif (clock >= 15 and clock < 45) {
                  playIncomingSound("1");
                } elsif (clock >= 45 and clock < 75) {
                  playIncomingSound("2");
                } elsif (clock >= 75 and clock < 105) {
                  playIncomingSound("3");
                } elsif (clock >= 105 and clock < 135) {
                  playIncomingSound("4");
                } elsif (clock >= 135 and clock < 165) {
                  playIncomingSound("5");
                } elsif (clock >= 165 and clock < 195) {
                  playIncomingSound("6");
                } elsif (clock >= 195 and clock < 225) {
                  playIncomingSound("7");
                } elsif (clock >= 225 and clock < 255) {
                  playIncomingSound("8");
                } elsif (clock >= 255 and clock < 285) {
                  playIncomingSound("9");
                } elsif (clock >= 285 and clock < 315) {
                  playIncomingSound("10");
                } elsif (clock >= 315 and clock < 345) {
                  playIncomingSound("11");
                } else {
                  playIncomingSound("");
                }
                return;
              }
            }
          }
        }
      } elsif (1==1) { # mirage: getprop("/controls/armament/mp-messaging")
        # latest version of failure manager and taking damage enabled
        #print("damage enabled");
        var last1 = split(" ", last_vector[1]);
        if(size(last1) > 2 and last1[size(last1)-1] == "exploded" ) {
          #print("missile hitting someone");
          if (size(last_vector) > 3 and last_vector[3] == " "~callsign) {
            #print("that someone is me!");
            var type = last1[1];
            if (type == "Matra" or type == "Sea") {
              for (var i = 2; i < size(last1)-1; i += 1) {
                type = type~" "~last1[i];
              }
            }
            var number = split(" ", last_vector[2]);
            var distance = num(number[1]);
            #print(type~"|");
            if(distance != nil) {
              var dist = distance;

      			  #check distance w/ if statement here
      			  
      			  if (contains(warhead_lbs, type)) {
                #maxDist = maxDamageDistFromWarhead(warhead_lbs[type]);
              } else {
                return;
              }
			  
              if (type == "M90" and distance < 300) {
                var failed = fail_systems(warhead_lbs[type]/2);
                return;
              } elsif (distance < 150) {
        				var prob = 1;
        				if ( distance > 50 ) {
        					distance = distance - 50;
        					prob = 1 - (distance/100);
        				}
      			  }
				

              var failed = fail_systems(warhead_lbs[type] * prob);
              #ar percent = 100 * probability;
              #printf("Took %.1f%% damage from %s missile at %0.1f meters. %s systems was hit", percent,type,dist,failed);
            }
          }
        } elsif (cannon_types[last_vector[1]] != nil) {
          # cannon hitting someone
          print("cannon");
          if (size(last_vector) > 2 and last_vector[2] == " "~callsign) {
      			print("cannon hit us");
      		    var last3 = split(" ", last_vector[3]);
      			#print("last3[2]: " ~ last3[2]);
      			#print("last3[1]: " ~ last3[1]);
      		  if(size(last3) > 2) {
      				if ( last3[2] == "hits" ) {
      					var hit_count = num(last3[1]);
      				}
      			} else {
      			  var hit_count = 4;
      			}
      			var damaged_sys = 0;
      			var probability = cannon_types[last_vector[1]];
      			for (var i = 1; i <= hit_count; i = i + 1) {
      				var failed = fail_systems(probability);
      				damaged_sys = damaged_sys + failed;
      			}
            # that someone is me!
            #print("hitting me");

            printf("Took %.1f%% damage from cannon! %s systems was hit.", probability*hit_count*100, damaged_sys);
          }
        }
      }
    }
  }
}


var maxDamageDistFromWarhead = func (lbs) {
  # very simple
  var dist = 7*math.sqrt(lbs);

  return dist;
}

var fail_systems = func (damage) {
	hp = hp - damage;
	print("HP: " ~ hp ~ "/" ~ hp_max);
	
	if ( hp < 0 ) {
		setprop("/carrier/sunk/",1);
    setprop("/sim/multiplay/generic/int[0]",1);
	}
	return 1;
};

var playIncomingSound = func (clock) {
  setprop("sound/incoming"~clock, 1);
  settimer(func {stopIncomingSound(clock);},3);
}

var stopIncomingSound = func (clock) {
  setprop("sound/incoming"~clock, 0);
}

var callsign_struct = {};
var getCallsign = func (callsign) {
  var node = callsign_struct[callsign];
  return node;
}

var processCallsigns = func () {
  callsign_struct = {};
  var players = props.globals.getNode("ai/models").getChildren();
  foreach (var player; players) {
    if(player.getChild("valid") != nil and player.getChild("valid").getValue() == TRUE and player.getChild("callsign") != nil and player.getChild("callsign").getValue() != "" and player.getChild("callsign").getValue() != nil) {
      var callsign = player.getChild("callsign").getValue();
      callsign_struct[callsign] = player;
    }
  }
  settimer(processCallsigns, 1.5);
}

processCallsigns();

var logTime = func{
  #log time and date for outputing ucsv files for converting into KML files for google earth.
  if (getprop("logging/log[0]/enabled") == TRUE and getprop("sim/time/utc/year") != nil) {
    var date = getprop("sim/time/utc/year")~"/"~getprop("sim/time/utc/month")~"/"~getprop("sim/time/utc/day");
    var time = getprop("sim/time/utc/hour")~":"~getprop("sim/time/utc/minute")~":"~getprop("sim/time/utc/second");

    setprop("logging/date-log", date);
    setprop("logging/time-log", time);
  }
}

setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);