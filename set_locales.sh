#!/bin/bash

sudo apt install language-pack-ko
sudo locale-gen ko_KR.UTF-8
sudo dpkg-reconfigure locales

### GUI 화면에서 ko_KR.UTF-8 선택
