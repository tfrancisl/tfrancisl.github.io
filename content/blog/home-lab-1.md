---
date: '2026-07-12T10:28:43-04:00'
draft: false
title: 'Home Lab with NixOS - RPi4, pi-hole, gatus'
---

When you carry a NixOS shaped hammer, you'll hit home lab shaped nails. Or at least I am.
DNS content blocking is useful for sparing your network and devices from unwanted requests, often
telemetry pulses, but in the worst cases, malicious traffic.


## On content blocking

There are a bunch of ways to achieve this type of content blocking, and, in fact, my ISP seemingly
already has some sort of blocking built in. Naturally, their blocking covers the latter case of
malicious sites much more so than telemetry, as the router I am mandated to use is for residential
networks in the US. So, you can look around and find [pi-hole](https://pi-hole.net/), 
[technitium](https://github.com/TechnitiumSoftware/DnsServer), or another DNS server that is
optimized around content blocking from block lists. I went with pi-hole since it is so ubiquitous
and proven.

## Setting up the Pi

I happen to have a pi3 and a pi4 laying around from projects of old. For a variety of reasons, I
chose to use the pi4 at this time, but realistically, it would be easy enough to get the set up
I will describe going on any pi2+ as far as I understand.

Nixpkgs has derivations for aarch64-linux SD card images of NixOS, which come with the requisite 
firmware for Raspberry Pi's, as well as a uboot bootloader to allow for swapping generations at boot.
Further, these derivations are 
[built and cached in Hydra](https://hydra.nixos.org/job/nixos/release-26.05/nixos.sd_image.aarch64-linux), 
so I don't even have to build the image. Just download the image, `dd` it over to your SD card, put
the SD card in the Pi and plug it in. You'll see uboot, then you'll boot into a tty on NixOS. From
there I did a small amount of manual sysadmin - log in to root, give it a password, then change the
password for the `nixos` user as well. Use `nmtui` to connect to wireless, or, better yet, wire the Pi
right into your network by ethernet if possible.

At this point, you could start tweaking the default configuration.nix file generated on the system
and begin changing the system locally, but my preference was to manage this from my main machine.
Since the default image enables ssh, we've connected to the network, and set creds for root and
the primary user, we can just use the `--target-host` and `--build-host` flags on our preferred
nix system management command (`nixos-rebuild`, or, as I usually recommend, `nh os`) to apply config
from wherever to the Pi. The Pi4 is powerful enough to evaluate nix fairly quickly, and build small
programs, so I haven't bothered with arch emulation on my main machine, or using a more powerful ARM builder.


## Virtualization and isolation

For a small project like this where I'm not sure how many services I'll even run on the system, it's
arguable that virtualization and isolation are not particularly necessary. I don't really think they
are, but I was very curious about the simpler methods of isolation that are easy to configure with
NixOS. The `containers` option in NixOS modules provides an abstraction around `systemd-nspawn` containers
such that you can provide an entire NixOS configuration to define as a container to run on the host
system. This abstraction is awesome and beats the one provided by `virtualisation.oci-containers.containers`,
as, as far as I can tell, I would need to generate OCI-compliant images ahead of time and use those as input.
There are drawbacks to systemd-npsawn, of course. Isolation is more manual and limited. By default,
most resources are directly shared from the host to the guests, most notably networking. But, having
all of the NixOS modules and nixpkgs available and as easy to use as using them in a regular system 
config is just so powerful.


## The easy part: setting up services

Everything gets a whole lot easier now since our container definitions are just NixOS configurations.
We can define one container for each service we want, or, multiple services in one container as
appropriate.

### Pi-hole

There's a pi-hole NixOS module under `services`, so our container definition can be as simple as:
```nix
_: { services.pihole-ftl.enable = true; }
```
This would give us a container running pi-hole with no block lists, no local DNS records, the domain
name `pi.hole` and no web dashboard. It would also have port 53 (DNS) blocked on its firewall anyway.
So let's expand this a bit:

```nix
{ lib, ... }: {
  networking.firewall.enable = false; # use the hosts firewall
  services = {
    pihole-web = {
      enable = true;
      ports = [
        "80r"
        "443so"
      ];
    };
    pihole-ftl = {
      enable = true;
      settings = {
        dns = {
          upstreams = [
            "1.1.1.1"
          ];
          hosts = [
            "192.168.1.224 yggdrasil.midgard.lan"
            "192.168.1.123 valhalla.midgard.lan"
          ];
          hostRecord = "yggdrasil,yggdrasil.midgard.lan,192.168.1.224";
          piholePTR = "HOSTNAMEFQDN";
          domain = {
            name = "midgard.lan";
            local = true;
          };
        };
        webserver = {
          domain = lib.mkForce "yggdrasil.midgard.lan";
        };
      };
      lists = [
        {
          url = "https://media.githubusercontent.com/media/zachlagden/Pi-hole-Optimized-Blocklists/main/lists/comprehensive.txt";
          type = "block";
          enabled = true;
          description = "zachlagden/Pi-hole-Optimized-Blocklists/main/lists/comprehensive.txt";
        }
      ];
    };
  };
}
```

The pi-hole web server actually has a separate module option, but if you look into the definition of
both options, they are tightly linked together. Since we are in a container and have our network
interfaces bound to the host network interfaces, most of our networking config will actually be on the host.
Here's what the host config for this container may look like:
```nix
{ lib, ... }: {
  networking = {
    firewall = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [
        53
        80
        443
      ];
    };
  };
  containers = {
    pihole = {
      ephemeral = false; # pihole has lots of state, this is unavoidable I think
      autoStart = true;
      config = import ./guest.nix { inherit lib; };
    };
  };
}
```

After this, I had to take a few steps to make sure (most if not all) of my devices would use pi-hole
for DNS. The first step is setting this as the primary name server on your router. This might be
perilous if you have a more draconian ISP than myself. Mine, fortunately, gives the option to set
up to two name servers, and seems to honor them for all devices on the network.
The second step depends on whether your devices use your router as their primary name server by
default. I've found that the default config in NetworkManager or networkd-systemd on NixOS do,
MacOS seems to, and my Android phone does not. So I had to manually tweak that on my phone.

My findings using pi-hole for just about a week now:
My primary machine, where I use Firefox with uBlock Origin, sees almost no blocked requests.
Occasionally I'll see a few telemetry pulses get blocked (mostly duckduckgo's search improvement API).
This isn't surprising. The block lists used by UBO and the block list I chose certainly have a ton
of overlap, including telemetry end points.

For my work laptop, a Macbook Pro, between 1/5th and 1/3rd of all requests were blocked.
Let me repeat that: for every 1 non-telemetry request made by software on my work machine, 2-4 
telemetry requests were made. 90% of those were to Microsoft services, and 90% of those were by
Teams. Amazing software if you ask me, it's a wonder with all that telemetry how the performance
of the app is worse than ever.

### Gatus

Ok, I'll admit I got bored by how simple that was to set up. There were a couple hiccups here and
there, mostly around trying to use the `.local` TLD for my network, not knowing it was reserved.
That threw me for a loop for a few hours...

[Gatus](https://github.com/TwiN/gatus) is a declarative status page software that is configured in 
YML and simply makes requests to endpoints and reports back based on the contents of the response. 
I saw it promoted on HN a few months ago and figured, hey, that's a lot simpler than building my own 
status page. I also figured I would end up wanting more and more on this dashboard as time goes on, 
so I went for it.

I figured I'd have to write my own service definition and such since the project seemed new, but nope,
someone already added it to nixpkgs. Here's a minimal config for the container:
```nix
_: {
  networking.firewall.enable = false; # use the hosts firewall
  services = {
    gatus = {
      enable = true;
      configFile = ./gatus.yml;
    };
  };
}
```
Note that in this case, I am referencing a yml file that lives next to this nix file. You could also
use some of the builtins to write this in Nix, but it's a little easier to just write the YML in my opinion.
I'm starting with a dead simple config which will lookup my main machine's A record to check that
the pi-hole is running as expected.
```yml
web:
  port: 8091

endpoints:
  - name: pihole-dns
    url: "127.0.0.1"
    dns:
      query-name: "valhalla.midgard.lan"
      query-type: "A"
    conditions:
      - "[BODY] == 192.168.1.123"
      - "[DNS_RCODE] == NOERROR"
```

The host configuration, then, is much like that for pi-hole, but with only port 8091 exposed to the
network.

## Future work

Naturally, a simple project like this is inspiring me in a few different directions. I want to add
more services to my home network for various purposes, possibly including git mirrors, intrusion
detection or other suspicious activity detection, and possibly a nix builder for some custom nix packages.

Other than expanding the home lab, I should also look into further isolation of the containers I'm using.
I could switch all the containers to be unpriveleged, and I could force them to use a private network.
With a private network, the host system would have to specifically bind ports on the containers to
ports on it's interface, rather than exposing the network interface to the containers to use as they please.
This isn't super critical since this pi is living on a private network, behind a NAT, with no ports
exposed to the broader internet, but it's still worth it.

The code for this system is on my [GitHub at yggdrasil-at-midgard](https://github.com/tfrancisl/yggdrasil-at-midgard).
