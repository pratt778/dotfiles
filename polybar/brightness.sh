#!/bin/bash

case "$1" in
  up)
    brightnessctl set +5% >/dev/null
    ;;
  down)
    brightnessctl set 5%- >/dev/null
    ;;
esac

brightnessctl -m info | awk -F, '{ print "BRT " $4 }'
