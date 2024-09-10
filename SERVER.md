# TsockM server plans

## TODO

### 0.6.x
* [ ] {feat} encrypt body of the protocol
* [ ] {feat} store messages
---
### 0.5.x
### 0.5.1
* [ ] {feat} PeerPool v2 (hash table approach) ~ ppv2
* [ ] {fix} depricated function calls of `shared-data/peerPoolFindId` 
### 0.5.2
* [ ] {UPDATE} separate `Peer` instance creation from pool insertion
    - peer pool should only update peer ID
* [ ] {update} ppv2 tests
---
### 0.4.5
* [x] {FIX} printing commands
### 0.4.4
* [x] {TEST} `peer`
* [x] {UPDATE} make `Peer` more robust with more functions and quality of life things
### 0.4.3
* [x] {TEST} `protocol`
* [x] {UPDATE} `core.zig` rename to `server.zig`
* [x] {TEST} `actioner`
* [x] {UPDATE} make `Protocol` more robust with more functions and quality of life things
* [x] {FIX} report unknown argument
* [x] {FEAT} ERROR protocol sent when peer was ping that does not exist
---
### 0.3.0
* [x] {FEAT} Introduce server commands
* [x] {FEAT} Introduce server actions
* [x] {FEAT} `:mute` and `:unmute` server commands
---
### 0.2.0
* [x] {FEAT} Server strcture
* [x] {FEAT} Consume program arguments:
    * `--log-level <level>` ... specify log level to be used
* [x] {UPDATE} introduce `thread_pool` 
* [x] {UPDATE} transform functions to be camel case as per zig standrad
* [x] {UPDATE} transform variables to be snake case as per zig standrad
* [x] {UPDATE} Unwrap Protocol structure file
* [x] {UPDATE} Unwrap Peer structure file
---
### 0.1.0
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
