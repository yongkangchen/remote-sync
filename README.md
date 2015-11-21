# Atom Remote Sync

This package provides functionality for:

* Uploading changes automatically when you save a file
* Uploading/downloading files to/from the server
* Displaying diffs between the local and remote files with your favourite diff tool
* set difftoolPath in AtomSettingView of `remote-sync` — The path to your diff tool executable

Currently, both SCP/SFTP and FTP are supported.

## Installation

You can install this like any other Atom package, with one of these methods:

* Open your settings in Atom, select the "Install" tab, search for "remote-sync", and click install on it
* Run `apm install remote-sync` in a terminal
* Download or clone this repository to your `~/.atom/packages/` directory

## Usage

Create file `.remote-sync.json` in your project root with these settings:

* `transport` — `scp` for SCP/SFTP, or `ftp` for FTP
* `hostname` — Remote host address
* `port` - Remort port to connect on (typically 22 for SCP/SFTP, 21 for FTP)
* `username` — Remote host username
* `password` — Remote host password
* `keyfile` — Absolute path to SSH key (only used for SCP)
* `passphrase` — Passphrase for the SSH key (only used for SCP)
* `useAgent` — Whether or not to use an agent process, default: false (only used for SCP)
* `target` — Target directory on remote host
* `ignore` — Array of [minimatch](https://github.com/isaacs/minimatch) patterns of files to ignore
* `uploadOnSave` — Whether or not to upload the current file when saved, default: false
* `uploadMirrors` — transport mirror config array when upload
* `deleteLocal` - whether or not to delete the local file / folder after remote delete

SCP example:
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
    ".remote-sync.json",
    ".git/**"
  ]
}
```

SCP `useAgent` example:
```json
{
  "transport": "scp",
  "hostname": "10.10.10.10",
  "port": 22,
  "username": "vagrant",
  "useAgent": true,
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".remote-sync.json",
    ".git/**"
  ]
}
```

FTP example:
```json
{
  "transport": "ftp",
  "hostname": "10.10.10.10",
  "port": 21,
  "username": "vagrant",
  "password": "vagrant",
  "target": "/home/vagrant/dirname/subdirname",
  "ignore": [
    ".remote-sync.json",
    ".git/**"
  ]
}
```

Upload mirrors example:
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
    ".remote-sync.json",
    ".git/**"
  ],
  "uploadMirrors":[
    {
      "transport": "scp",
      "hostname": "10.10.10.10",
      "port": 22,
      "username": "vagrant",
      "password": "vagrant",
      "keyfile": "/home/vagrant/.ssh/aws.pem",
      "passphrase": "your_passphrase",
      "target": "/home/vagrant/dirname/subdirname_one",
      "ignore": [
	    ".remote-sync.json",
        ".git/**"
      ]
    },
    {
      "transport": "ftp",
      "hostname": "10.10.10.10",
      "port": 21,
      "username": "vagrant",
      "password": "vagrant",
      "target": "/home/vagrant/dirname/subdirname_two",
      "ignore": [
	    ".remote-sync.json",
        ".git/**"
      ]
    }
  ]
}
```

## Usage example

### Existing project

1. Add a file named `.remote-sync.json` to your project, with the contents above
2. Open the command palette by pressing cmd + shift + P on a Mac, or ctrl + shift + P on Linux/Windows
3. Type in `remote sync reload config` and press enter

That's it!

### From scratch, with a remote server

1. Create a folder for your project, and create a file named `.remote-sync.json` in it with the contents above
2. In the Atom editor, open the command palette by pressing cmd + shift + P on a Mac, or ctrl + shift + P on Linux/Windows
3. Type in `remote sync reload config` and press enter
4. Open the command palette again
5. Input `remote sync download all`

The package will download all of the files from the remote server for you.


#Make a donation via Paypal ![Make a donation via Paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)
Click 'Send Money' after login PayPal, and my PayPal account is: lx1988cyk#gmail.com
