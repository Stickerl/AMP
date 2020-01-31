library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

-- ###################################################################
-- # Function: read ADC via SPI, ADC-word length in bytes needs to be 
-- # defined in Global_params file (bytes_p_frame_c).

entity ReadAdc is
port(   sys_clk_i       : in     std_ulogic;             -- system clock (50MHz)
        spi_mod_clk_i   : in	 std_ulogic;             -- clk for spi logic
        sample_clk_i    : in     std_ulogic;             -- adc sample clk
        
        reset_n_i       : in     std_ulogic;
            
        sample_o        : out    unsigned(adc_word_len_c-1 downto 0); -- complete ADC value
         
        sd_i            : in     std_ulogic;             -- serial data in
        sclk_o          : out    std_ulogic;             -- spi clk
        sd_o	        : out    std_ulogic;             -- serial data out
        csn_o           : out    std_ulogic              -- spi chip select
);  
end ReadAdc;

architecture AdcReadLoop of ReadAdc is
    
    -- input / output of Spi-module
    signal tx_s             : std_ulogic_vector (7 downto 0);   -- next byte to be send
    signal rx_s             : std_ulogic_vector (7 downto 0);   -- last byte that was received
    
    -- spi status/ control signals
    signal start_s          : std_ulogic;   -- start a spi transmission, immediate assert of tx_s
    signal done_s           : std_ulogic;   -- 0: spi in idle status, 1: spi transmission ongoing

    -- adc related signals
    signal byte_nr_s        : unsigned (2 downto 0);    -- received byte counter (spi)
    -- shift register containing received bytes from ADC
    signal adc_val_s        : std_ulogic_vector (8*bytes_p_frame_c downto 0) :=(others=>'0');
    -- singed adc output ready for delta sigma
    signal sample_s         : signed (dac_bits-1 downto 0) :=(others=>'0');
    
    -- helper signals for edge detection
    signal sample_clk_old_s : std_ulogic;   -- sample_clk_i delayed by 1 sys_clk
    signal done_old_s       : std_ulogic;

begin
    -- handle spi bus
    Adc_via_spi: entity work.Spi port map (sys_clk_i, spi_mod_clk_i,
                                           tx_s, rx_s,
                                           start_s, done_s, reset_n_i,
                                           sd_i, sclk_o, sd_o);

   -- send read cmd to ADC and receive sample byte per byte
   read_adc      : process (sys_clk_i, reset_n_i)
        variable byte_nr_v    : unsigned (2 downto 0);
    begin
        if reset_n_i = '0' then
            byte_nr_v           := (others => '0');
            done_old_s          <= '0'; 
            sample_clk_old_s    <= '0';
            adc_val_s         <= (others => '0');
            start_s             <= '0';
            tx_s                <= x"00"; -- probably a bug, shouldn't it be x"AA"?
            csn_o               <= '1';
        elsif sys_clk_i'event and sys_clk_i='1' then
            -- delay signals by 1 sys_clk cycle
            sample_clk_old_s <= sample_clk_i;
            done_old_s       <= done_s; 
            
            -- ####################################
            -- # receive byte and assemble ADC word
            -- ####################################
            if done_s = '1' then 
                if sample_clk_i ='1' xor sample_clk_old_s='1' then -- edge on sample clk
                    byte_nr_v := (others => '0');
                    adc_val_s <= adc_val_s;
                elsif done_old_s = '0' then -- on rising edge on done_s
                    
                    adc_val_s <= std_ulogic_vector(unsigned(adc_val_s) sll 8);   -- lshift received bytes by 8 bit
                    adc_val_s(7 downto 0) <= rx_s;  -- append last received byte
                    byte_nr_v := byte_nr_v +1;      -- increase byte receive counter
                    
                    -- only give adc_val_s to modulation when full 12bit transmission is finished
                    if byte_nr_v = bytes_p_frame_c then -- if received # bytes == expected
                        -- cut out adc word length (bits) and convert to signed
                        -- TODO: check if conversion is correct?
                        sample_o <= unsigned(adc_val_s(adc_word_len_c-1 downto 0));
                    end if;
                end if;
            end if;
            
            -- #################################################################
            -- # send read cmd 0xAA and dummy bytes to request a sample from ADC 
            -- #################################################################
            if done_s = '1' then
                if byte_nr_v < bytes_p_frame_c then
                    start_s <= '1';         -- trigger spi transmission
                    tx_s    <= x"00";       -- send cmd 0x00 (dummy bytes)
                    csn_o   <= '0';
                else
                    csn_o   <= '1';
                end if;
            else
                start_s <= '0';
                tx_s    <= x"AA";           -- send acquire cmd
            end if;
        end if;
    end process;    
end AdcReadLoop;