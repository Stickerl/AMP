library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity shadow_compare is
port(   reset_n_i           : in    std_ulogic := '0';
        dbg_data_i          : in    std_ulogic_vector(dbg_word_size_c-1 downto 0);
        shadow_dbg_data_i   : in    std_ulogic_vector(dbg_word_size_c-1 downto 0);
        mask_o              : out   std_ulogic);
end shadow_compare;

architecture if_compare of shadow_compare is
begin
    again_a_compare_with_some_name : process(dbg_data_i, shadow_dbg_data_i, reset_n_i) --clk_i)
    begin
        if reset_n_i = '0' then
            mask_o <= '0';
        elsif dbg_data_i /= shadow_dbg_data_i then
            mask_o <= '1';
        else
            mask_o <= '0';
        end if;
    end process;
end if_compare;