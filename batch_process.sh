#!/bin/bash
############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Batch process mp3loop.exe" >&2;
   echo "All input wav files must have a 32k 44.1k or 48k sample rate, and" >&2;
   echo "also must be encoded with a bit depth of 16-bit." >&2;
   echo "Syntax: $0 [-h|v|q|d] [files]" >&2;
   echo "options:" >&2;
   echo "-h             Print this Help." >&2;
   echo "-v             Verbose mode." >&2;
   echo "-q [1-10]      Quality [1-10]. Default is 10 (best)." >&2;
   echo "-d [directory] Recurse through directory and convert all valid files." >&2;
   echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################
VERBOSE=
QUALITY=10
DIRECTORY=
MP3LOOP=$(find . -iname "mp3loop.exe");

readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
test_wav(){
  if [ $VERBOSE ]; then
    echo "Testing file with ffprobe";
  fi;
  test=$(ffprobe $1 2>&1 | grep pcm_s24 -o);
  if [ $test ]; then
    warning "mp3loop requires 16-bit wav files. Convert $1 with ffmpeg;"
  fi;
  return 1;
}

convert_mp3(){

  if [[ $(test_wav) ]]; then
    return 0;
  fi;
  test_incompatible_basename "$1";
  NODEL=
  if [[ "$(pwd)" == "$(dirname $1)" ]]; then
    NODEL=1
  fi;
  cp "$1" ./;
  
  tmpfile1=$(basename "$1");
  wine "$MP3LOOP" "$tmpfile1";
  if [ $? -eq 1 ]; then 
    tmpfile2=$(echo "$tmpfile1" | sed 's/^./~/g');
    rm $tmpfile2;
    error "mp3loop.exe failed";
  fi;
  if [ $NODEL ]; then
    return
  fi;
  rm $tmpfile1
  mkdir -p converted_mp3s
  last_mp3="$(ls *.mp3 -t | head -n 1)";
  if [ "$last_mp3" == "$(echo $tmpfile1 | sed 's/.wav$/.mp3/gi')" ]; then
    mv "$last_mp3" converted_mp3s/;
  fi;
}

test_incompatible_basename(){
  basename "$1" | grep "^~" &>/dev/null;
  if [ $? -eq 0 ]; then
    error "${1} has an incompatible filename for mp3loop.exe. Rename the file avoiding the \"~\" char." >&2;
  fi;
}

error(){
  echo ERROR: $1 >&2;
  echo "" >&2;
  Help;
  exit 1;
}

warning(){
  echo WARNING: $1 >&2;
}

requires_arg(){
  error "${1} requires an argument.";
}

if ! [[ "$(pwd)" == "$(dirname $0)" ]]; then
  error "$0 must be called from within its local directory, $(readlinkf $(dirname $0))";
fi;

if (($# == 0)); then
  error "No arguments provided." 
fi
while getopts "hvq:d" opt; do
  case $opt in
    h)
      Help;
      exit 0;
      ;;
    v)
      export VERBOSE=1;
      ;;
    q)
      if [[ -z "$OPTARG" ]]; then requires_arg "-q"; fi;
      export QUALITY="$OPTARG";
        echo "$QUALITY" | grep "^[1-9]0\?$" > /dev/null;
        if [ $? -eq 1 ]; then 
          error "${QUALITY} is not a valid argument for -q." 
        fi
      ;;
    d)
      export DIRECTORY=1;
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [[ $DIRECTORY ]]; then 
  if ! [ -d "$1" ]; then
    error "$1 is not a directory." >&2;
  fi;
  if [[ $VERBOSE ]]; then 
    echo "Converting directory ${DIRECTORY}" >&2; 
  fi;
  if  [ $VERBOSE ]; then
    find "$1" -type f -iname "*.wav"; >&2;
  fi;
  find "$1" -type f -iname "*.wav" | while read _file; do
    if [ $VERBOSE ]; then
      echo "Converting ${_file}..." >&2;
    fi;
    convert_mp3 "$_file";
  done;
  exit 0;
fi;


if [ $VERBOSE ]; then
  echo Converting $* >&2;
fi;
#test if there are directories in input
for _path in $*; do
  if [ -d "$_path" ]; then
    error "${_path} is a Directory. Call again with the -d option.";
  fi;
done;
ls $* | while read _file; do
  if [ $VERBOSE ]; then
    echo "Converting ${_file}..." >&2;
  fi;
  convert_mp3 "$_file";
done;
