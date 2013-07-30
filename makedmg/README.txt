Couchbase Server 2.1.1, Mac OSX

Couchbase Server 2.1.1 is the third release for Couchbase Server 2.0. Couchbase Server is a distributed NoSQL document database for interactive applications. Its scale-out architecture runs in the cloud or on commodity hardware and provides a flexible data model, consistent high-performance, easy scalability and always-on 24x365 availability. This release contains fixes, for more information, see our Release Notes: http://www.couchbase.com/docs/couchbase-manual-2.1.0/couchbase-server-rn.html

REQUIREMENTS

Before you start the server for the first time, please do make sure you
erase any previous Membase/Couchbase settings by deleting:

"~/Library/Application Support/Couchbase" and
"~/Library/Application Support/Membase".

- To run cbcollect_info you must have administrative privileges

INSTALL

This is a self-contained installation of Couchbase Server.
  * To start the server, simply launch the downloaded application by double-clicking on the icon.
  * Click the Couchbase icon in the menu bar to access menu commands.
  * To stop the server, choose "Quit Couchbase Server" from the menu.

This application may be run from any location on any writeable disk.
You can move it to /Applications, but this is not required. 
Do not move the application while it running.

The server will automatically start after install and will be available by default on port 8091

For a full list of network ports for Couchbase Server, see http://www.couchbase.com/docs/couchbase-manual-2.1.0/couchbase-network-ports.html

To read more about Couchbase Server best practices, see http://www.couchbase.com/docs/couchbase-manual-2.1.0/couchbase-bestpractice.html

