-- author: Furkan Cayci, 2018
-- description: video timing generator
--      choose between hd1080p, hd720p, svga, and vga

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timing_generator is
    generic (
        RESOLUTION   : string  := "HD720P"; -- hd1080p, hd720p, svga, vga
        GEN_PIX_LOC  : boolean := true;
        OBJECT_SIZE  : natural range 1 to 32 := 16
    );
    port(
        rst           : in  std_logic;
        clk           : in  std_logic;
        hsync, vsync  : out std_logic;
        video_active  : out std_logic;
        pixel_x       : out std_logic_vector(OBJECT_SIZE-1 downto 0);
        pixel_y       : out std_logic_vector(OBJECT_SIZE-1 downto 0)
    );
end timing_generator;

architecture rtl of timing_generator is

    type video_timing_type is record
        H_VIDEO : integer;
        H_FP    : integer;
        H_SYNC  : integer;
        H_BP    : integer;
        H_TOTAL : integer;
        V_VIDEO : integer;
        V_FP    : integer;
        V_SYNC  : integer;
        V_BP    : integer;
        V_TOTAL : integer;
        H_POL   : std_logic;
        V_POL   : std_logic;
        ACTIVE  : std_logic;
    end record;

-- HD1080p timing
--      screen area 1920x1080 @60 Hz
--      horizontal : 1920 visible + 88 front porch (fp) + 44 hsync + 148 back porch = 2200 pixels
--      vertical   : 1080 visible +  4 front porch (fp) +  5 vsync +  36 back porch = 1125 pixels
--      Total area 2200x1125
--      clk input should be 148.5 MHz signal (2200 * 1125 * 60)
--      hsync and vsync are positive polarity

    constant HD1080P_TIMING : video_timing_type := (
        H_VIDEO => 1920,
        H_FP    =>   88,
        H_SYNC  =>   44,
        H_BP    =>  148,
        H_TOTAL => 2200,
        V_VIDEO => 1080,
        V_FP    =>    4,
        V_SYNC  =>    5,
        V_BP    =>   36,
        V_TOTAL => 1125,
        H_POL   =>  '1',
        V_POL   =>  '1',
        ACTIVE  =>  '1'
    );

-- HD720p timing
--      screen area 1280x720 @60 Hz
--      horizontal : 1280 visible + 72 front porch (fp) + 80 hsync + 216 back porch = 1648 pixels
--      vertical   :  720 visible +  3 front porch (fp) +  5 vsync +  22 back porch =  750 pixels
--      Total area 1648x750
--      clk input should be 74.25 MHz signal (1650 * 750 * 60)
--      hsync and vsync are positive polarity

    constant HD720P_TIMING : video_timing_type := (
        H_VIDEO => 1280,
        H_FP    =>   72,
        H_SYNC  =>   80,
        H_BP    =>  216,
        H_TOTAL => 1648,
        V_VIDEO =>  720,
        V_FP    =>    3,
        V_SYNC  =>    5,
        V_BP    =>   22,
        V_TOTAL =>  750,
        H_POL   =>  '1',
        V_POL   =>  '1',
        ACTIVE  =>  '1'
    );

-- SVGA timing
--      screen area 800x600 @60 Hz
--      horizontal : 800 visible + 40 front porch (fp) + 128 hsync + 88 back porch = 1056 pixels
--      vertical   : 600 visible +  1 front porch (fp) +   4 vsync + 23 back porch =  628 pixels
--      Total area 1056x628
--      clk input should be 40 MHz signal (1056 * 628 * 60)
--      hsync and vsync are positive polarity

    constant SVGA_TIMING : video_timing_type := (
        H_VIDEO =>  800,
        H_FP    =>   40,
        H_SYNC  =>  128,
        H_BP    =>   88,
        H_TOTAL => 1056,
        V_VIDEO =>  600,
        V_FP    =>    1,
        V_SYNC  =>    4,
        V_BP    =>   23,
        V_TOTAL =>  628,
        H_POL   =>  '0',
        V_POL   =>  '0',
        ACTIVE  =>  '1'
    );

