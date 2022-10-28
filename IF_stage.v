module IF_stage(
    input           clk,
    input           reset,
    // allowin from ID stage
    input           ds_allowin,
    // branch bus
    input   [33:0]  br_bus,
    // output to ID stage
    output          fs_to_ds_valid,
    output  [64:0]  fs_to_ds_bus,
    // inst sram interface
    output          inst_sram_req,       // if there is a request
    output          inst_sram_wr,        // read or write
    output  [3:0]   inst_sram_wstrb,     // write strobes
    output  [1:0]   inst_sram_size,      // number of bytes  0:1 bytes 1:2bytes 2:4bytes
    output  [31:0]  inst_sram_addr,      // request addr
    output  [31:0]  inst_sram_wdata,     // write data
    input   [31:0]  inst_sram_rdata,     // read data
    input           inst_sram_addr_ok,   // if data and addr has been received
    input           inst_sram_data_ok,   // if data has been written or given back
    // interrupt signal
    input           wb_ex,
    input           wb_ertn,
    input   [31:0]  csr_eentry,
    input   [31:0]  csr_era
);

wire handshake;
assign handshake = inst_sram_addr_ok & inst_sram_req;
parameter if_empty  = 2'b01;
parameter if_full   = 2'b10;
parameter preif_req = 3'b001;
parameter preif_inst= 3'b010;
parameter preif_br_req = 3'b110;

reg [1:0] if_current_state;
reg [1:0] if_next_state;
reg [2:0] preif_current_state;
reg [2:0] preif_next_state;

assign inst_sram_wr = 0;
assign inst_sram_wstrb = 0;
assign inst_sram_size = 2'b10;
assign inst_sram_wdata = 0;

// to detech adef
wire adef_detected;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;

// signals for pc
wire [31:0] seq_pc;
wire [31:0] nextpc;

// signals from branch
wire        br_taken;
wire [31:0] br_target;
wire        br_taken_cancel;
assign {br_taken_cancel,br_taken,br_target} = br_bus;

// signals to output for ID_stage
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {adef_detected,fs_inst,fs_pc};

reg [31:0]  last_nextpc;
always @(posedge clk)
begin
    if(reset)
    begin
        last_nextpc <= 32'h1C000000;
    end
    else
        last_nextpc <= nextpc;
end
// pre-IF stage
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       =   wb_ex       ? csr_eentry :
                        wb_ertn     ? csr_era   :
                        preif_current_state[2] ? last_nextpc:
                        br_taken    ? br_target : seq_pc;

assign adef_detected = nextpc[1:0] == 2'b00 ? 0 : 1;



// IF stage
assign fs_ready_go     = ~preif_current_state[2] & ((if_current_state[0] & inst_sram_data_ok & ds_allowin) | if_current_state[1]);
assign fs_allowin      = !(fs_valid & fs_ready_go) | fs_ready_go & ds_allowin | preif_current_state[2];
assign fs_to_ds_valid  = fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= 1'b1;
    end
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end
end

always @(posedge clk)
begin
    if(reset)
    begin
        if_current_state <= if_empty;
        preif_current_state <= preif_req;
    end
    else
    begin
        if_current_state <= if_next_state;
        preif_current_state <= preif_next_state;
    end
end

always @(*)
begin
    if(if_current_state[0])
    begin
        if(~inst_sram_data_ok)
            if_next_state <= if_empty;
        else if(inst_sram_data_ok && ds_allowin)
            if_next_state <= if_empty;
        else if(inst_sram_data_ok & ~ds_allowin)
            if_next_state <= if_full;
    end
    else// if(if_current_state[1])
    begin
        if(ds_allowin)
            if_next_state <= if_empty;
        else
            if_next_state <= if_full;
    end
end

always @(*)
begin
    if(preif_current_state[0])
    begin
        /*if(handshake)
            preif_next_state <= preif_inst;
        else
            preif_next_state <= preif_req;*/
        if(~br_taken)
        begin
            if(handshake)
                preif_next_state <= preif_inst;
            else
                preif_next_state <= preif_req;
        end
        else//if(br_taken)
        begin
            if(~handshake)
                preif_next_state <= preif_br_req;
            else
                preif_next_state <= preif_inst;
        end
    end
    else if(preif_current_state[1])
    begin
        if(~br_taken)
        begin
            if(inst_sram_data_ok)
            begin
                if(handshake)
                begin
                    preif_next_state <= preif_inst;
                end
                else
                begin
                    preif_next_state <= preif_req;
                end
            end
            else if(~inst_sram_data_ok)
            begin
                preif_next_state <= preif_inst;
            end
        end
        else// if(br taken)
        begin
            if(handshake)
            begin
                preif_next_state <= preif_inst;
            end
            else
            begin
                preif_next_state <= preif_br_req;
            end
        end
    end
    else if(preif_current_state[2])
    begin
        if(handshake)
        begin
            preif_next_state <= preif_inst;
        end
        else
        begin
            preif_next_state <= preif_br_req;
        end
    end
end

// PC update
always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1BFFFFFC;  // make nextpc=0x1C000000;
    end
    else if (fs_allowin & inst_sram_req & inst_sram_addr_ok) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_req = fs_allowin & (preif_current_state[0] | (preif_current_state[1] & inst_sram_data_ok & fs_allowin) | preif_current_state[2]);
// FIXME: reconstruct inst_sram
// interface with sram
assign inst_sram_we     = 4'h0;
assign inst_sram_en     = fs_allowin && ~reset;
assign inst_sram_addr   = nextpc;
assign inst_sram_wdata  = 32'h0;
assign fs_inst          = inst_sram_rdata;

endmodule
