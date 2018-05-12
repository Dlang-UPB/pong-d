# D Workshop (DPong)

## Getting started
First we need to install the lastest D version, by running the commands listed below.
```
wget http://downloads.dlang.org/releases/2.x/2.080.0/dmd_2.080.0-0_amd64.deb
sudo dpkg --install  dmd_2.080.0-0_amd64.deb 
```

We then need to install SDL to be able to run our game:
```
sudo apt-get install libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev 
```

## Building the game
```
dub run
```

## Building the documentation
```
dub build --build=docs
```

## Please visit our wiki
```
https://github.com/edi33416/pong-d/wiki/Pong-D
```
