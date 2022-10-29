module IF_stage(
    input           clk,
    input           reset,
    // allowin
    input           ds_allowin,
    output          fs_allowin,
    // output to ID stage
    output          fs_to_ds_valid,
    output  [64:0]  fs_to_ds_bus,
    // input from perIF stage
    input           to_fs_valid,
    input   [33:0]  to_fs_bus,
    // inst sram interface
    input   [31:0]  inst_sram_rdata,     // read data
    input           inst_sram_data_ok    // if data has been written or given back
);

// instruction buffer
reg         [31:0] inst_buff;
reg         inst_buff_valid;

// control signals
reg         fs_valid;
wire        fs_ready_go;

reg  [32:0] to_fs_bus_r;
wire [31:0] fs_inst;
wire [31:0] fs_pc;
wire        br_taken_cancel;

assign  fs_ready_go     = inst_sram_data_ok || inst_buff_valid;
assign  fs_allowin      = !fs_valid || fs_ready_go && ds_allowin;
assign  fs_to_ds_valid  = fs_valid && fs_ready_go;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end
    if (fs_allowin & to_fs_valid) begin
        to_fs_bus_r <= to_fs_bus;
    end
end

// input from preIF to IF bus
assign  {br_taken_cancel,adef_detected,fs_pc} = to_fs_bus_r;

// output for ID_stage
assign fs_to_ds_bus = {adef_detected,fs_inst,fs_pc};

assign fs_inst      = (inst_buff_valid) ? inst_buff : inst_sram_rdata;

endmodule
