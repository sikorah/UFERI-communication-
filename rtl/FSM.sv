module FSM(
    input logic          clk,
    input logic          rst_n,

    input logic          cmd_ready,

    output logic         cmd_valid,
    output logic [3:0]   cmd,
    output logic [41:0]  data2ctrl
);

    typedef enum logic [3:0] {
        IDLE                = 4'b0000,
        MODE_COUNT          = 4'b0001,
        MODE_READ_1         = 4'b0010,
        MODE_READ_2         = 4'b0011,
        MODE_READ_3         = 4'b0100,
        MODE_WRITE_1        = 4'b0101,
        MODE_WRITE_2        = 4'b0110,
        MODE_WRITE_3        = 4'b0111,
        PIXEL_CONFIG_STORE  = 4'b1000,
        PIXELS_READ         = 4'b1001,
        PIXELS_CLEAR        = 4'b1010,
        PIXELS_WRITE        = 4'b1011,
        INIT                = 4'b1100
    } sequnce_opcode_t;

    typedef enum logic [2:0] {
        PIX_WRITE          = 3'b000,
        PIX_READ           = 3'b001,
        PIX_READ_END       = 3'b010,
        WRITE_PCLK_0       = 3'b011,
        WRITE_PCLK_1       = 3'b100,
        WRITE_FULL_PCLK_0  = 3'b101,
        WRITE_FULL_PCLK_1  = 3'b110,
        SREG_READ          = 3'b111
    } cmd_opcode_t;

    typedef struct packed {
        //config_reg_0
        logic [2:0] pclk_en;            // Pixel clock singal enable
        logic [2:0] shift_en;           // Pixel counter operation mode

        //config_reg_1
        logic       pixel_write_en;     // Enable writing data from SREG to pixel matrix
        logic       pixel_store_cfg;    // Store all counters values   // usunac

        //config_reg_2
        logic [1:0] cnt_length;         // Select pixel counter length /11
        logic       long_cnt_en;        // Enable 24-bit counters /1 
        logic       zdt_en;             // Enable zero detection
        logic       ddr_en;             // Enable DDR mode

        //config_reg_selection
        logic [1:0] config_reg_sel;     // Config regester selection            
        logic       config_write_full;  // Select config register length
    } config_t;

    sequnce_opcode_t state;
    config_t         seq_config;

    logic        WRITE_ENABLE =  1'b0;
    logic [29:0] MODE_BTSRM   = 30'h0;
    logic [ 3:0] seq_counter;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cmd_valid   <= 1'b1;
            cmd         <= 3'b000;
            data2ctrl   <= 42'b0;
            state       <= INIT; 
        end else begin
            case (state)
                INIT: begin // Ustawia sygnały jak w clustrze na podstawie wartości defaultowych
                    seq_config.shift_en         <= 3'h0;
                    seq_config.pclk_en          <= 3'h7;
                    seq_config.pixel_write_en   <= 1'h0;
                    seq_config.cnt_length       <= 2'h3;
                    seq_config.long_cnt_en      <= 1'h1;
                    seq_config.zdt_en           <= 1'h0;
                    seq_config.ddr_en           <= 1'h0;

                    cmd_valid                   <= 1'b1;
                end
                IDLE: begin // Przejścia do stanów od wejścia UART i ustawienie rejestrów na stałe wartości
                    seq_config.cnt_length      <= 2'h3; // dlugosc licznikow 12-bit (wymagane do 24-bitowych licznikow)
                    seq_config.long_cnt_en     <= 1'h1; // 24-bit counters enabled 

                    cmd_valid                  <= 1'b1;
                    seq_counter                <= 4'h0;
                
                    state <= sequence_opcode_t'(uart_in);
                end
                MODE_COUNT: begin
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h0;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en = 1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h7;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h7;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h7;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en = 0 & shift_en = 0)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h0;
                        seq_config.shift_en          <= 3'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h0;
                        seq_config.shift_en          <= 3'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h0;
                        seq_config.shift_en          <= 3'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_COUNT;
                    end
                end
                MODE_READ_1: begin
                    WRITE_ENABLE <= 1'b0;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h0;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_READ_1;
                    end
                end
                MODE_READ_2: begin
                    WRITE_ENABLE <= 1'b0;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h0;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_READ_2;
                    end
                end
                MODE_READ_3: begin
                    WRITE_ENABLE <= 1'b0;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h0;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_READ_3;
                    end
                end
                MODE_WRITE_1: begin
                    WRITE_ENABLE <= 1'b1;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h1;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h1;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_WRITE_1;
                    end
                end
                MODE_WRITE_2: begin
                    WRITE_ENABLE <= 1'b1;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h1;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h2;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_WRITE_2;
                    end
                end
                MODE_WRITE_3: begin
                    WRITE_ENABLE <= 1'b1;
                    cmd_valid                     <= 1'b0;
                    seq_config.pixel_write_en     <= 1'h1;
                    seq_config.config_write_full  <= 1'h0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeRead
                    if (!cmd_ready && seq_counter == 0) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (pclk_en[1]=1)
                    else if (!cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pclk_en           <= 3'h4;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end
                // Wykonanie ModeSet (shift_en[1] = 1)
                    else if (!cmd_ready && seq_counter == 7) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 8) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 9) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.shift_en          <= 3'h4;
                        cmd                          <= WRITE_PCLK_0;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 10) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= MODE_WRITE_3;
                    end
                end
                PIXEL_CONFIG_STORE: begin
                    cmd_valid                     <= 1'b0;
                    seq_config.pclk_en            <= 3'h7;
                // Wykonanie ModeSet
                    if (!cmd_ready) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pixel_store_cfg    <= 1'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 1) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pixel_store_cfg    <= 1'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 3) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pixel_store_cfg    <= 1'h1;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end 
                // Wykonanie ModeSet
                    else if (cmd_ready && seq_counter == 4) begin
                        seq_config.config_reg_sel    <= 2'h0;
                        seq_config.pixel_store_cfg    <= 1'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_0
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.shift_en[2],
                            seq_config.shift_en[1],
                            seq_config.shift_en[0],
                            seq_config.pclk_en[2],
                            seq_config.pclk_en[1],
                            seq_config.pclk_en[0],
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 5) begin
                        seq_config.config_reg_sel    <= 2'h2;
                        seq_config.pixel_store_cfg    <= 1'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_2
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            '0,                             // gate_en[2]
                            '0,                             // gate_en[1]
                            '0,                             // gate_en[0]
                            '0,                             // pixel_cal_strobe
                            seq_config.pixel_write_en,
                            seq_config.pixel_store_cfg,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (!cmd_ready && seq_counter == 6) begin
                        seq_config.config_reg_sel    <= 2'h1;
                        seq_config.pixel_store_cfg    <= 1'h0;
                        cmd                          <= WRITE_PCLK_1;
                        data2ctrl <= {                      // reg_1
                            32'b0,                          // Dopełnienie do 42 bitów
                            seq_config.config_reg_sel[1],
                            seq_config.config_reg_sel[0],
                            seq_config.config_write_full,
                            seq_config.cnt_length[1],
                            seq_config.cnt_length[0],
                            seq_config.long_cnt_en,
                            seq_config.zdt_en,
                            seq_config.ddr_en,
                            '0,
                            '0
                        };
                        seq_counter <= seq_counter + 1;
                    end else if (cmd_ready && seq_counter == 7) begin
                        state <= IDLE;
                    end else begin
                        cmd_valid <= 1'b1;
                        state     <= PIXEL_CONFIG_STORE;
                    end
                end
                PIXELS_READ: begin

                end
                PIXELS_CLEAR: begin

                end
                PIXELS_WRITE: begin

                end
            default: begin
                state <= INIT;
            end
            endcase
        end
    end

endmodule