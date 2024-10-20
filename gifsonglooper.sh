print_help(){
    echo -e "\nUsage: gifsonglooper [SPOTIFY_URL] [GIF_SRC] [BPM] [OUTPUT_FILE_NAME]"
    echo
}

download_spotify_song(){
    spotifySongURL=$1
    # source ~/venv2/bin/activate && echo "Activated python virtual environment"
    spotdl "$spotifySongURL"
}

timestamp_to_seconds(){
    durationString=$1
    hours=$(echo "$durationString" 2>&1 | cut -d ":" -f 1)
    minutes=$(echo "$durationString" 2>&1 | cut -d ":" -f 2)
    seconds=$(echo "$durationString" 2>&1 | cut -d ":" -f 3 | cut -d '.' -f 1)
    centiseconds=$(echo "$durationString" 2>&1 | cut -d ":" -f 3 | cut -d '.' -f 2)

    # echo "hours: $hours"
    # echo "minutes: $minutes"
    # echo "seconds: $seconds"
    clipDurationSeconds=$((($hours * 3600) + ($minutes * 60) + $seconds))
    clipDurationSeconds=$(bc <<< "scale=1; $clipDurationSeconds + ($centiseconds/100)")
    echo "$clipDurationSeconds"
}


spotifyURL=$1
gifSrc=$2
bpm=$3
outputFileName=$4

if [ -z "$spotifyURL" ]; then
    echo "No spotify URL specified. Exiting."
    print_help
    exit 1
fi

if [ -z "$gifSrc" ]; then
    echo "No gif source specified. Exiting."
    print_help
    exit 1
fi

if [ -z "$bpm" ]; then
    echo "No bpm specified. Exiting."
    print_help
    exit 1
fi

if [ -z "$outputFileName" ]; then
    echo "No output filename specified. Exiting."
    print_help
    exit 1
fi



tempDir="gifsonglooper"
echo "tempDir: $tempDir"


rm -rf $tempDir
mkdir -p $tempDir
cd $tempDir

python -m venv venv
source venv/bin/activate

download_spotify_song $spotifyURL
songPath=$(ls | grep ".mp3")

IFS='\n'
songDuration=$(ffprobe "$songPath" 2>&1 | grep Duration: | cut -d ',' -f1 | cut -d ':' -f2- | xargs)
echo "songDuration: $songDuration"
gifDuration=$(ffprobe "$gifSrc" 2>&1 | grep Duration: | cut -d ',' -f1 | cut -d ':' -f2- | xargs)
echo "gifDuration: $gifDuration"

gifSeconds=$(timestamp_to_seconds $gifDuration 2>&1)
echo "gifSeconds: $gifSeconds"

bps=$(bc <<< "scale=1; $bpm/60")
echo "bps: $bps"

barSeconds=$(bc <<< "scale=1; $bps*4")
echo "barSeconds: $barSeconds"


if  [ $(($bpm/60*4)) -gt $(echo "$barSeconds" | cut -d '.' -f1) ]; then
    gifScale=$(bc <<< "scale=2; $gifSeconds/$barSeconds")
else
    gifScale=$(bc <<< "scale=2; $barSeconds/$gifSeconds")
fi

while [ $(echo "$gifScale" | cut -d '.' -f1) -gt 2 ] || [ $(echo "$gifScale" | cut -d '.' -f1) -eq 2 ]; do 
    gifScale=$(bc <<< "scale=2; $gifScale/2")
done;

echo "gifScale: $gifScale"

ffmpeg -itsscale $gifScale -i "$gifSrc" scaledgif.gif
ffmpeg -stream_loop -1 -i scaledgif.gif -t "$songDuration" scaledvid1.mp4
ffmpeg -i scaledvid1.mp4 -i "$songPath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 loopedvid.mp4

cp loopedvid.mp4 "../$outputFileName.mp4"
rm -rf $tempDir

echo "Done"



