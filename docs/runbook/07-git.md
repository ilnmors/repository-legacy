# Git configuration

## Convention

- `type(scope): subject`

- type:
    - feat: Append the new feature
    - fix: Fix the bug or errors
    - docs: Fix the documentations
    - refactor: Modify code structure without functional changes
    - perf: Improve the performance
    - chore: Modify system, package manager, etc configuration 
    - style: Fix code formatting, etc...

## Commit and tags

- In this homelab, `[Infra_structure_change]:[Services_change]:[Documents_and_configuration_change]` is the tagging rule.
- Tagging and commit should be distinguished.
- The change which affects system: tagging
- The change which doesn't affect system: commit
- `git commit -m "docs(git): define git convention"`

## Local git

```bash
# git config
git config --global user.name "il"
git config --global user.email "il@ilnmors.internal"
git config --global init.defaultBranch main # Set default branch name as main

# Git repository path
# $PROJECT_REPOSITORY/.git

# Remote registration and push git
cd ~/workspace/homelab

# Create .gitignore management for data directory
echo data/bin/ | tee  ./.gitignore
echo data/volumes/ | tee -a ./.gitignore
echo data/images/ | tee -a ./.gitignore
echo docs/archives/textfiles/ | tee -a ./.gitignore

# Select files
# When the set repository as first time
git init

# To commit and tag, you should `git add`
git add .
# Check git changes
git status
git commit -m "1.0.0: Release IaaS baseline"
git tag -a 1.0.0 -m "IaaS baseline"


# Commands
git status # What files are changed
git log # The version record
git diff # What is changed after last commit
git show $tag # Tag version and information check.
git checkout $tag # rollback to tag version
git branch $branch_name # Create branch
git switch $branch_name # Switch branch
git branch # list of branch
git switch main # Switch to main branch
git merge $branch_name # run at the main branch, merge.
git stash # temporary save
git stash pop # get temporary save

# After git switch
git switch service
git rebase --ignore-date main # set date as current time on main branch
```

## Add Service with git

```bash
# Example of establish gitea
git branch caddy-app
git switch caddy-app
git commit -m "0.0.1-caddy-app: Start caddy-app branch"
git tag -a 0.0.1-caddy-app -m "caddy-app: Start caddy-app branch"
## After finishing gitea implement
git switch main
git merge caddy-app
```

## Connect local git and remote git

- Set this after gitea is implemented

```bash
# Add git remote repository
git config --global credential.helper store
git remote add origin https://gitea.ilnmors.com/il/ilnmors-homelab.git
# For first time to make connection between local and remote git
git push -u origin main
# Username for 'https://gitea.ilnmors.com': il
# Password for 'https://il@gitea.ilnmors.com': gitea.il.token
git push --tags
# After first connection, -u origin main option is not needed
git add $PATH
git commit -m "comment"
git tag -a $VERSION -m "comment"
git push && git push --tags
# -f and --force-with-lease can be used in commit and tags
# -f option and --force-with-lease
# -f: just overwrite forcefully without any condition. it is dangerous, because it doesn't care the changes (commit) from other local git
# --force-with-lease: overwrite forcefully only when there's no changes (commit) from other local git
```
