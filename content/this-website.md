+++
date = '2026-05-17T18:29:17-04:00'
draft = false
title = 'How This Website Works'
+++

This website is statically generated with [Hugo](https://gohugo.io/). It's deployed as a GitHub page for my account. I make use of the free GitHub Actions usage offered to public repositories.

I use the [nix](https://nixos.org/) expression language and its rich ecosystem every chance I get. The developer tools and build environment for this website are defined in a simple `default.nix` file, and I use [npins](https://github.com/andir/npins) to pin nixpkgs.

It was obvious to me as soon as I realized that I could define the website as a nix derivation that I could simplify the build and deployment process to three steps:
1. Source a nix binary (or, my preferred fork of the evaluator, [lix](https://git.lix.systems/lix-project/lix))
2. Do anything special GitHub pages requires
3. Run a single nix command which builds the derivation

For 1, I could simply write my own script or GitHub action to download and install nix, but I looked around and was satisfied with [lix-gha-install-action](https://github.com/samueldr/lix-gha-installer-action). 
I've seen others use Docker images with nix baked in, or simpler wrappers around the lix installer, but this one works.

For 2, it's fair to say that GitHub (pre-Microsoft GitHub!) has a principle of dogfooding wherever possible: you simply chain three actions to get your page configured and deployed.

For 3, we get to the slightly interesting part. We're going to build a derivation whose output is our website. Sounds as simple as running `hugo build`, and it basically is. The only wrinkle are Hugo modules. These are just go modules which Hugo can load. 
It seems many themes for Hugo use a module, where the old way of doing this was git submodules. I don't mind submodules but figured I may as well hop aboard. The problem with Hugo modules is that by default, they will be fetched at build time by Hugo.

This is a big no-no if you're trying to build something with nix, because it's not inherently pure. 
We could expose the `go.sum` to nix in some way and verify the module hashes against that (it's unknown to me whether this is what `buildGoModules` does), but it's a lot easier to define a fixed output derivation (FOD) which depends on Hugo and runs `hugo mod vendor`.
The derivation which defines the website now depends on this FOD, where we simply run `hugo build` with whatever arguments we'd like. 
Finally, in GitHub Actions, we can run `nix build` against this derivation (`nix build -f . package` as of writing) and the `result` we get points to the contents of the website. We can upload this directory and we are done!


Below is the Action file as of the time of writing. It can also be [found](https://github.com/tfrancisl/tfrancisl.github.io/blob/main/.github/workflows/main.yml) in the git repo for [my website on GitHub](https://github.com/tfrancisl/tfrancisl.github.io/).


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
          submodules: recursive
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
