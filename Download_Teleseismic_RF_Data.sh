#!/bin/bash

################################################################################
# Script for Automatic Downloading Teleseismic Event Data, SAC Files with Pole-Zero files
# This script downloads SAC files for teleseismic events, aligning them on P-wave arrival.
################################################################################

### By A. Mahanama / Last modified: 02/14/2025

## DIRECTORY
WD=/FOLDER_PATH

## Create required directories
rm -rf $WD/Event_RF
mkdir -p $WD/Event_RF/{Info,Fetch_Text,Data,Fetch_Script,PZfile_Ev_St_Pair}

############################### INPUT PARAMETERS #####################################################

## STUDY REGION
mn_lat=-90.00
mx_lat=90.00
mn_lon=-180.00
mx_lon=180.00

s_date=2011-01-03T00:00:00
e_date=2011-02-23T00:00:00

## NETWORK & STATION
ntwk=IU
stat=WVT

# Define Station Location
station_lat=36.1297
station_lon=-87.83


## CHANNELS
chn=BH1,BH2,BHZ
loc_code=10

## DEPTH RANGE
min_depth=10.0
max_depth=700.0

## WAVEFORM TIME WINDOW
T1=200   # Seconds before P arrival
T2=400   # Seconds after P arrival

############################### DOWNLOADING EVENT INFORMATION #######################################

# Fetch event catalog for both magnitude ranges
echo "Downloading event catalogs..."

# Range A: M6.5-10.0, 20-180°
curl -o "$WD/Event_RF/Info/Event_RF_A.txt" \
"https://service.iris.edu/fdsnws/event/1/query?starttime=$s_date&endtime=$e_date&minmagnitude=6.5&maxmagnitude=10&mindepth=$min_depth&maxdepth=$max_depth&latitude=$station_lat&longitude=$station_lon&minradius=20&maxradius=180&output=text"

# Range B: M5.7-6.49, 20-50°
curl -o "$WD/Event_RF/Info/Event_RF_B.txt" \
"https://service.iris.edu/fdsnws/event/1/query?starttime=$s_date&endtime=$e_date&minmagnitude=5.7&maxmagnitude=6.49&mindepth=$min_depth&maxdepth=$max_depth&latitude=$station_lat&longitude=$station_lon&minradius=20&maxradius=50&output=text"

# Merge both event lists and remove duplicates
cat "$WD/Event_RF/Info/Event_RF_A.txt" "$WD/Event_RF/Info/Event_RF_B.txt" | sort -u > "$WD/Event_RF/Info/Event_RF.txt"

# Download station metadata
curl -o "$WD/Event_RF/Info/T_Station.txt" "http://service.iris.edu/fdsnws/station/1/query?net=$ntwk&sta=$stat&cha=$chn&starttime=$s_date&endtime=$e_date&level=station&format=text&maxlat=$mx_lat&minlon=$mn_lon&maxlon=$mx_lon&minlat=$mn_lat"

# Verify downloads
if [ ! -f "$WD/Event_RF/Info/Event_RF.txt" ] || [ ! -f "$WD/Event_RF/Info/T_Station.txt" ]; then
    echo "Error: Failed to download event or station data."
    exit 1
fi

# Process event and station data
awk -F "|" '{print $1, $2, $3, $4, $5}' $WD/Event_RF/Info/Event_RF.txt > $WD/Event_RF/Info/Event_Time.txt
awk -F "|" 'NR>1 {print $1, $2, $3, $4}' $WD/Event_RF/Info/T_Station.txt > $WD/Event_RF/Info/STID.txt


############################### PROCESSING EVENTS ######################################

