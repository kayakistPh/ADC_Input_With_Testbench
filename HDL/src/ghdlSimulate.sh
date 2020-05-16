#!/bin/bash
export DISPLAY=:0
ghdl -a ADCinputAD4007.vhd
ghdl -a tb/AD4007.vhd
ghdl -a tb/tb_ADCinputAD4007.vhd
ghdl -e tb_ADCinputAD4007
ghdl -r tb_ADCinputAD4007 --wave=wave.ghw
gtkwave wave.ghw
