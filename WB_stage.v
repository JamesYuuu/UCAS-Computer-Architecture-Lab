module WB_stage(
    input               clk,
    input               reset,
    // allowin
    output              ws_allowin,
    // input from ID stage
    input               ms_to_ws_valid,
    input   [69:0]      ms_to_ws_bus,
    // output for reg_file
    output  [37:0]      rf_bus,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we  ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

wire        gr_we;
wire [31:0] final_result;
wire [31:0] pc;
wire [4: 0] dest;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

assign rf_we    = gr_we && ws_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

reg         ws_valid;
wire        ws_ready_go;
reg  [69:0] ms_to_ws_bus_r;
 
assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

//deal with input and output
assign {gr_we,dest,final_result,pc}=ms_to_ws_bus_r;
assign rf_bus={rf_we,rf_waddr,rf_wdata};

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule