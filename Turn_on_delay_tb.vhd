library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Turn_on_delay_tb is
end Turn_on_delay_tb;

architecture testbench of Turn_on_delay_tb is
    signal clk50_s  : std_ulogic;
    signal freq_s   : std_ulogic;
    signal HS_s     : std_ulogic;

begin
    gen_clk50 : process
	begin
		clk50_s <= '0';
		wait for 10ns;
		clk50_s <= '1';
		wait for 10ns;
	end process;
    
    Gen_freq: entity work.GenFreq port map ('1',clk50_s,x"0000_01F4",freq_s);
    
    HS_delay_machine: entity work.TurnOnDelay port map (clk50_s,'1',freq_s,to_unsigned(100, del_cnt_bits),HS_s);
    

end testbench;