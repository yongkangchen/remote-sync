![Atom Remote Sync](http://i.imgur.com/xBqYanL.png)

# Atom Remote Sync [![Atom.io](https://img.shields.io/badge/Atom.io-1.7.3-40A977.svg)](https://atom.io) [![GitHub stars](https://img.shields.io/github/stars/yongkangchen/remote-sync.svg)](https://github.com/yongkangchen/remote-sync/stargazers) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/yongkangchen/remote-sync/master/LICENSE) [![GitHub issues](https://img.shields.io/github/issues/yongkangchen/remote-sync.svg)](https://github.com/yongkangchen/remote-sync/issues)

Use SFTP and FTP features inside Atom, having the ability to upload and download files directly from inside Atom.

## Features

- Uploading/downloading files to/from the server
- Displaying diffs between the local and remote files with your favourite diff tool
- Monitoring files for external changes and automatically uploading - useful for scss/less compiling
- Support for both SCP/SFTP and FTP

## Extras

- Toggle for uploading changes automatically when you save a file
- Define files to be monitored to be automatically monitoring
- Set difftoolCommand in AtomSettingView of `remote-sync` -- The path to your diff tool executable
- Toggle the logs for extra information
- Toggle the hiding and showing of the log panel
- Set custom config name

## Installation

You can install this like any other Atom package, with one of these methods:

### Via Atom (recommended)

- Open Atom
- Open settings

  - <kbd>ctrl</kbd>+<kbd>,</kbd> | <kbd>cmd</kbd>+<kbd>,</kbd>
  - Edit > Preferences (Linux)
  - Atom > Preferences (OS X)
  - File > Preferences (Windows)

- Select "Install" tab
- Search for `remote-sync` and click install

### APM - terminal

- Open a terminal
- Run `apm install remote-sync`

### Manually

- Download / clone this repository to your `~/.atom/packages/`
- Enter the directory
- Run `apm install`

## Usage

You can configure remote sync a couple of ways:

### Existing project

#### Via Atom (recommended)

1. Right click main project folder
2. Navigate to Remote Sync > Configure
3. Fill in the details / select options
4. Hit save

#### Manually

1. Add a file named `.remote-sync.json` to your project
2. Add/configure with one of the contents below
3. Save the file

### From scratch, with a remote server

1. Follow setups for creating existing project - see above
1. Right click main project folder
2. Navigate to Remote Sync > Download folder


## Options

The `.remote-sync.json` in your project root will use these options:


| Option            | Datatype | Default                         | Details                                                                                        |
|-------------------|----------|---------------------------------|------------------------------------------------------------------------------------------------|
| `transport`       | String   | ""                              | `scp` for SCP/SFTP, or `ftp` for FTP                                                           |
| `hostname`        | String   | ""                              | Remote host address                                                                            |
| `port`            | String   | ""                              | Remort port to connect on (typically 22 for SCP/SFTP, 21 for FTP)                              |
| `username`        | String   | ""                              | Remote host username                                                                           |
| `password`        | String   | ""                              | Remote host password                                                                           |
| `keyfile`         | String   | ""                              | Absolute path to SSH key (only used for SCP)                                                   |
| `secure`          | Boolean  | false                           | Set to true for both control and data connection encryption (only used for FTP)                |
| `passphrase`      | String   | ""                              | Passphrase for the SSH key (only used for SCP)                                                 |
| `useAgent`        | String   | false                           | Whether or not to use an agent process (only used for SCP)                                     |
| `target`          | String   | ""                              | Target directory on remote host                                                                |
| `source`          | String   | ""                              | Source directory relative to project root                                                      |
| `ignore`          | Array    | [".remote-sync.json",".git/**"] | Array of [minimatch](https://github.com/isaacs/minimatch) patterns of files to ignore          |
| `watch`           | Array    | []                              | Array of files (relative to project root - starting with "/") to watch for changes             |
| `uploadMirrors`   | Array    | []                              | Transport mirror config array when upload                                                      |
| `uploadOnSave`    | Boolean  | false                           | Whether or not to upload the current file when saved                                           |
| `saveOnUpload`    | Boolean  | false                           | Whether or not to save a modified file before uploading                                        |
| `useAtomicWrites` | Boolean  | false                           | Upload file using a temporary filename before moving to its final location (only used for SCP) |
| `deleteLocal`     | Boolean  | false                           | Whether or not to delete the local file / folder after remote delete                           |


## Example configuration's

### SCP example:

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
  "watch":[
    "/css/styles.css",
    "/index.html"
  ]
}
```

### SCP `useAgent` example:

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
  ],
  "watch":[
    "/css/styles.css",
    "/index.html"
  ]
}
```

### FTP example:

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
  ],
  "watch":[
    "/css/styles.css",
    "/index.html"
  ]
}
```

### Upload mirrors example:

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
  "watch":[
    "/css/styles.css",
    "/index.html"
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

# Make a donation via Paypal ![Make a donation via Paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)

Click 'Send Money' after login PayPal, and my PayPal account is: lx1988cyk#gmail.com
