![](assets-raw/icon.png)

# animdustry

the anime gacha bullet hell rhythm game; *created as a mindustry april 1st event*

[downloads for windows/linux/android are available on the releases page.](https://github.com/Anuken/animdustry/releases)

please read [the last release notes](https://github.com/Anuken/animdustry/releases/tag/v1.2) for information about the future of this game.

# compiling

## initial mac/linux/android setup

1. install the latest stable version of Nim. `~/.nimble/bin` must be on your PATH.
2. make sure this repository was cloned with `--recursive`, as it uses git submodules!
3. if on linux, `sudo apt install -y xorg-dev libgl1-mesa-dev` or equivalent packages
4. `nimble install -y -d` (the flags are important!)

## running on windows

- building on windows **does not work**
- I don't develop on Windows and I don't have much interest in adding support for it myself; **use linux or WSL instead**

## running on desktop

- `nimble run` to launch the game directly
- `nimble deploy <win/lin/mac>` to create an executable in the `build/` directory for a specific platform; cross-compiling for Windows requires mingw installed

## running/compiling on android

1. make sure you have the Android SDK and NDK installed

- `nimble androidPackage` will create an unsigned APK at `android/build/outputs/apk/debug/`
- `nimble android` will attempt to compile and run the game on a connected Android device - USB debugging must be enabled

# credits

music used:

- [Aritus - For You](https://soundcloud.com/aritusmusic/4you)
- [PYC - Stoplight](https://soundcloud.com/pycmusic/stoplight)
- [Keptor's Room - Bright 79](https://soundcloud.com/topazeclub/bright-79)
- [Aritus - Pina Colada II](https://soundcloud.com/aritusmusic/pina-colada-ii-final)
- [ADRIANWAVE - Peach Beach](https://soundcloud.com/adrianwave/peach-beach)


all other art/sounds/assets/programming by me