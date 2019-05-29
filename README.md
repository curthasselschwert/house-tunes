# HouseTunes

HouseTunes provides a proxy interface for the
[SpeakerCraft ERS-1.0 Web Server](https://www.manualslib.com/manual/263387/Speakercraft-Web-Server-Ers-1-0.html).
The ERS creates an web interface on a wireless home network to allow control of
a MZC via a web browser. Unfortunately, the Web interface no longer appears to
function in modern browsers (as of 2018). This left me unable to control my MZC.

The ERS controls the MZC by processing `GET` requests from Web browsers-which
means that in order to control the MZC, all I needed was a proxy that could
read the HTML from the ERS, display an interface, and issue `GET` requests
back to the ERS.

This Phoenix application provides a pleasant UI for controlling the MZC via the
ERS. It only supports the functions I needed and includes some customization
of the source names due to my configuration. I only plan to make updates to
the code when I encounter a new use case or a bug, but feel free to fork this
code and modify it anyway you like.

## Commands

Commands to the ERS are made by making `GET` requests to
`http://192.168.1.254/:command`. The list of commands I
was able to work out are listed in the table below. Depending on which
view the ERS is displaying, not all commands are available.

| Command      | Function                       |
|--------------|--------------------------------|
| SelLine[0-6] | Select list option             |
| SelJumpUp    | Page up in a list of options   |
| SelJumpDn    | Page down in a list of options |
| SelMenuBk    | Go back                        |
| SelPageUp    | Page up in a list of options   |
| SelPageDn    | Page down in a list of options |
| SelPower1    | Power on for zone              |
| SelPower0    | Power off for zone             |
| SelParty1    | Party mode on                  |
| SelParty0    | Party mode off                 |
| SelMute1     | Mute zone                      |
| SelMute0     | Unmute zone                    |
| SelVolDn     | Zone volume up                 |
| SelVolUp     | Zone volume down               |
| SelPrvTr     | Previous track                 |
| SelRewTr     | Rewind                         |
| SelPlyTr     | Play                           |
| SelFwdTr     | Fast forward                   |
| SelNxtTr     | Next Track                     |
