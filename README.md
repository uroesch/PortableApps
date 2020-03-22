# Personal PortableApps Meta Repository

This is my personal meta repository holding all my PortableApps
repositories and some useful scripts.

# How to clone

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

