### TODO

#### 0.6.x
* [ ] {FEAT} decrypt body of the protocol
* [ ] {UPADTE} removed depricated code
* [ ] {FEAT} custom messeging commands like `\c{RED};HELLO\` that applies special properties to text
    * `\b;HELLO\` prints bold text
    * `\u;HELLO\` prints underlined text
    * `\c{#00FFAA};HELLO\` prints colored text based on hex value 
* {FEAT} Client commands
    * [ ] `:ping` ~ ping user by username and print user info
* {FEAT} keybind list screen that shows all keybinds and their functionality 
* [ ] {UPDATE} `Input-Box` report when switching between `selection` and `insert` mode
* [ ] {UPDATE} `Input-Box` report deletion of text
* [ ] Introduce tests
* {FEAT} InputBox should have cursors
    * [ ] `SelectionCursor` move around text
    * [ ] `InsertCursor` place where char should be appended
#### 0.5.x
* [ ] {FEAT} Unit tests
* [ ] {BUG} when a message is sent to the server the server responds with `OK`, this should not be printed
* [ ] {BUG} message input box not in bounds (overflows)
* [ ] {BUG} client should respond with `OK` on `ping` ??
#### 0.4.8
* [x] {UPDATE} `INSERT` mode for input-box
* [x] {UPDATE} selection cursor movement ~ not all text selected at once
* [x] {UPDATE} Client FPS inforamtion
#### 0.4.7
* [x] {FEAT} `SimplePopup` multiposition support
* [x] {UPDATE} clean up and make popup hanling more robust
    * assert `popup.text.len > 0`, popups with no text should not be allowed
* [x] {BUG} input filed click detection too high for `server_ip_input`
* [x] {BUG} only two popups are displayed at a time, there should be more
* [x] {BUG} when `tab` is pressed and no ui element is selected the client crashes (LoginScreen)
* [x] {BUG} when client uses `:close` and reconnects and sends a message two messages are sent
#### 0.4.6
* [x] {UPDATE} `localhost` is a valid `server_ip_input` string that is mapped to `127.0.0.1`
* [x] {FEAT}   `:close` command that disconnects from the server and returns to the login screen
* [x] {UPDATE} `Input-Box` should hold font data to be used within the input box
* [x] {UPDATE} `Input-Box` should hold sizing information of the client
* [x] {FEAT}   `Input-Box` copying selected text support
#### 0.4.5
* [x] {UPDATE} Replace succesful connection screen with a popupdon't crash the the client wait for a connection to the server be available
* [x] {UPDATE} Input box should accept placeholder "ghost" text
* [x] {UPDATE} Input box should accept a label
* [x] {UPDATE} Switching active input using the TAB key inside `LoginScreen`
* [x] {UPDATE} TAB key enables messaging input if it is disabled `MessagingScreen`
* [x] {UPDATE} If no port is specified in `server_ip_input` assume port `6969`
* [x] {FEAT} `CTRL A` combination selects whole input box text 
* [x] {UPDATE} when `x` is pressed the selected text gets deleated
* [x] {UPDATE} when `enter` or `space` is pressed the exit `selection mode` 
* [x] {UPDATE} when `CTRL C` is pressed exit `selection mode`
#### 0.4.4
* [x] {UPDATE} don't allow login if login name is empy or ip is not defined
* [x] {UPDATE} ask for server ip before login
* [x] {UPDATE} report connection request blocked (unsuccessful conection)
* [x] {FEAT} server termination handler (bad-request::collectError)
#### 0.4.3
* {UPDATE} Multicolor support for message display
    * [x] `SimplePopup`
    * [x] `Message`
#### 0.4.1
* [x] {UPDATE} make `Action` and `Command` a shared library between server and client src code
* [x] {UPDATE} finish implementaton of `:exit` action ~ handle COMM_END response
#### 0.4.x
* [x] {FEAT} popups for warnings and errors
* [x] {FEAT} clipboard paste support
* {FEAT} `ClientScreen` ~ groups of related render/functionality code
    * [x] `LoginScreen`
    * [x] `MessagingScreen`
#### 0.3.0
* [x] {FEAT} print client termination
* {FEAT} Introduce `ClientActions`
    * [x] bad-request-action
    * [x] comm-action
    * [x] comm-end-action
    * [x] get-peer-action
    * [x] msg-action
    * [x] ntfy-kill-action
* [x] {FEAT} Introduce `ClientCommands`
#### 0.2.2
* [x] {FIX} when exiting duuring `connection succesful` the program deadlocks
* [x] {FEAT} consume `-fp` for setting location to the font 
* [x] {FEAT} consume `-F` start parameter to set scaling factor of the window
* [x] set client address source when sending things to the server
#### 0.2.x
* [x] {FEAT} read server adddress as program argument
#### 0.1.0
* [x] Consume peer termination notification and print it on screen
* [x] Test message coloring
* [x] Accept address as a variable when connecting a server
* [x] Use **Mutex** to share `should_exit` state between `read_cmd` and `listen_for_comms`
* [x] `:info` command to print information about the client instance
