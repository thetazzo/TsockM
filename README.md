![](./tsockm_logo.png)

# TsockM

* The **LIGHTWEIGHT**, **FAST** and **PRIVACY FOCUSED** chatting program
    * p.s. communications are transmitted as plaintext 

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
* Zig version >= `0.12.0`

* **SERVER**
```bash
zig build dev-server -- <subcommand>
```
* **CLIENT**
```bash
zig build dev-client -- <subcommand>
```

## Server

* The server portion of the application that handles communication between multiple client instances

### Protocol

* Communication between *server* and *client* is achived through the use of `TsockM.Protocol` 
* Protocol definition:
```
[type]::[action]::[status]::[origin]::[sender_id]::[src]::[dst]::[body]
```
* `[type]` defines the protocol type:
    * `REQ`: request
    * `RES`: response
    * `ERR`: error
* `[action]` defines the action the protocol is performing
    * `COMM`: establishing a communication socket
    * `COMM_END`: terminate the communication socket
    * `MSG`: message handling 
    * `GET_PEER`: when pinging a peer
    * `NTFY_KILL`: reporting termination of a peer
* `[status]` defines the status code of the program (based on HTTP status codes)
    * `OK`: 200
    * `BAD_REQUEST`: 400
    * `NOT_FOUND`: 404
    * `METHOD_NOT_ALLOWED`: 405,
    * `BAD_GATEWAY`: 502,
* `[origin]` telles the reciever roghly from where the message is comming from
    * `CLIENT`: protocol comes from the client app
    * `SERVER`: protocol comes from the server
    * `UNKNOWN`: I don't know from where the protocol is comming from :)
* `[sender_id]` defines some unsigned integer value
    * Used when communicating the `sender id` value
    * Used when communicating the `error code` of an *error protocol*
* `[src_addr]` address of the protocol source
    * *TBA*
* `[dest_addr]` address of the protocol destination
    * *TBA*
* `[body]` text data
    * used for sending a variaty of plaintext(for now) data

## Client

* Application given to the user for chatting

---

# References

* Raylib.zig: https://github.com/Not-Nik/raylib-zig
