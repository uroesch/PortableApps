![build-all-packages](https://github.com/uroesch/PortableApps/workflows/build-all-packages/badge.svg)
![daily-submodules-sync](https://github.com/uroesch/PortableApps/workflows/daily-submodules-sync/badge.svg)

# Personal PortableApps Meta Repository 
This is my personal meta repository holding all my PortableApps
repositories and some useful scripts.


# Build environment setup

## Linux

### Ubuntu 18.04

At this point in time the only verified build environemnt on Linux is
Ubuntu 18.04. There are a few dependencies to be installed to build 
the PortableApps included in this repository. 

Namely:
* PowerShell
* Wine
* Git
* 7zip
* Xfvb [optional]

#### Installation instructions

1. Install powershell
```bash
sudo snap install powershell --classic
```
2. Install wine
```bash
sudo dpkg --add-architecture i386 && \
  sudo apt-get update && \
  sudo apt-get -y install wine32
```
3. Install git
```bash
sudo apt-get -y install git git-lfs
```
4. Install 7zip
```bash
sudo apt-get -y install p7zip-full
```
5. Install Virtual Frame Buffer
```bash
sudo apt-get -y install xvfb
```

## Windows 

### Windows 10

Windows 10 should work out of the box as far as the supporting scripts
are concerned the only dependency required to be installed is a version
of Git.

# Clone repositories

## Prerequisites

Since there are few `submodules` linked in this repo the usual
clone command does not apply.

```
git clone --recursive https://github.com/uroesch/PortableApps.git
```

If you forgot the `--recursive` option you can populate the
submodules with this command.

```
git submodule update --recursive --init
```

# Build PortableApps

## Build single installaller

In this example the `PlinkProxyPortable` installer is built.

```bash
cd PortableApps 
cd PlinkProxyPortable
pwsh -ExecutionPolicy ByPass -File Other/Update/Update.ps1
```

## Build all installers

```bash
cd PortableApps
./scripts/build-all.ps1
```
