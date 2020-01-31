-- ############################
-- Function divides clk_i by comp_i/2 *2 and outputs it on freq_o
-- In case comp_i is 0 or 1 freq_o is clk_i
-- ############################

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity GenFreq is
    port( reset_n_i :   in  std_ulogic;                             -- asynchronus reset
          clk_i     :   in  std_ulogic;                             -- clk, that shall be divided
          comp_i    :   in  unsigned(31 downto 0) :=x"FFFF_FFFF";   -- clk divider
          freq_o    :   out std_ulogic);                            -- divided frequency
end GenFreq;

architecture clk_devide of GenFreq is
    signal comp_s   : unsigned(31 downto 0);                -- counter compare value (comp_i /2)
    signal psc_s    : unsigned (31 downto 0) :=X"0000_0000";-- current counter value
    signal pscout_s : std_ulogic :='0';                     -- output of counter

begin
    -- if comp_i == 0 or 1 freq_o = clk_i (counter shorted)
    -- else freq_o = pscout_s (output of counter)
    clk_plain_mux : process(reset_n_i, comp_s, clk_i, pscout_s)
    begin
        if reset_n_i = '0' then
            freq_o <= '0';
        else
            case comp_s is
                when x"0000_0000"   => freq_o <= clk_i;
                when x"0000_0001"   => freq_o <= clk_i;
                when others         => freq_o <= pscout_s;
            end case;
        end if;
    end process;
    
    comp_s <= comp_i srl 1; -- comp_i / 2, counter divides by it's nature by 2
    
    -- divide input by comp_i /2 *2 (only even dividers)
    Counter : process (clk_i, reset_n_i, comp_s)
    begin
        if reset_n_i = '0' then
            pscout_s <= '0';
            
        elsif clk_i' event and clk_i='1' then
            if psc_s = comp_s-1 then
               psc_s <=(others => '0');
               pscout_s <= not pscout_s;
            else
                psc_s <= psc_s+1;
            end if;
        end if;
    end process Counter;
    
end clk_devide;