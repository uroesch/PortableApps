![build-all-packages](https://github.com/uroesch/PortableApps/workflows/build-all-packages/badge.svg)
![daily-submodules-sync](https://github.com/uroesch/PortableApps/workflows/daily-submodules-sync/badge.svg)

# Personal PortableApps Meta Repository
This is my personal meta repository holding all my PortableApps
repositories and some useful scripts for helping with building and 
updating.


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

### Docker

This is a fairly new way to build on Linux and may still consist
a few issues here or there.

The dependencies such as wine and powershell are all packed into
the docker container so other than the omnipresent `bash` shell
and `git` and obviously a working installation of `docker` there
are no other dependecies.

### Installation instructions

```bash
git clone --recursive https://github.com/uroesch/PortableApps.git
cd PortableApps
./scripts/docker-build --all
```
## Windows

### Windows 10

Windows 10 should work out of the box as far as the supporting scripts
are concerned the only dependency required to be installed is a version
of Git.

---

# Clone repositories

## Prerequisites

Since there are few `submodules` linked in this repo the usual
clone command does not apply.

```bash
git clone --recursive https://github.com/uroesch/PortableApps.git
```

If you forgot the `--recursive` option you can populate the
submodules with this command.

```bash
git submodule update --recursive --init
```

---

# Build PortableApps

## Build single installer

In this example the `PlinkProxyPortable` installer is built.

```bash
cd PortableApps
cd PlinkProxyPortable
./Other/Update/Update.ps1
```

Note: If above command does throw an error on Windows due to execution policy try
  `powershell -ExecutionPolicy ByPass -File .\Other\Update\Update.ps1`.

## Build all installers

```bash
cd PortableApps
./scripts/build-all.ps1
```

Note: If above command does throw an error on Windows due to execution policy try
  `powershell -ExecutionPolicy ByPass -File .\scripts\build-all.ps1`.
