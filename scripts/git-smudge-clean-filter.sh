declare -A mapArr

mapArr["prodPassword"]="obfuscatedProductionPassword"
mapArr["devPassword"]="obfuscatedDevelopmentPassword"

echo "test"

sedcmd="sed"
if [[ "$1" == "clean" ]]; then
  for key in ${!mapArr[@]}; do
    sedcmd+=" -e \"s/${key}/${mapArr[${key}]}/g\""
  done  
elif [[ "$1" == "smudge" ]]; then
  for key in ${!mapArr[@]}; do
    sedcmd+=" -e \"s/${mapArr[${key}]}/${key}/g\""
  done  
else  
  echo "use smudge/clean as the first argument"
  exit 1
fi

eval $sedcmd