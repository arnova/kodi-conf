#!/bin/sh

if [ -z "$1" ]; then
  echo "No target path specified" >&2
  exit
fi

ROOT_DIR="$1"

symlink()
{
  local FN_DIR=`dirname "$1"`
  local FN_FILE_SOURCE=`basename "$1"`
  local FN_FILE_TARGET=`basename "$2"`

  cd "$FN_DIR"
  ln -sv "$FN_FILE_SOURCE" "$FN_FILE_TARGET"
#  ln -v "$FN_FILE_SOURCE" "$FN_FILE_TARGET"
}


is_linked()
{
  if [ -h "$1" ]; then
    if [ -e "$1" ]; then # Is it a dead link?
      return 0
    else
      rm -f "$1" # Remove dead link
    fi
  fi

#  local FILE_DIR=`dirname "$1"`
#  local FILE_NAME=`basename "$1"`

#  if [ find "$FILE_DIR/" -xdev -samefile "$FILE_NAME"

  return 1
}

has_video_file()
{
  local FN=`echo "$1" |sed -e s:'\.[a-z]*$'::`

  # Assume video files have either of the files below linked to them:
  if [ -e "${FN}.nfo" -o -e "${FN}-poster.jpg" -o \
       -e "${FN}-thumb.jpg" -o -e "${FN}-fanart.jpg" ]; then
    return 0
  fi

  # Not found:
  return 1
}


is_movies_folder()
{
  # Don't confuse with a series root folder:
  if ! is_series_root_folder "$1" && ! is_episode_folder "$1" && has_video_file "$1"; then
    local FILE_TBN="$(echo "$1" |sed s:'\.[a-z]*$':'\.tbn':)"
    local FILE_POSTER="$(echo "$1" |sed s:'\.[a-z]*$':'-poster\.jpg':)"
    if [ -e "$FILE_TBN" -o -e "$FILE_POSTER" ]; then
      echo "* movie: $1"
      return 0
    fi
  fi

  # Not found:
  return 1
}


is_series_root_folder()
{
  local SEASON_TBN="$(dirname "$1")/season-all.tbn"
  local SEASON_POSTER="$(dirname "$1")/season-all-poster.jpg"

  if [ -e "$SEASON_TBN" -o -e "$SEASON_POSTER" ]; then
    echo "* tvshow: $1"
    return 0
  fi

  # Not found:
  return 1
}


is_episode_folder()
{
  local DIR_NAME=`dirname "$1"`
  # If the parent folder is the series root we're in the episode folder
  if is_series_root_folder "$DIR_NAME/../."; then
#    if has_video_file "$1"; then
      echo "* episode: $1"
      return 0
#    fi
  fi

  #  Check for episodes without episode folder: This means that our current dir holds both series root + episodes
  if is_series_root_folder "$1"; then
    local FN=`basename "$1"`
    # Only key to check whether it also contains the episodes is check for .tbn/-thumb files without season-
    if echo "$FN" |grep -i -q -e '-thumb\.jpg$' || echo "$FN" |grep -v '^season' |grep -q -i '\.tbn$'; then
      echo "* episode/serie: $1"
      return 0
    fi
  fi

  return 1
}



# file-poster.jpg: for eg. movies
check_file_poster()
{
  local FILE_POSTER="$1"
  local FILE_TBN="$(echo "$FILE_POSTER" |sed s:'-poster\.jpg$':'\.tbn':)"

  if is_linked "$FILE_TBN"; then
    return
  fi

  # This is tricky: only symlink from -poster to .tbn when it's in a movies or series root folder
  if is_movies_folder "$FILE_TBN" || is_series_root_folder "$FILE_TBN"; then
    # Make sure it's no combined episode/series root folder:
    if ! is_episode_folder "$FILE_TBN"; then 
      if [ -e "$FILE_TBN" ]; then
        rm -vf "$FILE_TBN"
      fi
      symlink "$FILE_POSTER" "$FILE_TBN"
    fi
  fi
}


