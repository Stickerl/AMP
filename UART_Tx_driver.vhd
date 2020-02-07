library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity tx_driver is
port(
    clk_i           :   in      std_ulogic;
    space_left_i    :   in      unsigned(15 downto 0);
    request_i       :   in      std_ulogic;
    uart_busy_i     :   in      std_ulogic;
    uart_tx_en_o    :   out     std_ulogic;
    uart_tx_byte_o  :   out     std_ulogic_vector(7 downto 0)
);
end tx_driver;

architecture papagei of tx_driver is
    type states_t is (IDLE, TX_MSB, TX_LSB, RESET);
    signal state_s      : states_t := IDLE;
    signal space_left_s : unsigned(15 downto 0);
    signal lsb_avail_s  : std_ulogic :='0';

begin
    tx_buffer   : process (clk_i)
    
    begin
        if rising_edge(clk_i) then
            case state_s is
                when IDLE =>
                    if request_i = '1' then
                        space_left_s    <= space_left_i;
                        state_s         <= TX_MSB;
                    end if;
                    
                when TX_MSB =>
                    if uart_busy_i = '0' then
                        uart_tx_en_o    <= '1';
                        uart_tx_byte_o  <= std_ulogic_vector(space_left_s(15 downto 8));
                        state_s         <= TX_LSB;
                    end if;
                    
                when TX_LSB =>
                    if uart_busy_i = '0' then
                        uart_tx_en_o    <= '1';
                        uart_tx_byte_o  <= std_ulogic_vector(space_left_s(7 downto 0));
                        state_s         <= RESET;
                    end if;
                    
                when RESET =>
                    space_left_s    <= (others => '0');
                    uart_tx_byte_o  <= (others => '0');
                    uart_tx_en_o    <= '0';
                    state_s         <= IDLE;
            end case;
        end if;
    end process tx_buffer;
end papagei;
