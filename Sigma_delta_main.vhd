library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Sigma_delta_main is
port (clk50_i           :   in  std_ulogic; -- 50MHz external clk input

      reset_n_i         :   in  std_ulogic; -- system reset mapped to button
      
      uart_rx_i         :   in  std_ulogic; -- Pin to receive UART stream from PC
      uart_tx_o         :   out std_ulogic; 
      
      hs_o              :   out std_ulogic; -- high side gate driver
      ls_o              :   out std_ulogic; -- low  side gate driver
      bit_str_raw_o     :   out std_ulogic; -- high side driver output without break before make
      bit_str_raw_n_o   :   out std_ulogic; -- low  side driver output without break before make
      
      identifier_o      :   out std_ulogic_vector(7 downto 0);  -- identifier (debug channel)
      dbg_bus_o         :   out std_ulogic_vector(15 downto 0); -- debugging data lines 
      dbg_clk_o         :   out std_ulogic;                     -- debugging clk
      
      led_o             :   out std_ulogic_vector(7 downto 0) := x"00";
      dbg_pins_o        :   out std_ulogic_vector(4 downto 0) := (others => '0') -- spare pins
      );
end Sigma_delta_main;

architecture Sigma_delta_modulator of Sigma_delta_main is
    -- ##############################################
    -- # Clock Domains
    -- ##############################################
    signal sys_clk_s        : std_ulogic;   -- main clk, other clks derived from this
    signal mod_clk_s        : std_ulogic;   -- clk for sigma-delta loop
    signal sample_clk_s     : std_ulogic;   -- ADC sample clk
    signal sample_clk_old_s : std_ulogic;   -- needed?
    signal dbg_clk_s        : std_ulogic;   -- clk of debugging bus
    signal sign_gen_clk_s   : std_ulogic;   -- clk for reading sample from LUT (signal generator)
    
    -- ##############################################
    -- # modulator output before adding turn on delay
    -- ##############################################
    signal bitstream_s      : std_ulogic;   -- high side
    signal bitstream_n_s    : std_ulogic;   -- low side


    -- ##############################################
    -- # signals related to signal generator
    -- ##############################################
    signal offset_s         : unsigned(dac_bits downto 0); -- offset to set artificial signals into center of signed number range
    signal sig_gen_s        : unsigned(dac_bits-1 downto 0); -- test signal read out of array
    signal signed_sig_gen_s : signed(dac_bits downto 0);     -- result (extended by 1 Bit) of substraction of sig_gen_s - offset_s
    
    -- ##############################################
    -- # signals related to audio stream
    -- ##############################################
    signal wrusedw_s        : unsigned(11 downto 0);
    signal space_left_s     : unsigned(15 downto 0); 
    signal fifo_wr_rq_s     : std_ulogic;
    signal word_s           : std_ulogic_vector(15 downto 0);
    signal no_audio_avail_s : std_ulogic;
    signal audio_sample_s   : signed(15 downto 0);
    signal tx_done_s        : std_ulogic;
    signal tx_busy_s        : std_ulogic;
    signal resp_avail_s     : std_ulogic;
    signal uart_tx_en_s     : std_ulogic;
    signal uart_tx_byte_s   : std_ulogic_vector(7 downto 0);
    
    -- ##############################################
    -- # signals related to debugging bus
    -- ##############################################
    signal dbg_data_a       : dbg_data_buf_t;
    signal dbg_fifo_wr_a    : dbg_fifo_wr_t;    -- ctrl signals regarding writing to FIFO
    signal dbg_fifo_rd_a    : dbg_fifo_rd_t;    -- ctrl signals regarding reading from FIFO
    signal dbg_fifo_in_s    : std_ulogic_vector(23 downto 0);   -- value written to FIFO
    signal dbg_fifo_out_s   : std_ulogic_vector(23 downto 0);   -- value read from FIFO
    signal dbg_fifo_rdempty_s : std_ulogic;
    
    -- ##############################################
    -- # debugging signals 
    -- ##############################################
    signal uart_out_s       : std_ulogic_vector (7 downto 0);
    signal uart_received_s  : std_ulogic;
    signal toggle_s         : std_ulogic;
    signal new_audio_data_s : std_ulogic := '0';
    
