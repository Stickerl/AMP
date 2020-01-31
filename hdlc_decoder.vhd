library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity hdlc_decoer is
port (
    clk50_i             :   in  std_ulogic; -- 50MHz external clk input
    data_i              :   in  std_ulogic_vector(7 downto 0);
    reset_n_i           :   in  std_ulogic;
    data_avail_i        :   in  std_ulogic;
    wrusedw_i           :   in  unsigned(11 downto 0);
    space_left_o        :   out unsigned(15 downto 0) :=x"FFFF";
    fifo_wr_rq_o        :   out std_ulogic;
    word_o              :   out std_ulogic_vector(15 downto 0)
);
end hdlc_decoer;

architecture hdlc_protocol of hdlc_decoer is

    signal escape_s     :   std_ulogic :=0;
    signal byte_cnt_s   :   unsigned(hdlc_cnt_size_c downto 0);
    signal word_s       :   std_ulogic_vector(15 downto 0);    

begin     
    der_hdlc_juergen : process (clk50_i)
    
    begin
    
        word_o <= word_s;
        if clk50_i'event and clk50_i = '1' then
            
            -- if UART data available
            if data_avail_i = '1' then
                
                -- frame delimiter
                if data_i = x"7E" then
                    space_left_o    <= 4096 -2 - wrusedw_i; -- -2 bytes due to turnaround time
                    uart_tx_en_o    <= '1';
                    escape_s        <= '0';
                    fifo_wr_rq_o    <= '0';
                    
                -- escape character
                elsif data_i = x"7D" then
                    space_left_o    <= x"FFFF";
                    uart_tx_en_o    <= '0';
                    escape_s        <= '1';
                    fifo_wr_rq_o    <= '0';
                  
                -- valid data bytes
                else
                    space_left_o    <= x"FFFF";
                    uart_tx_en_o    <= '0';
                    escape_s <= '0';
                    word_s(15 downto 8) <= word_s(7 downto 0);
                    
                    if escape_s = '1' then
                        word_s <= data_i xor x"20"; -- invert bit5 (HDLC)
                    else
                        word_s <= data_i;
                    end if;
                    
                    -- assert FIFO write request, because word (sample) is complete
                    if byte_cnt_s = hdlc_word_size_c-1 then
                        fifo_wr_rq_o <= '1';
                        byte_cnt_s := 0;
                    else
                        fifo_wr_rq_o <= '0';
                        byte_cnt_s := byte_cnt_s + 1;
                    end if;
                end if;
            else
                space_left_o    <= x"FFFF";
                uart_tx_en_o    <= '0';
                fifo_wr_rq_o <= '0';
            end if;
        end if;
    end process der_hdlc_juergen;

end hdlc_protocol;