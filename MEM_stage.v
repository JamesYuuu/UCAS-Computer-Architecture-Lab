module MEM_stage(
    input   wire            clk,
    input   wire            reset,
    // allowin
    input   wire            ws_allowin,
    output  wire            ms_allowin,
    // input from EXE stage
    input   wire            es_to_ms_valid,
    input   wire [70:0]     es_to_ms_bus,
    // output for WB stage
    output  wire            ms_to_ws_valid,
    output  wire [69:0]     ms_to_ws_bus,
    // data sram interface
    input   wire [31:0]     data_sram_rdata,
    // output ms_valid and ms_to_ds_bus to ID stage
    output                  out_ms_valid
);

wire        gr_we;
wire        res_from_mem;
wire [31:0] pc;
wire [4: 0] dest;
wire [31:0] mem_result;
wire [31:0] final_result;

wire [31:0] alu_result;

reg         ms_valid;
wire        ms_ready_go;
reg  [70:0] es_to_ms_bus_r;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
// deal with input and output
assign {res_from_mem,gr_we,dest,alu_result,pc}=es_to_ms_bus_r;
assign ms_to_ws_bus={gr_we,dest,final_result,pc};

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

wire   out_ms_valid;
assign out_ms_valid = ms_valid;

endmodule