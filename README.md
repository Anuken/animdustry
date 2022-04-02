# animdustry

the anime gacha rhythm game mindustry event

# compiling

## windows

1. use linux instead
2. no, really - compilation doesn't work on windows, I don't develop on Windows and I don't have much interest in adding support for it

## mac/linux

1. install the latest stable version of Nim. `~/.nimble/bin` must be on your PATH.
2. make sure this repository was cloned with `--recursive`, as it uses git submodules!
3. if on linux, `sudo apt install -y xorg-dev libgl1-mesa-dev` or equivalent packages
4. `nimble install`
5. `nimble debug`

# future plans

- code cleanup; main.nim is too big
- android support as a standalone APK
- more levels, if I have time
- better movement sync if possible, hit detection can be very janky sometimes
- delay slider for audio, maybe settings

*(as I am trying to focus on Mindustry now, don't expect any significant updates!)*

# credits

music used:

- [Aritus - For You](soundcloud.com/aritusmusic/4you)
- [PYC - Stoplight](soundcloud.com/pycmusic/stoplight)
- [Keptor's Room - Bright 79](soundcloud.com/topazeclub/bright-79)
- [Aritus - Pina Colada II](soundcloud.com/aritusmusic/pina-colada-ii-final)
- [ADRIANWAVE - Peach Beach](soundcloud.com/adrianwave/peach-beach)


all other art/sounds/assets/programming by me