#!/bin/zsh

export CUDDLE_TEMPLATE_URL=git@git.front.kjuulh.io:kjuulh/cuddle-templates.git

# Coffee setup (https://git.front.kjuulh.io/kjuulh/coffee) is a gitea cli client like gh-cli
export COFFEE_OWNER=kjuulh
export FLUX_RELEASER_REGISTRY=https://releaser.i.kjuulh.io:443

#source <(jj util completion --zsh)

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
  elif [[ "$REMOTE_URL" =~ "git.front.kjuulh.io" ]]; then
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
  gh_client pr create
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
    local timeout=5  # Timeout in seconds for local connection attempt
    local local_host="nef"
    local remote_host="nef_remote"

    echo "Attempting local connection to $local_host..."
    
    # Try local connection first with timeout
    if timeout $timeout ssh -o ConnectTimeout=$timeout \
                          -o BatchMode=yes \
                          -o StrictHostKeyChecking=accept-new \
                          "$local_host" "exit" 2>/dev/null; then
        # If the test connection succeeded, make the actual connection
        echo "Connected locally"
        ssh "$local_host" zellij
    else
        echo "Local connection failed, trying remote connection..."
        # Try remote connection
        if ssh -o ConnectTimeout=10 \
               -o StrictHostKeyChecking=accept-new \
               "$remote_host" "exit" 2>/dev/null; then
            echo "Connected remotely"
            ssh "$remote_host" zellij
        else
            echo "Error: Both local and remote connections failed"
            return 1
        fi
    fi
}

alias git-review=~/.cargo/bin/rev
alias ranger=yazi
