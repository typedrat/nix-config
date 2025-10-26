{
  writeScript,
  jq,
  socat,
}:
writeScript "hyprland-bitwarden-resize" ''
  #!/bin/sh

  handle() {
    case $1 in
      windowtitle*)
        # Extract the window ID from the line
        window_id=''${1#*>>}

        # Fetch the list of windows and parse it using jq to find the window by its decimal ID
        window_info=$(hyprctl clients -j | ${jq}/bin/jq --arg id "0x$window_id" '.[] | select(.address == ($id))')

        # Extract the title from the window info
        window_title=$(echo "$window_info" | ${jq}/bin/jq '.title')

        # Check if the title matches the characteristics of the Bitwarden popup window
        if [[ "$window_title" == *"(Bitwarden Password Manager) - Bitwarden"* ]]; then

          hyprctl --batch "dispatch togglefloating address:0x$window_id ; dispatch resizewindowpixel exact 500 800,address:0x$window_id"
        fi
        ;;
    esac
  }

  # NB: the directory should match the UID of the user you are running hyprland in.
  # Listen to the Hyprland socket for events and process each line with the handle function
  ${socat}/bin/socat -U - UNIX-CONNECT:/run/user/1000/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
''
