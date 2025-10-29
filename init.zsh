#!/bin/zsh

export CUDDLE_TEMPLATE_URL=git@git.kjuulh.io:kjuulh/cuddle-templates.git

# Coffee setup (https://git.kjuulh.io/kjuulh/coffee) is a gitea cli client like gh-cli
export COFFEE_OWNER=kjuulh
export FLUX_RELEASER_REGISTRY=https://releaser.i.kjuulh.io:443


get_commit_title() {
  # Read entire input into a variable
  local input=$1

  # Separate lines into an array (we'll ignore trailing empty lines)
  local -a lines
  lines=("${(f)input}")

  local title=""
  local -a rest=()

  local foundTitle=false
  for line in "${lines[@]}"; do
    if [[ -z "$line" && "$foundTitle" == false ]]; then
      # Skip leading empty lines until we find a title
      continue
    fi

    if [[ "$foundTitle" == false ]]; then
      title="$line"
      foundTitle=true
    else
      rest+=("$line")
    fi
  done

  # Now remove everything after 'diff --git'
  local -a descriptionLines=()
  for line in "${rest[@]}"; do
    if [[ "$line" =~ ^diff[[:space:]]--git ]]; then
      break
    fi
    descriptionLines+=("$line")
  done

  # Join the description lines and trim leading/trailing whitespace
  local descriptionBlock
  descriptionBlock="${(F)descriptionLines}"
  descriptionBlock="$(echo "$descriptionBlock" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  echo "$title"
}

get_commit_description() {
  # Read entire input into a variable
  local input=$1

  # Separate lines into an array (we'll ignore trailing empty lines)
  local -a lines
  lines=("${(f)input}")

  local title=""
  local -a rest=()

  local foundTitle=false
  for line in "${lines[@]}"; do
    if [[ -z "$line" && "$foundTitle" == false ]]; then
      # Skip leading empty lines until we find a title
      continue
    fi

    if [[ "$foundTitle" == false ]]; then
      title="$line"
      foundTitle=true
    else
      rest+=("$line")
    fi
  done

  descriptionBlock="${(F)rest}"

  echo "$descriptionBlock" | cut-after "diff --git"
}


function jprc() {
  branch=$(gum input --placeholder "Your new branch name")
  if [ -z $branch ]; then
    echo "no branch was provided"
    return 1
  fi

  jj bookmark create "$branch" -r @-
  jj git push -b "$branch" --allow-new

  bookmark_commit=$(jj show "$branch" --template 'description' --git)

  title=$(get_commit_title "$bookmark_commit")
  body=$(get_commit_description "$bookmark_commit")

  cmd=(ghprc --head "$branch")

  if [[ -n "$title" ]]; then
    cmd+=(--title "$title")
  fi
  
  if [[ -n "$body" ]]; then
    cmd+=(--body "$body")
  else
    cmd+=(--body "$title")
  fi

  # Execute the command
  "${cmd[@]}"
}

function jpv() {
  ghpv
}

function jls() {
  jj status
}

function jl() {
  jj log
}

function jc() {
  message=$(gum write)
  if [ -z $message ]; then
    echo "no message arg was provided"
    return 1
  fi

  jca "$message"
}


function jpl() {
  bookmarks=$(jj b l -r 'bookmarks(regex:"master|main")')

  if echo "$bookmarks" | grep -q "main"; then
      jj b m main --to @-
  elif echo "$bookmarks" | grep -q "master"; then
      jj b m master --to @-
  else
      echo "No 'main' or 'master' bookmark found."
      return 1
  fi

  jj git push
}


function jca() {
  local message=$1
  if [ -z $message ]; then
    echo "no message arg was provided"
    return 1
  fi

  jj commit -m "$message"
}

function jp() {
  if [ -z $message ]; then
    echo "no message arg was provided"
    return 1
  fi

  commit_msg=$(jj commit -m "$message" 2>&1)
}