-- VGA timing
--      screen area 640x480 @60 Hz
--      horizontal : 640 visible + 16 front porch (fp) + 96 hsync + 48 back porch = 800 pixels
--      vertical   : 480 visible + 10 front porch (fp) +  2 vsync + 33 back porch = 525 pixels
--      Total area 800x525
--      clk input should be 25 MHz signal (800 * 525 * 60)
--      hsync and vsync are negative polarity

    constant VGA_TIMING : video_timing_type := (
        H_VIDEO =>  640,
        H_FP    =>   16,
        H_SYNC  =>   96,
        H_BP    =>   48,
        H_TOTAL =>  800,
        V_VIDEO =>  480,
        V_FP    =>   10,
        V_SYNC  =>    2,
        V_BP    =>   33,
        V_TOTAL =>  525,
        H_POL   =>  '0',
        V_POL   =>  '0',
        ACTIVE  =>  '1'
    );

    -- horizontal and vertical counters
    signal hcount  : unsigned(OBJECT_SIZE-1 downto 0) ;
    signal vcount  : unsigned(OBJECT_SIZE-1 downto 0) ;
    signal timings : video_timing_type;

begin

    timings <= HD1080P_TIMING when RESOLUTION = "HD1080P" else
               HD720P_TIMING  when RESOLUTION = "HD720P" else
               SVGA_TIMING    when RESOLUTION = "SVGA"   else
               VGA_TIMING     when RESOLUTION = "VGA";

    -- pixel counters
    process (rst,clk) is
    begin
        if rst = '1' then
          hcount <= to_unsigned(0,hcount'length);
          vcount <= to_unsigned(0,vcount'length);
        elsif rising_edge(clk) then
            if (to_integer(hcount) = timings.H_TOTAL-1) then
                hcount <= to_unsigned(0,hcount'length);
                if (to_integer(vcount) = timings.V_TOTAL-1) then
                    vcount <= to_unsigned(0,vcount'length);
                else
                    vcount <= vcount + 1;
                end if;
            else
                hcount <= hcount + 1;
            end if;
        end if;
    end process;

    -- pixel syncronizers
    process (rst,clk) is
    begin
        if rst = '1' then
          video_active <= not  timings.ACTIVE;
          hsync        <= not  timings.H_POL;
          vsync        <= not  timings.V_POL;
        elsif rising_edge(clk) then
        
          -- generate video_active, hsync, and vsync signals based on the counters
          if (to_integer(hcount) <  timings.H_VIDEO) and (to_integer(vcount) < timings.V_VIDEO ) then
            video_active <=      timings.ACTIVE;
          else
            video_active <= not  timings.ACTIVE;
          end if;

          if (to_integer(hcount) >= timings.H_VIDEO + timings.H_FP) and (to_integer(hcount) < timings.H_TOTAL-1 - timings.H_BP) then
            hsync        <=      timings.H_POL;
          else
            hsync        <= not  timings.H_POL;
          end if;
          
          if (to_integer(vcount) >= timings.V_VIDEO + timings.V_FP) and (to_integer(vcount) < timings.V_TOTAL-1 - timings.V_BP) then
            vsync        <=      timings.V_POL;
          else
            vsync        <= not  timings.V_POL;
          end if;
          
        end if;
    end process;

    g0: if GEN_PIX_LOC = true generate
    begin
        -- send pixel locations
        pixel_x <=  std_logic_vector(hcount) when to_integer(hcount) < timings.H_VIDEO else
                    std_logic_vector(to_unsigned(0,pixel_x'length));
        pixel_y <=  std_logic_vector(vcount) when to_integer(vcount) < timings.V_VIDEO else
                    std_logic_vector(to_unsigned(0,pixel_x'length));
    end generate;

    g1: if GEN_PIX_LOC = false generate
    begin
        -- send pixel locations
        pixel_x <= std_logic_vector(to_unsigned(0,pixel_x'length));
        pixel_y <= std_logic_vector(to_unsigned(0,pixel_y'length));
    end generate;

end rtl;