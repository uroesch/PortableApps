### Build

#### Preparation 

##### Install build infra

Note: When building with docker this steps is not required. 

```
git clone https://github.com/uroesch/PortableApps.comInstaller.git
git clone -b patched https://github.com/uroesch/PortableApps.comLauncher.git
```

##### Clone repository

```
git clone https://github.com/uroesch/{{ AppName }}.git
cd {{ AppName }}
```

#### Windows 

##### Windows 10

The only supported build platform for Windows is version 10 other releases
have not been tested.

To build the installer run the following command in the root of the git
repository.

```
powershell -ExecutionPolicy ByPass -File Other/Update/Update.ps1
```

#### Linux

##### Docker

Note: This is currently the preferred way of building the PortableApps installer.

For a Docker build run the following command.

```
curl -sJL https://raw.githubusercontent.com/uroesch/PortableApps/master/scripts/docker-build.sh | bash
```

#### Local build

To build the installer under Linux with `Wine` and `PowerShell` installed run the
command below.

```
pwsh Other/Update/Update.ps1
```
