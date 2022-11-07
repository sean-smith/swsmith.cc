---
title: Github Best Practices
description:
date: 2021-06-14
draft: false
tags: [Git, Github]
---

*tl;dr*

1. One commit, one feature!
2. Specific commit messages
3. No merge commits!


## 0. Supercharge GIT 🦸‍♂️

Create a global `~/.gitconfig` file and include the following (change my name, email and home dir obviously):

```ini
[alias]
  st = status
  ci = commit
  br = branch
  co = checkout
  lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --"
  
[user]
        email = email@domain.com
        name = Sean Smith
[rebase]
        autoStash = true
[core]
        excludesfile = /Users/username/.gitignore
```

Then create a `~/.gitignore` file:

```
.DS_Store
.idea
*.swp
```

## 1. Get the code🍴

Fork the repo from the Github page:

![Just fork it](/img/github/fork.png)

Now go ahead and clone the fork:

```bash
git clone https://github.com/sean-smith/aws-hpc-tutorials
```

Now you can add the main repo as an upstream this will allow you to track the differences in your fork with the main repo

```bash
git remote add upstream https://github.com/aws-samples/aws-hpc-tutorials
```

Check to make sure everything is configured correctly:

```bash
$ git remote -vv
origin  https://github.com/sean-smith/aws-hpc-tutorials (fetch)
origin  https://github.com/sean-smith/aws-hpc-tutorials (push)
upstream        https://github.com/aws-samples/aws-hpc-tutorials (fetch)
upstream        https://github.com/aws-samples/aws-hpc-tutorials (push)
```

## 2. Make Changes 🥗

The first step before coding is to create a branch, it's helpful to branch off upstream/master so git will tell you when the branch/fork is out of sync:

```bash
$ git checkout -b super-awesome-feature upstream/develop
```

Then go wild and have some fun writing code :D

## 3. Commit those changes 🥘

An easy way to commit is to remember SAM (hi sam)

```bash
$ git commit -sam “Commit message”

-s = sign the commit, that looks like: `Signed-off-by: Sean Smith <seaam@amazon.com>`
-a = add all changed files, check `git st` before doing this to see what will change
-m = write the commit message inline, we only write short commit messages so this works for our purposes
```

Commit messages should be short and and answer the question:

> If applied this commit would... [*commit message here]*

For example:

```bash
$ git commit -sam “Add NICE DCV Section”
$ git commit -sam “Improve CSS Theme"
```

Read more about good commit messages here: https://chris.beams.io/posts/git-commit/

## 4. One feature one commit!!!

Squash all the commits into one commit. Each feature should be one commit.

Then you can rebase & squash:

```bash
git fetch upstream && git rebase upstream/master
git rebase -i upstream/master
```

Then change pick to squash for all but 1 commit, for example:

![Rebase](/img/github/rebase.png)

## 5. Pull Requests

Pull requests are easy-peasy, just push to your fork (origin):

```bash
git push origin my-awesome-feature-branch
```

Then create a Pull Request from the Github console:

![PR](/img/github/pr.png)

6. Making Changes to a Open Pull Request

If you need to make changes based on comments on the pull request, fret not:

Just amend your commit (remember one commit, one feature, no exceptions!)

```bash
git commit -a --amend 
```
-a = add everything that’s been changed
--amend = amend the last commit to include those changes

Then force push to your fork:

```bash
git push origin my-awesome-feature-branch --force
```

## 7. Merging a Pull Request

**Rule #1:** Never click “Merge Pull Request”.

Always Always Always “Rebase and Merge”. This keep the branch history clean of a bunch of merges and keeps the One feature One commit rule intact.

![Rebase and Merge](/img/github/rebase-merge.png)