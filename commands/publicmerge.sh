#!/bin/bash


cd $(cd "$(dirname "$0")" ; pwd)/..


rm .git/index.lock 2> /dev/null
branch="$(git branch | awk '/^\*/{print $2}')"

./commands/keycache.sh

git remote add internal git@github.com:cyph/internal.git 2> /dev/null
git remote add public git@github.com:cyph/cyph.git 2> /dev/null
git fetch --all

./commands/merge.sh internal/prod public/master

git checkout $branch
