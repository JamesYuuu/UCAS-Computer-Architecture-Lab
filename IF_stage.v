module IF_stage(
    input           clk,
    input           reset,
    // allowin from ID stage
    input           ds_allowin,
    // branch bus
    input   [33:0]  br_bus,
    // output to ID stage
    output          fs_to_ds_valid,
    output  [63:0]  fs_to_ds_bus,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata
);

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
assign fs_to_ds_bus = {fs_inst,fs_pc};

// pre-IF stage
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

// IF stage
assign fs_ready_go     = 1'b1;
assign fs_allowin      = !fs_valid || fs_ready_go && ds_allowin;
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

// PC update
always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1BFFFFFC;  // make nexpc=0x1C000000;
    end
    else if (fs_allowin) begin
        fs_pc <= nextpc;
    end
end

// interface with sram
assign inst_sram_we     = 4'h0;
assign inst_sram_en     = fs_allowin && ~reset;
assign inst_sram_addr   = nextpc;
assign inst_sram_wdata  = 32'h0;
assign fs_inst          = inst_sram_rdata;

endmodule
