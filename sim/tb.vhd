library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;
use ieee.math_real.all;      

use work.globals.all;

entity etb  is
end entity;

architecture arch of etb is

   signal clk   : std_logic := '1';
   
	signal CLKCPU_I       : std_logic := '1';
	signal CLKPIX_I       : std_logic := '1';
	signal CEPIX_I        : std_logic := '1';
	signal SELPIX_O       : std_logic_vector(1 downto 0);
	signal CEAUD_I        : std_logic;
	signal RESET_I        : std_logic := '1';
	signal MEM_CYC_O      : std_logic;
	signal MEM_STB_O      : std_logic;
	signal MEM_WE_O       : std_logic;
	signal MEM_ACK_I      : std_logic;
	signal MEM_ERR_I      : std_logic;
	signal MEM_RTY_I      : std_logic;
	signal MEM_SEL_O      : std_logic_vector(3 downto 0);
	signal MEM_CTI_O      : std_logic_vector(2 downto 0);
	signal MEM_ADDR_O     : std_logic_vector(21 downto 0);
	signal MEM_DAT_I      : std_logic_vector(31 downto 0);
	signal MEM_DAT_O      : std_logic_vector(31 downto 0);
	signal HSYNC          : std_logic;
	signal VSYNC          : std_logic;
	signal VIDEO_R        : std_logic_vector(3 downto 0);
	signal VIDEO_G        : std_logic_vector(3 downto 0);
	signal VIDEO_B        : std_logic_vector(3 downto 0);
	signal VIDEO_EN       : std_logic;
	signal VIDBASECLK_O   : std_logic_vector(1 downto 0);
	signal VIDSYNCPOL_O   : std_logic_vector(1 downto 0);
	signal I2C_DOUT       : std_logic;
	signal I2C_DIN        : std_logic;
	signal I2C_CLOCK      : std_logic;
	signal DEBUG_LED      : std_logic;
	signal img_mounted    : std_logic_vector(1 downto 0); 
	signal img_wp         : std_logic;
	signal img_size       : std_logic_vector(31 downto 0);   
	signal sd_lba         : std_logic_vector(31 downto 0) := (others => '0');
	signal sd_rd          : std_logic_vector(1 downto 0);
	signal sd_wr          : std_logic_vector(1 downto 0);
	signal sd_ack         : std_logic;
	signal sd_buff_addr   : std_logic_vector(7 downto 0) := (others => '0');
	signal sd_buff_dout   : std_logic_vector(15 downto 0) := (others => '0');
	signal sd_buff_din    : std_logic_vector(15 downto 0);
	signal sd_buff_wr     : std_logic := '0';
	signal KBD_OUT_DATA   : std_logic_vector(7 downto 0);
	signal KBD_OUT_STROBE : std_logic;
	signal KBD_IN_DATA    : std_logic_vector(7 downto 0);
	signal KBD_IN_STROBE  : std_logic;
	signal JOYSTICK0      : std_logic_vector(4 downto 0);
	signal JOYSTICK1      : std_logic_vector(4 downto 0);
	signal AUDIO_L        : std_logic_vector(15 downto 0);
	signal AUDIO_R        : std_logic_vector(15 downto 0);
   
   signal DDRAM_OUT_BUSY       : std_logic := '0'; 
   signal DDRAM_OUT_DOUT       : std_logic_vector(31 downto 0); 
   signal DDRAM_OUT_DOUT_READY : std_logic; 
   signal DDRAM_OUT_BURSTCNT   : std_logic_vector(7 downto 0); 
   signal DDRAM_OUT_ADDR       : std_logic_vector(27 downto 0) := (others => '0'); 
   signal DDRAM_OUT_RD         : std_logic; 
   signal DDRAM_OUT_DIN        : std_logic_vector(31 downto 0);
   signal DDRAM_OUT_BE         : std_logic_vector(7 downto 0);
   signal DDRAM_OUT_WE         : std_logic; 
   
   type t_data is array(0 to (2**27)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
   signal tx_command  : std_logic_vector(31 downto 0);
   signal tx_bytes    : integer range 0 to 4;
   signal tx_enable   : std_logic := '0';
  
begin

   clk       <= not clk after 5 ns;
   CLKCPU_I  <= not CLKCPU_I after 24 ns; -- not exactly 42Mhz
   CLKPIX_I  <= not CLKPIX_I after 20 ns; -- ?
   CEPIX_I   <= not CEPIX_I after 40 ns; -- ?
   
   process
   begin
      wait until rising_edge(clk);
      if (tx_enable = '1' and tx_command(7) = '1') then
         RESET_I <= tx_command(0);
         wait until rising_edge(clk);
         wait until rising_edge(clk);
      end if;
   end process;
   
   iarchimedes_top : entity work.archimedes_top
   generic map
   (
      CLKCPU => 42000000
   )
   port map
   (
      CLKCPU_I       => CLKCPU_I      ,
      CLKPIX_I       => CLKPIX_I      ,
      CEPIX_I        => CEPIX_I       ,
      SELPIX_O       => SELPIX_O      ,
      CEAUD_I        => CEAUD_I       ,
      RESET_I        => RESET_I       ,
      MEM_CYC_O      => MEM_CYC_O     ,
      MEM_STB_O      => MEM_STB_O     ,
      MEM_WE_O       => MEM_WE_O      ,
      MEM_ACK_I      => MEM_ACK_I     ,
      MEM_ERR_I      => MEM_ERR_I     ,
      MEM_RTY_I      => MEM_RTY_I     ,
      MEM_SEL_O      => MEM_SEL_O     ,
      MEM_CTI_O      => MEM_CTI_O     ,
      MEM_ADDR_O     => MEM_ADDR_O    ,
      MEM_DAT_I      => MEM_DAT_I     ,
      MEM_DAT_O      => MEM_DAT_O     ,
      HSYNC          => HSYNC         ,
      VSYNC          => VSYNC         ,
      VIDEO_R        => VIDEO_R       ,
      VIDEO_G        => VIDEO_G       ,
      VIDEO_B        => VIDEO_B       ,
      VIDEO_EN       => VIDEO_EN      ,
      VIDBASECLK_O   => VIDBASECLK_O  ,
      VIDSYNCPOL_O   => VIDSYNCPOL_O  ,
      I2C_DOUT       => I2C_DOUT      ,
      I2C_DIN        => I2C_DIN       ,
      I2C_CLOCK      => I2C_CLOCK     ,
      DEBUG_LED      => DEBUG_LED     ,
      img_mounted    => img_mounted   ,
      img_wp         => img_wp        ,
      img_size       => img_size      ,
      sd_lba         => sd_lba        ,
      sd_rd          => sd_rd         ,
      sd_wr          => sd_wr         ,
      sd_ack         => sd_ack        ,
      sd_buff_addr   => sd_buff_addr  ,
      sd_buff_dout   => sd_buff_dout  ,
      sd_buff_din    => sd_buff_din   ,
      sd_buff_wr     => sd_buff_wr    ,
      KBD_OUT_DATA   => KBD_OUT_DATA  ,
      KBD_OUT_STROBE => KBD_OUT_STROBE,
      KBD_IN_DATA    => KBD_IN_DATA   ,
      KBD_IN_STROBE  => KBD_IN_STROBE ,
      JOYSTICK0      => JOYSTICK0     ,
      JOYSTICK1      => JOYSTICK1     ,
      AUDIO_L        => AUDIO_L       ,
      AUDIO_R        => AUDIO_R       
   );
   
   DDRAM_OUT_RD                <= MEM_STB_O and not MEM_WE_O;
   DDRAM_OUT_WE                <= MEM_STB_O and MEM_WE_O;
   DDRAM_OUT_DIN               <= MEM_DAT_O;
   DDRAM_OUT_ADDR(23 downto 2) <= MEM_ADDR_O;
   
   --MEM_CYC_O 
   --MEM_STB_O 
   --MEM_WE_O  
   --MEM_SEL_O 
   --MEM_CTI_O 
   --MEM_ADDR_O
   --MEM_DAT_O 
   
   MEM_ACK_I <= DDRAM_OUT_DOUT_READY;
   MEM_ERR_I <= '0';
   MEM_RTY_I <= '0';
   MEM_DAT_I <= DDRAM_OUT_DOUT;
   
   iestringprocessor : entity work.estringprocessor
   port map
   (
      ready       => '1',
      tx_command  => tx_command,
      tx_bytes    => tx_bytes,  
      tx_enable   => tx_enable, 
      rx_command  => x"00000000",
      rx_valid    => '1'
   );
    
   process
      variable address : integer;
      
      variable data : t_data := (others => 0);
      
      variable readmodifywrite : std_logic_vector(31 downto 0);
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte0     : std_logic_vector(7 downto 0);
      variable read_byte1     : std_logic_vector(7 downto 0);
      variable read_byte2     : std_logic_vector(7 downto 0);
      variable read_byte3     : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (3 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
   
         temp := ARG;
         for i in 0 to SIZE-1 loop
   
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
   
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
   
        return result;  
      end;
      
   begin

      DDRAM_OUT_DOUT_READY <= '0';
   
      while (0 = 0) loop
      
         -- data from file
         COMMAND_FILE_ACK <= '0';
         if COMMAND_FILE_START = '1' then
            
            assert false report "received" severity note;
            assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
         
            file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
         
            targetpos := COMMAND_FILE_TARGET  / 4;
         
            while (not endfile(infile)) loop
               
               read(infile, next_vector, actual_len);  
               
               read_byte0 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               read_byte1 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(1)), 8);
               read_byte2 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(2)), 8);
               read_byte3 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(3)), 8);
            
               if (COMMAND_FILE_ENDIAN = '1') then
                  data(targetpos) := to_integer(signed(read_byte3 & read_byte2 & read_byte1 & read_byte0));
               else
                  data(targetpos) := to_integer(signed(read_byte0 & read_byte1 & read_byte2 & read_byte3));
               end if;
               targetpos       := targetpos + 1;
               
            end loop;
         
            file_close(infile);
         
            COMMAND_FILE_ACK <= '1';
         
         end if;
      
         if (DDRAM_OUT_BUSY = '0') then
            address := to_integer(unsigned(DDRAM_OUT_ADDR)) / 4;
            while (DDRAM_OUT_RD = '1') loop
               DDRAM_OUT_DOUT_READY <= '1';
               DDRAM_OUT_DOUT <= std_logic_vector(to_signed(data(address), 32));
               wait until rising_edge(CLKCPU_I);
               wait for 1 ns;
               address := address + 1;
            end loop;
            DDRAM_OUT_DOUT_READY <= '0';
            
            if (DDRAM_OUT_WE = '1') then
               data(address) := to_integer(unsigned(DDRAM_OUT_DIN));
            end if;
         end if;
         
         wait until rising_edge(CLKCPU_I);
      end loop;
   
   end process;
   
   
   
end architecture;


