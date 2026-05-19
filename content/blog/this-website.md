---
date: '2026-05-17T18:29:17-04:00'
draft: false
title: 'How This Website Works'
---

This website is statically generated with [Hugo](https://gohugo.io/) and deployed as a GitHub Page. I make use of the free GitHub Actions usage offered to public repositories.

I use the [nix](https://nixos.org/) expression language and its ecosystem every chance I get. The developer tools and build environment for this website are defined in one nix file, and I use [npins](https://github.com/andir/npins) to pin nixpkgs.

I knew I would be able to simplify build and deployment of the site to three steps:
1. Source a nix binary (I use [lix](https://git.lix.systems/lix-project/lix) via [lix-gha-installer-action](https://github.com/samueldr/lix-gha-installer-action))
2. Do whatever GitHub Pages requires
3. Run `nix build -f . package` and upload

## Avoiding Hugo modules

I originally chose to include a `hugoModules` fixed output derivation (FOD) and use the Ananke theme that is suggested by the Hugo docs. The FOD worked but was of course cumbersome, and I also realized I didn't understand how to build anything with Ananke. So I decided to drop it altogether and learn how Hugo's template engine works.

Templating has always felt cursed to me, but it is just too powerful for working with static content. You can read arbitrary config from the project, or access info about the document, and so forth, to build a "dynamic" site statically. It's awesome.

## Per-page git info

If it's so easy to get info about pages, why not include git info? I noticed the Hugo wiki does this already and figured there must be a function for it. Enter `.GitInfo`.

Each page on this site shows the original creation date and the date and hash of the most recent commit that touched that file, with a link to that commit on GitHub. This uses Hugo's built-in `enableGitInfo` feature, which runs `git log` against the repository to populate `.GitInfo` per page.

The interesting part is making this work inside a nix sandbox. Nix derivations normally strip `.git/` from the source when copying it to the store. The fix is `builtins.path` with a custom filter that keeps `.git/` but excludes build artifacts. Since nix copies the source to the build directory (which is owned by the build user), git can read the history there without hitting safe directory issues.

## Classless CSS and Hugo are friends

I didn't even know about classless CSS libraries until I started using Hugo. There's a whole industry out there selling CSS tooling that I have refused to acknowledge, and maybe that's naive, but the libraries I looked at are not in it for profit. 

Simplicity is key, and you do not need to "sell" simple designs. They are too good to sell, if you ask me.

Hugo works nicely with simple.css because you can effectively write HTML in a way that is more similar to Markdown in terms of overall complexity, but with your templating commands all around it. This makes everything massively easier to reason about for me. Of course I'll likely change my mind at some point when I want more than one type of nav or article or such.


---

The full source is [on GitHub](https://github.com/tfrancisl/tfrancisl.github.io).

Below is the Action file as of the time of writing.

```yaml
name: Build and deploy
on:
  push:
    branches:
      - main
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
defaults:
  run:
    shell: bash
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: samueldr/lix-gha-installer-action@7b7f14d320d6aacfb65bd1ef761566b3b69e474c # v2026-02-22
      - uses: actions/configure-pages@v6
      - run: nix build -f . package
      - run: ls -alF result/
      - uses: actions/upload-pages-artifact@v5
        with:
          path: ./result
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/deploy-pages@v5
        id: deployment
```
