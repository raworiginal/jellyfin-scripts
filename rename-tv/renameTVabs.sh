#!/bin/bash

# Directory of the series
SOURCE=$1

# Get the series name from the Source Directory
series="$(basename "$SOURCE")"

# Remove the Release Year for file naming
echo "what year did the series premiere?"
read DATE
series_nodate="${series// ($DATE)/}"

# Create an array of Season Directories
seasons=("$SOURCE"/*)

# Loop over each season Directory
for season in "${seasons[@]}"; do
    # Get the Season Number for file naming
    season_name="$(basename "$season")"
    season_number="${season_name##* }"

    # Start the episode counter
    echo "What episode number does this batch start on?"
    read episode_number

    # Create an array of the episode files in the season directory
    episodes=("$season"/*)

    # Loop over each episode
    for episode in "${episodes[@]}"; do
        # Format each episode number as two digits (e.g 01, 02...)
        f_episode_num=$(printf "%02d" "$episode_number")

        # Concatenate the new file name
        new_name="${series_nodate} S${season_number}E${f_episode_num}.mkv"

        # Increment the counter
        (( episode_number++ ))

        echo "$episode becomes..."
        echo "$season/$new_name"

        # Rename the file in place
        mv "$episode" "$season/$new_name"
    done
done
