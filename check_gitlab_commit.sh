#!/bin/bash
#
#   Simple bash script to check, if a local clone of a gitlab repository
#   is up to date, with the remote state (or vice versa), on a given branch.
#   Copyright (C) 2021 Levin Czepuck
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.


#startup check
if [ ! -e "/usr/bin/git" ]; then
  echo "/usr/bin/git is missing."
    exit 3
fi
if [ -z "$BASH" ]; then
  echo "Please use BASH."
    exit 3
fi

#Usage
usage() {
  echo ''' Usage: check_gitlab_commit.sh [OPTIONS]
  [OPTIONS]
  -b BRANCH     your branch you would like to check.
                defaults to the local branch
  -i ID         Id of your gitlab project.
                (required)
  -p PATH       Path to the git repository you want to check. 
                The path must be given from the root up.
                example: /path/to/git-repo
                (required)
  -t TOKEN      Your private access token.
                (required)
  -u URL        Your gitlab url, if you are self hosting.
                defaults to: https://gitlab.com
                example: https://gitlab.example.com
  '''
}

#default values 
url="https://gitlab.com"

#get options
while getopts "b:i:p:t:u:" opt; do
  case $opt in
    b)
      branch_remote=$OPTARG 
      ;;
    i)
      project_id=$OPTARG
      ;;
    p)
      path=$OPTARG
      ;;
    t)
      token=$OPTARG
      ;;
    u)
      url=$OPTARG
      ;;
    *)
      usage
      exit 3
      ;;
  esac
done

#check required options
if [ -z "$project_id" ] || [ $# -eq 0 ]; then
      echo "Error: project-id is required"
        usage
          exit 3
fi

if [ -z "$path" ] || [ $# -eq 0 ]; then
      echo "Error: path is required"
        usage
          exit 3
fi

if [ -z "$token" ] || [ $# -eq 0 ]; then
      echo "Error: token is required"
        usage
          exit 3
fi


#get info
#local branch
branch_local=$(git --git-dir=${path}/.git branch | grep \*)

if [ $? -eq 1 ] ; then
  echo "Error: could not fetch local branch."
    exit 3;
fi;

branch_local=${branch_local:2}

if [ -z "$branch_remote" ] || [ $# -eq 0 ]; then
  branch_remote=$branch_local
fi

#local commit
commit_local=$(git --git-dir=${path}/.git log -1 --date-order | grep commit)

if [ $? -eq 1 ] ; then
  echo "Error: could not fetch local commit."
    exit 3;
fi;

commit_local=${commit_local:7}
commit_local_short=${commit_local:0:${#commit_local}-32}

#remote commit
commit_remote=$(curl -s --header "PRIVATE-TOKEN: ${token}" "${url}/api/v4/projects/${project_id}/repository/commits/${branch_remote}" | grep id) 

if [ $? -eq 1 ] ; then
  echo "Error: could not fetch remote commit."
    exit 3;
fi;

commit_remote=${commit_remote:7}
commit_remote=${commit_remote%\",\"short*}
commit_remote_short=${commit_remote:0:${#commit_remote}-32}


#compare
if [ "$branch_remote" = "$branch_local" ]; then
  branch_state=0
else

  branch_state=1
fi

if [ "$commit_remote" = "$commit_local" ]; then
  commit_state=0
else
  commit_state=1
fi

#Decide output
if [ "$branch_state" -eq 0 ] && [ "$commit_state" -eq 0 ] ; then
  echo "OK: remote and local on commit: ${commit_remote_short} and on branch: ${branch_remote}"
    exit 0;
fi;

if [ "$branch_state" -eq 0 ] ; then
  echo "WARNING: remote and local are on different commits."
  echo "remote: ${commit_remote_short}"
  echo "local: ${commit_local_short}"
  echo "branch: ${branch_local}"
  exit 1;
fi;

if [ "$commit_state" -eq 0 ] ; then
  echo "WARNING: remote and local are on differnt branches."
  echo "remote branch: ${branch_remote} local branch: ${branch_local}"
  echo "Both branches are on commit: ${commit_remote_short}"
  exit 1;
fi;

echo "WARNING: remote and local are on different branches and commits."
echo "remote branch: ${branch_remote} remote commit ${commit_remote_short}"
echo "local branch: ${branch_local} local commit: ${commit_local_short}"
exit 1
