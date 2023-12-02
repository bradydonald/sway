#!/bin/bash
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4 foldmethod=marker
# ----------------------------------------------------------------------
# Why are we using the wallpapers hashes? # {{{
#   Since more than one wallpaper can have the exact same name and
#   extension in different sub-directories, we're using two different
#   associative arrays, indexed by the wallpaper md5sum hash. Which
#   takes time to generate, specially if there are too many wallpapers
#   and/or their sizes are big, and/or the CPU power. That's why we're
#   using cache concept, to store the hashes and recall it whenever we
#   need to as long as nothing has changed in the wallpapers directory.
#   Of corse we can use another ways to avoid using the file hashes,
#   but we went with th hashes idea, because we're planning to name the
#   generated thumbnails by their original files hash. (not implemented
#   yet) The whole idea is to show the wallpaper thumbnail in rofi,
#   once we hit Alt+2, or execute : ~/.config/sway/bin/pick-wallpaper.sh
# }}}
# ----------------------------------------------------------------------
# @TODO: # {{{
#   - Show wallpapers thumbnails next to their names in rofi.
#   - Instead of relying on extensions in our find command, maybe it's
#     better to check the result with `file` command to determine
#     whether or not it is an image.
# Changelog:
#   2023/11/18:
#       - Fixed the symlinked files md5sum hash. In order to show them
#         in rofi choices.
#       - Rewrite the find command to ignore .git/ and show *png, *.jpg,
#         *.jpeg or the symlink file named: default.
#       - Since we can't copy an associative array in BASH, we create a
#         function called: get_associative_array_definition().
#       - Instead of regenerate all wallpapers hashes, whenever changes
#         have been detected, it might be better to just generate the
#         missing hashes, and remove the ones that their wallpapers were
#         removed.
#   2023/11/17:
#       - Instead of relying on the wallpapers count to determine a change
#         in the wallpapers directory, we can store all wallpapers in a
#         variable, and the total size in another variable, and use them to
#         decide whether or not we need to regenerate the cache.
#       - Show different notification based on whether or not it is the
#         first time we generate hashes.
#   2023/11/16:
#       - Using the cache concept to speedup the process.
#       - Rewrite most of the script.
# }}}
# ----------------------------------------------------------------------
#set -x


NOTIFYICON='/usr/share/icons/Adwaita/scalable/devices/video-display.svg'

DTIME=$(date +'%Y%m%d_%H%M%S')
PATH_WPS="${HOME}/Pictures/wallpapers"
PATH_THUMBNAILS="${HOME}/.cache/thumbnails/rofi-wallpapers"
PATH_CACHE="${HOME}/.cache/swayora"
WP_CACHE="${PATH_CACHE}/wallpapers_data"

# find only images or the symlink: default
RESULT=$(find "${PATH_WPS}" \( -type d -name .git -prune \) -or \( -not -type d \( -iname *.jpg -or -iname *.jpeg -or -iname *.png -or -name default \) \) -print)

WP_TOTAL=$(echo -e "${RESULT}" | wc -l)
WP_TOTAL_CACHE=0
WP_FILES=$(echo -e "${RESULT}" | sort -h)
WP_FILES_CACHE=()

[ -f "${PATH_CACHE}" ] && mv -Z "${PATH_CACHE}"{,.bkp-${DTIME}}
[ ! -d "${PATH_CACHE}" ] && mkdir -Z "${PATH_CACHE}"
[ -f "${WP_CACHE}" ] && source "${WP_CACHE}"

# For Debugging
#echo "${WP_TOTAL[@]}" > /tmp/ds.tmp/wp_files
#echo "${WP_FILES[@]}" >> /tmp/ds.tmp/wp_files
#echo "${WP_TOTAL_CACHE[@]}" > /tmp/ds.tmp/wp_files_cache
#echo "${WP_FILES_CACHE[@]}" >> /tmp/ds.tmp/wp_files_cache

function get_associative_array_definition() {
    # $1: array_name
    declare -p $1 | sed "s/declare -A $1=//"
}

