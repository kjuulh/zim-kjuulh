#!/bin/zsh

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
    echo "This is a Github repo."
    # Execute gh command
    gh $@
  elif [[ "$REMOTE_URL" =~ "git.front.kjuulh.io" ]]; then
    echo "This is a Gitea repo."
    # Execute gtea command
    coffee $@
  else
    echo "This repo's origin is not recognized."
  fi
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
