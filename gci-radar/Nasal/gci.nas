# (c) 2018 pinto
# license: gplv2+
srand();# seed the random generator with systime
# v0.2b
# will only report the closest bad guy, does no threat assessment.
# todo:
# test
# toggle radar on/off

##########################################
### Variables
##########################################

# prop_watch is a mp[x] boolean property set by that aircraft designer. the plane sets this to 1 when it wants to receive BRAA
# if the plane is not on the enemy list, and is one of the first ~10 to
# request a BRAA, then it will receive it.
var damage_prop = props.globals.getNode("/carrier/sunk");
var prop_watch = {
    "MiG-15bis": [0,1,2],
    "MiG-21bis": [0,1,2],
    "MiG-21MF-75": [0,1,2],
    "QF-4E": [0,1,2],
    "F-16": [50,51,52],
    "m2000-5B": [0,1,2],
    "m2000-5": [0,1,2],
    "JA37Di-Viggen": [20,21,22],
    "AJ37-Viggen": [20,21,22],
    "AJS37-Viggen": [20,21,22],
    "Jaguar-GR1":  [20,21,22],
};

var radar_stations = [
    "gci",
    "frigate",
];

var update_rate = 10; #how often the message should update in seconds
var hostile_radius = 300000; #max distance to check against, in meters

var true = 1;
var false = 0;

# request types
var NONE = 0;
var PICTURE = 1;
var BOGEYDOPE = 2;
var CUTOFF = 3;

var PENDING = 0;
var SENDING = 1;
var SENT = 2;

var output_prop = 0;
var radar_tx_output_prop = 11;
var enemy_node = props.globals.getNode("/enemies");
var player_node = props.globals.getNode("/ai/models");
var opfor_switch = props.globals.getNode("/enemies/opfor-switch"); # targets all non-opfor
var friend_switch = props.globals.getNode("/enemies/friend-switch"); # targets all opfor
##########################################
### Objects
##########################################

