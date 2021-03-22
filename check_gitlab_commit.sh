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
    exit 3;
fi
if [ -z "$BASH" ]; then
  echo "Please use BASH."
    exit 3;
fi


#Usage
usage() {
  echo ''' Usage: check_gitlab_commit.sh [OPTIONS]
  [OPTIONS]
  -b BRANCH     your branch you would like to check.
                defaults to the local branch
  -B c/w/o      Which state a wrong branch should result in
                c(ritical)/w(arning)/o(k) 
                default: warning
  -c c/w/o      Which state a wrong commit should result in
                c(ritical)/w(arning)/o(k) 
                default: warning
  -C c/w/o      Which state the check should end in,
                if the remote commit was read from the cache.
                c(ritical)/w(arning)/o(k) 
                default: warning
  -i ID         Id of your gitlab project.
                (required)
  -p PATH       Path to the git repository you want to check. 
                The path must be given from the root up.
                example: /path/to/git-repo
                (required)
  -t TOKEN      Your private access token.
                (required)
  -T INTEGER    Minutes for the cache to expire
                (default 0 (no cache))
  -u URL        Your gitlab url, if you are self hosting.
                defaults to: https://gitlab.com
                example: https://gitlab.example.com
  '''
}

#default values 
url="https://gitlab.com"
time_to_live=0
branch_criticallity="w"
commit_criticallity="w"
cache_criticallity="w"

#get options
while getopts "b:B:c:C:i:p:t:T:u:" opt; do
  case $opt in
    b)
      branch_remote=$OPTARG 
      ;;
    B)
      branch_criticallity=$OPTARG
      ;;
    c)
      commit_criticallity=$OPTARG
      ;;
    C)
      cache_criticallity=$OPTARG
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
    T)
      time_to_live=$OPTARG
      ;;
    u)
      url=$OPTARG
      ;;
    *)
      usage
      exit 3;
      ;;
  esac
done

#check required options
if [ -z "$project_id" ] || [ $# -eq 0 ]; then
      echo "Error: project-id is required"
        usage
          exit 3;
fi

if [ -z "$path" ] || [ $# -eq 0 ]; then
      echo "Error: path is required"
        usage
          exit 3;
fi

if [ -z "$token" ] || [ $# -eq 0 ]; then
      echo "Error: token is required"
        usage
          exit 3;
fi
time_to_live=$(expr $time_to_live \* 60)
if [ $? -eq 2 ] ; then
  echo "Error: Time to live is not an integer"
    exit 3;
fi;

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
  could_get_remote_commit=false
else 
  could_get_remote_commit=true
  commit_remote=${commit_remote:7}
  commit_remote=${commit_remote%\",\"short*}
  commit_remote_short=${commit_remote:0:${#commit_remote}-32}
fi;

#read/write cache remote commit
if [ $time_to_live -ne 0 ] ; then
  cache_file="/tmp/check_commit/cache"
  mkdir -p /tmp/check_commit

  if [ $could_get_remote_commit == true ] ; then
    echo "$commit_remote" > $cache_file
  else
    if [ ! -f "$cache_file" ] ; then
      echo "Unknown: could not get remote commit"
        exit -3;
    fi
    cache_creation=$(stat -c "%Y" $cache_file)
    current_time=$(date +%s)
    cache_age=$(expr $current_time - $cache_creation)
    cache_expiration=$(expr $time_to_live - $cache_age)
  
    if [ $cache_expiration -lt 0 ] ; then
      echo "Unknown: could not get remote commit"
        exit -3;
    fi
    commit_remote=$(cat $cache_file)
    commit_remote_short=${commit_remote:0:${#commit_remote}-32}
  fi
fi

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
if [ "$branch_state" -eq 0 ] && [ "$commit_state" -eq 0 ] && [ "$could_get_remote_commit" == true ] ; then
  echo "OK: remote and local on commit: ${commit_remote_short} and on branch: ${branch_remote}"
    exit 0;
fi;

if [ "$could_get_remote_commit" == false ] ; then
  echo "Could not get remote commit, reading from cache"
fi;

if [ "$commit_state" -ne 0 ] ; then
  echo "Remote and local are on different commits"
fi;

if [ "$branch_state" -ne 0 ] ; then
  echo "Remote and local are on different branches"
fi;


if [ "$commit_state" -ne 0 ] ; then
  echo "local commit: ${commit_local_short}"
  echo "remote commit: ${commit_remote_short}"
else
  echo "commit: ${comitt_local_short}"
fi;

if [ "$branch_state" -ne 0 ] ; then
  echo "local branch: ${branch_local}"
  echo "remote branch: ${branch_remote}"
else
  echo "branch: ${branch_local}"
fi;


if [ "$branch_criticallity" == "c" ] && [ "$branch_state" -ne 0 ] ; then
  exit 2;
elif [ "$cache_criticallity" == "c" ] && [ "$could_get_remote_commit" == false ] ; then
  exit 2;
elif [ "$commit_criticallity" == "c" ] && [ "$commit_state" -ne 0 ] ; then
  exit 2;
elif [ "$branch_criticallity" == "w" ] && [ "$branch_state" -ne 0 ] ; then
  exit 1;
elif [ "$cache_criticallity" == "w" ] && [ "$could_get_remote_commit" == false ] ; then
  exit 1;
elif [ "$commit_criticallity" == "w" ] && [ "$commit_state" -ne 0 ] ; then
  exit 1;
fi;
exit 0;
