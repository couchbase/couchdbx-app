Couchbase Server Community Edition 2.0.1 Developer Preview

This is a self-contained installation of Couchbase Server.
  * To start the server, simply launch the application.
  * Click the Couchbase icon in the menu bar to access menu commands.
  * To stop the server, choose "Quit Couchbase Server" from the menu.

This application may be run from any location on any writeable volume.
You may choose to move it to /Applications, but this is not required.
However:
  * Do not move the application while it's running.
  * After installing the command-line tools (via the item in the menu),
    moving the app will break the symbolic links that were created in
    /usr/local/bin (or wherever you installed the tools into.)

Before you start the server for the first time, please do make sure you
have erased any previous (1.8) Membase/Couchbase settings by deleting
"~/Library/Application Support/Couchbase" and
"~/Library/Application Support/Membase".
