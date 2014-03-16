# Purpose

The RasPlex update server is design to connect the rasplex-installer, and in-app plex auto-update features to GitHub releases.

Which OpenELEC provides a decent update service, we've opted to use the plex built-in update system as it provides a more native experience, that is consistent across all plex platforms.

When a client connects to update or download, this is also recorded, giving us statistics about our userbase.

Github limits polling via public interface to 60 times per hour per IP, so this acts as a cache and lets us query as much as we like.

The major advantage to this is it allows us to take advantage of github's free and powerful CDN, but still have control over release logic.

# Architecture

The server itself is pretty small, just a small sinatra eventmachine app behind the 'thin' web server.

The eventmachine will wake up during a predefined interval, and poll the specified github releases page. These releases are stored in a database, allowing us to cache them.

This process is managed by runit, which ensures that if it dies (for some reason) it will be brought back up immediately if possible.

Nginx is used to proxy to the port thin is running on.

Pingdom is recommended to monitor the root page, to notify of downtime.

# API

## /update

Returns a well-formatted XML file suitable for updating a plexHT installation based on the update.erb.

```
  <?xml version="1.0" encoding="UTF-8"?>
  <MediaContainer friendlyName="myPlex" identifier="com.plexapp.plugins.myplex" size="1" title="Updates">
    
      <Release id="1" version="test" added="" fixed="" live="true" autoupdate="true" createdAt="2014-03-16T01:57:11+00:00">
        <Package file="https://github.com/RasPlex/RasPlex/releases/download/test/RasPlex-test.tar.gz" fileHash="sumthing" fileName="RasPlex-test.tar.gz" delta="false"/>
      </Release>
    
  </MediaContainer>

```

## /install

Returns a json document with the following structure:

```
 [
  {
    "id": 1,
    "install_url": "https://github.com/RasPlex/RasPlex/releases/download/test/RasPlex-test.img.gz",
    "install_sum": "a823d770a0ccfefe0a04b34c677e6bf8",
    "update_url": "https://github.com/RasPlex/RasPlex/releases/download/test/RasPlex-test.tar.gz",
    "update_sum": "sumthing",
    "version": "test",
    "autoupdate": true,
    "time": "2014-03-16T01:57:11+00:00",
    "notes": "A change\nAnother change"
  }
]

```

Where each element in the list is a release, and there are actual checksum, etc.


## /

Just returns "pong", indicating te service is running.

# Creating a release

The github release should be created against the desired tag, and the update and install archives should be added to the release.

Note that the suffixes are very important, as they differentiate the update from the install archive.

The body of the release should be a well-formed yaml file of the following format:

```
  changes:
    - A change
    - Another change
  
  install:
  
    - file: RasPlex-test.img.gz
    - md5sum: a823d770a0ccfefe0a04b34c677e6bf8
  
  update:
  
    - file: RasPlex-test.tar.gz
    - shasum: sumthing
```    
     
Note that the spacing after each section is important, so that github will also interpret it as a markdown file and display it properly to users visiting the releases page.


# System setup

## Development

Just ensure you have ruby2.0+ and bundler installed. Running 'bundle install' and prefixing all commands with 'bundle exec' should suffice.

You'll need to have sqlite3 installed locally though.

## Server

You'll need to do the following on the server:

+ Install build tools for creating gems via bundler
+ Set up nginx with supplied recipe
+ Install ruby2.0 (haven't tried anything older)
+ Create a deploy user with access to your deploy directory (/u/apps/rasplex-updater-server)
+ Install runit on the server
+ Add the included runit recipe
+ Set up your mysql database 

### Runit setup

This is a bit annoying to find in [the docs](http://smarden.org/runit/faq.html), so it's documented here. After installing runit via your package manager do:

+ Copy the included "runit/updater" folder into /etc/sv/updater
+ Link your getty from /etc/sv to /etc/supervise
 + ln -s /etc/sv/getty-X /etc/service
+ Link your service directory to the service folder
 + ln -s /etc/sv/updater /etc/service
+ Fix permissions to allow deploy user to restart:
 + chmod 755 /etc/sv/updater/supervise
 + chown deploy /etc/sv/updater/supervise/ok /etc/sv/updater/supervise/status /etc/sv/updater/supervise/control

# Deploying

You must have your public key added to the deploy users. Then you should just be able to do:

```
 bundle exec cap production deploy
```

Which will push the new code out, and restart the runit service to use the new code.
