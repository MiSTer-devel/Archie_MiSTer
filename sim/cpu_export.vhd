
library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use STD.textio.all;

entity cpu_export is
   port 
   (
      clk              : in std_logic;
      rst              : in std_logic;
      new_export       : in std_logic;
      commandcount     : out integer;
      
      R0               : std_logic_vector(31 downto 0);
      R1               : std_logic_vector(31 downto 0);
      R2               : std_logic_vector(31 downto 0);
      R3               : std_logic_vector(31 downto 0);
      R4               : std_logic_vector(31 downto 0);
      R5               : std_logic_vector(31 downto 0);
      R6               : std_logic_vector(31 downto 0);
      R7               : std_logic_vector(31 downto 0);
      R8               : std_logic_vector(31 downto 0);
      R9               : std_logic_vector(31 downto 0);
      R10              : std_logic_vector(31 downto 0);
      R11              : std_logic_vector(31 downto 0);
      R12              : std_logic_vector(31 downto 0);
      R13              : std_logic_vector(31 downto 0);
      R14              : std_logic_vector(31 downto 0);
      R15              : std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of cpu_export is

   signal new_export_1 : std_logic := '0';
   
   signal rst_1        : std_logic := '1';
     
begin  
 
-- synthesis translate_off
   process
   
      file outfile         : text;
      variable f_status    : FILE_OPEN_STATUS;
      variable line_out    : line;
      variable recordcount : integer := 0;
      
      constant filenamebase    : string := "R:\debug_";
      variable filename        : string(1 to 14);
      
      variable nh : std_logic := '1';
      variable tc      : integer := 0;
      variable testrun : integer := 0;
      
      variable old_R0 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R1  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R2  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R3  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R4  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R5  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R6  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R7  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R8  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R9  : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R10 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R11 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R12 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R13 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R14 : std_logic_vector(31 downto 0) := (others => '0');
      variable old_R15 : std_logic_vector(31 downto 0) := (others => '0');

   begin
   
      filename := filenamebase & to_hstring(to_unsigned(testrun, 4)) & ".txt";
      file_open(f_status, outfile, filename, write_mode);

      while (true) loop
         wait until rising_edge(clk);
         
         rst_1 <= rst;
         if (rst_1 = '0' and rst = '1') then
            nh := '1';
            tc := 0;
            testrun := testrun + 1;
            
            filename := filenamebase & to_hstring(to_unsigned(testrun, 4)) & ".txt";
            file_close(outfile);
            file_open(f_status, outfile, filename, write_mode);
            file_close(outfile);
            file_open(f_status, outfile, filename, append_mode);
            
         end if; 
         
         new_export_1 <= new_export;
         if (rst = '0' and new_export_1 = '1') then

            write(line_out, string'("#")); write(line_out, tc); writeline(outfile, line_out);

            -- cpu 7
            if (nh = '1' or R0  /= old_R0 ) then write(line_out, string'("R0  ")); write(line_out, to_hstring(signed(R0 ))); writeline(outfile, line_out); old_R0  := R0 ; end if;
            if (nh = '1' or R1  /= old_R1 ) then write(line_out, string'("R1  ")); write(line_out, to_hstring(signed(R1 ))); writeline(outfile, line_out); old_R1  := R1 ; end if;
            if (nh = '1' or R2  /= old_R2 ) then write(line_out, string'("R2  ")); write(line_out, to_hstring(signed(R2 ))); writeline(outfile, line_out); old_R2  := R2 ; end if;
            if (nh = '1' or R3  /= old_R3 ) then write(line_out, string'("R3  ")); write(line_out, to_hstring(signed(R3 ))); writeline(outfile, line_out); old_R3  := R3 ; end if;
            if (nh = '1' or R4  /= old_R4 ) then write(line_out, string'("R4  ")); write(line_out, to_hstring(signed(R4 ))); writeline(outfile, line_out); old_R4  := R4 ; end if;
            if (nh = '1' or R5  /= old_R5 ) then write(line_out, string'("R5  ")); write(line_out, to_hstring(signed(R5 ))); writeline(outfile, line_out); old_R5  := R5 ; end if;
            if (nh = '1' or R6  /= old_R6 ) then write(line_out, string'("R6  ")); write(line_out, to_hstring(signed(R6 ))); writeline(outfile, line_out); old_R6  := R6 ; end if;
            if (nh = '1' or R7  /= old_R7 ) then write(line_out, string'("R7  ")); write(line_out, to_hstring(signed(R7 ))); writeline(outfile, line_out); old_R7  := R7 ; end if;
            if (nh = '1' or R8  /= old_R8 ) then write(line_out, string'("R8  ")); write(line_out, to_hstring(signed(R8 ))); writeline(outfile, line_out); old_R8  := R8 ; end if;
            if (nh = '1' or R9  /= old_R9 ) then write(line_out, string'("R9  ")); write(line_out, to_hstring(signed(R9 ))); writeline(outfile, line_out); old_R9  := R9 ; end if;
            if (nh = '1' or R10 /= old_R10) then write(line_out, string'("R10 ")); write(line_out, to_hstring(signed(R10))); writeline(outfile, line_out); old_R10 := R10; end if;
            if (nh = '1' or R11 /= old_R11) then write(line_out, string'("R11 ")); write(line_out, to_hstring(signed(R11))); writeline(outfile, line_out); old_R11 := R11; end if;
            if (nh = '1' or R12 /= old_R12) then write(line_out, string'("R12 ")); write(line_out, to_hstring(signed(R12))); writeline(outfile, line_out); old_R12 := R12; end if;
            if (nh = '1' or R13 /= old_R13) then write(line_out, string'("R13 ")); write(line_out, to_hstring(signed(R13))); writeline(outfile, line_out); old_R13 := R13; end if;
            if (nh = '1' or R14 /= old_R14) then write(line_out, string'("R14 ")); write(line_out, to_hstring(signed(R14))); writeline(outfile, line_out); old_R14 := R14; end if;
            if (nh = '1' or R15 /= old_R15) then write(line_out, string'("R15 ")); write(line_out, to_hstring(signed(R15))); writeline(outfile, line_out); old_R15 := R15; end if;

            recordcount := recordcount + 1;
            tc          := tc + 1;
            
            if (recordcount mod 1000 = 0) then
               file_close(outfile);
               file_open(f_status, outfile, filename, append_mode);
               recordcount := 0;
            end if;
            
            nh := '0';
         
         end if;
         
         commandcount <= tc;
         
      end loop;
      
   end process;
-- synthesis translate_on

end architecture;





