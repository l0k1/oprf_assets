var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var TRUE = 1;
var FALSE = 0;

#
# Install: Include this code into an aircraft to make it damagable. (remember to add it to the -set file)
#
# Author: Nikolai V. Chr. (with some improvement by Onox and Pinto)
#
#

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

var players = {
    "pinto":  1,
    "OPFOR77": 2,
    "Leto":   1,
    "swamp":  2,
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
      if (1==1) { # mirage: getprop("/controls/armament/mp-messaging")
        # latest version of failure manager and taking damage enabled
        #print("damage enabled");
        var last1 = split(" ", last_vector[1]);
          if (cannon_types[last_vector[1]] != nil) {
          # cannon hitting someone
          print("cannon");
          if (size(last_vector) > 2 and last_vector[2] == " "~callsign) {
      			print("cannon hit us");
      		  process_hit(author);
          }
        }
      }
    }
  }
}

var last_update_time = "/aa_tower/last-update-time";
var owning_team = "/aa_tower/owning_team";
var score_team_1 = "/aa_tower/score-team-1";
var score_team_2 = "/aa_tower/score-team-2";
setprop(last_update_time, -1);
setprop(owning_team, 0);
setprop(score_team_1, 0);
setprop(score_team_2, 0);

var process_hit = func (perp) {
  print("processing hit by: " ~ perp);
  if ( players[perp] != nil ) {
    if ( players[perp] != getprop(owning_team) ) {
      setprop(last_update_time,systime());
      setprop(owning_team, players[perp]);
      setprop("/aa_tower/score-team-" ~ players[perp], getprop("/aa_tower/score-team-" ~ players[perp]) + 1);
      setprop("/sim/multiplay/chat","Ownership transferred to team: " ~ players[perp]);
      write_xml();
    }
  }
}

var update = func () {
  var o_t = getprop(owning_team);
  if(o_t > 0) {
    if(systime() > getprop(last_update_time) + 300) {
      print("Adding point to team: " ~ o_t);
      setprop("/sim/multiplay/chat","Adding point to team: " ~ o_t);
      setprop("/aa_tower/score-team-" ~ o_t, getprop("/aa_tower/score-team-" ~ o_t) + 1);
      setprop(last_update_time, systime());
      write_xml();
    }
  }
  settimer(func(){update();},10);
}

update();

var twr_base = "/aa_tower/";
var filename_base = getprop("/sim/fg-home") ~ "/Export/tower-";
var write_xml = func() {
  io.write_properties( path: filename_base ~ rand() ~ ".xml", prop: twr_base );
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


setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);