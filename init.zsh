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
    RUST_LOG=warn voidpin listen --grpc "0.0.0.0:$voidpin_port" &
    local pid=$! 
     
    local timeout=5  # Timeout in seconds for local connection attempt
    local local_host="nef"
    local remote_host="nef_remote"
    #local zellij_cmd="if command -v zellij >/dev/null 2>&1; then zellij attach || zellij; else echo 'zellij not found, starting regular session'; $SHELL; fi"
    local zellij_cmd="zellij"

    echo "Attempting local connection to $local_host..."

    {
      # Try local connection first with timeout
      if timeout $timeout ssh -o ConnectTimeout=$timeout \
                            -o BatchMode=yes \
                            -o StrictHostKeyChecking=accept-new \
                            "$local_host" "exit" 2>/dev/null; then
          # If the test connection succeeded, make the actual connection
          echo "Connected locally"
          MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="ssh -t" "$local_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $zellij_cmd"
          #ssh -t "$local_host" "$zellij_cmd"
      else
          echo "Local connection failed, trying remote connection..."
          # Try remote connection
          if ssh -o ConnectTimeout=10 \
                 -o StrictHostKeyChecking=accept-new \
                 "$remote_host" "exit" 2>/dev/null; then
              echo "Connected remotely"
              MOSH_TITLE_NOPREFIX=1 mosh --no-init --ssh="ssh -t" "$remote_host" -- zsh -c "VOIDPIN_REMOTE=http://10.0.9.19:$voidpin_port $zellij_cmd"
              #ssh -t "$remote_host" "$zellij_cmd"
          else
              echo "Error: Both local and remote connections failed"
              return 1
          fi
      fi
    } always {
      kill $pid 2>/dev/null
    }

}

alias git-review=~/.cargo/bin/rev
alias ranger=yazi
