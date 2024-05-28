# TsockM

* A TCP socket based chatting application

## Server

* The server portion of the application that handles communication between multiple client instances

### Protocol

* Communication between *server* and *client* is achived through the use of `TsockM.Protocol` 
* Protocol definition:
```
[type]::[action]::[id]::[src]::[dst]::[body]
```
* `[type]` defines the protocol type:
    * `REQ`: request protocol
    * `RES`: response protocol
    * `ERR`: error protocol
* `[action]` defines the action the protocol is performing
    * `COMM`: establishing a communication socket
    * `COMM_END`: terminate the communication socket
    * `MSG`: message handling 
* `[id]` defines some unsigned integer value
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

* [ ] Protocol should also contain `src` and `dest` IP addresses, socket form
* [ ] Send periodic peer health check protocol ~ look for dead peers and remove them from the pool
* [ ] Executable commands on the server application
        * `KILL_ALL` - removes all peers
        * `LIST`     - prints relevant peer data
        * `EXIT`     - terminates the server the proper way

## Client

* Application given to the user for chatting