if [[ $WP_TOTAL -ne $WP_TOTAL_CACHE || "$WP_FILES" != "$WP_FILES_CACHE" ]]; then
    if [ -f "$WP_CACHE" ]; then
        notify-send -i $NOTIFYICON -t 5000 "Re-scan Wallpapers" \
            'Changes have been detected in wallpapers directory. Please wait.'
    else
        notify-send -i $NOTIFYICON -t 10000 "Generating Wallpapers hashes" \
            'Please wait, this might take a while depending on the wallpapers count, their sizes and how powerful is your CPU.'
        declare -A file_names file_paths file_sizes file_hashes
    fi

    declare -A file_names_new file_paths_new file_sizes_new file_hashes_new

    while IFS= read -r -d '' file; do
        size=$(du -b "$file" | awk '{print $1}')
        if [[ -v file_sizes[$file] && ${file_sizes[$file]} -eq $size ]]; then
            key=${file_hashes[$file]}
        else
            if [ -L "$file" ]; then
                key=$(md5sum <<< "$file" | cut -d ' ' -f 1)  # Use MD5 hash as the key
            else
                key=$(md5sum "$file" | cut -d ' ' -f 1)  # Use MD5 hash as the key
            fi
        fi

        file_sizes_new["$file"]=$size
        file_hashes_new["$file"]=$key
        #relative_path=${file#"${PATH_WPS}"/}
        #file_names_new["$key"]=$(basename "$relative_path")
        file_names_new["$key"]=$(basename "$file")
        file_paths_new["$key"]=$file
    done < <(find "${PATH_WPS}" \( -type d -name .git -prune \) -or \( -not -type d \( -iname *.jpg -or -iname *.jpeg -or -iname *.png -or -name default \) \) -print0)

    unset file_names file_paths file_sizes file_hashes
    declare -A \
        file_names=$(get_associative_array_definition file_names_new) \
        file_paths=$(get_associative_array_definition file_paths_new) \
        file_sizes=$(get_associative_array_definition file_sizes_new) \
        file_hashes=$(get_associative_array_definition file_hashes_new)
    unset file_names_new file_paths_new file_sizes_new file_hashes_new

    {
        declare -p file_names
        declare -p file_paths
        declare -p file_sizes
        declare -p file_hashes
        echo "WP_TOTAL_CACHE=\"$WP_TOTAL\""
        echo "WP_FILES_CACHE=\"$WP_FILES\""
    } > "$WP_CACHE"

fi

[[ ! -z $1 && $1 == 'init' ]] && exit 0

if [ "${#file_paths[@]}" -eq 0 ]; then
    notify-send -i $NOTIFYICON -t 5000 'No wallpapers found.'
    echo "No wallpapers found."
    exit 1
fi

choices=""
## @TODO: spend more time to make thumbnails work in rofi.. doesn't work.
#
#thumbnails=""
#
## Create the thumbnail directory if it doesn't exist
#[ ! -d "${PATH_THUMBNAILS}" ] && mkdir -p "${PATH_THUMBNAILS}"
#
#if [[ $(find "${PATH_THUMBNAILS}" -type f | wc -l) -le 2 ]]; then
#    #notify-send -i "$thumbnail_path" "Selected Wallpaper" "$full_path"
#    notify-send "Please wait until we generate thumbnails"
#fi
#
for key in "${!file_paths[@]}"; do
    choices+="${file_names["$key"]}\n"
#    thumbnail_path="${PATH_THUMBNAILS}/thumbnail_${key}.jpg"
#    if [ -f "${thumbnail_path}" ]; then
#        thumbnails+="\n${thumbnail_path}"
#    else
#        # Error handling for ffmpeg
#        if ffmpeg -i "${file_paths["$key"]}" -vf "thumbnail=100:100" -frames:v 1 "${thumbnail_path}" &>/dev/null; then
#            thumbnails+="\n${thumbnail_path}"
#        else
#            echo "Failed to generate thumbnail for ${file_paths["$key"]}"
#            echo "Using a default thumbnail instead."
#            thumbnails+="\n/path/to/default_thumbnail.jpg"  # Specify a default thumbnail path
#        fi
#    fi
done

# remove the last \n
choices="${choices%??}"

#selected=$(echo -e "$choices" | rofi -dmenu -select 'default_tree_art' -p "Select Wallpaper:" -mesg "$thumbnails")
selected=$(echo -e "$choices" | rofi -dmenu -i -select 'default_tree_art' -p "Select Wallpaper:")

if [ -z "$selected" ]; then
    notify-send -i $NOTIFYICON -t 1500 'No wallpaper selected.'
    echo "No wallpaper selected."
    exit 1
fi

selected_key=""
for key in "${!file_names[@]}"; do
    if [ "${file_names["$key"]}" == "$selected" ]; then
        selected_key="$key"
        break
    fi
done

full_path="${file_paths["$selected_key"]}"
echo "Selected wallpaper: ${full_path}"

## Extract the corresponding thumbnail path
#thumbnail_path="${PATH_THUMBNAILS}/thumbnail_${selected_key}.jpg"

# Set the selected image as wallpaper
bash "${HOME}/.config/sway/bin/chbg" "$full_path"
exit 0

