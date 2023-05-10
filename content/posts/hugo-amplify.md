---
title: Static Websites with Hugo and Amplify ♥️
description:
date: 2023-05-10
tldr: Build static websites with full CI/CD using Hugo and Amplify.
draft: false
og_image: /img/hugo-amplify/hugo-amplify.jpg
tags: [aws, hugo, amplify]
---

{{< rawhtml >}}
<p align="center">
    <img src='/img/hugo-amplify/hugo-amplify.jpg' alt='Hugo + Amplify Logo' style='border: 0px; width:600px;' />
</p>
{{< /rawhtml >}}

It should be no secret that I ♥️ Hugo and Amplify. Combined I've built out nearly a dozen websites using these tools, including [hpcworkshops.com](https://www.hpcworkshops.com/), [pcluster.cloud](https://pcluster.cloud), [thefiftyproject.com](https://thefiftyproject.com/) and of course this website. These websites are hosted on AWS Amplify for a grand total of $.30/month with no server maintenance ever needed. Deployments are done using Github actions and new changes are automatically built and published when new commits are pushed to Github. Oh and all of this takes about 30 mins to setup, including TLS (https) certificates and Github integration. Need I say more?

## Hugo Setup

1. First install hugo, on a mac you can do:

    ```bash
    brew install hugo
    ```

2. Next create a new hugo project and name it with the domain you plan to use, i.e. `example.com`:

    ```bash
    hugo new site example.com
    cd example.com
    ```

2. Next create a git repository and add a theme. You can browse themes [here](https://themes.gohugo.io/). The theme I use for this website is [Archie Theme](https://github.com/athul/archie) and in the past I've used [Hugo Learn](https://github.com/matcornic/hugo-theme-learn) and [hugo story](https://themes.gohugo.io/themes/hugo-story/). I highly recommend looking for a theme that's popular (lots of github stars) as it'll be easier to customize and better supported going forward.

    ```bash
    git init
    git submodule add https://github.com/athul/archie themes/archie
    echo "theme = 'archie'" >> config.toml
    ```

    We use [Git Submodules](https://www.atlassian.com/git/tutorials/git-submodule) to add the theme. This is really important to get right, git submodules allow you to include one git repo inside another but without including all the files individually. Think of this like a symlink to another directory, you can easily update the theme when a new version comes out by pulling the latest version. On Github this will show up like `name @ commit` like so:

    ![Github Submodule](/img/hugo-amplify/github-submodule.png)
    
    Since this is a bit tricky, I recommend [reading about submodules]() to make sure you get it right. When done properly, the entire directory will show up in `git status` as a single file.

3. Now that you've added the theme you can preview changes locally with:

    ```bash
    hugo server -D
    ```

    Your content can now be viewed at http://localhost:1313. The page live-reloads when you make changes.

In the next section we'll show you how to host your website with AWS Amplify so it can be viewed from anywhere.

## Amplify Setup

1. First navigate to [AWS Amplify](https://console.aws.amazon.com/amplify/home) console. If you don't have an account you'll need to create one.

2. Select **New app** > **Host a web app**. Select Github as the source:

    ![Select Github](/img/hugo-amplify/setup-1.png)

3. Next you'll need to authenticate with Github, you'll then be prompted to select a source repo. If you don't have a Github repo already, go ahead and create one, it can start out empty. See [Github Best Practices 🦸‍♂️](/posts/github-best-practices.html) for tips on pushing to Github. I like naming the repos with the same domain as they publish too, i.e. the repo for this website is [https://github.com/sean-smith/swsmith.cc](https://github.com/sean-smith/swsmith.cc).

    ![Select Repo](/img/hugo-amplify/setup-2.png)

3. Next amplify will attempt to auto-detect your build-settings. If you already have a hugo site setup, it'll correctly populate the build settings. If not you can use the following snippet to correctly setup the build.

    ```yaml
    version: 1
    frontend:
      phases:
        build:
          commands:
            - hugo
      artifacts:
        baseDirectory: public
        files:
          - '**/*'
      cache:
        paths: []
    ```

    ![Select Repo](/img/hugo-amplify/setup-3.png)

4. Next click **Review** and then **Save and deploy**

5. After a little bit your website will be available at a url like: `https://main.d1m7bkiki6tdw1.amplifyapp.com`
