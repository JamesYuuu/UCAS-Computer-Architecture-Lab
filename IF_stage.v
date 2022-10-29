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

// instruction buffer
reg [31:0] inst_buff;
reg inst_buff_valid;

// to detech adef
wire adef_detected;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        pre_fs_ready_go;
wire        to_fs_valid;

// signals for pc
wire [31:0] seq_pc;
wire [31:0] nextpc;

// signals from branch
wire        br_taken;
wire [31:0] br_target;
wire        br_stall;
assign {br_stall,br_taken,br_target} = br_bus;

// signals to output for ID_stage
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {adef_detected,fs_inst,fs_pc};

// pre-IF stage
assign pre_fs_ready_go = inst_sram_req && inst_sram_addr_ok;
assign to_fs_valid  = pre_fs_ready_go & ~reset;
assign seq_pc       =   fs_pc + 3'h4;
assign nextpc       =   wb_ex       ? csr_eentry :
                        wb_ertn     ? csr_era   :
                        br_taken    ? br_target : seq_pc;

assign adef_detected = nextpc[1:0] == 2'b00 ? 0 : 1;

// IF stage
assign fs_ready_go     = inst_sram_data_ok || inst_buff_valid;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid  = fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

// buffer
reg [31:0]  nextpc_buf;
reg         br_taken_buf;
wire [31:0]  final_nextpc;
assign final_nextpc = br_taken_buf ? nextpc_buf : nextpc;

// PC update
always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1BFFFFFC;  // make nextpc=0x1C000000;
    end
    else if (fs_allowin & to_fs_valid) begin
        fs_pc <= final_nextpc;
    end
end

always @(posedge clk)
begin
    if (reset)
    begin
        inst_buff <= 32'b0;
        inst_buff_valid <= 1'b0;
    end
    else if (!ds_allowin & fs_ready_go)
    begin
        inst_buff <= inst_sram_rdata;
        inst_buff_valid <= 1'b1;
    end
    else
    begin
        inst_buff <= 32'b0;
        inst_buff_valid <= 1'b0;
    end
end

// interface with sram
assign inst_sram_req    = fs_allowin;
assign inst_sram_addr   = final_nextpc;
assign inst_sram_wr     = 1'b0;
assign inst_sram_wstrb  = 4'b0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wdata  = 32'b0;

assign fs_inst          = inst_buff_valid ? inst_buff : inst_sram_rdata;

always @(posedge clk) begin
    if (reset) begin
        nextpc_buf <= 32'b0;
    end
    else if (br_taken && ~br_stall) begin
        nextpc_buf <= nextpc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        br_taken_buf <= 1'b0;
    end
    else if (br_taken_buf && pre_fs_ready_go && fs_allowin) begin
        br_taken_buf <= 1'b0;
    end
    else if (br_taken && ~br_stall && ~pre_fs_ready_go) begin
        br_taken_buf <= br_taken;
    end
end

endmodule
