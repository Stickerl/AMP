library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity tx_driver is
port(
    clk_i           :   in      std_ulogic;
    space_left_i    :   in      unsigned(15 downto 0);
    uart_busy_i     :   in      std_ulogic;
    uart_tx_en_o    :   out     std_ulogic;
    uart_tx_byte_o  :   out     std_ulogic_vector(7 downto 0);
    
    
);

architecture papagei of tx_driver is

    signal space_left_s : unsigned(7 downto 0);
    signal lsb_avail_s  : std_ulogic :='0';

begin

    tx_buffer   : process (clk_i)
    
    begin
        if clk_i'event and clk_i='1' then
            if uart_busy_i <> '1' then
                if lsb_avail_s = 1 then
                    uart_tx_byte_o  <= space_left_s(7 downto 0);
                    uart_tx_en_o    <= '1';
                    lsb_avail_s     <= '0';
                
                elsif space_left_i <> x"FFFF" then
                    space_left_s    <= space_left_i(7 downto 0);
                    uart_tx_byte_o  <= space_left_i(15 downto 8);
                    uart_tx_en_o    <= '1';
                    lsb_avail_s     <= '1';
                else
                    space_left_s    <= x"FFFF";
                    uart_tx_en_o    <= '0';
                    lsb_avail_s     <= '0';
                end if;
            else
                uart_tx_en_o    <= '0';
            end if;
        end if;
    end process tx_buffer;

end papagei;