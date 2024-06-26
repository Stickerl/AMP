library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity hdlc_decoder is
port (
    clk_i               :   in  std_ulogic;
    data_i              :   in  std_ulogic_vector(7 downto 0);
    reset_n_i           :   in  std_ulogic;
    data_avail_i        :   in  std_ulogic;
    flag_received_o     :   out std_ulogic :='0';
    fifo_wr_rq_o        :   out std_ulogic;
    word_o              :   out std_ulogic_vector(15 downto 0)
);
end hdlc_decoder;

architecture hdlc_protocol of hdlc_decoder is
    type states_t is (WAIT_FOR_START, RESET_OUTPUTS, DECODE_BYTE, ESCAPE, FLAG_DETECTED, STORE_BYTE, PASS_WORD);
    signal state_s          :   states_t := WAIT_FOR_START;
    signal first_byte_s     :   std_ulogic :='0';
    signal cached_byte_s    :   std_ulogic_vector(7 downto 0);
    signal word_s           :   std_ulogic_vector(15 downto 0);

begin     
    der_hdlc_juergen : process (clk_i, reset_n_i)
    
    begin
        if reset_n_i = '0' then
            flag_received_o  <= '0';
            fifo_wr_rq_o    <= '0';
            word_o          <= (others => '0');
            word_s          <= (others => '0');
            cached_byte_s   <= (others => '0');
            state_s         <= WAIT_FOR_START;
            first_byte_s    <= '1';
            
        elsif rising_edge(clk_i) then
            case state_s is
                when WAIT_FOR_START =>
                    if data_avail_i = '1' then
                        if data_i = x"7E" then
                            first_byte_s <= '1';
                            state_s <= FLAG_DETECTED;
                        end if;
                    end if;
                
                when FLAG_DETECTED =>
                    flag_received_o  <= '1';
                    state_s         <= RESET_OUTPUTS;
                
                when RESET_OUTPUTS =>
                    fifo_wr_rq_o <= '0';
                    word_o <= ( others => '0');
                    flag_received_o  <= '0';
                    state_s <= DECODE_BYTE;
                
                when DECODE_BYTE =>
                    if data_avail_i = '1' then
                        if data_i = x"7E" then
                            first_byte_s <= '1';
                            state_s <= FLAG_DETECTED;
                        elsif data_i = x"7D" then
                            state_s <= ESCAPE;
                        else
                            cached_byte_s <= data_i;
                            state_s <= STORE_BYTE;
                        end if;
                    end if;
                
                when ESCAPE =>
                    if data_avail_i = '1' then
                        cached_byte_s <= data_i xor x"20"; -- invert bit5 (HDLC)
                        state_s <= STORE_BYTE;
                    end if;
                
                when STORE_BYTE =>
                    if first_byte_s = '1' then
                        word_s(15 downto 8) <= cached_byte_s;
                        first_byte_s <= '0';
                        state_s <= RESET_OUTPUTS;
                    else
                        word_s(7 downto 0) <= cached_byte_s;
                        first_byte_s <= '1';
                        state_s <= PASS_WORD;
                        
                    end if;
                    
                when PASS_WORD =>
                    word_o <= word_s;
                    fifo_wr_rq_o <= '1';
                    state_s <= RESET_OUTPUTS;
                    
                when others =>
                    state_s <= WAIT_FOR_START;
                
            end case;
        end if;
    end process der_hdlc_juergen;

end hdlc_protocol;