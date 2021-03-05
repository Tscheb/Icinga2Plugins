
A simple bash script to check, if a local clone of a gitlab repository
is up to date, with the remote state (or vice versa), on a given branch.

## Usage 

    Usage: check_gitlab_commit.sh [OPTIONS]
    [OPTIONS]
    -b BRANCH     Your branch you would like to check.
                  Defaults to the local branch.
    -i ID         Id of your gitlab project.
                  (required)
    -p PATH       Path to the git repository you want to check.
                  The path must be given from the root up.
                  example: /path/to/git-repo
                  (required)
    -t TOKEN      Your private access token.
                  (required)
    -u URL        Your gitlab url, if you are self hosting.
                  Defaults to: https://gitlab.com
                  example: https://gitlab.example.com
## Sample config:

#### Check Command

    object CheckCommand "gitlab_commit" {
        import "plugin-check-command"
        command = [ PluginDir + "/check_gitlab_commit.sh" ]

        arguments = {
            "-b" = "$branch$"
            "-i" = "$id$"
            "-p" = "$path$"
            "-t" = "$token$"
            "-u" = "$url$"
        }
    }

#### Service 

    apply Service "gitlab_commit" {
      import "generic-service"

      display_name = "Git Commit"
      check_command = "gitlab_commit"
      command_endpoint = host.vars.client_endpoint
      vars.id = 123
      vars.path = "/path/to/git-repo"
      vars.token = "XXXXXXXXXXXXXXXXXXXX"
      vars.url = "https://git.yourdomain.de"
      assign where host.vars.git == true
    }
