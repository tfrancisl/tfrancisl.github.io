---
date: '2026-08-23T08:50:01-04:00'
draft: false
title: 'How I Nix'
---

Did I mention that I really like Nix? It's a powerful tool for managing development environments and 
packaging software. Some of the hurdles people who are new to using nix face are scattered, possibly
outdated documentation, and wrapping one's head around the different ways to structure nix code. The
latter applies to personal dotfile repos (nixosConfigurations etc.), projects for nix tooling, and
any other software project you want to package with nix.

This article will demonstrate how I structure nix code in new repos, and some commentary on why I
think my approach is easier to generalize, easier to reason about than some other approaches, and 
why I'm more confident than ever in using nix to package software.


## Preamble: the Nix Ecosystem

The core parts of the Nix ecosystem, from my persective, are the [language itself](https://github.com/nixos/nix), 
the [nixpkgs package repository](https://github.com/NixOS/nixpkgs/), and 
the [NixOS modules defined within](https://github.com/NixOS/nixpkgs/tree/master/nixos/modules) that repo.
These repos ship more than enough for someone to [follow the tutorials at nix.dev](https://nix.dev/tutorials/),
where you might define a development shell using a hand-pinned copy of nixpkgs in order to achieve
reproducibility.

Outside of these core parts, there are tons of projects which are either packaged with nix, or
otherwise provide nix code like NixOS modules or helper functions. The simplest way to interact
with any code out there is to fetch it, pin it, and then use it similarly to how one may use nixpkgs.

### Enter: Flakes
I am not going to spend too much time on flakes. They provide *a* schema for managing inputs and
outputs in a git repo with nix code. Generally, I find them to be inflexible and that they obscure
some of the important machinery (namely, the transforms that happen to the inputs). Now, this isn't
to say I don't use projects that define flakes to manage their nix code--I do, and a "third-party"
tool is how I do it.

### "Third-party" Tools
In language ecosystems like Golang and Rust, it is common to target some git repository out there
as an input to your project and no one thinks anything of it. So I use the term "third-party" here
mostly to distinguish tooling from that supported upstream, i.e., anything you can't do with just
a nix implementation. 

Most of the tools that come to mind for me in this space have a high quality bar, and are usually
"upstreamed" to nixpkgs within a few weeks of introduction to the community, at least in my last
year of being around the nix community.

## How I Nix

This is the basic structure of the toplevel of any repository I plan on using nix in:
```sh
.tack/          # tack-managed inputs
default.nix     # entrypoint; i.e., `nix repl -f ./.`
inputs.nix      # inputs transforms or pass-through
outputs.nix     # output transforms
shell.nix       # development shell definition
```
and invariably the contents of `default.nix` are `import ./outputs.nix (import ./inputs.nix)`.

I think it should be fairly obvious if you've used flakes, or another pinning tool like `npins`, that
the heavy lifting on the inputs is being done by [`tack`](https://github.com/manic-systems/tack).
This is a relatively new tool by a reputable group of nix folks who like making fast, thorough tools
for nix. "All" it does is provide a nix helper function to lazily fetch inputs based on a toml file
enumerating the inputs. This makes for a very uninteresting, and perhaps seemingly bloated setup for
this website, so I will show some examples from my NixOS config/dotfiles to solidify the concepts.


### My NixOS config/dotfiles

Any code I share in this section is from [this revision](https://github.com/tfrancisl/nixos-config/tree/f1e36d1c15cf630c6f41e059d417aac24acf0a02) 
of my NixOS config.

You can bootstrap `tack` against a recent `nixpkgs-unstable` revision with a command like:
```sh
TACK_DIR="./.tack" nix run nixpkgs#tack -- init
```
...after which you will likely want to initialize and activate a dev shell in the repo with `tack`.

Here's my `.tack/pins.toml`:
```toml
[all_follow]
nixpkgs = "nixpkgs"

[inputs]
[inputs.nixpkgs]
url = "github:NixOS/nixpkgs/nixpkgs-unstable"

[inputs.hjem]
url = "github:feel-co/hjem"

[inputs.nix-darwin]
url = "github:nix-darwin/nix-darwin"

[inputs.claude]
url = "github:sadjow/claude-code-nix"

[inputs.ncro]
url = "github:manic-systems/ncro"
```
You can either manually edit this file, or use `tack` commands like `tack add` to configure your
inputs.

The `all_follow` section simply forces all pins to use the singular pinned copy of nixpkgs as their
nixpkgs input, if they have one. This is usually correct if none of your inputs are specifically 
meant to build against a particular nixpkgs revision or otherwise are cached against a particular 
revision.

Next we need to consume the inputs, which is as simple as importing the tack directory in nix.
Here's my `inputs.nix`:
```nix
let
  inputs = import ./.tack;
  inherit (inputs)
    nixpkgs
    hjem
    claude
    ncro
    nix-darwin
    ;
  mkNixosSystem =
    {
      system,
      modules,
      packages,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system modules;
      specialArgs = {
        inherit nixpkgs;
        pkgs' = packages.${system};
      };
    };
  mkDarwinSystem =
    {
      system,
      modules,
      packages,
    }:
    nix-darwin.lib.darwinSystem {
      inherit system modules;
      specialArgs = {
        inherit nixpkgs;
        pkgs' = packages.${system};
      };
    };
in
{
  inherit
    nixpkgs
    hjem
    claude
    ncro
    mkNixosSystem
    mkDarwinSystem
    ;
}
```
Arguably the two `mk` functions could go elsewhere, but these are simple transforms on `*.lib.{darwin,nixos}System`
which one may reasonably use to define multiple systems (not me though). As you can see, `tack` simply provides
an attr set of the inputs. That's super simple, and transparent to me as to how it fetched them.
No need to maintain a separate fetcher FOD for each input, or treat inputs specially if they are
a flake or a non-flake.

Since `default.nix` simply imports the outputs with the inputs as inputs, these attrs get passed on
and I then define each system, which I won't show here. Realistically, though, you can put *any attr set*
you want for your outputs. You don't need to think about the flake schema of `outputs.{nixosConfigurations,packages,shells}`,
etc.

`shell.nix` similarly consumes our inputs. To simplify things, I usually make it consume `inputs.nix` 
rather than `import ./.tack`.

```nix
let
  inputs = import ./inputs.nix;
  system = builtins.currentSystem;
  pkgs = inputs.pkgs.${system};
in
pkgs.mkShell {
  name = "nixos-config";
  TACK_DIR = "./.tack";
  packages = [
    pkgs.just
    pkgs.tack
    pkgs.treefmt
    pkgs.nixfmt
    pkgs.taplo
    (pkgs.callPackage ./packages/jqfmt.nix { })
    pkgs.deadnix
    pkgs.statix
    pkgs.nixf-diagnose
  ];
}
```
Note the impure `builtins.currentSystem`. This is a devshell, so you could take the flake approach
of defining the shells over a generator of system architectures, but I choose not to as it is
essentially pointless and makes `shell.nix` unusable. I use direnv with `use nix` directives so 
having a working `shell.nix` is important.


### Just put a derivation in `outputs.nix`
Ok, my NixOS config example is helpful for understanding how this stuff works for a NixOS config.
Obviously if I have an attr like `nixosConfigurations.valhalla`, I can use `nixos-rebuild` or `nh`
to target that attr and transform my system into it. But what about packages?

Just put a derivation in `outputs.nix`. Seriously. Anywhere in the output works, but in the case of
the derivation which builds this website in GitHub Actions, I put it in `package.default`.

```nix
{ pkgs, ... }: {
  package = {
    default = pkgs.stdenvNoCC.mkDerivation {
      name = "tfrancisl.github.io";
      # Include .git/ so Hugo can populate per-page .GitInfo in the sandbox.
      # Nix copies this to the build dir (owned by the build user), so git works.
      src = builtins.path {
        path = ./.;
        name = "tfrancisl.github.io-src";
        filter =
          path: _type:
          let
            base = baseNameOf path;
          in
          base != "public" && base != "result" && base != ".direnv";
      };
      nativeBuildInputs = [
        pkgs.hugo
        pkgs.git
        pkgs.typst # for rendered documents
      ];
      buildPhase = ''
        typst compile documents/resume.typ content/resume.pdf
        hugo build --gc --minify
      '';
      installPhase = "cp -r public $out";
    };
  };
}
```
How do you work with this? It's pretty simple; if I wanted, for some reason, to include a build of
my website in my system closure, I would simply add the repo as a tack input, import it, and then
add `website.package.default` to `environment.systemPackages` or the like. Or, if I want to look at
the current build, do as I do in CI: `nix build -f . package`. The disadvantage with this particular
output is that I have fixed the `pkg` instance to `x86_64-linux` so I can't use this on my mac. Oh
well: if you need to define over multiple architectures, use the same schema flakes do of
`packages.${system}.${pkg-name}`.


## Conclusion
I think the takeaway I want to leave people with is that you should tinker, and you should try to 
understand how things really work. I know the examples I've shared here are pretty simple for
someone who has been using nix for a long time, but for my first several months I felt trapped by
flakes and unable to understand how to make things work without them. I didn't need `tack` to come
along to set me free (in fact I was using `npins` for a few weeks while `tack` was in development),
but I was certainly inspired by how easy it is to set up nix projects without flakes.

I will likely continue to evolve the "schema" I use for the toplevel nix files in a project, 
especially as I try to take on more serious projects in my free time. I think there's potential to
distribute cache information and possibly alternative builds of software in this way, such that
upstreaming to nixpkgs or relying on flakes are not necessary for some tasks.
