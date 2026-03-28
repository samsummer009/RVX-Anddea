#### ⚠️ Do not download APKs or modules from random websites you find on Google, as they may be dangerous and because providers impersonate ReVanced/ReVanced Extended. Please build your application from official sources or use open source builders like this one.

# Welcome to my ReVanced ExTended Builder!
[![CI](https://github.com/samsummer009/RVX/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/samsummer009/RVX/actions/workflows/ci.yml)
[![GitHub License](https://img.shields.io/github/license/samsummer009/RVX?logo=gnu&label=License&link=https%3A%2F%2Fgithub.com%2Fsamsummer009%2FRVX%2Fblob%2Fmain%2FLICENSE)](https://github.com/samsummer009/RVX/blob/main/LICENSE)
[![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/samsummer009/RVX/total?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0Ij48cGF0aCBkPSJNNC43NSAxNy4yNWEuNzUuNzUgMCAwIDEgLjc1Ljc1djIuMjVjMCAuMTM4LjExMi4yNS4yNS4yNWgxMi41YS4yNS4yNSAwIDAgMCAuMjUtLjI1VjE4YS43NS43NSAwIDAgMSAxLjUgMHYyLjI1QTEuNzUgMS43NSAwIDAgMSAxOC4yNSAyMkg1Ljc1QTEuNzUgMS43NSAwIDAgMSA0IDIwLjI1VjE4YS43NS43NSAwIDAgMSAuNzUtLjc1WiIgZmlsbD0iI0ZGRkZGRiI+PC9wYXRoPjxwYXRoIGQ9Ik01LjIyIDkuOTdaLjc0OS43NDkgMCAwIDEgMS4wNiAwbDQuOTcgNC45NjlWMi43NWEuNzUuNzUgMCAwIDEgMS41IDB2MTIuMTg5bDQuOTctNC45NjlhLjc0OS43NDkgMCAxIDEgMS4wNiAxLjA2bC02LjI1IDYuMjVhLjc0OS43NDkgMCAwIDEtMS4wNiAwbC02LjI1LTYuMjVhLjc0OS43NDkgMCAwIDEgMC0xLjA2WiIgZmlsbD0iI0ZGRkZGRiI+PC9wYXRoPjwvc3ZnPg==&label=Downloads&link=https%3A%2F%2Fgithub.com%2Fsamsummer009%2FRVX%2Freleases)](https://github.com/samsummer009/RVX/releases)

This ReVanced Builder creates both APKs and [Magisk](https://github.com/topjohnwu/Magisk)/[KernelSU](https://github.com/tiann/KernelSU) modules for [ReVanced Extended](https://github.com/inotia00/revanced-patches) versions of YouTube and YouTube Music.

#### **Get the latest CI release [here](https://github.com/samsummer009/RVX/releases/latest)!**

## Installation
### Non-root users
- Install the [ReVanced GmsCore app](https://github.com/ReVanced/GmsCore/releases/latest).
- Download the APK files you want to install from the [releases page](https://github.com/samsummer009/RVX/releases/latest).
### Root users
- Download the ZIP files you want to flash from the [releases page](https://github.com/samsummer009/RVX/releases/latest).
- (Optional) Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to detach YouTube and YouTube Music from the Play Store.
- Enjoy!


## Customization in ReVanced applications
- I have customized the patch options to better suit my preferences and requirements.
For my own testing, I've customized a few things in the APKs to suit my personal preferences. If you want to customize the patches for your own needs, you can check the patch options files:
- [patch-options.json](https://github.com/samsummer009/RVX/blob/main/patch-options.json) for YouTube
- [patch-options-music.json](https://github.com/samsummer009/RVX/blob/main/patch-options-music.json) for YouTube Music

## Building Locally
### On Termux
```bash
bash <(curl -sSf https://raw.githubusercontent.com/samsummer009/RVX/main/build-termux.sh)
```
### On Desktop
```bash
git clone https://github.com/samsummer009/RVX
cd RVX
./build.sh
```

## Credits
- [j-hc](https://github.com/j-hc) for creating this amazing builder.
- [Kevinr99089](https://github.com/kevinr99089) for providing assistance with the builder.
- [KitsunedFox](https://github.com/KitsunedFox) for the idea of the Obtainium tutorial.
- [peternmuller](https://github.com/peternmuller) for maintaining and improving this builder.
- And of course, the [ReVanced](https://github.com/ReVanced) team, [inotia00](https://github.com/inotia00) and [anddea](https://github.com/anddea) for their work on the ReVanced apps!

## License
    Copyright (C) 2024  Peter Noël Muller

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.