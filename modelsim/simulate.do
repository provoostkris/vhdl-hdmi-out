echo "Compiling libraries"

  vlib work
  vlib unisim
  
  set UNISIM_PATH "C:/Xilinx/Vivado/2019.2/data/vhdl/src/unisims"

  # vcom -quiet -work unisim $UNISIM_PATH/unisim_VCOMP.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/unisim_VPKG.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/primitive/BUFG.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/primitive/OBUFDS.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/primitive/PLLE2_ADV.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/primitive/PLLE2_BASE.vhd
  # vcom -quiet -work unisim $UNISIM_PATH/primitive/OSERDESE1.vhd
  

echo "Compiling design"

  vcom  -quiet -work work ../rtl/clock_gen.vhd
  vcom  -quiet -work work ../rtl/objectbuffer.vhd
  vcom  -quiet -work work ../rtl/tmds_encoder.vhd
  vcom  -quiet -work work ../rtl/serializer.vhd
  vcom  -quiet -work work ../rtl/rgb2tmds.vhd
  vcom  -quiet -work work ../rtl/pattern_generator.vhd
  vcom  -quiet -work work ../rtl/timing_generator.vhd
  vcom  -quiet -work work ../rtl/hdmi_out.vhd

echo "Compiling test bench"

  vcom  -quiet -work work ../sim/tb_hdmi_out.vhd

echo "start simulation"

  vsim -gui -t ps -novopt work.tb_hdmi_out

echo "adding waves"

  delete wave /*
  
  add wave    -expand      -group "uut0 i/o"   -ports         /tb_hdmi_out/uut0/*
  add wave    -expand      -group "uut0 sig"   -internal      /tb_hdmi_out/uut0/*


echo "view wave forms"
  view wave
  run 10 us