begin
--    dbg_pins_o(0)   <= 
--    dbg_pins_o(1)   <= 
--    dbg_pins_o(2)   <= 
--    dbg_pins_o(3)   <= 
--    dbg_pins_o(4)   <= 
--    dbg_pins_o(5)   <=
--    led_o(1) <= '1'; -- poor man's versioning (do verify whether programming worked)
--    led_o(2) <= '0'; -- poor man's versioning (do verify whether programming worked)
--    led_o(3) <= '1'; -- poor man's versioning (do verify whether programming worked)
    -- ##############################################
    -- # Clock Prescaler
    -- ##############################################
    
    -- 50MHz / 1 = 50MHz
    sys_clk_psc    : entity work.GenFreq port map (reset_n_i, clk50_i, x"0000_0001", sys_clk_s);
    
    -- sys_clk(50MHz) / 33 = 1.5MHz, modulation clk
    modulation_psc : entity work.GenFreq port map (reset_n_i, sys_clk_s, x"0000_0021", mod_clk_s);
    
    -- sys_clk(50MHz) / 4 = 12.5MHz, clk for debugging bus 
    dbgclk_psc     : entity work.GenFreq port map (reset_n_i, sys_clk_s, x"0000_0004", dbg_clk_s);
    
    -- sys_clk(50MHz) / 1040 = 48.08kHz, sample rate for ADC sample_clk_s / 2 
    -- TODO: Should'nt the divider be 260
    adc_sample_clk : entity work.GenFreq port map (reset_n_i, sys_clk_s, x"0000_0410", sample_clk_s);
    
    -- sys_clk(50MHz) / 520 = 96.15kHz, read clk for embedded signal generator (signal from LUT)
    sign_gen_clk   : entity work.GenFreq port map (reset_n_i, sys_clk_s, x"0000_0208", sign_gen_clk_s);
   
    -- ##############################################
    -- # Sigma-Delta-Modulation
    -- ##############################################
    
    Modulation : entity work.Modulator port map( --Modulator2nd port map (
        mod_clk_i         => mod_clk_s,
        -- adc_sample_s, TODO: change back to adc_sample_s
        sample_i          => resize(audio_sample_s, dac_bits + 1),    --signed(signed_sig_gen_s(dac_bits) & signed_sig_gen_s(dac_bits-2 downto 0)), -- drop bit(dac_bits-1)
        bitstream_o       => bitstream_s,
        rst_n_i           => reset_n_i
        --dbg_chan0_o       => dbg_data_a(0),
        --dbg_chan1_o       => dbg_data_a(1),
        --dbg_chan2_o       => dbg_data_a(2),
        --dbg_chan3_o       => dbg_data_a(3)
    );
      
    bitstream_n_s   <= not(bitstream_s); 
    bit_str_raw_o   <= bitstream_s;     -- Gate-signal power stage without break before make
    bit_str_raw_n_o <= bitstream_n_s;   -- inv Gate-signal power stage without break before make
    
    -- ##############################################
    -- # Break before Make
    -- ##############################################
    
    HS_delay_machine: entity work.TurnOnDelay port map (sys_clk_s, reset_n_i,
                                                        bitstream_s,
                                                        to_unsigned(10, del_cnt_bits), hs_o);
    LS_delay_machine: entity work.TurnOnDelay port map (sys_clk_s, reset_n_i,
                                                        bitstream_n_s,
                                                        to_unsigned(10, del_cnt_bits), ls_o);
 
    -- ##############################################
    -- # Audio Stream
    -- ##############################################
    uart_rx : entity work.UART_RX port map(
        i_Clk       => sys_clk_s,
        i_RX_Serial => uart_rx_i,
        o_RX_DV     => uart_received_s,
        std_logic_vector(o_RX_Byte)   => uart_out_s
        );
    
    hdlc_decoder : entity work.hdlc_decoder port map (
        clk_i           => sys_clk_s, 
        data_i          => uart_out_s,
        reset_n_i       => reset_n_i,
        data_avail_i    => uart_received_s,
        wrusedw_i       => wrusedw_s,
        space_left_o    => space_left_s,
        trg_response_o  => resp_avail_s,
        fifo_wr_rq_o    => fifo_wr_rq_s,
        word_o          => word_s
    );
    
    audio_fifo : entity work.AudioStreamFifo port map(
        aclr        => not(reset_n_i),
        data        => std_logic_vector(word_s),
        rdclk       => sample_clk_s,
        rdreq       => '1',
        wrclk       => sys_clk_s,
        wrreq       => fifo_wr_rq_s,
        signed(q)   => audio_sample_s,
        rdempty     => no_audio_avail_s,
        unsigned(wrusedw) => wrusedw_s
    );

    uart_tx_driver : entity work.tx_driver port map(
        clk_i           => sys_clk_s,
        space_left_i    => space_left_s,
        request_i       => resp_avail_s,
        uart_busy_i     => tx_busy_s,
        uart_tx_en_o    => uart_tx_en_s,
        uart_tx_byte_o  => uart_tx_byte_s
    );
    
    uart_tx : entity work.UART_TX port map(
        i_Clk       => sys_clk_s,
        i_TX_DV     => uart_tx_en_s,
        i_TX_Byte   => std_logic_vector(uart_tx_byte_s),
        o_TX_Active => tx_busy_s,
        o_TX_Serial => uart_tx_o,
        o_TX_Done   => tx_done_s
    );
    
    audio_sample_dbg_out    :   process (sample_clk_s, reset_n_i)
        
    begin
        if reset_n_i = '0' then
            new_audio_data_s <= '0';
            
        elsif rising_edge(sample_clk_s) then
            if no_audio_avail_s = '0' then
                dbg_data_a(1) <= new_audio_data_s & std_Ulogic_vector(audio_sample_s);
                new_audio_data_s <= not new_audio_data_s;
            end if;
        end if;
    end process;
    
    -- ##############################################
    -- # signal generator
    -- ##############################################
    --signal_gen  : entity work.SignalGenerator port map(sign_gen_clk_s, reset_n_i, resize(x"8FF", dac_bits),
    --                                                   "00", sig_gen_s, resize(signed_sig_gen_s, dac_bits), 
    --                                                   offset_s, dbg_data_a(4), dbg_data_a(5));
    --                                                 
    --
    -- ############################################## 
    -- # Debugging Bus
    -- ##############################################
    debug_fifo_inst : entity work.DebugFifo port map(
        aclr                 => not(reset_n_i),
        data                 => std_logic_vector(dbg_fifo_in_s),
        wrclk                => std_logic(dbg_fifo_wr_a(wrclk)),
        wrreq                => std_logic(dbg_fifo_wr_a(wrreq)),
        std_ulogic(wrempty)  => dbg_fifo_wr_a(wrempty),
        std_ulogic(wrfull)   => dbg_fifo_wr_a(wrfull),
        std_ulogic_vector(q) => dbg_fifo_out_s,
        std_ulogic(rdempty)  => dbg_fifo_rdempty_s,
        rdclk                => std_logic(dbg_fifo_rd_a(rdclk)),
        rdreq                => std_logic(dbg_fifo_rd_a(rdreq)),
        std_ulogic(rdfull)   => dbg_fifo_rd_a(rdfull)
    );
    
    debug_port  : entity work.DbgInterface port map(
        rst_n_i         => reset_n_i,
        clk_i           => dbg_clk_s,
        dbg_fifo_word_i => dbg_fifo_out_s,
        dbg_rdempty_i   => dbg_fifo_rdempty_s,
        
        toggle_o        => toggle_s,
        identifier_o    => identifier_o,
        dbg_bus_o       => dbg_bus_o,
        dbg_clk_o       => dbg_clk_o,
        rdclk_o         => dbg_fifo_rd_a(rdclk),
        rdreq_o         => dbg_fifo_rd_a(rdreq)
    );
    
    feed_fifo   : entity work.FeedFifo port map(
    reset_n_i           => reset_n_i,
    sys_clk_i           => sys_clk_s,
    wrempty_i           => dbg_fifo_wr_a(wrempty),
    wrfull_i            => dbg_fifo_wr_a(wrfull),  
    dbg_data_a          => dbg_data_a,
    fifo_word_o         => dbg_fifo_in_s,    
    wrclk_o             => dbg_fifo_wr_a(wrclk),
    wrreq_o             => dbg_fifo_wr_a(wrreq)
    );
end Sigma_delta_modulator;