var gci_contact = {
    new: func(c, class) {
        var m = {parents:[gci_contact]};
        m.time_from_last_message = 0;
        m.node = c;
        m.model = remove_suffix(remove_suffix(split(".", split("/", c.getNode("sim/model/path").getValue())[-1])[0], "-model"), "-anim");
        m.valid = c.getNode("valid");
        m.callsign = c.getNode("callsign").getValue();
        if ( contains(prop_watch, m.model) ) {
            m.picture_node = c.getNode("sim/multiplay/generic/bool["~prop_watch[m.model][0]~"]");
            m.bogeydope_node = c.getNode("sim/multiplay/generic/bool["~prop_watch[m.model][1]~"]");
            m.cutoff_node = c.getNode("sim/multiplay/generic/bool["~prop_watch[m.model][2]~"]");
        } else {
            m.picture_node = -1;
            m.bogeydope_node = -1;
            m.cutoff_node = -1;
        }
        m.is_radar_station = find_match(m.model,radar_stations);
        m.contact = radar_logic.Contact.new(c,class);
        m.foe = false;
        m.match = false;
        m.request = NONE;
        m.last_request = NONE;
        m.request_status = PENDING;
        m.msg_queue = [];
        m.last_seen = 0;
        if (m.is_radar_station) {
            m.radar_station_process_send();
        } else {
            m.process_send();
        }
        return m;
    },
    getValid: func() {
        if (me.valid.getValue() == 0 or me.callsign != me.node.getNode("callsign").getValue()) {
            return 0;
        } else {
            return 1;
        }
    },
    check_foe: func() {
        me.foe = false;
        if (opfor_switch.getValue() == true ) {
            if (left(string.lc(me.callsign),5) != "opfor") {
                me.foe = true;
            }
        } elsif (friend_switch.getValue() == true) {
            if (left(string.lc(me.callsign),5) == "opfor") {
                me.foe = true;
            }
        } else {        
            foreach (var cs; enemy_node.getChildren()) {
                if (me.callsign == cs.getValue()) {
                    me.foe = true;
                    break;
                }
            }
        }
        return me.foe;
    },
    update_request: func() {
        if (me.picture_node == -1) {
            return;
        }
        #print("updating info");
        if (me.picture_node.getValue() == true) {
            me.request = PICTURE;
        } elsif (me.bogeydope_node.getValue() == true) {
            me.request = BOGEYDOPE;
        } elsif (me.cutoff_node.getValue() == true) {
            me.request = CUTOFF;
        } else {
            me.request = NONE;
        }
    },
    check_node: func() {
        #print('checking node');
        if (me.picture_node == -1){
            #print('watch node is -1');
            return false;
        } elsif (me.check_foe() == true) {
            #print('check_foe is true');
            return false;
        } elsif (me.request == NONE) {
            #print('node is false');
            return false;
        } elsif (systime() - me.time_from_last_message < update_rate) {
            #print("update failed");
            return false;
        } else {
            me.time_from_last_message = systime();
            return true;
        }
    },
    process_send: func() {
        # messages are first in, first out order
        # updates every 1.5 seconds
        #print('in process_send()');
        
        # send messages
        # if the request type changes, stop sending messages except for popups
        
        if (damage_prop.getValue() == 0) {

            me.update_request();
            
            if (me.request != me.last_request or me.request == NONE) {
                # keep popup messages, purge everything else
                for (var i = 0; i < size(me.msg_queue); i = i + 1) {
                    if (split(":",me.msg_queue[i])[2] != 5) {
                        me.msg_queue = purge_from_vector(me.msg_queue, i);
                    }
                }
            }
            
            me.last_request = me.request;
            
            if (size(me.msg_queue) > 0) {
                #print("msg_queue: " ~ debug.dump(me.msg_queue));
                setprop("/sim/multiplay/generic/string["~output_prop~"]",me.msg_queue[0]);
                screen.log.write(me.msg_queue[0],1.0,0.2,0.2);
                output_prop = output_prop > 9 ? 0 : output_prop + 1;
                me.msg_queue = purge_from_vector(me.msg_queue,0);
            }

        }

        settimer(func(){me.process_send();},1.3);
    },
    radar_station_process_send: func() {
        # messages are first in, first out order
        # updates every 1.5 seconds
        #print('in process_send()');

        if (size(me.msg_queue) > 0 and damage_prop.getValue() == 0) {
            #print("msg_queue: " ~ debug.dump(me.msg_queue));
            setprop("/sim/multiplay/generic/string["~radar_tx_output_prop~"]",me.msg_queue[0]);
            radar_tx_output_prop = radar_tx_output_prop >= 16 ? 11 : radar_tx_output_prop + 1;
            me.msg_queue = purge_from_vector(me.msg_queue,0);
        }

        settimer(func(){me.radar_station_process_send();},1.3);
    },
};

##########################################
### Functions
##########################################

# gather up all contacts, so we can iterate over them

var cx_master_list = [];

var gather_contacts = func() {
    # first we need to clean the contact list
    for (var i = 0; i < size(cx_master_list); i = i + 1) {
        if (cx_master_list[i] == nil) { break; }
        if (!cx_master_list[i].getValid()) {
            print("purging contact: " ~ cx_master_list[i].contact.get_Callsign());
            cx_master_list = purge_from_vector(cx_master_list, i);
        }
    }
    var matching = false;
    foreach(var mp; player_node.getChildren("multiplayer")) {
        if (mp.getNode("valid").getValue() == 1) {
            matching = false;
            foreach(var cx; cx_master_list) {
                if ( mp.getPath() == cx.contact.getNode().getPath() and mp.getNode("callsign").getValue() == cx.callsign) {
                    matching = true;
                    break;
                }
            }
            if (matching == false) {
                cx = gci_contact.new(mp,0);
                print("adding contact: " ~ cx.contact.get_Callsign());
                append(cx_master_list,cx);
            }
        }
    }
}

