library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity TurnOnDelay is
port(   sys_clk_i   :   in  std_ulogic;

        res_n_i     :   in  std_ulogic;
        
        slope_i     :   in  std_ulogic;     -- not delayed input signal
        comp_i      :   in  unsigned (del_cnt_bits-1 downto 0); -- 
        delayd_o    :   out std_ulogic);    -- delayed output signals
end TurnOnDelay;

architecture DelayCounter of TurnOnDelay is
    signal cnt_s    :   unsigned (del_cnt_bits-1 downto 0) :=(others => '0');
    signal delayd_s :   std_ulogic;
    
begin
    delayd_o <= not(delayd_s); -- inverted due to optocopler (additional inverter on hardware)
    
    -- delay (implicitly) rising edge by comp_i * sys_clk_s, falling edge not delayed
    delay_unit : process  (sys_clk_i, res_n_i)
    begin
        if res_n_i = '0' then
            delayd_s    <= '0';
            cnt_s       <= (others => '0');
        elsif sys_clk_i'event and sys_clk_i='1' then
            if slope_i='1' then
                if cnt_s = comp_i then
                    delayd_s <= slope_i;
                else
                    cnt_s <= cnt_s + 1;
                    delayd_s <= '0';
                end if;
            else
                cnt_s <= (others => '0');
                delayd_s <= slope_i;
            end if;
        end if;
    end process;

end DelayCounter;