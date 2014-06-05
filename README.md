# Atom Remote Sync

Upload your files to remote host after every change.

## Usage

Create file `.remote-sync.json` in your project root with these settings:

* `transport` — Only `scp` supported right now.
* `hostname` — Remote host address.
* `username` — Remote host username.
* `password` — Remote host password.
* `keyfile` — Absolute path to SSH key.
* `target` — Target directory on remote host.
* `ignore` — Array of [minimatch](https://github.com/isaacs/minimatch) patterns
  to ignore.


For example:

```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "username": "vagrant",
  "password": "vagrant",
  "keyfile": "/home/vagrant/.ssh/aws.pem"
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".git/**"
  ]
}
```