# file-thumb.jpg: for eg. episodes
check_file_thumb()
{
  local FILE_THUMB="$1"
  local FILE_TBN="$(echo "$FILE_THUMB" |sed s:'-thumb\.jpg$':'\.tbn':)"
  
  if is_linked "$FILE_TBN"; then
#    echo "* $FILE_THUMB already symlinked to $FILE_TBN"
    return
  fi

  # This is tricky: only symlink from -thumb to .tbn when it's in an episode folder
  if is_episode_folder "$FILE_TBN"; then
    if [ -e "$FILE_TBN" ]; then
      rm -vf "$FILE_TBN"
    fi
    symlink "$FILE_THUMB" "$FILE_TBN"
  fi
}


# file.tbn
check_file_tbn()
{
  local FILE_TBN="$1"

  if is_linked "$FILE_TBN"; then
#    echo "* $FILE_TBN already symlinked"
    return
  fi

  local FILE_TARGET=""
  # This is tricky: for episode folders .tbn=-thumb, for series root folders .tbn=-poster, for movies: .tbn=-poster
  if is_episode_folder "$FILE_TBN"; then
    # Episode folder use -thumb:
    FILE_TARGET="$(echo "$FILE_TBN" |sed s:'\.tbn$':'-thumb.jpg':)"
  elif is_movies_folder "$FILE_TBN" || is_series_root_folder "$FILE_TBN"; then
    # All others use -poster (movies,series-root, etc.)
    FILE_TARGET="$(echo "$FILE_TBN" |sed s:'\.tbn$':'-poster.jpg':)"
  else
    echo "* Folder type unknown!: $FILE_TBN" >&2
    # NO-OP since type is unknown
    return
  fi

  if [ -n "$FILE_TARGET" ]; then
    if [ -e "$FILE_TARGET" ]; then
      rm -fv "$FILE_TBN"
    else
      mv -v "$FILE_TBN" "$FILE_TARGET"
    fi

    symlink "$FILE_TARGET" "$FILE_TBN"
  fi
}


# folder.jpg, if here it's a file which should become a symlink
check_folder_jpg()
{
  local FOLDER_JPG="$1"
  
  if is_linked "$FOLDER_JPG"; then
    # Already converted
 #   echo "* $FOLDER_JPG already symlinked"
    return
  fi
 
  # Make sure this is a series folder
  if ! is_series_root_folder "$FOLDER_JPG"; then
    return
  fi

  local FOLDER_BANNER="$(echo "$FOLDER_JPG" |sed s:'folder\.jpg$':'banner\.jpg':)"
 
  if [ -e "$FOLDER_BANNER" ]; then
    # Folder poster exists
    rm -fv "$FOLDER_JPG"
  else
    mv -v "$FOLDER_JPG" "$FOLDER_BANNER"
  fi
  
  symlink "$FOLDER_BANNER" "$FOLDER_JPG"
}


# banner.jpg check
check_folder_banner()
{
  local FOLDER_BANNER="$1"
  local FOLDER_JPG="$(echo "$FOLDER_BANNER" |sed s:'banner\.jpg$':'folder\.jpg':)"
  
  # Check for folder poster
  #########################
  if is_linked "$FOLDER_JPG"; then
    # Already converted
#    echo "* $FOLDER_JPG already symlinked"
    return
  fi
   
  # Make sure this is a series folder
  if ! is_series_root_folder "$FOLDER_BANNER"; then
    return
  fi

  if [ -e "$FOLDER_JPG" ]; then
    rm -fv "$FOLDER_JPG"
  fi

  symlink "$FOLDER_BANNER" "$FOLDER_JPG"
}


IFS='
'
find "$ROOT_DIR" -type f -iname "*\.tbn" -o -iname "*-poster\.jpg" -o -iname "*-thumb\.jpg" -o -iname "banner\.jpg" -o -iname "folder\.jpg" |while read FN; do
  case `basename "$FN"` in
  *-poster.jpg )
    check_file_poster "$FN";
    ;;
  *-thumb.jpg )
    check_file_thumb "$FN";
    ;;
  *.tbn )
    check_file_tbn "$FN";
    ;;
  folder.jpg )
    check_folder_jpg "$FN";
    ;;
  banner.jpg )
    check_folder_banner "$FN";
    ;;
  esac
done

