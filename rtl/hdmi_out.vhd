-- author: Furkan Cayci, 2018
-- description: hdmi out top module
--    consists of the timing module, clock manager and tgb to tdms encoder
--    three different resolutions are added, selectable from the generic
--    objectbuffer is added that displays 2 controllable 1 stationary objects
--    optional pattern generator is added

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity hdmi_out is
    generic (
        RESOLUTION   : string  := "SVGA"; -- HD1080P, HD720P, SVGA, VGA
        ram_d        : natural :=  9;  --! ram data size
        ram_x        : natural :=  8;  --! ram addr size for x pixels (in 2**n)
        ram_y        : natural :=  8;  --! ram addr size for y pixels (in 2**n)
        GEN_PATTERN  : boolean := false; -- generate pattern or objects
        GEN_PIX_LOC  : boolean := true; -- generate location counters for x / y coordinates
        OBJECT_SIZE  : natural := 16; -- size of the objects. should be higher than 11
        PIXEL_SIZE   : natural := 24; -- RGB pixel total size. (R + G + B)
        SERIES6      : boolean := false -- disables OSERDESE2 and enables OSERDESE1 for GHDL simulation (7 series vs 6 series)
    );
    port(
        clk, rst : in std_logic;
        -- tmds output ports
        clk_p  : out std_logic;
        clk_n  : out std_logic;
        data_p : out std_logic_vector(2 downto 0);
        data_n : out std_logic_vector(2 downto 0)
    );
end hdmi_out;

architecture rtl of hdmi_out is

  signal pixclk_rst     : std_logic;
  signal pixclk, serclk : std_logic;
  signal video_active   : std_logic;
  signal video_data     : std_logic_vector(PIXEL_SIZE-1 downto 0);
  signal vsync, hsync   : std_logic;
  signal pixel_x        : std_logic_vector(OBJECT_SIZE-1 downto 0);
  signal pixel_y        : std_logic_vector(OBJECT_SIZE-1 downto 0);
  signal object1x       : std_logic_vector(OBJECT_SIZE-1 downto 0) := std_logic_vector(to_unsigned(400, OBJECT_SIZE));
  signal object1y       : std_logic_vector(OBJECT_SIZE-1 downto 0) := std_logic_vector(to_unsigned(300, OBJECT_SIZE));
  signal object2x       : std_logic_vector(OBJECT_SIZE-1 downto 0) := std_logic_vector(to_unsigned(240, OBJECT_SIZE));
  signal object2y       : std_logic_vector(OBJECT_SIZE-1 downto 0) := std_logic_vector(to_unsigned(340, OBJECT_SIZE));
  signal backgrnd_rgb   : std_logic_vector( PIXEL_SIZE-1 downto 0) := x"FFFF00"; -- yellow

  signal ram_wr_ena     : std_logic;
  signal ram_wr_dat     : std_logic_vector(ram_d-1 downto 0);
  signal ram_wr_add     : std_logic_vector(ram_x+ram_y-1 downto 0);
