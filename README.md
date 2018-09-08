# RileyLink iOS App

[![Join the chat at https://gitter.im/ps2/rileylink](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ps2/rileylink?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/ps2/rileylink_ios.svg?branch=master)](https://travis-ci.org/ps2/rileylink_ios)

The RileyLink iOS app connects to a [RileyLink](https://github.com/ps2/rileylink) via Bluetooth Low Energy (BLE, or Bluetooth Smart) and uploads CGM and pump data to a Nightscout instance via the REST API. The Nightscout web page is also displayed in the App.

### Getting Started

You'll need Xcode, which is available for free, but will only build apps that last a week.  To make your apps run longer, you'll have to sign up for a developer account.

You should not need to change bundle id, or sign the app.  Just clicking on the build and run button in Xcode should build and install the app to your connected phone.

### Configuration

* Pump ID - Enter in your six digit pump ID
* Nightscout URL - Should look like `http://mysite.azurewebsites.net`. You can use http or https.  Trailing slash or no trailing slash.
* Nightscout API Secret - Use the unhashed form, exactly specified in your `API_SECRET` variable.

### Nightscout

To see treatments and pump data uploaded to nightscout, you'll need to be running the [dev branch](https://github.com/nightscout/cgm-remote-monitor/tree/dev) of cgm-remote-monitor.  You'll want to set the following Nightscout variables:

* DEVICESTATUS_ADVANCED = true
* ENABLE = pump openaps basal careportal iob
* PUMP_FIELDS = reservoir battery clock status


