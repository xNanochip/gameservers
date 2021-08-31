#!/usr/bin/env python3
import os
import datetime;
import sys

# we add things to this string over the course of this script and eventually flush it to disk as our server config file
config_file_string = ""

# get current utc time
utcnow = datetime.datetime.utcnow()
# get timestamp of current utc time
timestamp = utcnow.timestamp()

config_file_string += ("// config generated at: {}\n".format(utcnow))
config_file_string += ("// utc timestamp: {}\n\n".format(timestamp))

# this is our server id variable straight from bash
server_id = os.environ["SERVER_ID"]

# staging servers do their own thing
if "staging" in server_id:
    print("STAGING SERVER DETECTED! FALLING BACK TO MANUAL CFG")
    if "mvm" in server_id:
        mapcyclefile = "quickplay/mapcycle_mvm.txt"
    else:
        mapcyclefile = "quickplay/mapcycle.txt"

    ext_args = ("+mapcyclefile {}\n".format(mapcyclefile))
    print("args --->", ext_args)

    config_file_string += ("exec quickplay/econ\n")

    # Get the region from the string and exec a special config.
    # We only have two staging servers (EU and Virginia)
    if "eu" in server_id:
        config_file_string += ("exec quickplay/server-staging-eu\n")
    else:
        config_file_string += ("exec quickplay/server-staging-vin\n")

    # At this point, both server-staging-### configs execute everything we
    # need to worry about such as "exec quickplay/base", setting hostname,
    # password, etc etc.

    # Flush our config file contents to disk quickly.
    with open("./tf/cfg/quickplay/_id.cfg", "w") as f:
        f.write(config_file_string)
        f.flush()

    # Flush our external arguments as well.
    with open("./py_args", "w") as f:
        f.write(ext_args)
        f.flush()
    sys.exit(0)

# Testing Servers do their own thing
elif "test" in server_id:
    print("PUBLIC TESTING SERVER DETECTED! FALLING BACK TO MANUAL CFG")
    if "mvm" in server_id:
        mapcyclefile = "quickplay/mapcycle_mvm.txt"
    else:
        mapcyclefile = "quickplay/mapcycle.txt"

    ext_args = ("+mapcyclefile {}\n".format(mapcyclefile))
    print("args --->", ext_args)

    config_file_string += ("exec quickplay/econ\n")

    # Exec a special config.
    # Currently the only public testing server is located in Virginia.
    # If another server is added in another region, feel free to add it here.
    config_file_string += ("exec quickplay/server-publictest-vin\n")

    # At this point, the server-weapon-test config executes everything we
    # need to worry about such as "exec quickplay/base", setting hostname,
    # password, etc etc.

    # Flush our config file contents to disk quickly.
    with open("./tf/cfg/quickplay/_id.cfg", "w") as f:
        f.write(config_file_string)
        f.flush()

    # Flush our external arguments as well.
    with open("./py_args", "w") as f:
        f.write(ext_args)
        f.flush()
    sys.exit(0)

# If we're not a staging or weapons testing server,
# treat every server ID as an int past this point.
sid = int(server_id)

region = ""
cregion = ""

econ = False
pubs = False

if sid > 100 and sid <= 199:
    c_region = "EU 1"

    if sid <= 103:
        type = "Quickplay"

    elif sid <= 106:
        type = "Vanilla+"

    elif sid <= 112:
        type = "DigitalDirective"

elif sid > 200 and sid <= 299:

    c_region = "VIN"

    if sid <= 203:
        type = "Quickplay"

    elif sid <= 206:
        type = "Vanilla+"

    elif sid <= 210:
        type = "DigitalDirective"


elif sid > 300 and sid <= 399:

    c_region = "LA"

    if sid == 301:
        type = "Quickplay"

    elif sid == 302:
        type = "Vanilla+"

    else:
        type = "DigitalDirective"

elif sid > 400 and sid <= 499:

    c_region = "CHI"

    type = "DigitalDirective"

#elif sid > 500 and sid <= 599:


elif sid > 600 and sid <= 699:

    c_region = "AUS"

    if sid == 601:
        type = "Quickplay"

    elif sid == 602:
        type = "Vanilla+"

    else:
        type = "DigitalDirective"


elif sid > 700 and sid <= 799:

    c_region = "SGP"

    if sid == 701:
        type = "Quickplay"

    elif sid == 702:
        type = "Vanilla+"

    else:
        type = "DigitalDirective"


elif sid > 800 and sid <= 899:

    if sid >= 800 and sid <= 849:

        c_region = "US_POT"
        type = "DigitalDirective"

    elif sid >= 850 and sid <= 899:

        c_region = "EU_POT"
        type = "DigitalDirective"

else:
    c_region = "Unknown"



# it might not be this simple in the future lol
if "EU" in c_region:
    region = "West EU"

elif c_region == "VIN" or c_region == "US_POT":
    region = "East US"

elif c_region == "LA":
    region = "West US"

elif c_region == "CHI":
    region = "East US"

elif c_region == "SGP":
    region = "Singapore"

elif c_region == "AUS":
    region = "Australia"

# type of server

pubs = False
econ = False

if type == "Vanilla+":
    ctype = "Vanilla+ | NoDL"
    pubs = True
    econ = False

elif type == "DigitalDirective":
    ctype = "Digital Directive MVM"
    pubs = False
    econ = True

else:
    ctype = type
    pubs = True
    econ = True

# always exec our base cfg
config_file_string += ("exec quickplay/base\n")
# change our hostname to what it should be
config_file_string += ("hostname \"{} | {} | {} | #{}\"\n".format("Creators.TF", region, ctype, sid))
# set our server id to the server id we got passed in as a var
config_file_string += ("ce_server_index {}\n".format(sid))
config_file_string += ("sb_id {}\n".format(sid))
config_file_string += ("ce_type {}\n".format(ctype))
config_file_string += ("ce_region {}\n".format(c_region))

mapcyclefile = ""

# mapcyclefile gets tacked onto the launch options so we don't waste time on itemtest
if pubs:
    mapcyclefile = "quickplay/mapcycle.txt"
    config_file_string += ("exec quickplay/pubs\n")

else:
    mapcyclefile = "quickplay/mapcycle_mvm.txt"
    config_file_string += ("exec quickplay/mvm\n")


config_file_string += ("mapcyclefile {}\n".format(mapcyclefile))

if econ:
    config_file_string += ("exec quickplay/econ\n")

else:
    config_file_string += ("exec quickplay/vanilla\n")


print(config_file_string)


ext_args = "+mapcyclefile {}".format(mapcyclefile)
print("args --->", ext_args)


# we flush these so we write asap
with open("./tf/cfg/quickplay/_id.cfg", "w") as f:
    f.write(config_file_string)
    f.flush()

with open("./py_args", "w") as f:
    f.write(ext_args)
    f.flush()
