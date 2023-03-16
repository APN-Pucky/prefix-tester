if [ ! $# -eq 5 ]
then
    echo "Usage: $0 OS FULL_LOG BUILD_LOG INFO_LOG KEY"
    exit 1
else
    OS=$1
    FULL=$2
    BUILD=$3
    INFO=$4
    KEY=$5
    if [ ! -f "$FULL" ]; then
      echo "$FULL does not exist."
      exit 1
    fi
    if [ ! -f "$BUILD" ]; then
      echo "$BUILD does not exist."
      exit 1
    fi
    if [ ! -f "$INFO" ]; then
      echo "$INFO does not exist."
      exit 1
    fi
fi

TITLE=$(grep -i -A 1 "Details might be found in the build log:" $FULL | tail -n1  | sed 's/.*portage\/\(.*\)\/temp.*/\1/')
TITLE="$TITLE: bootstrap-prefix.sh fails"

# compress both logs with bz2
bzip2 -z $FULL
bzip2 -z $BUILD
FULL=$FULL.bz2
BUILD=$BUILD.bz2

##################
# Report the bug #
##################


# Search for existing bugs
bugz -k $KEY search "$TITLE" -r alexander@neuwirth-informatik.de 1> bgo_$SUFFIX.out 2> bgo_$SUFFIX.err
echo "Failed: $TITLE"
if grep -Fq "$TITLE" bgo_$SUFFIX.out ; then
  echo "found"
else
  echo "not found"
fi
if grep -Fq "$TITLE" bgo_$SUFFIX.out ; then
    echo "Bug exists"
    #exit 1
    # abort if multiple bugs reported
    if grep -Fq "Info: 1 bug" bgo_$SUFFIX.out
    then
        # get bug id
        id=$(cat bgo_$SUFFIX.out | tail -n2 | head -n1 | awk '{print $1}')
        echo "Bug id: $id"
        bugz -k $KEY get "$id" 1> bgo_$SUFFIX.out 2> bgo_$SUFFIX.err
        if grep -Fq "$OS" bgo_$SUFFIX.out
        then
            # already reportet for this OS
            echo "Bug already reported for $OS"
        else
            echo "Adding message for $OS"
            # add message fails for this os as well
            bugz -k $KEY modify --comment-from "./$INFO" $id 1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err
            # attach logs
            bugz -k $KEY attach --content-type "application/x-bzip2" --description "" $id $FULL 1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err
            bugz -k $KEY attach --content-type "application/x-bzip2" --description "" $id $BUILD 1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err
        fi
    else
        echo "Multiple bugs found, aborting"
    fi
else
    echo "Reporting the bug"
    # Post the bug
    bugz --key $KEY \
        post \
        --product "Gentoo/Alt"          \
        -a prefix@gentoo.org \
        --component "Prefix Support"    \
        --version "unspecified"           \
        --title "$TITLE"          \
        --op-sys "Linux"                  \
        --platform "All"                  \
        --priority "Normal"               \
        --severity "Normal"            \
        --alias ""                        \
        --description-from "./$INFO"   \
        --batch                           \
        --default-confirm n               \
        --cc alexander@neuwirth-informatik.de \
        1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err 

    id=$(grep "Info: Bug .* submitted" bgo_$SUFFIX.out | sed 's/[^0-9]//g')
    # Attach the logs
    bugz -k $KEY attach --content-type "application/x-bzip2" --description "" $id $FULL 1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err 
    bugz -k $KEY attach --content-type "application/x-bzip2" --description "" $id $BUILD 1>bgo_$SUFFIX.out 2>bgo_$SUFFIX.err 
fi

