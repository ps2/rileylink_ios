# RileyLink iOS App

[![Join the chat at https://gitter.im/ps2/rileylink](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ps2/rileylink?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/ps2/rileylink_ios.svg?branch=master)](https://travis-ci.org/ps2/rileylink_ios)

The RileyLink iOS app connects to a [RileyLink](https://github.com/ps2/rileylink) via Bluetooth Low Energy (BLE, or Bluetooth Smart) and uploads CGM and pump data to a Nightscout instance via the REST API. The Nightscout web page is also displayed in the App.

The main purpose of the RileyLink iOS App is for developpers to test the device commands. 

## How to contibute
**WARNING the PODs will fail rapidly, so testing will require a lot of PODs.**

If you need test pods, please contact @jwedding on https://omniaps.slack.com/ or https://gitter.im/ps2/rileylink

To contribute to our Omnipod testing phase:

if there is an error, create an Issue here https://github.com/ps2/rileylink_ios/issues with:
* A description which steps you took. 
* The console output from Xcode as a text snippet

If you own a RFCAT USB Device, also try to capture the radio messages as well and adding this to the Issue by using https://github.com/openaps/openomni or if you have rtlomni handy, capturing iq data might help as well in trying to see what went wrong for future attempts.

### Getting Started

#### Clone this repo to your machine
```
git clone https://github.com/ps2/rileylink_ios.git
cd rileylink_ios
git checkout omnikit // to switch the branch or do it Xcode using the branch button on the left
```

#### Flash the Rileylink Device
Flash your rileylink with the dev branch of https://github.com/ps2/rileylink/tree/dev
subg_rfspy *and* ble113_rfspy (there are two chips) need to be flashed.
And then run this omnikit branch of rileylink_ios.

#### Install the Rileylink iOS app to your phone

##### Install Xcode
You'll need Xcode, which is available for free, but will only build apps that last a week.  To make your apps run longer, you'll have to sign up for a developer account. Or send a message to @ps2 on gitter with your email address, and I'll add you to the distribution list and you can receive builds via testflight.

* Connect your iphone with a usb lightning connector to your laptop
* Select your iphone

You should not need to change bundle id, but you do have to sign the app by your team id on 3 places highlighted in red.  
![errors_when_building](../omnikit/Images/errors_when_building.png)
* Then just clicking on the build and run button in Xcode should build and install the app to your connected phone.


### How to Use

To use the Rileylink, it has to connect to a Rileylink device first. If you don't see your RileyLink, close any app that uses the Rileylink or reboot your phone. 

![turn on rileylink in command section](../omnikit/Images/turn_on_rileylink_in_command_section.PNG)

Click on your Rileylink name to see the available commands.

#### Setup an Omnipod

Scroll all the way down on in the command list to click on Pair new POD.
Follow the steps, but only push once to insert canula, else the Pod wil fail.

If all went well you should see something like this:

![turn on rileylink in command section](../omnikit/Images/pod_paired.png)

#### Setup a Medtronic pump

* Pump ID - Enter in your six digit pump ID

#### Setup Nightscout

* Nightscout URL - Should look like `http://mysite.azurewebsites.net`. You can use http or https.  Trailing slash or no trailing slash.
* Nightscout API Secret - Use the unhashed form, exactly specified in your `API_SECRET` variable.

To see treatments and pump data uploaded to nightscout, you'll need to be running the [dev branch](https://github.com/nightscout/cgm-remote-monitor/tree/dev) of cgm-remote-monitor.  You'll want to set the following Nightscout variables:

* DEVICESTATUS_ADVANCED = true
* ENABLE = pump openaps basal careportal iob
* PUMP_FIELDS = reservoir battery clock status