var check_requests = func(){
    foreach (var cx; cx_master_list) {
        if (check_visible(cx)) {
            #print('cx is visible');
            #print('cx last seen time is ' ~ cx.last_seen ~ ' | ' ~ (systime() - cx.last_seen));
            #print('iff: ' ~ cx.check_foe());
            #print('node: ' ~ cx.check_node());
            if (systime() - cx.last_seen > 30 and (cx.check_foe() == true or cx.check_node() == false)) {
                foreach (var tx; cx_master_list) {
                    if (cx.check_foe() == true) { continue; }
                    var bearing = math.round(tx.contact.get_Coord().course_to(cx.contact.get_Coord()),1);
                    var range = math.round(cx.contact.get_Coord().distance_to(tx.contact.get_Coord()));
                    var altitude = math.round(cx.contact.get_altitude(),1);
                    var aspect = math.round(math.periodic(-180,180,cx.contact.get_heading() - cx.contact.get_Coord().course_to(tx.contact.get_Coord())));
                    print(tx.callsign ~ ":" ~ get_random() ~ ":5:" ~ bearing ~ ":" ~ range ~ ":" ~ altitude ~ ":" ~ aspect);
                    append(tx.msg_queue, tx.callsign ~ ":" ~ get_random() ~ ":5:" ~ bearing ~ ":" ~ range ~ ":" ~ altitude ~ ":" ~ aspect);
                }
            }
            cx.last_seen = systime();
        }
        if (cx.check_foe() == true or cx.check_node() == false) { continue; }
        if (size(cx.msg_queue) > 0) { continue; } # msg queue should be reset or emptied when request changes.
        if (cx.request == NONE) {
            continue;
        } elsif (cx.request == PICTURE) {
            var blue_coords = [];
            var opfor_coords = [];
            var match = false;
            append(blue_coords, cx.contact.get_Coord());
            foreach (var check; cx_master_list) {
                if (!check_visible(check)) { continue; }
                match = false;
                if (check.check_foe()) {
                    foreach (var coord; opfor_coords) {
                        if (coord.distance_to(check.contact.get_Coord()) < 3 * NM2M) {
                            match = true;
                            break;
                        }
                    }
                    if (!match) { append(opfor_coords,check.contact.get_Coord()); }
                } else {
                    foreach (var coord; blue_coords) {
                        if (coord.distance_to(check.contact.get_Coord()) < 3 * NM2M) {
                            match = true;
                            break;
                        }
                    }
                    if (!match) { append(blue_coords,check.contact.get_Coord()); }
                }
                
                if (!match) {
                    #send message
                    var bearing = math.round(cx.contact.get_Coord().course_to(check.contact.get_Coord()),1);
                    var range = math.round(check.contact.get_Coord().distance_to(cx.contact.get_Coord()));
                    var altitude = math.round(check.contact.get_altitude(),1);
                    # requestor-callsign:unique-message-id:2:bearing:range:altitude:[BLUFOR=0|OPFOR=1]
                    append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":2:" ~ bearing ~ ":" ~ range ~ ":" ~ altitude ~ ":" ~ check.check_foe());
                }
            }
            if (size(cx.msg_queue) == 0) {
                append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":1:n:n:n:n");
            } else {
                append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":0:d:d:d:d");
            }
            
        } elsif (cx.request == BOGEYDOPE) {
            min_dist = hostile_radius;
            closest = nil;
            #print('checking bogey dope');
            foreach (var check; cx_master_list) {
                if (!check.check_foe()) { continue; }
                var dist = cx.contact.get_Coord().distance_to(check.contact.get_Coord());
                if ( dist > min_dist) { continue; }
                if (!check_visible(check)) { continue; }
                min_dist = dist;
                closest = check;
            }
            if (closest != nil) {
                var bearing = math.round(cx.contact.get_Coord().course_to(closest.contact.get_Coord()),1);
                var range = math.round(closest.contact.get_Coord().distance_to(cx.contact.get_Coord()));
                var altitude = math.round(closest.contact.get_altitude(),1);
                var aspect = math.round(math.periodic(-180,180,closest.contact.get_heading() - closest.contact.get_Coord().course_to(cx.contact.get_Coord())));
                append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":3:" ~ bearing ~ ":" ~ range ~ ":" ~ altitude ~ ":" ~ aspect);
            } else {
                append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":1:n:n:n:n");
            }
                
        } elsif (cx.request == CUTOFF) {
            min_dist = hostile_radius;
            closest = nil;
            foreach (var check; cx_master_list) {
                if (!check.check_foe()) { continue; }
                var dist = cx.contact.get_Coord().distance_to(check.contact.get_Coord());
                if ( dist > min_dist) { continue; }
                if (!check_visible(check)) { continue; }
                min_dist = dist;
                closest = check;
            }
            if (closest != nil) {
                var bogey_speed = closest.contact.speed.getValue();
                var cx_speed = cx.contact.speed.getValue();
                var bogey_heading = closest.contact.heading.getValue();
                var bearing = cx.contact.get_Coord().course_to(closest.contact.get_Coord());
                var range = closest.contact.get_Coord().distance_to(cx.contact.get_Coord());
                var altitude = math.round(closest.contact.get_altitude(),1);
                var aspect = math.round(math.periodic(-180,180,closest.contact.get_heading() - closest.contact.get_Coord().course_to(cx.contact.get_Coord())));
                # get_intercept(bearing, dist_m, runnerHeading, runnerSpeed, chaserSpeed)
                var info = get_intercept(bearing, range, bogey_heading, bogey_speed * KT2MPS, cx_speed * KT2MPS);
                if (info == nil) {
                    append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":1:n:n:n:n");
                } else {
                    append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":4:" ~ int(info[1]) ~ ":" ~ int(info[0]) ~ ":" ~ altitude ~ ":" ~ aspect);
                }
            } else {
                append(cx.msg_queue, cx.callsign ~ ":" ~ get_random() ~ ":1:n:n:n:n");
            }
        }
    }
}