gbt () 
{
  list=$(git branch -l --all  | grep origin | sed 's/remotes\///g')
  choice=$(echo $list | fzf | sed 's/\*//g' | xargs echo)
  git checkout --track $choice
}


gcm ()
{
    local message=$1

    git commit -s -m "$message"
}

ga ()
{
    git add .
}

gs() 
{
  git -c color.status=always status -s
}

gca ()
{
    local message=$1

    git add .
    git commit -s -m "$message"
}

gc ()
{
    git add .
    git commit -s
}

gbc () 
{
  list=$(git branch -l)
  choice=$(echo $list | fzf | sed 's/\*//g' | xargs echo)
  git checkout $choice

}

gbn ()
{
  git checkout -b "$1"
}

gp () 
{
    git push
}

gsync ()
{
  git pull origin master --rebase
}

gh_client ()
{
  REMOTE_URL=$(git config --get remote.origin.url)

  # Check if the URL contains "github.com"
  if [[ "$REMOTE_URL" =~ "github.com" ]]; then
    # Execute gh command
    gh $@
  elif [[ "$REMOTE_URL" =~ "git.kjuulh.io" ]]; then
    # Execute gtea command
    coffee $@
  else
    echo "This repo's origin is not recognized."
    read "REPO_TYPE?Is this a Github repo or a Gitea repo? (github/gitea) "

    if [[ "$REPO_TYPE" = "github" ]]; then
      # Execute gh command
      gh $@
    elif [[ "$REPO_TYPE" = "gitea" ]]; then
      # Execute gtea command
      coffee $@
    else
      echo "Input not recognized. Please input either 'github' or 'gitea'."
    fi
  fi
}

ghrc() {
  gh_client repo create
}

ghpv ()
{
    gh_client pr view -w
}

ghrv ()
{
    gh_client repo view -w
}

ghpc ()
{
  list=$(gh_client pr list | tail -n +1)
  choice=$(echo $list | fzf  | awk '{print $1}' | sed 's/#//g')

  gh_client pr checkout $choice

}

ghprc () 
{
  gh_client pr create "$@"
}

update()
{
  zellij run -c -- sh -c 'brew update && brew upgrade'
  zellij run -c -- rustup update
  zellij run -c -- cargo install-update -a
  zellij run -c -- yay -Syyuu
}

preview_parquet() {
  p=$1
  fd .parquet "${p}" | fzf --preview 'pqrs head -n 5 {} --json | jq' --preview-window 'top:70%'
}

dev() {
    voidpin_port=$(shuf -i 30000-40000 -n 1)
    RUST_LOG=warn voidpin listen --grpc "0.0.0.0:$voidpin_port" >/dev/null 2>&1 &
    local pid=$!
    disown $pid

    local tunnel_port=$(shuf -i 30000-40000 -n 1)
    local client_remote_ip="10.0.9.19"
    local server_remote_ip="10.0.9.18"
    
    RUST_LOG=warn notunnel \
      --host "$client_remote_ip:$tunnel_port" \
      --server-host "$server_remote_ip" \
      --client-host "$client_remote_ip" \
      --client-host-port $tunnel_port \
      serve >/dev/null 2>&1 &
    local notunnel_pid=$!
    disown $notunnel_pid 
     
    local timeout=5  # Timeout in seconds for local connection attempt
    local local_host="nef"
    local remote_host="nef_remote"
    #local zellij_cmd="if command -v zellij >/dev/null 2>&1; then zellij attach || zellij; else echo 'zellij not found, starting regular session'; $SHELL; fi"
    local zellij_cmd="zellij"

    local tunnel_cmd="NOTUNNEL_HOST=$server_remote_ip NOTUNNEL_CLIENT_HOST=$client_remote_ip NOTUNNEL_HOST_PORT=$tunnel_port"

    local ssh_cmd=/usr/bin/ssh

    echo "Attempting local connection to $local_host..."

    {
      # Try local connection first with timeout
      if timeout $timeout $ssh_cmd -o ConnectTimeout=$timeout \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=accept-new \
                            "$local_host" "exit" ; then
          # If the test connection succeeded, make the actual connection
          echo "Connected locally"
          MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="$ssh_cmd -t" "$local_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $tunnel_cmd $zellij_cmd"
          #ssh -t "$local_host" "$zellij_cmd"
      else
          echo "Local connection failed, trying remote connection..."
          # Try remote connection
          if $ssh_cmd -o ConnectTimeout=10 \
                 -o StrictHostKeyChecking=accept-new \
                 "$remote_host" "exit"; then
              echo "Connected remotely"
              MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="$ssh_cmd -t" "$remote_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $tunnel_cmd $zellij_cmd"
              #ssh -t "$remote_host" "$zellij_cmd"
          else
              echo "Error: Both local and remote connections failed"
              return 1
          fi
      fi
    } always {
      {
          kill $pid 2>/dev/null
          kill $notunnel_pid 2>/dev/null
      } 2>/dev/null
    }
}

