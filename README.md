# Atom Remote Sync

Upload your files to remote host after every change.

## Usage

Create file `.remote-sync.json` in your project root with these settings:

* `transport` — Only `scp` supported right now.
* `hostname` — Remote host address.
* `port` - Remort port to connect on.
* `username` — Remote host username.
* `password` — Remote host password.
* `keyfile` — Absolute path to SSH key.
* `target` — Target directory on remote host.
* `ignore` — Array of [minimatch](https://github.com/isaacs/minimatch) patterns
  to ignore.
* `uploadOnSave` — Optional, default: true

For example:

```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "port": 22,
  "username": "vagrant",
  "password": "vagrant",
  "keyfile": "/home/vagrant/.ssh/aws.pem",
  "passphrase": "your_passphrase",
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".git/**"
  ]
}
```

useAgent example:
```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "port": 22,
  "username": "vagrant",
  "useAgent": true,
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".git/**"
  ]
}
```

## Usage Example

Create folder, then create a file name called, `.remote-sync.json` like below.

```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "port": 22,
  "username": "vagrant",
  "password": "vagrant",
  "keyfile": "/home/vagrant/.ssh/aws.pem",
  "passphrase": "your_passphrase",
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".git/**"
  ]
}
```

in ATOM editor press command + shitf + p, 

input `remote sync Reload config`

in ATOM editor press command + shitf + p, 

input `remote sync Reload download all`

After those steps, you can upload files after files was changed.