var cx_data_transmit = func(){
    #print('transmitting');
    foreach (var cx; cx_master_list) {
        if (!cx.is_radar_station) { continue; }
        if (size(cx.msg_queue) > 0) { continue; }
        if (cx.check_foe()) { continue; }
        foreach (var tx; cx_master_list) {
            if (tx != cx) {
                append(cx.msg_queue,cx.callsign ~ ":" ~ get_random() ~ ":" ~ tx.callsign);
            }
        }
    }
}

var data_receive_callsigns = [];
var cx_data_receive = func() {
    # clean out old data (15 seconds)
    var time = systime();
    var new_vec = [];
    foreach (var rx; data_receive_callsigns){
        if (time - rx[1] < 15) {
            append(new_vec,rx);
        }
    }
    data_receive_callsigns = new_vec;
    foreach (var cx; cx_master_list) {
        for (var i = 11; i <= 15; i = i + 1) {
            var msg = getprop(cx.node.getPath() ~ "/sim/multiplay/generic/string["~i~"]");
            if (msg == "") { continue; }
            if (msg == nil) { continue; }
            msg = split(":",msg);
            if (msg[0] != getprop("/sim/multiplay/callsign")) { continue; };
            if (find_match(msg[2], data_receive_callsigns)) { continue; }
            #print("adding cs to received list");
            append(data_receive_callsigns,[msg[2],systime()]);
        }
    }
}

var check_visible = func(check) {
    foreach(var rx; data_receive_callsigns) {
        if (rx[0] == check.callsign) {
            return true;
        }
    }
    if (radar_logic.isNotBehindTerrain(check.node) == false){ return false; }

    var target_heading = check.contact.heading.getValue();
    var relative_bearing = math.abs(geo.normdeg180(check.contact.get_Coord().course_to(geo.aircraft_position()) - target_heading));
    var target_radial_airspeed = (-1 * ( ( relative_bearing / 90 ) - 1 ) ) * check.node.getNode("velocities/true-airspeed-kt").getValue();
    if ( math.abs(target_radial_airspeed) < 20 ) { return false; } # i.e. notching, landed aircraft
    return true;
}

