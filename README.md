# TsockM

* A TCP socket based chatting application

## Prerequisits

* xorg-X11
    * `libX11-dlevel`
    * `libXcursor-dlevel`
    * `libXrandr-dlevel`
    * `libXinerama-dlevel`
* wayland
    * `wayland-dev` or `wayland-deval`

* OpenGL
    * `mesa-libGL-dlevel`

## Fedora 40 [RedHat]
* Install required libraries
```bash
sudo yum install wayland-devel.x86_64 libxkbcommon-devel.x86_64 mesa-libGL-devel.x86_64
```

## Quick Start
* This shoudl work on zig version `0.12.0`
* Build and run
* **SERVER**
```bash
zig build server -- <subcommand>
```
* **CLIENT**
```bash
zig build client -- <subcommand>
```

* **SUBCOMMANDS**
```
help ............................ print program usage
start <?flag>` .................. start the program
    --addr [address] [port]` .... specify the address and port on which the program runs / is connected to (default: `127.0.0.1 6969`)
```

## Server

* The server portion of the application that handles communication between multiple client instances

### Server Commands
* These actions can be executed by the server administrator using these commands
* `:list`
    * Print information about peers that are currenlty connected to the server
* `:kill`
    * Disconnects one or more peers from the server
    * `:kill all` - disconnect all connected peers
    * `:kill <peer_id>` - disconnect the peer with the provided id
* `:help`
    * Print available commands to the standard output

### Protocol

* Communication between *server* and *client* is achived through the use of `TsockM.Protocol` 
* Protocol definition:
```
[type]::[action]::[status_code]::[sender_id]::[src]::[dst]::[body]
```
* `[type]` defines the protocol type:
    * `REQ`: request protocol
    * `RES`: response protocol
    * `ERR`: error protocol
* `[action]` defines the action the protocol is performing
    * `COMM`: establishing a communication socket
    * `COMM_END`: terminate the communication socket
    * `MSG`: message handling 
    * `GET_PEER`: when pinging a peer
    * `NTFY_KILL`: reporting termination of a peer
* `[status_code]` defines the status code of the program (based on HTTP status codes)
    * `OK`: 200
    * `BAD_REQUEST`: 400
    * `NOT_FOUND`: 404
    * `METHOD_NOT_ALLOWED`: 405,
    * `BAD_GATEWAY`: 502,
* `[sender_id]` defines some unsigned integer value
    * Used when communicating the `sender id` value
    * Used when communicating the `error code` of an *error protocol*
* `[src]` defines the source of the protocol
    * *TBA*
* `[dst]` defines the destination address of the protocol
    * *TBA*
* `[body]` text data
    * Used when communicating `MSG` ~ holds text of the message
    * Used when communicating error messages

### TODO

#### 0.3.0
* [ ] {FEAT} encrypt body of the protocol

#### 0.2.x
* [ ] {UPDATE} transform functions to be camel case as per zig standrad
* [ ] {UPDATE} transform variables to be snake case as per zig standrad
* [ ] {BUG} notifying peer death does not work every time
* [ ] `peer_find_all_username` find all peers with specific username
* [ ] `peer_bridge_ref` function that constructs a structre containing the sender peer and the peer the sender is trying to find
* [ ] when server sends a response set the source of the response to server ip
* [ ] Consume program arguments:
    * `LOG_LEVEL`:
        * `-s` .... silent mode
        * `-t` .... tiny mode
        * default `DEV`
#### 0.1.x
* [x] send a notification to client when a peer gets terminated
* [x] Test message coloring
* [x] `:info` action for printing server stats (amount of peers connected, uptime, server-address, etc.)
* [x] `:ping <peer_username>` action for pinging the status of a peer
* [x] Thread shared data - Mutex and shared data between threads
* [x] Send periodic peer health check protocol ~ look for dead peers and remove them from the pool
* Executable commands on the server application
        * [x] `KILL <peer_id>` - removes a specific peer
        * [x] `KILL_ALL`       - removes all peers
        * [x] `LIST`           - prints relevant peer data
        * [x] `CC`             - Clear screen
* [x] Accept address as a variable when launching a server
* [x] Protocol should also contain `src` and `dest` IP addresses, socket form
* [x] Peer unique hash as ID 
* [x] Handle invalid *action* arguments
    * `KILL` - action must be provided with eather `<peer_id` or `all`, error otherwise 

## Client

* Application given to the user for chatting
    
### TODO

#### 0.3.0
* [ ] {FEAT} decrypt body of the protocol
* [ ] {FEAT} clipboard paste support
#### 0.2.x
* [ ] {UPADTE} removed depricated code
* {FEAT} Client actions
    * [ ] Exiting the application
    * [ ] Sending messages
* [ ] {UPDATE} transform functions to be camel case as per zig standrad
* [ ] {UPDATE} transform variables to be snake case as per zig standrad
* [ ] {FEAT} read server adddress as program argument
* [ ] {BUG} a message is printed on top of a command being written
    * I don't know how to fix this
    * Probably it will be an issue until we move to raylib
* [ ] `:ping <peer_username` action for pinging the status of a peer
* [ ] don't crash the the client wait for a connection to the server be available
* [ ] Allow user to specify the color of the text
#### 0.1.0
* [x] Consume peer termination notification and print it on screen
* [x] Test message coloring
* [x] Accept address as a variable when connecting a server
* [x] Use **Mutex** to share `should_exit` state between `read_cmd` and `listen_for_comms`
* [x] `:info` command to print information about the client instance

---

# References

* SQIDS: https://github.com/sqids/sqids-zig
* Raylib.zig: https://github.com/Not-Nik/raylib-zig