dev_ratchet() {
    voidpin_port=$(shuf -i 30000-40000 -n 1)
    RUST_LOG=warn voidpin listen --grpc "0.0.0.0:$voidpin_port" &
    local pid=$!

    local tunnel_port=$(shuf -i 30000-40000 -n 1)
    local client_remote_ip="10.0.9.19"
    local server_remote_ip="10.0.9.1"
    
    RUST_LOG=warn notunnel \
      --host "$client_remote_ip:$tunnel_port" \
      --server-host "$server_remote_ip" \
      --client-host "$client_remote_ip" \
      --client-host-port $tunnel_port \
      serve &
    local notunnel_pid=$! 
     
    local timeout=5  # Timeout in seconds for local connection attempt
    local local_host="ratchet"
    local remote_host="ratchet"
    #local zellij_cmd="if command -v zellij >/dev/null 2>&1; then zellij attach || zellij; else echo 'zellij not found, starting regular session'; $SHELL; fi"
    local zellij_cmd="zellij"

    local tunnel_cmd="NOTUNNEL_HOST=$server_remote_ip NOTUNNEL_CLIENT_HOST=$client_remote_ip NOTUNNEL_HOST_PORT=$tunnel_port"

    local ssh_cmd=/usr/bin/ssh

    echo "Attempting local connection to $local_host..."

    {
      # Try local connection first with timeout
      if timeout $timeout $ssh_cmd -o ConnectTimeout=$timeout \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=accept-new \
                            "$local_host" "exit" ; then
          # If the test connection succeeded, make the actual connection
          echo "Connected locally"
          MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="$ssh_cmd -t" "$local_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $tunnel_cmd $zellij_cmd"
          #ssh -t "$local_host" "$zellij_cmd"
      else
          echo "Local connection failed, trying remote connection..."
          # Try remote connection
          if $ssh_cmd -o ConnectTimeout=10 \
                 -o StrictHostKeyChecking=accept-new \
                 "$remote_host" "exit"; then
              echo "Connected remotely"
              MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="$ssh_cmd -t" "$remote_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $tunnel_cmd $zellij_cmd"
              #ssh -t "$remote_host" "$zellij_cmd"
          else
              echo "Error: Both local and remote connections failed"
              return 1
          fi
      fi
    } always {
      kill $pid 2>/dev/null
      kill $tunnel_pid 2>/dev/null
    }
}

alias git-review=~/.cargo/bin/rev
alias ranger=yazi

