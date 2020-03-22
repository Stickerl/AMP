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
    wrusedw_i           :   in  unsigned(11 downto 0);
    space_left_o        :   out unsigned(15 downto 0) :=x"FFFF";
    trg_response_o      :   out std_ulogic :='0';
    fifo_wr_rq_o        :   out std_ulogic;
    word_o              :   out std_ulogic_vector(15 downto 0)
);
end hdlc_decoder;

architecture hdlc_protocol of hdlc_decoder is

    signal escape_s     :   std_ulogic :='0';
    signal byte_cnt_s   :   unsigned(hdlc_cnt_size_c downto 0);
    signal word_s       :   std_ulogic_vector(15 downto 0);    

begin     
    der_hdlc_juergen : process (clk_i, reset_n_i)
    
    begin
        if reset_n_i = '0' then
            space_left_o    <= x"FFFF";
            trg_response_o  <= '0';
            escape_s        <= '0';
            fifo_wr_rq_o    <= '0';
            word_o          <= (others => '0');
            word_s          <= (others => '0');
            byte_cnt_s      <= (others => '0');
            
        elsif rising_edge(clk_i) then
            word_o <= word_s;
            
            -- if UART data available
            if data_avail_i = '1' then
                
                -- frame delimiter
                if data_i = x"7E" then
                    space_left_o    <= resize((4096 -2 - wrusedw_i), 16); -- -2 bytes due to turnaround time
                    trg_response_o  <= '1';
                    escape_s        <= '0';
                    fifo_wr_rq_o    <= '0';
                    
                -- escape character
                elsif data_i = x"7D" then
                    space_left_o    <= x"FFFF";
                    trg_response_o  <= '0';
                    escape_s        <= '1';
                    fifo_wr_rq_o    <= '0';
                  
                -- valid data bytes
                else
                    space_left_o    <= x"FFFF";
                    trg_response_o  <= '0';
                    escape_s        <= '0';
                    word_s(15 downto 8) <= word_s(7 downto 0);
                    
                    if escape_s = '1' then
                        word_s(7 downto 0) <= data_i xor x"20"; -- invert bit5 (HDLC)
                    else
                        word_s(7 downto 0) <= data_i;
                    end if;
                    
                    -- assert FIFO write request, because word (sample) is complete
                    if byte_cnt_s = hdlc_word_size_c - 1 then
                        fifo_wr_rq_o    <= '1';
                        byte_cnt_s      <= ( others => '0');
                    else
                        fifo_wr_rq_o    <= '0';
                        byte_cnt_s      <= byte_cnt_s + 1;
                    end if;
                end if;
            else
                space_left_o    <= x"FFFF";
                trg_response_o  <= '0';
                fifo_wr_rq_o <= '0';
            end if;
        end if;
    end process der_hdlc_juergen;

end hdlc_protocol;