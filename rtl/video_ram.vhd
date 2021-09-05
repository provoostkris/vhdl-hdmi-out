------------------------------------------------------------------------------
--  draw an image stored in a memory buffer
--  rev. 1.0 : 2021 provoost kris
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_ram is
    generic (
        resolution  : string  := "svga"; -- hd1080p, hd720p, svga, vga
        ram_d       : natural :=  9;  --! ram data size (evenly divided over RGB)
        ram_x       : natural :=  8;  --! ram addr size for x pixels (in 2**n)
        ram_y       : natural :=  8;  --! ram addr size for y pixels (in 2**n)
        object_size : natural := 16;
        pixel_size  : natural := 24
    );
    port (
        rst                : in  std_logic;
        pixclk             : in  std_logic;
        video_active       : in  std_logic;
        pixel_x            : in  std_logic_vector(object_size-1 downto 0);
        pixel_y            : in  std_logic_vector(object_size-1 downto 0);
        ram_wr_clk         : in  std_logic;
        ram_wr_ena         : in  std_logic;
        ram_wr_dat         : in  std_logic_vector(ram_d-1 downto 0);
        ram_wr_add         : in  std_logic_vector(ram_x+ram_y-1 downto 0);
        rgb                : out std_logic_vector(pixel_size-1 downto 0)
    );
end video_ram;

architecture rtl of video_ram is

    constant bpp        : natural := ram_d / 3; --! bit per pixel
    constant dim_x      : natural := 2**ram_x;  --! dimention of RAM
    constant dim_y      : natural := 2**ram_y;  --! dimention of RAM
    -- memory
    type t_ram          is array ( integer range <> ) of std_logic_vector(ram_d-1 downto 0);
    signal memory       : t_ram ( 0 to 2**(ram_x+ram_y));

    -- signals that holds the x, y coordinates
    signal pix_x        : unsigned (object_size-1 downto 0);
    signal pix_y        : unsigned (object_size-1 downto 0);

    -- memory read access
    signal ram_draw_x   : std_logic;
    signal ram_draw_y   : std_logic;
    signal ram_rd_ena   : std_logic;
    signal ram_rd_dat   : std_logic_vector(ram_d-1 downto 0);
    signal ram_rd_add   : integer range 0 to 2**(ram_x+ram_y) ;

begin

    -- follow pixels
    process(rst, pixclk) is
    begin
        if rst='1' then
          pix_x       <= ( others => '0');
          pix_y       <= ( others => '0');
        elsif rising_edge(pixclk) then
          pix_x       <= unsigned(pixel_x);
          pix_y       <= unsigned(pixel_y);
        end if;
    end process;

    -- Put image from RAM in the corner
    ram_draw_x  <= '1' when pix_x < dim_x else '0';
    ram_draw_y  <= '1' when pix_y < dim_y else '0';
    ram_rd_ena  <= ram_draw_x and ram_draw_y;
    ram_rd_add  <= to_integer(pix_x) + to_integer(pix_y)*dim_x;

    -- write data in memory
    process(ram_wr_clk) is
    begin
        if rising_edge(ram_wr_clk) then
          if ram_wr_ena = '1' then
            memory(to_integer(unsigned(ram_wr_add))) <= ram_wr_dat;
          end if;
        end if;
    end process;

    -- read data from memory
    process(rst, pixclk) is
    begin
        if rst='1' then
          ram_rd_dat <= ( others => '0');
        elsif rising_edge(pixclk) then
          if ram_rd_ena = '1' then
            ram_rd_dat <= memory(ram_rd_add);
          end if;
        end if;
    end process;

    -- display the image
    process(video_active, ram_rd_dat, ram_draw_x, ram_draw_y) is
    begin
        if video_active='0' then
          rgb <= ( others => '0'); --blank
        else
          -- by default set some grey value
          rgb(1*8-1 downto 0*8) <= x"10";
          rgb(2*8-1 downto 1*8) <= x"10";
          rgb(3*8-1 downto 2*8) <= x"10";
          if ram_draw_x = '1' and ram_draw_y = '1' then
            -- assign the memory data to pixel format
            -- hard coded for bbp in 8 bit per color out
            rgb(1*8-1 downto 1*8-bpp)  <= ram_rd_dat(1*bpp-1 downto 0*bpp);
            rgb(2*8-1 downto 2*8-bpp)  <= ram_rd_dat(2*bpp-1 downto 1*bpp);
            rgb(3*8-1 downto 3*8-bpp)  <= ram_rd_dat(3*bpp-1 downto 2*bpp);
          end if;
        end if;
    end process;

end rtl;