function jjt {
  # Check if gum is installed (only needed for interactive mode)
  if [[ -z "$1" ]] && ! command -v gum &> /dev/null; then
      echo "Error: gum is not installed"
      echo "Install with: brew install gum"
      exit 1
  fi

  # Check if bookmark was provided as argument
  if [[ -n "$1" ]]; then
      selected_bookmark="$1"
      echo "Using provided bookmark: $selected_bookmark"
  else
      gum style --foreground 212 --bold "Fetching remote bookmarks from origin..."

      # Get list of remote bookmarks from origin
      remote_bookmarks=$(jj bookmark list --remote origin 2>/dev/null | grep '@origin:' | awk '{print $1}' | sed 's/@origin:$//')

      if [[ -z "$remote_bookmarks" ]]; then
          gum style --foreground 196 "No remote bookmarks found on origin"
          exit 1
      fi

      # Convert to array
      bookmarks_array=("${(@f)remote_bookmarks}")

      if [[ ${#bookmarks_array[@]} -eq 0 ]]; then
          gum style --foreground 196 "No remote bookmarks available"
          exit 1
      fi

      # Use gum filter for fuzzy search
      gum style --foreground 86 --bold "Select a remote bookmark (type to search):"
      selected_bookmark=$(printf "%s\n" "${bookmarks_array[@]}" | gum filter --height 15 --placeholder "Search bookmarks..." | sed 's/@origin:$//')

      if [[ -z "$selected_bookmark" ]]; then
          gum style --foreground 196 "No bookmark selected"
          exit 1
      fi

      gum style --foreground 86 "Selected: $selected_bookmark"

      # Confirm action
      gum confirm "Track and checkout '$selected_bookmark'?" || {
          gum style --foreground 214 "Cancelled"
          exit 0
      }
  fi

  echo "Tracking bookmark: ${selected_bookmark}@origin"
  # Track the bookmark
  if ! jj bookmark track "${selected_bookmark}@origin" 2>&1; then
      echo "Failed to track bookmark"
      exit 1
  fi

  echo "Creating new change on: $selected_bookmark"
  # Create new change based on the bookmark
  if ! jj new "$selected_bookmark" 2>&1; then
      echo "Failed to create new change"
      exit 1
  fi

  echo "✓ Successfully tracked and checked out bookmark: $selected_bookmark"
}

function ght {
  # Check if gum is installed
  if ! command -v gum &> /dev/null; then
      echo "Error: gum is not installed"
      echo "Install with: brew install gum"
      exit 1
  fi

  # Check if gh is installed
  if ! command -v gh &> /dev/null; then
      echo "Error: gh is not installed"
      echo "Install with: brew install gh"
      exit 1
  fi

  gum style --foreground 212 --bold "Fetching open PRs from GitHub..."

  # Get list of open PRs
  pr_list=$(gh pr list --state open --json number,title,headRefName --template '{{range .}}{{printf "%d\t%s\t%s\n" .number .title .headRefName}}{{end}}' 2>/dev/null)

  if [[ -z "$pr_list" ]]; then
      gum style --foreground 196 "No open PRs found"
      exit 1
  fi

  # Convert to array
  pr_array=("${(@f)pr_list}")

  if [[ ${#pr_array[@]} -eq 0 ]]; then
      gum style --foreground 196 "No open PRs available"
      exit 1
  fi

  # Use gum filter for fuzzy search
  gum style --foreground 86 --bold "Select a PR (type to search):"
  selected_line=$(printf "%s\n" "${pr_array[@]}" | gum filter --height 15 --placeholder "Search PRs...")

  if [[ -z "$selected_line" ]]; then
      gum style --foreground 196 "No PR selected"
      exit 1
  fi

  # Extract PR number and branch name
  pr_number=$(echo "$selected_line" | awk -F'\t' '{print $1}')
  branch_name=$(echo "$selected_line" | awk -F'\t' '{print $3}')

  gum style --foreground 86 "Selected: PR #$pr_number ($branch_name)"

  # Confirm action
  gum confirm "Checkout PR #$pr_number branch '$branch_name'?" || {
      gum style --foreground 214 "Cancelled"
      exit 0
  }

  echo "Checking out PR #$pr_number..."
  # Checkout the PR
  if ! gh pr checkout "$pr_number" 2>&1; then
      echo "Failed to checkout PR"
      exit 1
  fi

  echo "✓ Successfully checked out PR #$pr_number on branch: $branch_name"
}