begin

    -- generate 1x pixel and 5x serial clocks
    timing_hd1080p: if RESOLUTION = "HD1080P" generate
    begin
    clock: entity work.clock_gen(rtl)
      generic map (CLKIN_PERIOD=>5*8.000, CLK_MULTIPLY=>59, CLK_DIVIDE=>5/5, CLKOUT0_DIV=>2, CLKOUT1_DIV=>10) -- 1080p
      port map (clk_i=>clk, clk0_o=>serclk, clk1_o=>pixclk);
    end generate;

    timing_hd720p: if RESOLUTION = "HD720P" generate
    begin
    clock: entity work.clock_gen(rtl)
        generic map (CLKIN_PERIOD=>5*8.000, CLK_MULTIPLY=>59, CLK_DIVIDE=>5/5, CLKOUT0_DIV=>4, CLKOUT1_DIV=>20) -- 720p
        port map (clk_i=>clk, clk0_o=>serclk, clk1_o=>pixclk);
    end generate;

    timing_svga: if RESOLUTION = "SVGA" generate
    begin
    clock: entity work.clock_gen(rtl)
        generic map (CLKIN_PERIOD=>5*8.000, CLK_MULTIPLY=>5*8, CLK_DIVIDE=>1, CLKOUT0_DIV=>5, CLKOUT1_DIV=>25) -- 800x600
        port map (clk_i=>clk, clk0_o=>serclk, clk1_o=>pixclk);
    end generate;

    timing_vga: if RESOLUTION = "VGA" generate
    begin
    clock: entity work.clock_gen(rtl)
        generic map (CLKIN_PERIOD=>5*8.000, CLK_MULTIPLY=>5*8, CLK_DIVIDE=>1, CLKOUT0_DIV=>8, CLKOUT1_DIV=>40) -- 640x480
        port map (clk_i=>clk, clk0_o=>serclk, clk1_o=>pixclk );
    end generate;

    -- video timing
    timing: entity work.timing_generator(rtl)
        generic map (RESOLUTION => RESOLUTION, GEN_PIX_LOC => GEN_PIX_LOC, OBJECT_SIZE => OBJECT_SIZE)
        port map (rst=>pixclk_rst, clk=>pixclk, hsync=>hsync, vsync=>vsync, video_active=>video_active, pixel_x=>pixel_x, pixel_y=>pixel_y);

    -- tmds signaling
    tmds_signaling: entity work.rgb2tmds(rtl)
        generic map (SERIES6=>SERIES6)
        port map (rst=>pixclk_rst, pixelclock=>pixclk, serialclock=>serclk,
        video_data=>video_data, video_active=>video_active, hsync=>hsync, vsync=>vsync,
        clk_p=>clk_p, clk_n=>clk_n, data_p=>data_p, data_n=>data_n);

    --! transfer reset in clock domain
    p_rst: process (rst,pixclk)
    begin
      if rst = '1' then
        pixclk_rst  <= '1';
      elsif rising_edge(pixclk) then
        pixclk_rst  <= '0';
      end if;
    end process p_rst;

    -- pattern generator
    gen_patt: if GEN_PATTERN = true generate
    begin
    pattern: entity work.pattern_generator(rtl)
        port map (rst=>pixclk_rst,clk=>pixclk, video_active=>video_active, rgb=>video_data);
    end generate;

    -- game object buffer
    gen_no_patt: if GEN_PATTERN = false generate
    begin

    -- dummy data generator
    process(pixclk_rst, pixclk) is
      variable v_cnt  : unsigned(PIXEL_SIZE-1 downto 0);
    begin
        if pixclk_rst='1' then
            ram_wr_add <= ( others => '0');
            ram_wr_dat <= ( others => '0');
            ram_wr_ena <= '1';
            v_cnt      := ( others => '0');
        elsif rising_edge(pixclk) then
            v_cnt      := v_cnt + 1 ;
            ram_wr_add <= std_logic_vector(v_cnt(ram_wr_add'range));
            ram_wr_dat <= std_logic_vector(v_cnt(ram_wr_dat'range));
            ram_wr_ena <= '1';
        end if;
    end process;

    --! video_ram instance
    video_ram: entity work.video_ram(rtl)
        generic map (
          RESOLUTION => RESOLUTION,
          OBJECT_SIZE =>OBJECT_SIZE,
          PIXEL_SIZE  =>PIXEL_SIZE,
          ram_x =>ram_x,
          ram_y =>ram_y,
          ram_d =>ram_d
          )
        port map (
          rst=>pixclk_rst,
          pixclk=>pixclk,
          video_active=>video_active,
          pixel_x=>pixel_x,
          pixel_y=>pixel_y,
          ram_wr_ena=>ram_wr_ena,
          ram_wr_dat=>ram_wr_dat,
          ram_wr_add=>ram_wr_add,
          rgb=>video_data
          );

    end generate;

end rtl;
