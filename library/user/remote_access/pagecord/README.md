\# PageCord



\### Control WiFi Pineapple Pager Through Discord



\## Overview



This payload allows the user to control WiFi Pineapple Pager using a Discord bot/app.



Designed as a simple reverse shell along with extras such as file transfer, on-device setup and basic security features.





\## Features



\* Upload and download files

\* Restart as background task

\* Basic session security

\* Single user ID access

\* Changeable working directory

\* Batched messages for large outputs

\* On-device setup





\## Setup



1\. make a discord bot at https://discord.com/developers/applications/

2\. Turn on ALL intents in the 'Bot' tab.



!\[intents](images/intents.png)



3\. Give these permissions in Oauth2 tab (Send-Messages, Read-messages/view-channels, Attach files)



!\[perms](images/perms.png)



4\. Copy the link/URL at the bottom of the page into a browser url bar

5\. Add the bot to your server

6\. Click 'Reset Token' in "Bot" tab for your token and copy it

7\. Run the payload once to create setup files

8\. You can either use the setup prompts on device, or edit the newly created .env file and edit these feilds

\* Change YOUR\_BOT\_TOKEN\_HERE with your bot token.

\* Change CHANNEL\_ID\_HERE to the channel ID of your channel you intend to use for this.

\* Change 'password' to your own (use a unique password, it will be viewable to anyone in the channel selected)



\*Once this is done you can run the payload again and you should get a 'session waiting' message in discord. Only your user ID will be able to interact.\*



\## Commands



\*\*These commands are case sensitive!\*\*


```
options  - Show the options list

pause    - Pause this session (re-authenticate to resume)

background  - Restart the payload in the background

sysinfo    - Show basic system information

close    - Close this session permanently

download   - Send a file to Discord \[download path/to/file.txt]

upload     - Upload file to Pager \[attach to 'upload' command]
```








