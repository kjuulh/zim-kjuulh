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

ghpv ()
{
    gh pr view -w
}

ghrv ()
{
    gh repo view -w
}

ghpc ()
{
  list=$(gh pr list | tail -n +1)
  choice=$(echo $list | fzf  | awk '{print $1}' | sed 's/#//g')

  gh pr checkout $choice

}

ghprc () 
{
  gh pr create
}

