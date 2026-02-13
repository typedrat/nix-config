{
  name = "Track upstream issues";

  on = {
    push.branches = ["master"];
    workflowDispatch = {};
    schedule = [
      {cron = "0 22 * * *";}
    ];
  };

  jobs = {
    track = {
      runsOn = "ubuntu-latest";

      permissions = {
        issues = "write";
        contents = "read";
      };

      steps = [
        {uses = "actions/checkout@v4";}
        {
          name = "Scan and update dashboard";
          env.GH_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
          run = ''
            set -euo pipefail

            # Scan .nix files for GitHub issue/PR references (owner/repo#number)
            refs=$(grep -rPoh '[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+#[0-9]+' \
              --include='*.nix' --exclude-dir=.github . | sort -u) || true

            if [ -z "$refs" ]; then
              echo "No upstream references found."
              exit 0
            fi

            declare -A ref_title ref_state ref_status ref_locations

            for ref in $refs; do
              owner_repo="''${ref%#*}"
              number="''${ref##*#}"

              locations=$(grep -rPn "''${owner_repo}#''${number}\\b" \
                --include='*.nix' --exclude-dir=.github . \
                | sed 's|^\./||' \
                | while IFS=: read -r file line _; do echo -n "\`$file:$line\` "; done) || true

              if ! api_response=$(gh api "repos/$owner_repo/issues/$number" \
                --jq '[.title, .state, .pull_request.merged_at // empty] | @tsv' 2>/dev/null); then
                echo "Warning: could not fetch $ref, skipping"
                continue
              fi

              title=$(echo "$api_response" | cut -f1)
              state=$(echo "$api_response" | cut -f2)
              merged_at=$(echo "$api_response" | cut -f3)

              if [ -n "$merged_at" ]; then
                status="Merged"
              elif [ "$state" = "closed" ]; then
                status="Closed"
              else
                status="Open"
              fi

              ref_title["$ref"]="$title"
              ref_state["$ref"]="$state"
              ref_status["$ref"]="$status"
              ref_locations["$ref"]="$locations"
            done

            # Find existing dashboard issue
            issue_number=$(gh issue list --state open \
              --search "Upstream Issue Tracker in:title" \
              --json number,title \
              --jq '.[] | select(.title == "Upstream Issue Tracker") | .number' \
              | head -n1) || true

            # Create the issue if it doesn't exist
            if [ -z "$issue_number" ]; then
              issue_url=$(gh issue create \
                --title "Upstream Issue Tracker" \
                --body "Initializing...")
              issue_number="''${issue_url##*/}"
              echo "Created tracking issue #$issue_number"
            fi

            # Parse existing issue body for checkbox states and previously resolved refs
            declare -A prev_checked prev_resolved
            existing_body=$(gh api "repos/$GITHUB_REPOSITORY/issues/$issue_number" \
              --jq '.body' 2>/dev/null) || true

            while IFS= read -r line; do
              if [[ "$line" =~ ^\-\ \[x\]\ \[([a-zA-Z0-9_./-]+#[0-9]+)\] ]]; then
                prev_checked["''${BASH_REMATCH[1]}"]=1
                prev_resolved["''${BASH_REMATCH[1]}"]=1
              elif [[ "$line" =~ ^\-\ \[\ \]\ \[([a-zA-Z0-9_./-]+#[0-9]+)\] ]]; then
                prev_resolved["''${BASH_REMATCH[1]}"]=1
              fi
            done <<< "$existing_body"

            # Post comments for newly resolved refs
            for ref in $refs; do
              [ "''${ref_state[$ref]:-}" = "closed" ] || continue
              [ "''${prev_resolved[$ref]:-}" = "1" ] && continue

              owner_repo="''${ref%#*}"
              number="''${ref##*#}"

              comment="<!-- track-issues:$ref -->"
              comment+=$'\n'"@$GITHUB_REPOSITORY_OWNER **[$ref](https://github.com/$owner_repo/issues/$number)** has been resolved (''${ref_status[$ref]}). Locations that may need cleanup:"
              for loc in ''${ref_locations[$ref]}; do
                comment+=$'\n'"- $loc"
              done
              comment+=$'\n\n'"Check the box on the dashboard to dismiss this notification."

              gh api "repos/$GITHUB_REPOSITORY/issues/$issue_number/comments" \
                -f body="$comment" --silent
              echo "Posted notification for $ref"
            done

            # Delete comments for checked refs, removed refs, or no-longer-resolved refs
            tmp_comments=$(mktemp)
            gh api "repos/$GITHUB_REPOSITORY/issues/$issue_number/comments" \
              --paginate \
              --jq '.[] | select(.body | startswith("<!-- track-issues:")) | [.id, (.body | split("\n") | .[0])] | @tsv' \
              > "$tmp_comments" 2>/dev/null || true

            while IFS=$'\t' read -r comment_id first_line; do
              [ -z "$comment_id" ] && continue
              if [[ "$first_line" =~ track-issues:([a-zA-Z0-9_./-]+#[0-9]+) ]]; then
                comment_ref="''${BASH_REMATCH[1]}"
                should_delete=0

                # Delete if checkbox is checked
                [ "''${prev_checked[$comment_ref]:-}" = "1" ] && should_delete=1

                # Delete if ref no longer in codebase
                ref_in_codebase=0
                for ref in $refs; do
                  [ "$ref" = "$comment_ref" ] && { ref_in_codebase=1; break; }
                done
                [ "$ref_in_codebase" = "0" ] && should_delete=1

                # Delete if ref is no longer resolved (e.g. reopened upstream)
                if [ "$ref_in_codebase" = "1" ] && [ -n "''${ref_state[$comment_ref]:-}" ]; then
                  [ "''${ref_state[$comment_ref]}" != "closed" ] && should_delete=1
                fi

                if [ "$should_delete" = "1" ]; then
                  gh api "repos/$GITHUB_REPOSITORY/issues/comments/$comment_id" \
                    -X DELETE --silent 2>/dev/null || true
                  echo "Deleted notification for $comment_ref"
                fi
              fi
            done < "$tmp_comments"
            rm -f "$tmp_comments"

            # Generate dashboard body
            resolved_items=""
            open_rows=""

            for ref in $refs; do
              [ -z "''${ref_state[$ref]:-}" ] && continue
              owner_repo="''${ref%#*}"
              number="''${ref##*#}"
              link="[$ref](https://github.com/$owner_repo/issues/$number)"
              title="''${ref_title[$ref]}"

              if [ "''${ref_state[$ref]}" = "closed" ]; then
                checkbox=" "
                [ "''${prev_checked[$ref]:-}" = "1" ] && checkbox="x"
                resolved_items+="- [$checkbox] $link — $title (''${ref_status[$ref]}) — ''${ref_locations[$ref]}"
                resolved_items+=$'\n'
              else
                title_safe=$(echo "$title" | sed 's/|/\\|/g')
                open_rows+="| $link | $title_safe | ''${ref_locations[$ref]} |"
                open_rows+=$'\n'
              fi
            done

            body="This issue is automatically updated by CI to track external issue/PR references found in the codebase."
            body+=$'\n\n'"## Resolved"
            body+=$'\n\n'"These upstream issues have been resolved. The associated workarounds or temporary changes may no longer be needed."
            body+=$'\n'"Check the box to acknowledge and dismiss the notification."

            if [ -n "$resolved_items" ]; then
              body+=$'\n\n'"$resolved_items"
            else
              body+=$'\n\n'"_None_"$'\n'
            fi

            body+=$'\n'"## Awaiting Upstream"
            body+=$'\n\n'"These upstream issues are still open."
            body+=$'\n\n'"| Reference | Title | Locations |"
            body+=$'\n'"|-----------|-------|-----------|"

            if [ -n "$open_rows" ]; then
              body+=$'\n'"$open_rows"
            else
              body+=$'\n'"| _None_ | | |"
            fi

            body+=$'\n\n'"---"
            body+=$'\n'"*Last updated: $(date -u +%Y-%m-%d). This issue is managed by CI — do not edit manually.*"

            gh issue edit "$issue_number" --body "$body"
            echo "Updated issue #$issue_number"
          '';
        }
      ];
    };
  };
}
