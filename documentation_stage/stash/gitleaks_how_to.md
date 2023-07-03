# How to protect a documentation git repository with Gitleaks

Documentation repositories, which go by many names and aliases, are a great tool for sharing information in a long-lived but unofficial way. The very nature of their purpose can make them vulnerable to operator error, if the intent if the repo is to document work such as `curl` based API commands, then sensitive API credentials are simply likely to leak into the repository.

[Gitleaks](https://github.com/gitleaks/gitleaks) is a fantastic tool for this problem. While clearly purposed more for developer oriented workspaces, it's simplicity of [baseline management](https://github.com/gitleaks/gitleaks#creating-a-baseline) and ease of integration with [pre-commit](https://pre-commit.com/), mean that it can be easily configured to prevent credential leaks easily, before they are commited and then pushed, which is ideal for documentation repositories that may not be "GitOps" managed to include any Github or repository host side security protection.

Put simply, if a repository will store files containing fields like:

```
curl -X GET --header 'Accept: application/json' --header 'X-Auth-Token: 'YOURTOKENHERE'' 'https://api.equinix.com/metal/v1/projects/'YOURPROJECTIDHERE'/hardware-reservations'
```

Theres a good chance you copied that directly from a terminal and into a text editor that saved to a file in the repository. If you forgot to manually sanitize it, it's likely that credential will get commited and pushed to the public without review. No bueno.

Gitleaks will create a baseline of your repository when you know it is in a credential safe place. Before (hence `pre-hook`) every subsequent commit, Gitleaks will check the new changes against the safe baseline. If it can detect strings that look like they may be credentials that are being net new added or changed, it will abort the change before getting to the commit message stage and provide an error about what it saw:

```
$ git commit .
Detect hardcoded secrets.................................................Failed
- hook id: gitleaks
- exit code: 1

○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

Finding:     --header 'REDACTED...
Secret:      REDACTED
RuleID:      equinix-metal-api-token
Entropy:     3.664498
File:        documentation_stage/stash/metal_rescue_clone.md
Line:        40
Fingerprint: documentation_stage/stash/metal_rescue_clone.md:equinix-metal-api-token:40

Finding:     token: REDACTEDD
Secret:      REDACTED
RuleID:      generic-api-key
Entropy:     4.562500
File:        metal.yaml
Line:        4
Fingerprint: metal.yaml:generic-api-key:4

Finding:     REDACTED ...
Secret:      REDACTED
RuleID:      equinix-metal-cli-token
Entropy:     2.584963
File:        metal.yaml
Line:        4
Fingerprint: metal.yaml:equinix-metal-cli-token:4

Finding:     --header 'X-Auth-Token: REDACTED' \
Secret:      REDACTED
RuleID:      generic-api-key
Entropy:     4.601410
File:        documentation_stage/stash/metal_rescue_clone.md
Line:        40
Fingerprint: documentation_stage/stash/metal_rescue_clone.md:generic-api-key:40

9:40PM INF 1 commits scanned.
9:40PM INF scan completed in 69.2ms
9:40PM WRN leaks found: 4
```

It should be noted there are other, important ways to protect Secret privacy:

- [Github: Securing your repository](https://docs.github.com/en/code-security/getting-started/securing-your-repository) # **DO THIS!!**
- [Github: Code scanning](https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/about-code-scanning)

# Install Gitleaks CLI (Optional)

[Gitleaks](https://github.com/gitleaks/gitleaks#installing) documents a couple of different paths for installing itself.

If you are looking to just get expiramenting as quickly as possible, I suggest downloading the pre-compiled binary for your system at their [releases page](https://github.com/gitleaks/gitleaks/releases).

This isn't strictly needed, we will setup the git repository to install it's own Gitleaks environment. Installing Gitleaks through this path gives us an operator friendly view of the tool.

## Setting a baseline

[Read the documentation](https://github.com/gitleaks/gitleaks#creating-a-baseline) around setting a baseline.

Going through a and creating a baseline before working through Git `pre-commit` can be useful for working with existing Documentation repositories, that likely already have lots of hand-sanitized data.

To compare against baseline:

- `gitleaks detect -v -c gitleaks_em.toml --baseline-path gitleaks-report.json`

My baseline command looks like:

- `gitleaks detect -v -c gitleaks_em.toml --report-path gitleaks-report.json --baseline-path gitleaks-report.json`

### My commands:

To read a simple report:

- `gitleaks detect -c gitleaks_em.toml -v`

To avoid git history:

- `gitleaks detect -c gitleaks_em.toml --no-git -v`

To write the report as a file to use as a baseline (say you add a new file that is sanitized that goes into the baseline):

- `gitleaks detect -v -c gitleaks_em.toml --report-path gitleaks-report.json`

To commit overwriding gitleaks (I like to do my commit message in an edit versus the `-m` flag:

- `SKIP=gitleaks git commit .`

# Install pre-commit

You will need to install [pre-commit](https://pre-commit.com/#install). Where I would normally say install things to a `venv` by default, the easiest and most likely path you want is to install `pre-commit` at the same level of abstraction as how you use git. Put another way, if you got `git` from `apt install git`, then just do `pip install pre-commit` (or possibly `pip3 install pre-commit`).

# Setup your repository:

## Gitleaks Pre-hook setup

Follow the Gitleaks documentation on installing a *pre-hook* file:
- [Here](https://github.com/gitleaks/gitleaks#pre-commit)

**Note**
While also contained in a file in this repository, my pre-hook file looks like this all said and done:
```
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.16.1
    hooks:
      - id: gitleaks
        args: ['-c', 'gitleaks_em.toml', '--baseline-path', 'gitleaks-report.json']
```

### pre-hook build errors

If you attempt your first commit and get an error like:
```
[INFO] Initializing environment for https://github.com/gitleaks/gitleaks.
[INFO] Installing environment for https://github.com/gitleaks/gitleaks.
[INFO] Once installed this environment will be reused.
[INFO] This may take a few minutes...
An unexpected error has occurred: CalledProcessError: command: ('/home/dlotterman/.cache/pre-commit/repo26qyjy74/golangenv-default/.go/bin/go', 'install', './...')
return code: 1
stdout: (none)
stderr:
    go: downloading github.com/rs/zerolog v1.26.1
    go: downloading github.com/lucasjones/reggen v0.0.0-20200904144131-37ba4fa293bb
    go: downloading github.com/spf13/cobra v1.2.1
    go: downloading github.com/spf13/viper v1.8.1
    go: downloading github.com/gitleaks/go-gitdiff v0.8.0
    go: downloading github.com/charmbracelet/lipgloss v0.5.0
    go: downloading github.com/fatih/semgroup v1.2.0
    go: downloading github.com/h2non/filetype v1.1.3
    go: downloading github.com/petar-dambovaliev/aho-corasick v0.0.0-20211021192214-5ab2d9280aa9
    go: downloading github.com/fsnotify/fsnotify v1.4.9
    go: downloading github.com/hashicorp/hcl v1.0.0
    go: downloading github.com/magiconair/properties v1.8.5
    go: downloading github.com/mitchellh/mapstructure v1.4.1
    go: downloading github.com/pelletier/go-toml v1.9.3
    go: downloading github.com/spf13/afero v1.6.0
    go: downloading github.com/spf13/cast v1.3.1
    go: downloading github.com/spf13/jwalterweatherman v1.1.0
    go: downloading github.com/spf13/pflag v1.0.5
    go: downloading github.com/subosito/gotenv v1.2.0
    go: downloading gopkg.in/ini.v1 v1.62.0
    go: downloading gopkg.in/yaml.v2 v2.4.0
    go: downloading github.com/lucasb-eyer/go-colorful v1.2.0
    go: downloading github.com/mattn/go-runewidth v0.0.13
    go: downloading github.com/muesli/reflow v0.2.1-0.20210115123740-9e1d0d53df68
    go: downloading github.com/muesli/termenv v0.11.1-0.20220204035834-5ac8409525e0
    go: downloading golang.org/x/sys v0.0.0-20211110154304-99a53858aa08
    go: downloading golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
    go: downloading golang.org/x/text v0.3.6
    go: downloading github.com/rivo/uniseg v0.2.0
    go: downloading github.com/mattn/go-isatty v0.0.14
    error obtaining VCS status: exit status 128
        Use -buildvcs=false to disable VCS stamping.
    error obtaining VCS status: exit status 128
        Use -buildvcs=false to disable VCS stamping.
Check the log at /home/dlotterman/.cache/pre-commit/pre-commit.log
```

You can be a responsible operator and really dig into it, or you can be lazy like me and find it's a ephemeral (likely) golang toolchain problem I don't really care about, so I can ignore it and re-run my commit with a `GOFLAG`:

- `GOFLAGS=-buildvcs=false git commit .`

And then never worry about it again.

# Gitleaks .toml file
The default [configuration toml file](https://github.com/gitleaks/gitleaks#configuration) is enough for most things, it should catch Metal and related tokens.

I've stared a WIP of some more explicit Metal toml [here](/gitleaks_em.toml). It has fairly aggressive checks on Equinix Metal related magic numbers, namely `32` character strings that look like API tokens, and UUID's.

The aggressive checks are intended for these documentation heavy repositories. Where the aggressive checks are there to catch absent minded additions, with the expectation being that the operator updates the baseline

# .gitignore

I don't like the baseline file in my repo, so I exlude it from git in my [.gitignore](/.gitignore)
