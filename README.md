# Atom Remote Sync

Upload your files to remote host after every change.

## Usage

Create file `.remote-sync.json` in your project root with these settings:

* `transport` — Only `scp` supported right now.
* `hostname` — Remote host address.
* `username` — Remote host username.
* `password` — Remote host password.
* `target` — Target directory on remote host.

For example:

```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "username": "vagrant",
  "password": "vagrant",
  "target": "/home/vagrant/dirname/subdirname"
}
```
