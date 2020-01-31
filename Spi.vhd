-- ####################################
-- 

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

-- loop back mode could be used in combination with the debug bus

entity Spi is
port(sys_clk_i      : in    std_ulogic;                     -- system clock (50MHz)
     spi_mod_clk_i  : in	std_ulogic;                     -- clk for spi logic

     tx_i           : in    std_ulogic_vector(7 downto 0);  -- byte to transmit
     rx_o           : out   std_ulogic_vector(7 downto 0);  -- received byte
     
     start_i        : in    std_ulogic;                     -- trigger spi transmission
     done_o         : out   std_ulogic;                     -- spi transmission done
     reset_n_i      : in    std_ulogic;                     -- asynchronus reset
     
     sd_i           : in    std_ulogic;                     -- serial data in
     sclk_o         : out   std_ulogic;                     -- spi clk
	 sd_o	        : out   std_ulogic                     -- serial data out
     --debug_o        : out   std_ulogic                    -- spare debugging line
    );
end Spi;

architecture ShiftRegs of Spi is
    signal sclk_s       : std_ulogic :='0';                 -- spi clk directly connected to sclk_o
    
    signal rx_reg_s     : std_ulogic_vector(7 downto 0);    -- receive shift register
    signal tx_reg_s     : std_ulogic_vector(7 downto 0);    -- send shift register
    
    signal done_s       : std_ulogic :='1';                 -- spi module is idle
    signal old_done_s   : std_ulogic :='0';                 -- done_s delayed by 1 clk (slope detection)
    signal spi_busy_s   : std_ulogic :='0';                 -- spi is busy

    signal cnt_sclk_s   : unsigned(4 downto 0):=b"00000";   -- sclk clock edge counter
    signal cnt_tx_s     : unsigned(2 downto 0):=b"111";     -- current tx shift register offset
    signal cnt_rx_s     : unsigned(2 downto 0):=b"111";     -- current rx shift register offset
    
begin
    --debug_o <= start_i;
    sclk_o  <= sclk_s;
    done_o <= done_s;

    -- copy received byte from rx shift register to output
    copy_rx  : process (spi_busy_s, reset_n_i)
    begin
        if reset_n_i = '0' then
            rx_o     <= (others => '0');
        -- if spi module enters idle state
        elsif spi_busy_s'event and spi_busy_s = '0' then 
            rx_o     <= rx_reg_s;       -- copy last received byte to rx_o
        end if;
    end process;
    
    -- write tx byte form input to shift register
    assert_tx  : process (start_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            tx_reg_s <= (others => '0');
        -- if spi module is triggered
        elsif start_i'event and start_i = '1' then 
            if spi_busy_s = '0' then
                tx_reg_s <= tx_i;       -- assert byte in tx_i
            end if;
        end if;
    end process;
    
    clk_presc   : process (spi_mod_clk_i, reset_n_i) 
    begin
        if reset_n_i = '0' then
            cnt_sclk_s  <= b"00000";
            sclk_s      <= '1';         -- cpol_i;
            done_s      <= '1';
        elsif spi_mod_clk_i'event and spi_mod_clk_i='1' then
            if spi_busy_s = '1' then
                    cnt_sclk_s  <= cnt_sclk_s + 1;  -- count edges of sclk
                    
                    -- both edges are used (set output and receive input) -> clk speed doubled
                    if cnt_sclk_s = 16 then 
                        done_s  <= '1';             -- after 16 edges set transmission end
                        sclk_s      <= cpol_adc_c;      -- clk idle cpol_adc_c
                    else
                        done_s  <= '0';             -- transmission still ongoing
                        sclk_s      <= not sclk_s;  -- toggle sclk (polarity depends on cpol_adc_c)
                    end if;
                    
            else -- spi idle
                cnt_sclk_s  <= b"00000";
                done_s      <= '1';
                sclk_s      <= cpol_adc_c;
            end if;
        end if;
    end process;

    -- send 1 bit of the tx shifht register each sclk_s on not cpol_adc_c starting with MSB
    tx_shift_reg    : process (sclk_s, reset_n_i)
    begin
        if reset_n_i = '0' then
            cnt_tx_s            <= b"111";
            sd_o                <= '0';
        elsif sclk_s'event and sclk_s = not cpol_adc_c then
            sd_o            <= tx_reg_s(to_integer(cnt_tx_s));
            if cnt_tx_s = 0 then
                cnt_tx_s       <= b"111";
            else
                cnt_tx_s       <= cnt_tx_s -1;
            end if;
        end if;
    end process;
    
    -- receive 1 bit of the rx shifht register each sclk_s on cpol_sstarting with MSB
    rx_shift_reg   : process (sclk_s, reset_n_i)
    begin
        if reset_n_i = '0' then
            cnt_rx_s            <= b"111";
            rx_reg_s            <= (others => '0');
        elsif sclk_s'event and sclk_s = cpol_adc_c then
            rx_reg_s(to_integer(cnt_rx_s)) <= sd_i;
            if cnt_rx_s = 0 then
                cnt_rx_s       <= b"111";
            else
                cnt_rx_s       <= cnt_rx_s -1;
            end if;
        end if;
    end process;
    
    -- Reset spi busy-bit on done_s edge in last cycle
    reset_spi_busy  : process (sys_clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            spi_busy_s <= '0';
            old_done_s <= '0';
            
        elsif sys_clk_i'event and sys_clk_i = '1' then
            old_done_s <= done_s;           -- delay done_s by 1 clk to old_done_s
            
            -- if transaction finished in last cycle
            if done_s = '1' and old_done_s = '0' then
                spi_busy_s <= '0'; 
            elsif start_i = '1' then
                spi_busy_s <='1';
            end if;
        end if;
    end process;
end ShiftRegs;