while read x0 x1 x2 x3 x4; do
    ID=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$x1" "+%Y-%m-%dT%H-%M-%S" 2>/dev/null)
    event_lat=$x2
    event_lon=$x3
    event_depth=$x4

    # Determine station distance range based on magnitude
    if [[ $(echo "$x0 >= 6.5" | bc -l) -eq 1 ]]; then
        min_dist=20
        max_dist=180
    else
        min_dist=20
        max_dist=50
    fi

    while read net sta stla stlo; do
        echo "Processing event $ID for station $sta..."

        # Compute event-station distance (degrees)
        distance=$(awk -v lat1="$event_lat" -v lon1="$event_lon" -v lat2="$stla" -v lon2="$stlo" '
        BEGIN {
            pi = 3.141592653589793
            lat1 = lat1 * (pi / 180)
            lon1 = lon1 * (pi / 180)
            lat2 = lat2 * (pi / 180)
            lon2 = lon2 * (pi / 180)

            delta_lat = lat2 - lat1
            delta_lon = lon2 - lon1

            a = sin(delta_lat / 2) * sin(delta_lat / 2) + cos(lat1) * cos(lat2) * sin(delta_lon / 2) * sin(delta_lon / 2)
            c = 2 * atan2(sqrt(a), sqrt(1 - a))

            print c * (180 / pi)
        }')
        echo "DEBUG: Computed Distance = '$distance'"

        # Skip event if distance is empty
        if [[ -z "$distance" ]]; then
            echo "Skipping event due to missing distance"
            continue
        fi

# Define the path for taup_time
export PATH="/usr/local/taup/bin:$PATH"

# First try with P
# Feeding Event depth and the Degree distance to TauP for Phase picks and travel time calculation
# We can use Other Earth models too......
echo "Running taup_time with: -mod ak135 -h $event_depth -deg $distance -ph P"
        /usr/local/taup/bin/taup_time -mod ak135 -h "$event_depth" -deg "$distance" -ph P

taup_output=$(taup_time -mod ak135 -h "$event_depth" -deg "$distance" -ph P)
p_arrival=$(echo "$taup_output" | awk 'NR>1 && $3 == "P" {print $4; exit}')
ray_param=$(echo "$taup_output" | awk 'NR>1 && $3 == "P" {print $5; exit}')
takeoff_angle=$(echo "$taup_output" | awk 'NR>1 && $3 == "P" {print $6; exit}')
incident_angle=$(echo "$taup_output" | awk 'NR>1 && $3 == "P" {print $7; exit}')

# If P is not found, try Pdiff
if [ -z "$p_arrival" ]; then
    echo "No direct P-wave arrival found. Trying Pdiff..."
    echo "Running taup_time with: -mod ak135 -h $event_depth -deg $distance -ph Pdiff"
        /usr/local/taup/bin/taup_time -mod ak135 -h "$event_depth" -deg "$distance" -ph Pdiff

taup_output=$(taup_time -mod ak135 -h "$event_depth" -deg "$distance" -ph Pdiff)
p_arrival=$(echo "$taup_output" | awk 'NR>1 && $3 == "Pdiff" {print $4; exit}')
ray_param=$(echo "$taup_output" | awk 'NR>1 && $3 == "Pdiff" {print $5; exit}')
takeoff_angle=$(echo "$taup_output" | awk 'NR>1 && $3 == "Pdiff" {print $6; exit}')
incident_angle=$(echo "$taup_output" | awk 'NR>1 && $3 == "Pdiff" {print $7; exit}')
    phase_name="Pdiff"
else
    phase_name="P"
fi

# Debugging: Print selected phase and arrival time
echo "DEBUG: Selected Phase = '$phase_name'"
echo "DEBUG: Computed P-wave Arrival Time = '$p_arrival' sec"

# Skip event if no P or PP arrival is found
if [ -z "$p_arrival" ]; then
    echo "Skipping event $ID for station $sta (no P or Pdiff-wave arrival found)"
    continue
fi

# Round arrival time to nearest integer
# Use arrival time calculated by TauP to select the waveform starting and endings for downloads
p_arrival_int=$(printf "%.0f" "$p_arrival")

# Debugging: Print rounded arrival time
echo "DEBUG: Rounded Arrival Time = '$p_arrival_int' sec"

# Define waveform time window using rounded arrival time
sd=$(date -j -v+${p_arrival_int}S -v-${T1}S -f "%Y-%m-%dT%H:%M:%S" "$x1" "+%Y-%m-%dT%H:%M:%S")
ed=$(date -j -v+${p_arrival_int}S -v+${T2}S -f "%Y-%m-%dT%H:%M:%S" "$x1" "+%Y-%m-%dT%H:%M:%S")

# Debugging: Print computed Start and End times
echo "DEBUG: Computed Start Time (sd) = '$sd'"
echo "DEBUG: Computed End Time (ed) = '$ed'"

# Define the Tau_pick.txt file
TAU_PICK_FILE="$WD/Event_RF/Info/Tau_pick.txt" # Save all the TauP results in a .txt file for later use

# Convert Event_ID to the correct format (replace last two hyphens with colons)
formatted_ID=$(echo "$ID" | sed -E 's/([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2})-([0-9]{2})-([0-9]{2})/\1:\2:\3/g')

# If Tau_pick.txt does not exist, create it and add a header
if [ ! -f "$TAU_PICK_FILE" ]; then
    echo "Time Net Sta Depth Distance Phase ArrivalTime RayParam TakeoffAngle IncidentAngle" > "$TAU_PICK_FILE"
fi

# Append the formatted event details to Tau_pick.txt
echo "$formatted_ID $net $sta $event_depth $distance $phase_name $p_arrival $ray_param $takeoff_angle $incident_angle" >> "$TAU_PICK_FILE"


# Write to fetch file
# Fetchfiles updated for each waveform for fetching
echo "$net $sta $loc_code $chn $sd $ed" >> $WD/Event_RF/Fetch_Text/$ID.txt


        # Create the event directory **only if** valid P-arrival is found
        mkdir -p "$WD/Event_RF/Data/$ID"

        echo "$net $sta $loc_code $chn $sd $ed" >> $WD/Event_RF/Fetch_Text/$ID.txt

    done < $WD/Event_RF/Info/STID.txt

done < $WD/Event_RF/Info/Event_Time.txt

############################### DOWNLOADING SAC DATA ##############################################

cp $WD/FetchData_original.pl $WD/Event_RF/Fetch_Script/
chmod +x $WD/Event_RF/Fetch_Script/FetchData_original.pl # Using IRIS Fetch.pl for FEtching according to given reqirments.

for k in `ls $WD/Event_RF/Data/`; do
    BID=$(date -j -f "%Y-%m-%dT%H-%M-%S" "$k" "+%Y-%m-%dT%H:%M:%S")

    # Extract event information and convert time to Julian format
    event_info=$(awk -v var1="$BID" -F "|" '$2~var1 {print $2, $3, $4, $5}' $WD/Event_RF/Info/Event_RF.txt)

    if [[ -z "$event_info" ]]; then
        echo "Error: Missing event info for $k. Skipping..."
        continue
    fi

    event_time=$(echo "$event_info" | awk '{print $1}')
    event_lat=$(echo "$event_info" | awk '{print $2}')
    event_lon=$(echo "$event_info" | awk '{print $3}')
    event_depth=$(echo "$event_info" | awk '{print $4}')

    # Convert event time to Julian format
    formatted_event=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$event_time" "+%Y-%j-%H:%M:%S")

    if [[ -z "$formatted_event" ]]; then
        echo "Error: Failed to convert event time for $k. Skipping..."
        continue
    fi

    event="$formatted_event/$event_lat/$event_lon/$event_depth"
    
    echo "BID: $BID"
    echo "Event_RF: $event"

    # Run FetchData script to download miniSEED files and metadata
    # Miniseed and metadata will be saved for each Event separately
    $WD/Event_RF/Fetch_Script/FetchData_original.pl -l $WD/Event_RF/Fetch_Text/$k.txt -o $WD/Event_RF/Data/$k/$k.mseed -m $WD/Event_RF/Data/$k/$k.metadata


    cd $WD/Event_RF/Data/$k
    mkdir -p SAC_Files Fetch_Files
    
    # mseed2sac will convert miniseed to SAC. These SAC files contains header files with all the station and event information

    mseed2sac -v -E "$event" -O "$k.mseed" -m "$k.metadata"

    # Move output files
    mv -f *.SAC SAC_Files/
    mv -f *mseed *metadata Fetch_Files/

done

############################### DOWNLOADING PZ FILES ##############################################
# PZ files will be downloaded for each satation-event pair since PZ files tend to change with time for the same station. PZ files will use for Instrument corrections later on....
mkdir -p $WD/Event_RF/PZfile_Ev_St_Pair

for k in `ls $WD/Event_RF/Data/`; do
    mkdir -p "$WD/Event_RF/PZfile_Ev_St_Pair/$k"  # Ensure directory exists
    
    cd "$WD/Event_RF/Data/$k/SAC_Files"

    for sac_file in *.SAC; do
        net=$(echo $sac_file | awk -F. '{print $1}')
        sta=$(echo $sac_file | awk -F. '{print $2}')
        loc=$(echo $sac_file | awk -F. '{print $3}')
        chan=$(echo $sac_file | awk -F. '{print $4}')

        # Extract start and end times from Fetch_Text file
        line=$(grep -E "^$net\s+$sta\s+" $WD/Event_RF/Fetch_Text/$k.txt)

        start_time=$(echo $line | awk '{n=split($0,a," "); print a[n-1]}')
        end_time=$(echo $line | awk '{n=split($0,a," "); print a[n]}')

        # Convert times to ISO format
        start_iso=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$start_time" "+%Y-%m-%dT%H:%M:%S")
        end_iso=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$end_time" "+%Y-%m-%dT%H:%M:%S")

        # Set location code if missing
        loc=${loc:-"--"}

        # Construct URL and download PZ file
        pz_url="http://service.iris.edu/irisws/sacpz/1/query?net=$net&sta=$sta&loc=$loc&cha=$chan&starttime=$start_iso&endtime=$end_iso"
        output_file="$WD/Event_RF/PZfile_Ev_St_Pair/$k/SACPZ.${net}.${sta}.${loc}.${chan}"

        echo "Fetching PZ file from: $pz_url"
        curl -o "$output_file" "$pz_url"

    done
done