var iter = 0;
var main_loop = func() {
    #print("looping");
    if (getprop("/carrier/sunk/") == 0) {
        if (iter == 0) {
            gather_contacts();
            cx_data_transmit();
        }
        cx_data_receive();
        check_requests();
    }
    iter = iter >= 7 ? 0 : iter + 1;
    settimer(func(){main_loop();},1);
}


var get_intercept = func(bearing, dist_m, runnerHeading, runnerSpeed, chaserSpeed) {
    # from Leto
    # needs: bearing, dist_m, runnerHeading, runnerSpeed, chaserSpeed
    #        dist_m > 0 and chaserSpeed > 0

    #var bearing = 184;var dist_m=31000;var runnerHeading=186;var runnerSpeed= 200;var chaserSpeed=250;

    var trigAngle = 90-bearing;
    var RunnerPosition = [dist_m*math.cos(trigAngle*D2R), dist_m*math.sin(trigAngle*D2R),0];
    var ChaserPosition = [0,0,0];

    var VectorFromRunner = vector.Math.minus(ChaserPosition, RunnerPosition);
    var runner_heading = 90-runnerHeading;
    var RunnerVelocity = [runnerSpeed*math.cos(runner_heading*D2R), runnerSpeed*math.sin(runner_heading*D2R),0];

    var a = chaserSpeed * chaserSpeed - runnerSpeed * runnerSpeed;
    var b = 2 * vector.Math.dotProduct(VectorFromRunner, RunnerVelocity);
    var c = -dist_m * dist_m;

    if ((b*b-4*a*c)<0) {
      # intercept not possible
      return nil;
    }
    
    var t1 = (-b+math.sqrt(b*b-4*a*c))/(2*a);
    var t2 = (-b-math.sqrt(b*b-4*a*c))/(2*a);
    
    if (t1 < 0 and t2 < 0) {
      # intercept not possible
      return nil;
    }
    
    var timeToIntercept = 0;
    if (t1 > 0 and t2 > 0) {
          timeToIntercept = math.min(t1, t2);
    } else {
          timeToIntercept = math.max(t1, t2);
    }
    var InterceptPosition = vector.Math.plus(RunnerPosition, vector.Math.product(timeToIntercept, RunnerVelocity));

    var ChaserVelocity = vector.Math.product(1/timeToIntercept, vector.Math.minus(InterceptPosition, ChaserPosition));

    var interceptAngle = vector.Math.angleBetweenVectors([0,1,0], ChaserVelocity);
    var interceptHeading = geo.normdeg(ChaserVelocity[0]<0?-interceptAngle:interceptAngle);
    #print("output:");
    #print("time: " ~ timeToIntercept);
    #print("heading: " ~ interceptHeading);
    return [timeToIntercept, interceptHeading];
}

var purge_from_vector = func(vec, idx = nil, val = nil) {
    if (idx == nil and val == nil) { return vec; }
    var new_vec = [];
    for (var i = 0; i < size(vec); i = i + 1) {
        if ((idx != nil and i == idx) or (val != nil and val == vec[i])) { continue; }
        append(new_vec, vec[i]);
    }
    return new_vec;
}

var get_random = func() {
    return int(rand() * 9999)
}

var find_match = func(val,vec) {
    if (size(vec) == 0) {
        return 0;
    }
    foreach (var a; vec) {
        #print(a);
        if (a == val) { return 1; }
    }
    return 0;
}

var remove_suffix = func(s, x) {
    var len = size(x);
    if (substr(s, -len) == x)
        return substr(s, 0, size(s) - len);
    return s;
}

# visibility function
settimer( func{
    setprop("/sim/multiplay/visibility-range-nm",1200);
    print("set mp visibility to " ~ 1200);
}, 15);

main_loop();
