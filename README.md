# Immortalizer

 Keep your apps running in the foreground indefinitely, even if they are in the background!
 
 <img src="https://media.havoc.app/672ab83ba80bcf5e2e0aebe8"/>

### Features
- Enable/disable app backgrounding (foregrounding) through 3D touch context menu
- Works even if the screen is off / device is locked, so no worries about battery drain
- Has an option to have indicators / toast message depending on the state of the app
- Allows you to enable notifications on certain apps that doesn't show notifications when in foreground mode

### Works on iOS 14 - 16.7.7

<a href="https://havoc.app/package/immortalizer" target="_blank"><img src="https://docs.havoc.app/img/badges/available_square.png" alt="drawing" style="width:200px;"/></a>

## Changelogs:
### v1.0.1 
- Fixed a bug where rotations don't work
### v2.0.0
- I've changed a lot of things in this version
- Fixed a bug where some apps are just crashing/freezing
- Fixed a bug where keyboard doesn't work
- Better foregrounding optimization
- Optimized toast animation
- Added CC Support for quick actions
- Added an option to lock an app in app switcher
- Added an option to have a lock indicator on both SpringBoard and app switcher
### v2.4
- The state indicator now distinguishes a running app from a stopped one instead of always showing the same accessory
- The CC tile now reflects the toggle state
- Toast auto-hide starts when the toast is shown, and it no longer attaches itself to whichever window happens to be on top
- Alerts are no longer dropped when something else is already presenting
### v2.3
- Added roothide support
- Scene deactivation is no longer blocked system-wide when the tweak is disabled or nothing is immortalized
- The scene update completion handler is no longer dropped for immortalized apps
- Immortalized/locked lists are kept in memory instead of being re-read from preferences inside the icon, switcher and scene hooks
- Fixed CC menu actions writing back a stale copy of the lists
- Fixed a leaked notification token that kept the CC menu controller alive
##### v2.3.1 [minor]
- Fixed a crash on launching an immortalized app: the scene update completion is a stack block and has to be copied before it can be called later
##### v2.0.0-1 [minor]
- Fixed a bug where immortalizer has conflicts with other notification tweaks (Glance)
- Fixed a bug in CC where Disable button is not reflecting in the UI immediately

## Building

Needs AltList in theos. Its `install_to_theos.sh` only covers rootful and rootless; for roothide build it
with `make FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide TARGET=iphone:clang:16.5:15.0` and copy
`.theos/obj/AltList.framework` into `$THEOS/lib/iphone/roothide`.

    make package                                # rootful
    make package THEOS_PACKAGE_SCHEME=rootless
    make package THEOS_PACKAGE_SCHEME=roothide  # needs the roothide fork of theos

## Feature requests: (I'm  still thinking about it)
- Localization (working on it :D)
- Timer/CPU based immortalization 

## Known bug reports (as of Nov 21)
- Whatsapp issue (I still haven't looked at this tbh since I don't use whatsapp and I'm a bit busy, but will look into it)
- Discord message notification is not letting users to view the specific message after clicked (haven't looked into this as well since only 1 user reported such behavior but will look into it as well)
- Foreground notification doesn't work for all apps

# License
    Copyright (C) 2024  Serge Alagon

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>. 

